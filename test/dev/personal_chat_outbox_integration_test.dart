import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/dev/personal_chat_client.dart';
import 'package:timefit_native/dev/personal_chat_outbox_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';

const String _clientId = '11111111-1111-4111-8111-111111111111';
const String _assistantId = '22222222-2222-4222-8222-222222222222';
const String _pairing = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

PersonalChatSnapshot _snapshot(String state, {bool accepted = true}) =>
    PersonalChatSnapshot(
      acceptedClientMessageId: accepted ? _clientId : null,
      turns: <PersonalChatTurn>[
        PersonalChatTurn(
          sequence: 1,
          clientMessageId: _clientId,
          clientRequestId: _clientId,
          assistantMessageId: _assistantId,
          bodyText: '안녕하세요',
          state: state,
          answer: state == 'complete' ? '합성 GPT 답변' : null,
        ),
      ],
    );

final class _FakeApi implements PersonalChatApi {
  _FakeApi({required this.sendResults, required this.historyResults});

  final List<Object> sendResults;
  final List<PersonalChatSnapshot> historyResults;
  final List<String> sentIds = <String>[];

  @override
  Future<PersonalChatSnapshot> send({
    required String pairing,
    required String clientMessageId,
    required String bodyText,
  }) async {
    expect(pairing, _pairing);
    expect(bodyText, '안녕하세요');
    sentIds.add(clientMessageId);
    final result = sendResults.removeAt(0);
    if (result is PersonalChatFailure) throw result;
    return result as PersonalChatSnapshot;
  }

  @override
  Future<PersonalChatSnapshot> history(String pairing) async {
    expect(pairing, _pairing);
    return historyResults.removeAt(0);
  }
}

void main() {
  late AppDatabase database;
  late DateTime now;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 23, 10);
    await database
        .into(database.localConversations)
        .insert(
          LocalConversationsCompanion.insert(
            id: 'conversation',
            title: const Value('로컬 대화'),
            serverCreatedAt: now,
            serverUpdatedAt: now,
            lastSyncedAt: now,
          ),
        );
    await SendMessage(
      database: database,
      clock: () => now,
      clientMessageId: () => _clientId,
    ).submit(conversationId: 'conversation', bodyText: '안녕하세요');
  });

  tearDown(() => database.close());

  OutboxWorker worker(_FakeApi api, {int maximumPolls = 20}) => OutboxWorker(
    dao: database.outboxDao,
    executor: PersonalChatOutboxExecutor(
      database: database,
      api: api,
      pairing: _pairing,
      clock: () => now,
      maximumPolls: maximumPolls,
      delay: (_) async {},
    ),
    clock: () => now,
    retryPolicy: const RetryPolicy(_middleJitter),
    scope: 'personal-chat-test-${identityHashCode(database)}',
    leaseToken: () => 'lease-${now.microsecondsSinceEpoch}',
  );

  test(
    'durable accept acks original ID and stores separate assistant bubble',
    () async {
      final api = _FakeApi(
        sendResults: <Object>[_snapshot('complete')],
        historyResults: <PersonalChatSnapshot>[],
      );

      await worker(api).wake();

      expect(api.sentIds, <String>[_clientId]);
      final messages = await database.messageDao.readTimeline('conversation');
      expect(messages, hasLength(2));
      expect(messages[0].localId, _clientId);
      expect(messages[0].clientMessageId, _clientId);
      expect(messages[0].serverId, _clientId);
      expect(messages[0].deliveryState, 'sent');
      expect(messages[1].localId, 'personal-assistant:$_assistantId');
      expect(messages[1].clientMessageId, _assistantId);
      expect(messages[1].senderKind, 'system');
      expect(messages[1].bodyText, '합성 GPT 답변');
      expect((await database.outboxDao.getAll()).single.state, 'completed');
    },
  );

  test(
    'unknown POST outcome uses GET history and never creates a new ID',
    () async {
      final api = _FakeApi(
        sendResults: <Object>[
          const PersonalChatFailure(
            'request_timeout',
            postOutcomeUnknown: true,
          ),
        ],
        historyResults: <PersonalChatSnapshot>[
          _snapshot('complete', accepted: false),
        ],
      );

      await worker(api).wake();

      expect(api.sentIds, <String>[_clientId]);
      expect(await database.outboxDao.getAll(), hasLength(1));
      expect(await database.messageDao.getAll(), hasLength(2));
    },
  );

  test(
    'dispatch_unknown acks durable user turn without assistant or resend',
    () async {
      final api = _FakeApi(
        sendResults: <Object>[_snapshot('dispatch_unknown')],
        historyResults: <PersonalChatSnapshot>[],
      );

      await worker(api).wake();

      expect(api.sentIds, <String>[_clientId]);
      final messages = await database.messageDao.getAll();
      expect(messages, hasLength(1));
      expect(messages.single.deliveryState, 'sent');
      final outbox = (await database.outboxDao.getAll()).single;
      expect(outbox.state, 'completed');
      expect(outbox.lastErrorCode, 'personal_dispatch_unknown');
    },
  );

  test(
    'restart resumes the same outbox row and idempotently restores answer',
    () async {
      final firstApi = _FakeApi(
        sendResults: <Object>[_snapshot('pending')],
        historyResults: <PersonalChatSnapshot>[],
      );
      await worker(firstApi, maximumPolls: 0).wake();
      expect((await database.outboxDao.getAll()).single.state, 'retry_wait');
      expect((await database.messageDao.getAll()).single.deliveryState, 'sent');

      now = now.add(const Duration(seconds: 2));
      final restartedApi = _FakeApi(
        sendResults: <Object>[_snapshot('complete')],
        historyResults: <PersonalChatSnapshot>[],
      );
      await worker(restartedApi).wake();

      expect(firstApi.sentIds, <String>[_clientId]);
      expect(restartedApi.sentIds, <String>[_clientId]);
      expect(await database.outboxDao.getAll(), hasLength(1));
      expect(await database.messageDao.getAll(), hasLength(2));
      expect((await database.outboxDao.getAll()).single.state, 'completed');
    },
  );

  test('decoder rejects acceptance that is not backed by a committed turn', () {
    expect(
      () => decodePersonalChatSnapshot(
        '{"schemaVersion":1,"testOnly":true,"modelProvider":"chatgpt-siwc",'
                '"model":"synthetic","turns":[],"cleanup":null,'
                '"acceptance":{"durable":true,"sequence":1,'
                '"clientMessageId":"$_clientId",'
                '"clientRequestId":"$_clientId"}}'
            .codeUnits,
      ),
      throwsFormatException,
    );
  });
}

double _middleJitter() => 0.5;
