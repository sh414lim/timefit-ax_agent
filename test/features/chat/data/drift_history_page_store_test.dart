import 'dart:async';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/message_dao.dart';
import 'package:timefit_native/features/chat/application/history_controller.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/drift_history_page_store.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';

class FixtureSource implements HistoryPageSource {
  late HistoryPage page;
  @override
  Future<HistoryPage> loadBefore(HistoryRequest request) async => page;
}

class PauseInsert extends QueryInterceptor {
  bool enabled = false;
  final entered = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (enabled && statement.contains('local_messages')) {
      enabled = false;
      entered.complete();
      await resume.future;
    }
    return super.runInsert(executor, statement, args);
  }
}

void main() {
  late AppDatabase db;
  late MessageRepositoryImpl repository;
  late HistoryController controller;
  late FixtureSource source;
  late PauseInsert pause;
  final now = DateTime.utc(2026, 10, 20);
  CanonicalLocalMessage message(
    int seq, {
    String? client,
    String conversation = 'one',
    String? server,
  }) => CanonicalLocalMessage(
    serverId: server ?? 'server-$seq',
    conversationId: conversation,
    clientMessageId: client ?? 'client-$seq',
    sequence: seq,
    senderKind: 'user',
    bodyText: 'body',
    messageKind: 'text',
    serverCreatedAt: now,
  );
  CanonicalHistoryPage page(List<CanonicalLocalMessage> messages) =>
      CanonicalHistoryPage(
        conversationId: 'one',
        canonicalMessages: messages,
        hasMoreBefore: false,
      );
  setUp(() {
    pause = PauseInsert();
    db = AppDatabase(NativeDatabase.memory().interceptWith(pause));
    repository = MessageRepositoryImpl(database: db);
    source = FixtureSource();
    controller = HistoryController(
      source: source,
      conversationId: 'one',
      earliestSequence: 4,
      persistence: DriftHistoryPageStore(database: db),
    );
    source.page = page([message(1), message(2), message(3)]);
  });
  tearDown(() async {
    controller.dispose();
    await repository.dispose();
    await db.close();
  });

  test(
    'atomic page becomes visible through repository watch and only then advances cursor',
    () async {
      final values = <List<int?>>[];
      final visible = Completer<void>();
      final subscription = repository.watchCachedMessages('one').listen((rows) {
        values.add(rows.map((row) => row.sequence).toList());
        if (rows.length == 3 && !visible.isCompleted) visible.complete();
      });
      await controller.loadMore();
      await visible.future;
      expect(values.where((rows) => rows.isNotEmpty), everyElement([1, 2, 3]));
      expect(controller.state.beforeSequence, 1);
      expect(
        (await repository.readCachedMessages('one')).map((m) => m.sequence),
        [1, 2, 3],
      );
      await subscription.cancel();
    },
  );
  test(
    'page insert failure rolls back all rows and cursor; same page retries',
    () async {
      await db.customStatement(
        "CREATE TRIGGER fail_page BEFORE INSERT ON local_messages WHEN NEW.sequence = 2 BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      expect(await controller.loadMore(), equals(null));
      expect(await db.messageDao.getAll(), isEmpty);
      expect(controller.state.beforeSequence, 4);
      expect(controller.state.failure, HistoryFailure.persistenceFailed);
      await db.customStatement('DROP TRIGGER fail_page');
      expect(await controller.retry(), isNotNull);
      expect(await db.messageDao.getAll(), hasLength(3));
      expect(controller.state.beforeSequence, 1);
    },
  );
  test('cross-conversation metadata cannot hide in projected page', () async {
    source.page = page([
      message(1),
      message(2, conversation: 'other'),
      message(3),
    ]);
    expect(await controller.loadMore(), equals(null));
    expect(await db.messageDao.getAll(), isEmpty);
    expect(controller.state.beforeSequence, 4);
  });
  test('server identity conflict rolls back preceding page writes', () async {
    await db.messageDao.upsertCanonical(
      message(9, conversation: 'other', server: 'server-2'),
      fallbackLocalId: 'existing',
      fallbackClientCreatedAt: now,
    );
    expect(await controller.loadMore(), equals(null));
    final rows = await db.messageDao.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.conversationId, 'other');
    expect(controller.state.beforeSequence, 4);
  });
  test(
    'duplicate canonical is one row; pending local message and command are promoted',
    () async {
      final send = SendMessage(
        database: db,
        clock: () => now,
        clientMessageId: () => 'client-2',
      );
      await send.submit(conversationId: 'one', bodyText: 'body');
      await db.messageDao.upsertCanonical(
        message(3),
        fallbackLocalId: 'already-canonical',
        fallbackClientCreatedAt: now,
      );
      source.page = page([message(1), message(2), message(2), message(3)]);
      expect(await controller.loadMore(), isNotNull);
      final rows = await db.messageDao.getAll();
      expect(rows, hasLength(3));
      final promoted = rows.singleWhere((m) => m.clientMessageId == 'client-2');
      expect(promoted.localId, 'client-2');
      expect(promoted.deliveryState, 'sent');
      expect((await db.outboxDao.getAll()).single.state, 'completed');
    },
  );
  test(
    'repository dispose during paused page write drains rollback and leaves cursor',
    () async {
      pause.enabled = true;
      final loading = controller.loadMore();
      await pause.entered.future;
      var closed = false;
      final closing = repository.dispose().then((_) {
        closed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      pause.resume.complete();
      await closing;
      expect(await loading, equals(null));
      expect(await db.messageDao.getAll(), isEmpty);
      expect(controller.state.beforeSequence, 4);
      expect(await controller.retry(), equals(null));
      expect(await db.messageDao.getAll(), isEmpty);
    },
  );
  test('conversation switch during paused write rolls back old page', () async {
    pause.enabled = true;
    final loading = controller.loadMore();
    await pause.entered.future;
    controller.switchConversation(conversationId: 'two', earliestSequence: 4);
    pause.resume.complete();
    expect(await loading, equals(null));
    // Wait for the DB queue after the cancelled transaction to finish.
    await db.customSelect('SELECT 1').get();
    expect(await db.messageDao.getAll(), isEmpty);
    expect(controller.state.conversationId, 'two');
    expect(controller.state.beforeSequence, 4);
  });
}
