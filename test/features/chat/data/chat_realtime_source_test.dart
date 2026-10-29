import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/network/realtime_client.dart';
import 'package:timefit_native/features/chat/application/gap_fill_controller.dart';
import 'package:timefit_native/features/chat/data/chat_realtime_source.dart';

import 'support/fake_realtime_port.dart';

void main() {
  late FakeRealtimeReadPort port;
  late ChatRealtimeSource source;

  setUp(() {
    port = FakeRealtimeReadPort();
    source = ChatRealtimeSource(port: port);
  });

  tearDown(() async {
    source.dispose();
    await port.close();
  });

  test('trusted typed message event emits one gap-fill hint', () async {
    final hints = <GapFillHint>[];
    final statuses = <RealtimeChannelStatus>[];
    final hintSubscription = source.hints.listen(hints.add);
    final statusSubscription = source.statuses.listen(statuses.add);
    addTearDown(hintSubscription.cancel);
    addTearDown(statusSubscription.cancel);

    await source.subscribe('conversation-a');
    final handle = source.trustedHandle!;
    port.emit(RealtimeStatusEvent(handle, RealtimeChannelStatus.subscribed));
    port.emit(
      RealtimeMessageCreatedEvent(
        handle,
        eventId: 'event-1',
        conversationId: 'conversation-a',
        sequence: 8,
      ),
    );

    expect(statuses, <RealtimeChannelStatus>[RealtimeChannelStatus.subscribed]);
    expect(hints, hasLength(1));
    expect(hints.single.conversationId, 'conversation-a');
    expect(hints.single.sequence, 8);
    expect(source.diagnostics.emittedHintCount, 1);
  });

  test(
    'invalid, foreign, and non-positive events never become hints',
    () async {
      final hints = <GapFillHint>[];
      final subscription = source.hints.listen(hints.add);
      addTearDown(subscription.cancel);
      await source.subscribe('conversation-a');
      final handle = source.trustedHandle!;

      port.emit(RealtimeInvalidEvent(handle, code: 'candidate_invalid'));
      port.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: 'event-foreign',
          conversationId: 'conversation-b',
          sequence: 2,
        ),
      );
      port.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: 'event-zero',
          conversationId: 'conversation-a',
          sequence: 0,
        ),
      );
      port.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: '',
          conversationId: 'conversation-a',
          sequence: 2,
        ),
      );

      expect(hints, isEmpty);
      expect(source.diagnostics.ignoredCallbackCount, 4);
    },
  );

  test(
    'terminal status is visible but immediately fences later callbacks',
    () async {
      final hints = <GapFillHint>[];
      final statuses = <RealtimeChannelStatus>[];
      final hintSubscription = source.hints.listen(hints.add);
      final statusSubscription = source.statuses.listen(statuses.add);
      addTearDown(hintSubscription.cancel);
      addTearDown(statusSubscription.cancel);
      await source.subscribe('conversation-a');
      final handle = source.trustedHandle!;
      port.unsubscribeGates[handle] =
          Completer<RealtimeUnsubscribeObservation>();

      port.emit(
        RealtimeStatusEvent(handle, RealtimeChannelStatus.channelError),
      );
      port.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: 'late-event',
          conversationId: 'conversation-a',
          sequence: 9,
        ),
      );

      expect(statuses, <RealtimeChannelStatus>[
        RealtimeChannelStatus.channelError,
      ]);
      expect(hints, isEmpty);
      expect(source.trustedHandle, isNull);
      expect(source.diagnostics.ignoredCallbackCount, 1);
    },
  );

  test('callback handle identity is checked even on trusted stream', () async {
    final hints = <GapFillHint>[];
    final subscription = source.hints.listen(hints.add);
    addTearDown(subscription.cancel);
    await source.subscribe('conversation-a');
    final trusted = source.trustedHandle!;
    final foreign = RealtimeSubscriptionHandle(
      attemptId: const RealtimeAttemptId(999),
      generation: const RealtimeConversationGeneration(1),
      conversationId: 'conversation-a',
    );

    port.emitOn(
      trusted,
      RealtimeMessageCreatedEvent(
        foreign,
        eventId: 'foreign-handle-event',
        conversationId: 'conversation-a',
        sequence: 1,
      ),
    );

    expect(hints, isEmpty);
    expect(source.diagnostics.ignoredCallbackCount, 1);
  });

  test('stream error is redacted and terminates trusted attempt', () async {
    final statuses = <RealtimeChannelStatus>[];
    final subscription = source.statuses.listen(statuses.add);
    addTearDown(subscription.cancel);
    await source.subscribe('conversation-a');
    final handle = source.trustedHandle!;
    port.unsubscribeGates[handle] = Completer<RealtimeUnsubscribeObservation>();

    port.emitStreamError(handle, StateError('raw-private-canary'));

    expect(statuses, <RealtimeChannelStatus>[
      RealtimeChannelStatus.channelError,
    ]);
    expect(source.trustedHandle, isNull);
    expect(
      source.diagnostics.toString(),
      isNot(contains('raw-private-canary')),
    );
  });

  test(
    'event stream completion closes and fences the trusted attempt',
    () async {
      final statuses = <RealtimeChannelStatus>[];
      final subscription = source.statuses.listen(statuses.add);
      addTearDown(subscription.cancel);
      await source.subscribe('conversation-a');
      final handle = source.trustedHandle!;

      await port.closeEvents(handle);

      expect(statuses, <RealtimeChannelStatus>[RealtimeChannelStatus.closed]);
      expect(source.trustedHandle, isNull);
      expect(port.unsubscribeCalls[handle], 1);
    },
  );
}
