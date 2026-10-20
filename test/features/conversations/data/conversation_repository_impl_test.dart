import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/conversations/application/conversation_list_controller.dart';
import 'package:timefit_native/features/conversations/data/conversation_repository_impl.dart';
import 'package:timefit_native/features/conversations/domain/repositories/conversation_repository.dart';

class ConversationReadProbe extends QueryInterceptor {
  int selects = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('FROM local_conversations c')) selects++;
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  late AppDatabase db;
  late ConversationRepositoryImpl repository;
  late ConversationReadProbe probe;
  final now = DateTime.utc(2026, 10, 20);
  setUp(() {
    probe = ConversationReadProbe();
    db = AppDatabase(NativeDatabase.memory().interceptWith(probe));
    repository = ConversationRepositoryImpl(database: db);
  });
  tearDown(() async {
    await repository.dispose();
    await db.close();
  });
  Future<void> insert(String id, {String status = 'active'}) =>
      db.conversationDao.upsert(
        LocalConversationsCompanion.insert(
          id: id,
          title: Value(id),
          status: Value(status),
          serverCreatedAt: now,
          serverUpdatedAt: now,
          lastSyncedAt: now,
        ),
      );

  test(
    'cached active list is sorted deterministically and watches immediately',
    () async {
      await insert('a');
      await insert('z');
      await insert('archived', status: 'archived');
      final rows = await repository.watchCachedConversations().first;
      expect(rows.map((row) => row.id), ['z', 'a']);
      expect(await repository.readCachedConversations(), hasLength(2));
    },
  );

  test(
    'existing controller retains local cache as stale without claiming refresh success',
    () async {
      await insert('cached');
      final controller = ConversationListController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.phase, ConversationListPhase.stale);
      expect(controller.state.conversations.single.id, 'cached');
      await expectLater(
        repository.refreshConversations(),
        throwsA(isA<ConversationRepositoryException>()),
      );
    },
  );

  test('empty cache and closed-session error remain distinct', () async {
    expect(await repository.readCachedConversations(), isEmpty);
    await repository.dispose();
    await expectLater(
      repository.readCachedConversations(),
      throwsA(isA<LocalRepositoryException>()),
    );
  });

  test(
    'preview join has no N+1 reads and enforces conversation identity',
    () async {
      await db
          .into(db.localMessages)
          .insert(
            LocalMessagesCompanion.insert(
              localId: 'message',
              serverId: const Value('server-message'),
              conversationId: 'one',
              clientMessageId: 'client',
              senderKind: 'user',
              bodyText: const Value('cached preview'),
              messageKind: 'text',
              clientCreatedAt: now,
            ),
          );
      for (final id in ['one', 'two']) {
        await db.conversationDao.upsert(
          LocalConversationsCompanion.insert(
            id: id,
            lastMessageId: const Value('server-message'),
            serverCreatedAt: now,
            serverUpdatedAt: now,
            lastSyncedAt: now,
          ),
        );
      }
      probe.selects = 0;
      final rows = await repository.readCachedConversations();
      expect(probe.selects, 1);
      expect(
        rows.singleWhere((row) => row.id == 'one').preview,
        'cached preview',
      );
      expect(rows.singleWhere((row) => row.id == 'two').preview, '');
    },
  );

  test('new session namespace cannot receive previous cache', () async {
    await insert('old-user-cache');
    await repository.dispose();
    await db.close();
    db = AppDatabase(NativeDatabase.memory());
    final next = ConversationRepositoryImpl(database: db);
    addTearDown(next.dispose);
    expect(await next.watchCachedConversations().first, isEmpty);
    await expectLater(
      repository.readCachedConversations(),
      throwsA(isA<LocalRepositoryException>()),
    );
  });
}
