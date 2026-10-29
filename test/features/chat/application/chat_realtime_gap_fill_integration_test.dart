import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/daos/message_dao.dart';
import 'package:timefit_native/core/network/realtime_client.dart';
import 'package:timefit_native/features/chat/application/gap_fill_controller.dart';
import 'package:timefit_native/features/chat/data/chat_realtime_source.dart';

import '../data/support/fake_realtime_port.dart';

final class _CanonicalSource implements GapFillSource {
  int calls = 0;

  @override
  Future<GapFillPage> loadAfter(GapFillRequest request) async {
    calls += 1;
    return GapFillPage(
      conversationId: request.conversationId,
      messages: <CanonicalLocalMessage>[
        for (
          var sequence = request.afterSequence + 1;
          sequence <= 8;
          sequence++
        )
          CanonicalLocalMessage(
            serverId: 'server-$sequence',
            conversationId: request.conversationId,
            clientMessageId: 'client-$sequence',
            sequence: sequence,
            senderKind: 'user',
            bodyText: 'canonical-$sequence',
            messageKind: 'text',
            serverCreatedAt: DateTime.utc(2026, 10, 29, 0, 0, sequence),
          ),
      ],
      latestSequence: 8,
    );
  }
}

final class _RecordingPersistence implements GapFillPersistence {
  int latest = 4;
  int persistCalls = 0;
  final List<int> storedSequences = <int>[];

  @override
  Future<int> readLatestSequence(String conversationId) async => latest;

  @override
  Future<void> persist(
    GapFillRequest request,
    GapFillPage originalPage,
    List<CanonicalLocalMessage> acceptedMessages,
  ) async {
    persistCalls += 1;
    storedSequences.addAll(
      acceptedMessages.map((CanonicalLocalMessage message) => message.sequence),
    );
    latest = acceptedMessages.last.sequence;
  }
}

void main() {
  test(
    'typed current hints coalesce through canonical gap-fill only',
    () async {
      final port = FakeRealtimeReadPort();
      final realtime = ChatRealtimeSource(port: port);
      final canonicalSource = _CanonicalSource();
      final persistence = _RecordingPersistence();
      final gapFill = GapFillController(
        source: canonicalSource,
        persistence: persistence,
        conversationId: 'conversation-a',
      );
      addTearDown(() async {
        gapFill.dispose();
        realtime.dispose();
        await port.close();
      });

      await realtime.subscribe('conversation-a');
      final handle = realtime.trustedHandle!;
      final hints = <GapFillHint>[];
      final gapResults = <Future<GapFillResult>>[];
      final subscription = realtime.hints.listen((GapFillHint hint) {
        hints.add(hint);
        gapResults.add(gapFill.onHint(hint));
      });
      addTearDown(subscription.cancel);

      for (final entry in <({String eventId, int sequence})>[
        (eventId: 'event-5', sequence: 5),
        (eventId: 'event-3-a', sequence: 3),
        (eventId: 'event-3-b', sequence: 3),
        (eventId: 'event-8', sequence: 8),
      ]) {
        port.emit(
          RealtimeMessageCreatedEvent(
            handle,
            eventId: entry.eventId,
            conversationId: 'conversation-a',
            sequence: entry.sequence,
          ),
        );
      }

      expect(hints.map((GapFillHint hint) => hint.sequence), <int>[5, 3, 3, 8]);
      await Future.wait(gapResults);
      expect(canonicalSource.calls, 1);
      expect(persistence.persistCalls, 1);
      expect(persistence.storedSequences, <int>[5, 6, 7, 8]);
    },
  );

  test('Realtime source alone has no persistence input', () async {
    final port = FakeRealtimeReadPort();
    final realtime = ChatRealtimeSource(port: port);
    final hints = <GapFillHint>[];
    final subscription = realtime.hints.listen(hints.add);
    addTearDown(() async {
      await subscription.cancel();
      realtime.dispose();
      await port.close();
    });

    await realtime.subscribe('conversation-a');
    final handle = realtime.trustedHandle!;
    port.emit(
      RealtimeMessageCreatedEvent(
        handle,
        eventId: 'event-only',
        conversationId: 'conversation-a',
        sequence: 1,
      ),
    );

    expect(hints, hasLength(1));
    expect(hints.single.sequence, 1);
  });
}
