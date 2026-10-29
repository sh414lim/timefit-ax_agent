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

  test('conversation switch fences trusted old handle callbacks', () async {
    final hints = <GapFillHint>[];
    final statuses = <RealtimeChannelStatus>[];
    final hintSubscription = source.hints.listen(hints.add);
    final statusSubscription = source.statuses.listen(statuses.add);
    addTearDown(hintSubscription.cancel);
    addTearDown(statusSubscription.cancel);

    await source.subscribe('conversation-a');
    final oldHandle = source.trustedHandle!;
    port.unsubscribeGates[oldHandle] =
        Completer<RealtimeUnsubscribeObservation>();

    expect(
      await source.subscribe('conversation-b'),
      ChatRealtimeSubscribeResult.trusted,
    );
    final currentHandle = source.trustedHandle!;
    expect(currentHandle.generation.value, oldHandle.generation.value + 1);

    port.emit(
      RealtimeMessageCreatedEvent(
        oldHandle,
        eventId: 'old-event',
        conversationId: 'conversation-a',
        sequence: 1,
      ),
    );
    port.emit(RealtimeStatusEvent(oldHandle, RealtimeChannelStatus.subscribed));
    port.emit(
      RealtimeMessageCreatedEvent(
        currentHandle,
        eventId: 'current-event',
        conversationId: 'conversation-b',
        sequence: 2,
      ),
    );

    expect(hints.map((GapFillHint hint) => hint.conversationId), <String>[
      'conversation-b',
    ]);
    expect(statuses, isEmpty);
    expect(source.diagnostics.ignoredCallbackCount, 2);
    expect(source.diagnostics.trustedAttemptId, currentHandle.attemptId);
  });

  test(
    'same-conversation retry uses a new attempt and fences old events',
    () async {
      final hints = <GapFillHint>[];
      final subscription = source.hints.listen(hints.add);
      addTearDown(subscription.cancel);
      await source.subscribe('conversation-a');
      final oldHandle = source.trustedHandle!;
      port.unsubscribeGates[oldHandle] =
          Completer<RealtimeUnsubscribeObservation>();

      await source.subscribe('conversation-a');
      final currentHandle = source.trustedHandle!;

      expect(currentHandle.attemptId, isNot(oldHandle.attemptId));
      expect(currentHandle.generation, oldHandle.generation);
      port.emit(
        RealtimeMessageCreatedEvent(
          oldHandle,
          eventId: 'duplicate-event',
          conversationId: 'conversation-a',
          sequence: 3,
        ),
      );
      port.emit(
        RealtimeMessageCreatedEvent(
          currentHandle,
          eventId: 'duplicate-event',
          conversationId: 'conversation-a',
          sequence: 3,
        ),
      );

      expect(hints, hasLength(1));
      expect(hints.single.sequence, 3);
    },
  );

  test(
    'late subscribe result after conversation switch is quarantined',
    () async {
      port.autoCompleteSubscribe = false;
      final oldAttempt = source.subscribe('conversation-a');
      final currentAttempt = source.subscribe('conversation-b');

      port.completeSubscribe(1);
      expect(await currentAttempt, ChatRealtimeSubscribeResult.trusted);
      final currentHandle = source.trustedHandle!;

      port.completeSubscribe(0);
      expect(await oldAttempt, ChatRealtimeSubscribeResult.stale);
      expect(source.trustedHandle, currentHandle);
      expect(
        port.quarantineCalls.map((entry) => entry.handle),
        contains(port.pendingSubscribes[0].handle),
      );
    },
  );

  test('latest of two concurrent attempts in one generation wins', () async {
    port.autoCompleteSubscribe = false;
    final first = source.subscribe('conversation-a');
    final second = source.subscribe('conversation-a');

    port.completeSubscribe(1);
    expect(await second, ChatRealtimeSubscribeResult.trusted);
    final winner = source.trustedHandle!;
    port.completeSubscribe(0);

    expect(await first, ChatRealtimeSubscribeResult.stale);
    expect(source.trustedHandle, winner);
    expect(winner.generation.value, 1);
  });

  test('a late error from an older same-generation attempt is stale', () async {
    final statuses = <RealtimeChannelStatus>[];
    final subscription = source.statuses.listen(statuses.add);
    addTearDown(subscription.cancel);
    port.autoCompleteSubscribe = false;
    final older = source.subscribe('conversation-a');
    final current = source.subscribe('conversation-a');

    port.completeSubscribe(1);
    expect(await current, ChatRealtimeSubscribeResult.trusted);
    final winner = source.trustedHandle;
    port.failSubscribe(0, StateError('raw-stale-private-canary'));

    expect(await older, ChatRealtimeSubscribeResult.stale);
    expect(source.trustedHandle, winner);
    expect(statuses, isEmpty);
  });

  test('late old unsubscribe completion cannot close current handle', () async {
    await source.subscribe('conversation-a');
    final oldHandle = source.trustedHandle!;
    final oldCleanup = Completer<RealtimeUnsubscribeObservation>();
    port.unsubscribeGates[oldHandle] = oldCleanup;

    await source.subscribe('conversation-b');
    final currentHandle = source.trustedHandle!;
    oldCleanup.complete(RealtimeUnsubscribeObservation.completed);
    await Future<void>.delayed(Duration.zero);

    expect(source.trustedHandle, currentHandle);
    expect(source.diagnostics.trustedAttemptId, currentHandle.attemptId);
  });

  test('new session remains trusted after revoked cleanup completes', () async {
    await source.subscribe('conversation-a');
    final oldHandle = source.trustedHandle!;
    final oldCleanup = Completer<RealtimeUnsubscribeObservation>();
    port.unsubscribeGates[oldHandle] = oldCleanup;
    source.revokeSession();

    await source.subscribe('conversation-b');
    final currentHandle = source.trustedHandle!;
    oldCleanup.complete(RealtimeUnsubscribeObservation.uncertain);
    await Future<void>.delayed(Duration.zero);

    expect(source.trustedHandle, currentHandle);
    expect(source.diagnostics.generation.value, greaterThan(1));
  });

  test('session revoke fences pending and trusted callbacks', () async {
    final hints = <GapFillHint>[];
    final subscription = source.hints.listen(hints.add);
    addTearDown(subscription.cancel);
    await source.subscribe('conversation-a');
    final trusted = source.trustedHandle!;
    port.unsubscribeGates[trusted] =
        Completer<RealtimeUnsubscribeObservation>();

    source.revokeSession();
    port.emit(
      RealtimeMessageCreatedEvent(
        trusted,
        eventId: 'revoked-event',
        conversationId: 'conversation-a',
        sequence: 4,
      ),
    );

    expect(hints, isEmpty);
    expect(source.trustedHandle, isNull);
    expect(source.diagnostics.hasConversation, isFalse);
  });

  test('dispose fences a subscribe Future that completes late', () async {
    port.autoCompleteSubscribe = false;
    final pending = source.subscribe('conversation-a');
    source.dispose();
    port.completeSubscribe(0);

    expect(await pending, ChatRealtimeSubscribeResult.stale);
    expect(source.trustedHandle, isNull);
    expect(source.diagnostics.disposed, isTrue);
    expect(port.quarantineCalls, hasLength(1));
  });

  test('current subscribe error emits stable channel error only', () async {
    final statuses = <RealtimeChannelStatus>[];
    final subscription = source.statuses.listen(statuses.add);
    addTearDown(subscription.cancel);
    port.subscribeError = StateError('raw-private-canary');

    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.failed,
    );
    expect(statuses, <RealtimeChannelStatus>[
      RealtimeChannelStatus.channelError,
    ]);
    expect(
      source.diagnostics.toString(),
      isNot(contains('raw-private-canary')),
    );
  });
}
