import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/production_chat_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/infrastructure/production_chat_transport.dart';

const requestId = '11111111-1111-4111-8111-111111111111';
const conversationId = '22222222-2222-4222-8222-222222222222';
const assistantId = '33333333-3333-4333-8333-333333333333';
final scope = ProductionChatScope(
  tenantId: '44444444-4444-4444-8444-444444444444',
  conversationId: conversationId,
);

ProductionChatTurn turn(String state, {String? digest}) => ProductionChatTurn(
  sequence: 1,
  requestId: requestId,
  assistantId: assistantId,
  bodySha256: digest ?? productionBodyDigest('질문'),
  state: state,
  answer: state == 'complete' ? '답변' : null,
);

class Api implements ProductionChatApi {
  ProductionChatTurn? result;
  Object? sendFailure;
  Object? lookupFailure;
  Future<void> Function()? afterLookup;
  Future<void> Function()? beforeSend;
  int sends = 0;
  int lookups = 0;

  @override
  Future<ProductionChatTurn?> lookup(
    ProductionChatScope scope,
    String id,
  ) async {
    lookups++;
    expect(id, requestId);
    if (lookupFailure != null) throw lookupFailure!;
    await afterLookup?.call();
    return result;
  }

  @override
  Future<ProductionChatTurn> send(
    ProductionChatScope scope,
    String id,
    String body,
  ) async {
    sends++;
    expect(id, requestId);
    await beforeSend?.call();
    if (sendFailure != null) throw sendFailure!;
    return result = turn('complete');
  }
}

