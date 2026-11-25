import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/production_chat_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/infrastructure/production_chat_transport.dart';

void main() {
  final env = Platform.environment;
  final enabled = env['TIMEFIT_AX_TLS_FIXTURE'] == '1';
  test(
    'production HTTPS ticket WSS outbox five turns and restart recovery',
    () async {
      final origin = Uri.parse(env['TIMEFIT_AX_TLS_ORIGIN']!);
      final token = env['TIMEFIT_AX_TLS_TOKEN']!;
      final context = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificates(env['TIMEFIT_AX_TLS_CA']!);
      final api = ProductionChatTransport(
        origin: origin,
        allowedHosts: {origin.authority},
        accessToken: () async => token,
        clientFactory: () => HttpClient(context: context),
      );
      final scope = ProductionChatScope(
        tenantId: '11111111-1111-4111-8111-111111111111',
        conversationId: '22222222-2222-4222-8222-222222222222',
      );
      String id(int n) =>
          '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
      final dir = await Directory.systemTemp.createTemp('production-chat-app-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      var now = DateTime.now().toUtc();
      await db
          .into(db.localConversations)
          .insert(
            LocalConversationsCompanion.insert(
              id: scope.conversationId,
              serverCreatedAt: now,
              serverUpdatedAt: now,
              lastSyncedAt: now,
            ),
          );
      OutboxWorker worker() => OutboxWorker(
        dao: db.outboxDao,
        clock: () => now,
        scope: 'tls-process-${identityHashCode(db)}',
        retryPolicy: RetryPolicy(() => 0.5),
        executor: ProductionChatExecutor(
          database: db,
          session: LocalRepositorySession.forDatabase(db),
          api: api,
          scope: scope,
          isCurrentSession: () => true,
          clock: () => now,
        ),
      );
      Future<void> enqueue(int n, String body) => SendMessage(
        database: db,
        clock: () => now,
        clientMessageId: () => id(n),
      ).submit(conversationId: scope.conversationId, bodyText: body);
      for (var n = 1; n <= 5; n++) {
        await enqueue(n, 'synthetic-turn-$n');
        await worker().wake();
        final observed = (await db.outboxDao.getAll()).last;
        expect(
          observed.state,
          'completed',
          reason: 'turn=$n code=${observed.lastErrorCode}',
        );
      }
      final before = await db.messageDao.readTimeline(scope.conversationId);
      expect(before, hasLength(10));
      expect(before.every((r) => r.deliveryState == 'sent'), isTrue);
      final assistantIds = before
          .where((r) => r.senderKind == 'system')
          .map((r) => r.serverId)
          .toList();
      expect(assistantIds.toSet(), hasLength(5));

      // Simulate server commit followed by app death before the outbox finish.
      await (db.update(
        db.outboxCommands,
      )..where((r) => r.id.equals(id(1)))).write(
        OutboxCommandsCompanion(
          state: const Value('retry_wait'),
          nextAttemptAt: Value(now),
          lastErrorCode: const Value('production_dispatch_started'),
        ),
      );
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await worker().wake();
      final after = await db.messageDao.readTimeline(scope.conversationId);
      expect(after, hasLength(10));
      expect(
        after.where((r) => r.senderKind == 'system').map((r) => r.serverId),
        assistantIds,
      );
      expect((await db.outboxDao.getAll()).first.state, 'completed');

      // An uncertain provider result stays terminal, with no invented assistant.
      await enqueue(6, 'synthetic-failure');
      await worker().wake();
      expect((await db.outboxDao.getAll()).last.state, 'completed');
      expect(
        (await db.outboxDao.getAll()).last.lastErrorCode,
        'production_dispatch_unknown',
      );
      expect(
        await db.messageDao.readTimeline(scope.conversationId),
        hasLength(11),
      );

      // A persisted dispatch marker plus absent server row is quarantined.
      await enqueue(7, 'never-dispatch');
      await (db.update(
        db.outboxCommands,
      )..where((r) => r.id.equals(id(7)))).write(
        const OutboxCommandsCompanion(
          lastErrorCode: Value('production_dispatch_started'),
        ),
      );
      now = now.add(const Duration(seconds: 2));
      await worker().wake();
      final pending = (await db.outboxDao.getAll()).last;
      expect(pending.lastErrorCode, 'production_outcome_unknown');
      expect(pending.attemptCount, 0);
      expect(pending.state, 'retry_wait');

      final untrusted = ProductionChatTransport(
        origin: origin,
        allowedHosts: {origin.authority},
        accessToken: () async => token,
      );
      await expectLater(
        untrusted.lookup(scope, id(1)),
        throwsA(isA<ProductionChatFailure>()),
      );
    },
    skip: enabled ? false : 'Explicit disposable TLS fixture only',
  );
}
