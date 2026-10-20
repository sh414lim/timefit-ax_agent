import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/message_dao.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/message_reconciler.dart';

void main() {
  late AppDatabase db;
  late SendMessage send;
  late MessageReconciler reconciler;
  late int ids;
  final now = DateTime.utc(2026, 10, 20);
  setUp(() {
    ids = 0;
    db = AppDatabase(NativeDatabase.memory());
    send = SendMessage(
      database: db,
      clock: () => now,
      clientMessageId: () => 'client-${++ids}',
    );
    reconciler = MessageReconciler(database: db, clock: () => now);
  });
  tearDown(() => db.close());
  CanonicalTextMessage canonical({
    String id = 'client-1',
    String conversation = 'conversation',
    String body = ' body\ntext ',
    String server = 'server',
    int sequence = 1,
  }) => CanonicalTextMessage(
    serverId: server,
    conversationId: conversation,
    clientMessageId: id,
    sequence: sequence,
    bodyText: body,
    serverCreatedAt: now,
  );
  Future<LocalTextCommand> submit() =>
      send.submit(conversationId: 'conversation', bodyText: ' body\r\ntext ');

  test(
    'initial submission generates one ID and persists bubble plus local payload',
    () async {
      final command = await submit();
      expect(ids, 1);
      final message = (await db.messageDao.getAll()).single;
      final stored = (await db.outboxDao.getAll()).single;
      expect(message.clientMessageId, command.id);
      expect(message.deliveryState, 'pending');
      expect(message.bodyText, ' body\ntext ');
      expect(stored.payloadJson, command.encode());
      expect(stored.clientRequestId, command.id);
    },
  );

  test('outbox insert failure rolls back optimistic message', () async {
    await db.customStatement(
      "CREATE TRIGGER reject_outbox BEFORE INSERT ON outbox_commands BEGIN SELECT RAISE(ABORT, 'fixture'); END",
    );
    await expectLater(submit(), throwsA(isA<SqliteException>()));
    expect(await db.messageDao.getAll(), isEmpty);
    expect(await db.outboxDao.getAll(), isEmpty);
  });

  test(
    'synthetic Broadcast-before-RPC and duplicate promote one sent row',
    () async {
      await submit();
      await Future.wait([
        reconciler.reconcile(commandId: 'client-1', canonical: canonical()),
        reconciler.reconcile(commandId: 'client-1', canonical: canonical()),
      ]);
      await reconciler.reconcile(commandId: 'client-1', canonical: canonical());
      final row = (await db.messageDao.getAll()).single;
      expect(row.localId, 'client-1');
      expect(row.serverId, 'server');
      expect(row.sequence, 1);
      expect(row.deliveryState, 'sent');
      expect((await db.outboxDao.getAll()).single.state, 'completed');
    },
  );

  test(
    'timeout retry retains same ID payload and canonical sequence',
    () async {
      final command = await submit();
      final lease = (await db.outboxDao.claim(now, 'lease'))!;
      await db.outboxDao.finish(
        lease,
        now,
        state: 'retry_wait',
        failures: 1,
        nextAttemptAt: now.add(const Duration(seconds: 1)),
        errorCode: 'timeout',
      );
      final retry = (await db.outboxDao.claim(
        now.add(const Duration(seconds: 1)),
        'retry',
      ))!;
      expect(retry.clientRequestId, command.id);
      expect(retry.payloadJson, command.encode());
      await reconciler.reconcile(commandId: command.id, canonical: canonical());
      expect((await db.messageDao.getAll()).single.sequence, 1);
      expect(ids, 1);
      expect(
        await db.outboxDao.finish(
          retry,
          now.add(const Duration(seconds: 1)),
          state: 'completed',
          failures: 1,
        ),
        isFalse,
      );
    },
  );

  test(
    'user retry requeues same persisted command without generating ID',
    () async {
      final command = await submit();
      final lease = (await db.outboxDao.claim(now, 'lease'))!;
      await db.outboxDao.finish(
        lease,
        now,
        state: 'failed_permanent',
        failures: 8,
        errorCode: 'retry_exhausted',
      );
      expect(await send.retry(command.id), isTrue);
      final stored = (await db.outboxDao.getAll()).single;
      expect(stored.id, command.id);
      expect(stored.payloadJson, command.encode());
      expect(ids, 1);
    },
  );

  test(
    'payload mismatch is permanent local failure and cannot be retried',
    () async {
      await submit();
      expect(
        await reconciler.reconcile(
          commandId: 'client-1',
          canonical: canonical(body: 'different'),
        ),
        ReconciliationResult.permanentFailure,
      );
      final row = (await db.messageDao.getAll()).single;
      expect(row.serverId, equals(null));
      expect(row.bodyText, ' body\ntext ');
      expect(row.deliveryState, 'failed');
      expect(
        (await db.outboxDao.getAll()).single.lastErrorCode,
        'payload_mismatch',
      );
      expect(await send.retry('client-1'), isFalse);
    },
  );

  test(
    'cross-conversation or client canonical rolls back with original unchanged',
    () async {
      await submit();
      for (final input in [
        canonical(conversation: 'another'),
        canonical(id: 'another'),
      ]) {
        await expectLater(
          reconciler.reconcile(commandId: 'client-1', canonical: input),
          throwsA(isA<CanonicalIdentityConflict>()),
        );
      }
      expect((await db.messageDao.getAll()).single.deliveryState, 'pending');
      expect((await db.outboxDao.getAll()).single.state, 'queued');
    },
  );

  test('canonical server identity collision never moves other row', () async {
    await submit();
    await db.messageDao.upsertCanonical(
      CanonicalLocalMessage(
        serverId: 'server',
        conversationId: 'other',
        clientMessageId: 'other',
        sequence: 1,
        senderKind: 'user',
        bodyText: 'other',
        messageKind: 'text',
        serverCreatedAt: now,
      ),
      fallbackLocalId: 'other',
      fallbackClientCreatedAt: now,
    );
    await expectLater(
      reconciler.reconcile(commandId: 'client-1', canonical: canonical()),
      throwsA(isA<CanonicalIdentityConflict>()),
    );
    expect(
      (await db.messageDao.getAll())
          .singleWhere((row) => row.localId == 'other')
          .conversationId,
      'other',
    );
    expect((await db.outboxDao.getAll()).single.state, 'queued');
  });

  test(
    'cancelled command ignores late response without promoting bubble',
    () async {
      await submit();
      await db.outboxDao.cancel('client-1', now);
      expect(
        await reconciler.reconcile(
          commandId: 'client-1',
          canonical: canonical(),
        ),
        ReconciliationResult.cancelled,
      );
      expect((await db.messageDao.getAll()).single.serverId, equals(null));
      expect((await db.outboxDao.getAll()).single.state, 'cancelled');
    },
  );

  test(
    'reconciliation failure rolls back promotion and command state together',
    () async {
      await submit();
      await db.customStatement(
        "CREATE TRIGGER reject_complete BEFORE UPDATE ON outbox_commands WHEN NEW.state = 'completed' BEGIN SELECT RAISE(ABORT, 'fixture'); END",
      );
      await expectLater(
        reconciler.reconcile(commandId: 'client-1', canonical: canonical()),
        throwsA(isA<SqliteException>()),
      );
      expect((await db.messageDao.getAll()).single.serverId, equals(null));
      expect((await db.messageDao.getAll()).single.deliveryState, 'pending');
      expect((await db.outboxDao.getAll()).single.state, 'queued');
    },
  );
}
