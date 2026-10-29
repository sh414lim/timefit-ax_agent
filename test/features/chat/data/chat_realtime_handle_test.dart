import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/network/realtime_client.dart';
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

  test('handle identity and diagnostics never stringify conversation ID', () {
    const handle = RealtimeSubscriptionHandle(
      attemptId: RealtimeAttemptId(7),
      generation: RealtimeConversationGeneration(3),
      conversationId: 'private-conversation-canary',
    );

    expect(handle.toString(), isNot(contains('private-conversation-canary')));
    expect(const RealtimeAttemptId(7), const RealtimeAttemptId(7));
    expect(
      const RealtimeConversationGeneration(3),
      const RealtimeConversationGeneration(3),
    );
  });

  test(
    'unsubscribe is handle-scoped idempotent and shares one Future',
    () async {
      expect(
        await source.subscribe('conversation-a'),
        ChatRealtimeSubscribeResult.trusted,
      );
      final handle = source.trustedHandle!;
      final gate = Completer<RealtimeUnsubscribeObservation>();
      port.unsubscribeGates[handle] = gate;

      final first = source.unsubscribe(handle);
      final second = source.unsubscribe(handle);

      expect(identical(first, second), isTrue);
      expect(port.unsubscribeCalls[handle], 1);
      expect(source.trustedHandle, isNull);
      expect(
        port.quarantineCalls.where((entry) => entry.handle == handle),
        hasLength(1),
      );

      gate.complete(RealtimeUnsubscribeObservation.completed);
      expect(await first, RealtimeUnsubscribeObservation.completed);
      expect(await second, RealtimeUnsubscribeObservation.completed);
      expect(port.unsubscribeCalls[handle], 1);
    },
  );

  test('unsubscribe failure stays quarantined without leaking error', () async {
    await source.subscribe('conversation-a');
    final handle = source.trustedHandle!;
    port.unsubscribeError = StateError('private-canary-error');

    final observation = await source.unsubscribe(handle);

    expect(observation, RealtimeUnsubscribeObservation.uncertain);
    expect(source.trustedHandle, isNull);
    expect(source.diagnostics.quarantinedHandleCount, 1);
    expect(
      source.diagnostics.toString(),
      isNot(contains('private-canary-error')),
    );
  });

  test('invalid returned handle fails closed and is quarantined', () async {
    port.nextHandleOverride = const RealtimeSubscriptionHandle(
      attemptId: RealtimeAttemptId(99),
      generation: RealtimeConversationGeneration(99),
      conversationId: 'foreign',
    );

    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );
    expect(source.trustedHandle, isNull);
    expect(port.quarantineCalls, hasLength(1));
  });

  test('an adapter cannot reuse a handle identity for a new attempt', () async {
    await source.subscribe('conversation-a');
    final original = source.trustedHandle!;
    port.nextHandleOverride = original;

    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );

    expect(source.trustedHandle, isNull);
    expect(port.subscribeCalls, <RealtimeSubscriptionHandle>[
      original,
      original,
    ]);
    expect(port.unsubscribeCalls[original], 1);
  });
}
