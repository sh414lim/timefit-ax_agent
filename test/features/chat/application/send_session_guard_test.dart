import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart'
    show ExternalSessionTransactionException;
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/message_reconciler.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';

class PausedWrite extends QueryInterceptor {
  bool pauseInsert = false;
  bool pauseUpdate = false;
  String updateTable = 'local_messages';
  final entered = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (pauseInsert && statement.contains('local_messages')) {
      entered.complete();
      await resume.future;
    }
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (pauseUpdate && statement.contains(updateTable)) {
      entered.complete();
      await resume.future;
    }
    return super.runUpdate(executor, statement, args);
  }
}

void main() {
  late AppDatabase db;
  late PausedWrite pause;
  late SendMessage send;
  late MessageRepositoryImpl repository;
  late MessageReconciler reconciler;
  final now = DateTime.utc(2026, 10, 20);
  setUp(() {
    pause = PausedWrite();
    db = AppDatabase(NativeDatabase.memory().interceptWith(pause));
    // Default DB scope is shared even without explicit injection.
    send = SendMessage(
      database: db,
      clock: () => now,
      clientMessageId: () => 'client',
    );
    repository = MessageRepositoryImpl(database: db);
    reconciler = MessageReconciler(database: db, clock: () => now);
  });
  tearDown(() async {
    await repository.dispose();
    await db.close();
  });
  Future<LocalTextCommand> submit() =>
      send.submit(conversationId: 'conversation', bodyText: 'body');
  CanonicalTextMessage canonical() => CanonicalTextMessage(
    serverId: 'server',
    conversationId: 'conversation',
    clientMessageId: 'client',
    sequence: 1,
    bodyText: 'body',
    serverCreatedAt: now,
  );

  test(
    'old submit retry and reconcile handles reject writes after repository dispose',
    () async {
      await submit();
      await repository.dispose();
      await expectLater(submit(), throwsA(isA<LocalRepositoryException>()));
      await expectLater(
        send.retry('client'),
        throwsA(isA<LocalRepositoryException>()),
      );
      await expectLater(
        reconciler.reconcile(commandId: 'client', canonical: canonical()),
        throwsA(isA<LocalRepositoryException>()),
      );
      expect((await db.messageDao.getAll()).single.serverId, equals(null));
      await db.purgeChatData();
      await expectLater(submit(), throwsA(isA<LocalRepositoryException>()));
      expect(await db.messageDao.getAll(), isEmpty);
      expect(await db.outboxDao.getAll(), isEmpty);
    },
  );

  test('dispose waits for paused insert rollback before purge', () async {
    pause.pauseInsert = true;
    final operation = submit();
    final rejected = expectLater(
      operation,
      throwsA(isA<LocalRepositoryException>()),
    );
    await pause.entered.future;
    var disposed = false;
    final closing = repository.dispose().then((_) {
      disposed = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(disposed, isFalse);
    pause.resume.complete();
    await rejected;
    await closing;
    expect(await db.messageDao.getAll(), isEmpty);
    expect(await db.outboxDao.getAll(), isEmpty);
    await db.purgeChatData();
  });

  test('dispose drains and rolls back paused retry state transition', () async {
    await submit();
    final lease = (await db.outboxDao.claim(now, 'lease'))!;
    await db.outboxDao.finish(
      lease,
      now,
      state: 'failed_permanent',
      failures: 8,
      errorCode: 'retry_exhausted',
    );
    pause.updateTable = 'outbox_commands';
    pause.pauseUpdate = true;
    final rejected = expectLater(
      send.retry('client'),
      throwsA(isA<LocalRepositoryException>()),
    );
    await pause.entered.future;
    final closing = repository.dispose();
    pause.resume.complete();
    await rejected;
    await closing;
    expect((await db.outboxDao.getAll()).single.state, 'failed_permanent');
    expect((await db.outboxDao.getAll()).single.attemptCount, 8);
  });

  test(
    'external transaction rejects submit retry and reconcile before writing',
    () async {
      await submit();
      await db.transaction(() async {
        await expectLater(
          submit(),
          throwsA(isA<ExternalSessionTransactionException>()),
        );
        await expectLater(
          send.retry('client'),
          throwsA(isA<ExternalSessionTransactionException>()),
        );
        await expectLater(
          reconciler.reconcile(commandId: 'client', canonical: canonical()),
          throwsA(isA<ExternalSessionTransactionException>()),
        );
      });
      expect((await db.messageDao.getAll()).single.serverId, equals(null));
      expect((await db.outboxDao.getAll()).single.state, 'queued');
    },
  );

  test(
    'external transaction can dispose after rejected write without deadlock',
    () async {
      await db.transaction(() async {
        await expectLater(
          submit(),
          throwsA(isA<ExternalSessionTransactionException>()),
        );
        await expectLater(
          repository.dispose().timeout(const Duration(seconds: 2)),
          throwsA(isA<ExternalSessionTransactionException>()),
        );
      });
      await repository.dispose();
      await db.purgeChatData();
      expect(await db.messageDao.getAll(), isEmpty);
      expect(await db.outboxDao.getAll(), isEmpty);
      await expectLater(submit(), throwsA(isA<LocalRepositoryException>()));
    },
  );

  test(
    'external dispose cannot deadlock a guarded write queued behind it',
    () async {
      final entered = Completer<void>();
      final disposeInside = Completer<void>();
      final outer = db.transaction(() async {
        entered.complete();
        await disposeInside.future;
        await expectLater(
          repository.dispose().timeout(const Duration(seconds: 2)),
          throwsA(isA<ExternalSessionTransactionException>()),
        );
      });
      await entered.future;
      final rejected = expectLater(
        submit(),
        throwsA(isA<LocalRepositoryException>()),
      );
      disposeInside.complete();
      await outer;
      await rejected;
      await repository.dispose();
      await db.purgeChatData();
      expect(await db.messageDao.getAll(), isEmpty);
      expect(await db.outboxDao.getAll(), isEmpty);
    },
  );

  test(
    'dispose during canonical update rolls back promotion then allows purge',
    () async {
      await submit();
      pause.pauseUpdate = true;
      final operation = reconciler.reconcile(
        commandId: 'client',
        canonical: canonical(),
      );
      final rejected = expectLater(
        operation,
        throwsA(isA<LocalRepositoryException>()),
      );
      await pause.entered.future;
      var disposed = false;
      final closing = repository.dispose().then((_) {
        disposed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(disposed, isFalse);
      pause.resume.complete();
      await rejected;
      await closing;
      expect((await db.messageDao.getAll()).single.serverId, equals(null));
      expect((await db.outboxDao.getAll()).single.state, 'queued');
      await db.purgeChatData();
      expect(await db.messageDao.getAll(), isEmpty);
    },
  );
}
