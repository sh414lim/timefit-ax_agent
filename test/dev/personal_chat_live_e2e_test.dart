import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/dev/personal_chat_client.dart';
import 'package:timefit_native/dev/personal_chat_outbox_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';

const String _clientId = '33333333-3333-4333-8333-333333333333';

void main() {
  final pairing = Platform.environment['TIMEFIT_AX_PAIRING'];
  final enabled = Platform.environment['TIMEFIT_AX_PERSONAL_E2E'] == '1';
  final expectedAnswerPrefix =
      Platform.environment['TIMEFIT_AX_EXPECTED_ANSWER_PREFIX'];

  test(
    'real process Outbox to WebSocket to private SQLite survives app reopen',
    () async {
      final sandbox = await Directory.systemTemp.createTemp('timefit-ws-e2e-');
      addTearDown(() => sandbox.delete(recursive: true));
      final databaseFile = File('${sandbox.path}/app.sqlite');
      var now = DateTime.utc(2026, 11, 24, 4);
      var database = AppDatabase(NativeDatabase(databaseFile));
      await database
          .into(database.localConversations)
          .insert(
            LocalConversationsCompanion.insert(
              id: 'production-like-conversation',
              title: const Value('운영형 로컬 검증'),
              serverCreatedAt: now,
              serverUpdatedAt: now,
              lastSyncedAt: now,
            ),
          );
      await SendMessage(
        database: database,
        clock: () => now,
        clientMessageId: () => _clientId,
      ).submit(
        conversationId: 'production-like-conversation',
        bodyText: '운영형 앱 서버 통신 검증',
      );

      OutboxWorker buildWorker() => OutboxWorker(
        dao: database.outboxDao,
        executor: PersonalChatOutboxExecutor(
          database: database,
          api: const PersonalChatHttpClient(),
          pairing: pairing!,
          clock: () => now,
          delay: (_) => Future<void>.delayed(const Duration(milliseconds: 50)),
        ),
        clock: () => now,
        retryPolicy: const RetryPolicy(_middleJitter),
        scope: 'production-like-process-e2e',
        leaseToken: () => 'production-like-lease',
      );

      await buildWorker().wake();
      final beforeRestart = await database.messageDao.readTimeline(
        'production-like-conversation',
      );
      expect(beforeRestart, hasLength(2));
      expect(beforeRestart.first.clientMessageId, _clientId);
      expect(beforeRestart.first.serverId, _clientId);
      expect(beforeRestart.first.deliveryState, 'sent');
      expect(beforeRestart.last.senderKind, 'system');
      expect(beforeRestart.last.clientMessageId, isNot(_clientId));
      expect(beforeRestart.last.bodyText, isNotEmpty);
      if (expectedAnswerPrefix != null) {
        expect(beforeRestart.last.bodyText, startsWith(expectedAnswerPrefix));
      }
      expect((await database.outboxDao.getAll()).single.state, 'completed');

      await database.close();
      database = AppDatabase(NativeDatabase(databaseFile));
      addTearDown(database.close);
      now = now.add(const Duration(seconds: 2));
      await buildWorker().wake();

      final afterRestart = await database.messageDao.readTimeline(
        'production-like-conversation',
      );
      expect(afterRestart, hasLength(2));
      expect(afterRestart.first.clientMessageId, _clientId);
      expect(
        afterRestart.last.clientMessageId,
        beforeRestart.last.clientMessageId,
      );
      expect((await database.outboxDao.getAll()).single.state, 'completed');
    },
    skip: !enabled || pairing == null
        ? 'Set TIMEFIT_AX_PERSONAL_E2E=1 and TIMEFIT_AX_PAIRING.'
        : false,
  );
}

double _middleJitter() => 0.5;
