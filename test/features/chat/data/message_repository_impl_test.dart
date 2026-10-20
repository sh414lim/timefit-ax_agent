import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';

class ReadProbe extends QueryInterceptor {
  int selects = 0;
  bool fail = false;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('FROM local_messages')) {
      selects++;
      if (fail) throw StateError('private database failure');
    }
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  late AppDatabase db;
  late MessageRepositoryImpl repository;
  late ReadProbe probe;
  final now = DateTime.utc(2026, 10, 20);
  setUp(() {
    probe = ReadProbe();
    db = AppDatabase(NativeDatabase.memory().interceptWith(probe));
    repository = MessageRepositoryImpl(database: db);
  });
  tearDown(() async {
    await repository.dispose();
    await db.close();
  });
  Future<void> insert(
    String id, {
    int? sequence,
    String conversation = 'one',
    DateTime? created,
  }) async {
    await db
        .into(db.localMessages)
        .insert(
          LocalMessagesCompanion.insert(
            localId: id,
            conversationId: conversation,
            clientMessageId: id,
            sequence: Value(sequence),
            senderKind: 'user',
            messageKind: 'text',
            bodyText: Value(id),
            clientCreatedAt: created ?? now,
          ),
        );
  }

  test(
    'canonical sequence then durable pending insertion order in one query',
    () async {
      await insert('pending-z', created: now.add(const Duration(days: 1)));
      await insert('canonical-2', sequence: 2);
      await insert('pending-a', created: now.subtract(const Duration(days: 1)));
      await insert('canonical-1', sequence: 1);
      await insert('other', conversation: 'two');
      probe.selects = 0;
      final rows = await repository.readCachedMessages('one');
      expect(rows.map((row) => row.clientMessageId), [
        'canonical-1',
        'canonical-2',
        'pending-z',
        'pending-a',
      ]);
      expect(rows.map((row) => row.clientMessageId).toSet(), hasLength(4));
      expect(probe.selects, 1);
    },
  );

  test('empty differs from sanitized local read failure', () async {
    expect(await repository.readCachedMessages('one'), isEmpty);
    probe.fail = true;
    await expectLater(
      repository.readCachedMessages('one'),
      throwsA(
        isA<LocalRepositoryException>().having(
          (e) => e.kind,
          'kind',
          LocalRepositoryFailure.readFailed,
        ),
      ),
    );
    await expectLater(
      repository.watchCachedMessages('one'),
      emitsError(isA<LocalRepositoryException>()),
    );
  });

  test(
    'watch emits cached data, updates once, cancels and isolates disposed session',
    () async {
      await insert('cached');
      final received = <List<String>>[];
      final first = Completer<void>();
      final second = Completer<void>();
      final done = Completer<void>();
      final subscription = repository.watchCachedMessages('one').listen((rows) {
        received.add(rows.map((row) => row.clientMessageId).toList());
        if (!first.isCompleted) {
          first.complete();
        } else if (!second.isCompleted) {
          second.complete();
        }
      }, onDone: done.complete);
      await first.future;
      expect(received.single, ['cached']);
      await insert('next');
      await second.future;
      await repository.dispose();
      await done.future;
      final readsAfterDispose = probe.selects;
      await insert('after-dispose');
      expect(received, hasLength(2));
      expect(probe.selects, readsAfterDispose);
      await subscription.cancel();
      await expectLater(
        repository.readCachedMessages('one'),
        throwsA(
          isA<LocalRepositoryException>().having(
            (e) => e.kind,
            'kind',
            LocalRepositoryFailure.sessionClosed,
          ),
        ),
      );
      final fresh = MessageRepositoryImpl(database: db);
      addTearDown(fresh.dispose);
      expect(await fresh.readCachedMessages('two'), isEmpty);
    },
  );
}