void main() {
  late AppDatabase db;
  late DateTime now;
  late Api api;
  var current = true;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 25);
    api = Api();
    current = true;
    await db
        .into(db.localConversations)
        .insert(
          LocalConversationsCompanion.insert(
            id: conversationId,
            serverCreatedAt: now,
            serverUpdatedAt: now,
            lastSyncedAt: now,
          ),
        );
    await SendMessage(
      database: db,
      clock: () => now,
      clientMessageId: () => requestId,
    ).submit(conversationId: conversationId, bodyText: '질문');
  });
  tearDown(() => db.close());

  OutboxWorker worker() => OutboxWorker(
    dao: db.outboxDao,
    scope: 'test-${identityHashCode(db)}',
    clock: () => now,
    retryPolicy: RetryPolicy(() => 0.5),
    executor: ProductionChatExecutor(
      database: db,
      session: LocalRepositorySession.forDatabase(db),
      api: api,
      scope: scope,
      clock: () => now,
      isCurrentSession: () => current,
    ),
  );

  test(
    'lookup then one send stores original user and stable assistant identity',
    () async {
      await worker().wake();
      expect(api.lookups, 1);
      expect(api.sends, 1);
      final rows = await db.messageDao.readTimeline(conversationId);
      expect(rows.map((r) => r.localId), [
        requestId,
        'production-assistant:$assistantId',
      ]);
      expect(rows.every((r) => r.deliveryState == 'sent'), isTrue);
      expect((await db.outboxDao.getAll()).single.state, 'completed');
    },
  );

  test(
    'unknown command outcome persists quarantine across DB close and reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('production-outbox-');
      addTearDown(() => dir.delete(recursive: true));
      // Move this test to a real file without changing any application database.
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/app.sqlite')));
      await db
          .into(db.localConversations)
          .insert(
            LocalConversationsCompanion.insert(
              id: conversationId,
              serverCreatedAt: now,
              serverUpdatedAt: now,
              lastSyncedAt: now,
            ),
          );
      await SendMessage(
        database: db,
        clock: () => now,
        clientMessageId: () => requestId,
      ).submit(conversationId: conversationId, bodyText: '질문');
      api.sendFailure = const ProductionChatFailure(
        'timeout',
        commandSent: true,
      );
      await worker().wake();
      expect(api.sends, 1);
      expect(
        (await db.outboxDao.getAll()).single.lastErrorCode,
        'production_outcome_unknown',
      );
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/app.sqlite')));
      now = now.add(const Duration(seconds: 2));
      await worker().wake();
      expect(api.sends, 1);
      expect(await db.outboxDao.getAll(), hasLength(1));
      expect((await db.messageDao.getAll()).single.deliveryState, 'pending');
      // A later durable lookup resolves the same ID without another send.
      api.result = turn('complete');
      now = now.add(const Duration(seconds: 2));
      await worker().wake();
      expect(api.sends, 1);
      expect(await db.messageDao.getAll(), hasLength(2));
      expect((await db.outboxDao.getAll()).single.state, 'completed');
    },
  );

  test(
    'dispatch marker is committed before the command leaves the app',
    () async {
      api.beforeSend = () async {
        expect(
          (await db.outboxDao.getAll()).single.lastErrorCode,
          'production_dispatch_started',
        );
      };
      await worker().wake();
      expect(api.sends, 1);
    },
  );

  test(
    'proved pre-dispatch failure permits a retry with the same ID',
    () async {
      api.sendFailure = const ProductionChatFailure('unavailable');
      await worker().wake();
      expect(
        (await db.outboxDao.getAll()).single.lastErrorCode,
        'production_transport_unavailable',
      );
      api.sendFailure = null;
      now = now.add(const Duration(seconds: 2));
      await worker().wake();
      expect(api.sends, 2);
      expect(await db.outboxDao.getAll(), hasLength(1));
    },
  );

  test('dispatch_unknown acknowledges only a durable user row', () async {
    api.result = turn('dispatch_unknown');
    await worker().wake();
    expect(api.sends, 0);
    expect(await db.messageDao.getAll(), hasLength(1));
    expect((await db.messageDao.getAll()).single.deliveryState, 'sent');
    expect(
      (await db.outboxDao.getAll()).single.lastErrorCode,
      'production_dispatch_unknown',
    );
  });

  test(
    'authentication loss never clears a prior uncertain dispatch marker',
    () async {
      api.sendFailure = const ProductionChatFailure(
        'timeout',
        commandSent: true,
      );
      await worker().wake();
      api.lookupFailure = const ProductionChatFailure(
        'production_auth_required',
      );
      now = now.add(const Duration(seconds: 2));
      await worker().wake();
      expect(
        (await db.outboxDao.getAll()).single.lastErrorCode,
        'production_outcome_unknown',
      );
      api.lookupFailure = null;
      api.sendFailure = null;
      now = now.add(const Duration(seconds: 2));
      await worker().wake();
      expect(api.sends, 1);
    },
  );

  test('changed body digest never acknowledges the local message', () async {
    api.result = turn('complete', digest: 'a' * 64);
    await worker().wake();
    expect(api.sends, 0);
    expect((await db.messageDao.getAll()).single.deliveryState, 'pending');
    expect((await db.outboxDao.getAll()).single.state, 'retry_wait');
  });

  test(
    'logout while lookup is in flight prevents local writes and dispatch',
    () async {
      api.result = turn('complete');
      api.afterLookup = () async {
        current = false;
      };
      await worker().wake();
      expect(api.sends, 0);
      expect((await db.messageDao.getAll()).single.deliveryState, 'pending');
    },
  );

  test('expired lease prevents applying even a complete response', () async {
    api.result = turn('complete');
    api.afterLookup = () async {
      now = now.add(const Duration(seconds: 61));
    };
    await worker().wake();
    expect(api.sends, 0);
    expect((await db.messageDao.getAll()).single.deliveryState, 'pending');
  });

  test(
    'lease expiry during send is recovered by lookup without a second dispatch',
    () async {
      api.beforeSend = () async {
        now = now.add(const Duration(seconds: 61));
      };
      await worker().wake();
      expect((await db.messageDao.getAll()).single.deliveryState, 'pending');
      expect(
        (await db.outboxDao.getAll()).single.lastErrorCode,
        'production_dispatch_started',
      );
      now = now.add(const Duration(seconds: 2));
      await worker().wake();
      expect(api.sends, 1);
      expect(await db.messageDao.getAll(), hasLength(2));
    },
  );
}
