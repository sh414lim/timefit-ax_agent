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
    final handle = RealtimeSubscriptionHandle(
      attemptId: const RealtimeAttemptId(7),
      generation: const RealtimeConversationGeneration(3),
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
    port.nextHandleOverride = RealtimeSubscriptionHandle(
      attemptId: const RealtimeAttemptId(99),
      generation: const RealtimeConversationGeneration(99),
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

  test(
    'an unregistered handle never reaches quarantine or unsubscribe',
    () async {
      final foreign = RealtimeSubscriptionHandle(
        attemptId: const RealtimeAttemptId(300),
        generation: const RealtimeConversationGeneration(1),
        conversationId: 'conversation-a',
      );

      expect(
        await source.unsubscribe(foreign),
        RealtimeUnsubscribeObservation.uncertain,
      );
      expect(port.quarantineCalls, isEmpty);
      expect(port.unsubscribeCalls, isEmpty);
      expect(source.diagnostics.knownHandleCount, 0);
    },
  );

  test(
    'a structurally equal handle owned by another source is foreign',
    () async {
      final otherPort = FakeRealtimeReadPort();
      final otherSource = ChatRealtimeSource(port: otherPort);
      addTearDown(() async {
        otherSource.dispose();
        await otherPort.close();
      });
      await source.subscribe('conversation-a');
      await otherSource.subscribe('conversation-a');
      final otherHandle = otherSource.trustedHandle!;

      expect(otherHandle.attemptId, source.trustedHandle!.attemptId);
      expect(otherHandle.generation, source.trustedHandle!.generation);
      expect(otherHandle.conversationId, source.trustedHandle!.conversationId);
      expect(
        await source.unsubscribe(otherHandle),
        RealtimeUnsubscribeObservation.uncertain,
      );
      expect(port.unsubscribeCalls, isEmpty);
      expect(port.quarantineCalls, isEmpty);
      expect(source.trustedHandle, isNotNull);
    },
  );

  test(
    'one raw handle object cannot be owned by two sources sequentially',
    () async {
      final otherPort = FakeRealtimeReadPort();
      final otherSource = ChatRealtimeSource(port: otherPort);
      addTearDown(() async {
        otherSource.dispose();
        await otherPort.close();
      });
      final sharedHandle = RealtimeSubscriptionHandle(
        attemptId: const RealtimeAttemptId(801),
        generation: const RealtimeConversationGeneration(1),
        conversationId: 'conversation-a',
      );
      port.nextHandleOverride = sharedHandle;
      otherPort.nextHandleOverride = sharedHandle;

      expect(
        await source.subscribe('conversation-a'),
        ChatRealtimeSubscribeResult.trusted,
      );
      expect(
        await otherSource.subscribe('conversation-a'),
        ChatRealtimeSubscribeResult.invalidHandle,
      );

      expect(source.trustedHandle, same(sharedHandle));
      expect(otherSource.trustedHandle, isNull);
      expect(otherSource.diagnostics.knownHandleCount, 0);
      expect(otherPort.quarantineCalls, isEmpty);
      expect(otherPort.unsubscribeCalls, isEmpty);
      expect(
        await source.unsubscribe(sharedHandle),
        RealtimeUnsubscribeObservation.completed,
      );
      expect(port.unsubscribeCalls[sharedHandle], 1);
      expect(otherPort.unsubscribeCalls, isEmpty);
    },
  );

  test('foreign raw rejection still consumes its attempt ID locally', () async {
    final ownerPort = FakeRealtimeReadPort();
    final ownerSource = ChatRealtimeSource(port: ownerPort);
    addTearDown(() async {
      ownerSource.dispose();
      await ownerPort.close();
    });
    final foreignHandle = RealtimeSubscriptionHandle(
      attemptId: const RealtimeAttemptId(807),
      generation: const RealtimeConversationGeneration(1),
      conversationId: 'conversation-a',
    );
    ownerPort.nextHandleOverride = foreignHandle;
    expect(
      await ownerSource.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.trusted,
    );

    port.nextHandleOverride = foreignHandle;
    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );
    expect(port.quarantineCalls, isEmpty);
    expect(port.unsubscribeCalls, isEmpty);

    final freshHandleWithConsumedAttempt = RealtimeSubscriptionHandle(
      attemptId: foreignHandle.attemptId,
      generation: foreignHandle.generation,
      conversationId: foreignHandle.conversationId,
    );
    port.nextHandleOverride = freshHandleWithConsumedAttempt;
    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );
    expect(source.trustedHandle, isNull);
    expect(
      port.quarantineCalls.map((entry) => entry.handle),
      <RealtimeSubscriptionHandle>[freshHandleWithConsumedAttempt],
    );
    expect(port.unsubscribeCalls[foreignHandle], isNull);
    expect(port.unsubscribeCalls[freshHandleWithConsumedAttempt], 1);
  });

  test(
    'foreign-first concurrent return consumes attempt before latest clone',
    () async {
      final ownerPort = FakeRealtimeReadPort();
      final ownerSource = ChatRealtimeSource(port: ownerPort);
      addTearDown(() async {
        ownerSource.dispose();
        await ownerPort.close();
      });
      final foreignHandle = RealtimeSubscriptionHandle(
        attemptId: const RealtimeAttemptId(808),
        generation: const RealtimeConversationGeneration(1),
        conversationId: 'conversation-a',
      );
      ownerPort.nextHandleOverride = foreignHandle;
      await ownerSource.subscribe('conversation-a');
      final freshClone = RealtimeSubscriptionHandle(
        attemptId: foreignHandle.attemptId,
        generation: foreignHandle.generation,
        conversationId: foreignHandle.conversationId,
      );
      port.autoCompleteSubscribe = false;
      port.nextHandleOverride = foreignHandle;
      final oldRequest = source.subscribe('conversation-a');
      port.nextHandleOverride = freshClone;
      final latestRequest = source.subscribe('conversation-a');

      port.completeSubscribe(0);
      expect(await oldRequest, ChatRealtimeSubscribeResult.invalidHandle);
      port.completeSubscribe(1);
      expect(await latestRequest, ChatRealtimeSubscribeResult.invalidHandle);

      expect(source.trustedHandle, isNull);
      expect(port.unsubscribeCalls[foreignHandle], isNull);
      expect(port.unsubscribeCalls[freshClone], 1);
    },
  );

  test('invalid metadata still consumes the returned attempt ID', () async {
    final invalid = RealtimeSubscriptionHandle(
      attemptId: const RealtimeAttemptId(809),
      generation: const RealtimeConversationGeneration(99),
      conversationId: 'wrong-conversation',
    );
    port.nextHandleOverride = invalid;
    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );

    final correctedClone = RealtimeSubscriptionHandle(
      attemptId: invalid.attemptId,
      generation: const RealtimeConversationGeneration(1),
      conversationId: 'conversation-a',
    );
    port.nextHandleOverride = correctedClone;
    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );

    expect(source.trustedHandle, isNull);
    expect(port.unsubscribeCalls[invalid], 1);
    expect(port.unsubscribeCalls[correctedClone], 1);
  });

  test('stale returned handle still consumes its attempt ID', () async {
    port.autoCompleteSubscribe = false;
    final staleHandle = RealtimeSubscriptionHandle(
      attemptId: const RealtimeAttemptId(810),
      generation: const RealtimeConversationGeneration(1),
      conversationId: 'conversation-a',
    );
    port.nextHandleOverride = staleHandle;
    final staleRequest = source.subscribe('conversation-a');
    source.revokeSession();
    port.completeSubscribe(0);
    expect(await staleRequest, ChatRealtimeSubscribeResult.stale);

    port.autoCompleteSubscribe = true;
    final replay = RealtimeSubscriptionHandle(
      attemptId: staleHandle.attemptId,
      generation: const RealtimeConversationGeneration(3),
      conversationId: 'conversation-a',
    );
    port.nextHandleOverride = replay;
    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );

    expect(source.trustedHandle, isNull);
    expect(port.unsubscribeCalls[staleHandle], 1);
    expect(port.unsubscribeCalls[replay], 1);
  });

  test('simultaneous raw handle reuse produces exactly one owner', () async {
    final otherPort = FakeRealtimeReadPort();
    final otherSource = ChatRealtimeSource(port: otherPort);
    addTearDown(() async {
      otherSource.dispose();
      await otherPort.close();
    });
    final sharedHandle = RealtimeSubscriptionHandle(
      attemptId: const RealtimeAttemptId(802),
      generation: const RealtimeConversationGeneration(1),
      conversationId: 'conversation-a',
    );
    port.nextHandleOverride = sharedHandle;
    otherPort.nextHandleOverride = sharedHandle;

    final results = await Future.wait(<Future<ChatRealtimeSubscribeResult>>[
      source.subscribe('conversation-a'),
      otherSource.subscribe('conversation-a'),
    ]);

    expect(
      results.where(
        (ChatRealtimeSubscribeResult result) =>
            result == ChatRealtimeSubscribeResult.trusted,
      ),
      hasLength(1),
    );
    expect(
      results.where(
        (ChatRealtimeSubscribeResult result) =>
            result == ChatRealtimeSubscribeResult.invalidHandle,
      ),
      hasLength(1),
    );
    final losingPort = results.first == ChatRealtimeSubscribeResult.trusted
        ? otherPort
        : port;
    expect(losingPort.quarantineCalls, isEmpty);
    expect(losingPort.unsubscribeCalls, isEmpty);
  });

  test(
    'late old request sharing current raw handle cannot tear it down',
    () async {
      port.autoCompleteSubscribe = false;
      final sharedHandle = RealtimeSubscriptionHandle(
        attemptId: const RealtimeAttemptId(805),
        generation: const RealtimeConversationGeneration(1),
        conversationId: 'conversation-a',
      );
      port.nextHandleOverride = sharedHandle;
      final oldRequest = source.subscribe('conversation-a');
      port.nextHandleOverride = sharedHandle;
      final latestRequest = source.subscribe('conversation-a');

      port.completeSubscribe(1);
      expect(await latestRequest, ChatRealtimeSubscribeResult.trusted);
      port.completeSubscribe(0);
      expect(await oldRequest, ChatRealtimeSubscribeResult.stale);

      expect(source.trustedHandle, same(sharedHandle));
      expect(port.quarantineCalls, isEmpty);
      expect(port.unsubscribeCalls, isEmpty);
    },
  );

  test('old-first concurrent raw reuse fails closed once', () async {
    port.autoCompleteSubscribe = false;
    final sharedHandle = RealtimeSubscriptionHandle(
      attemptId: const RealtimeAttemptId(806),
      generation: const RealtimeConversationGeneration(1),
      conversationId: 'conversation-a',
    );
    port.nextHandleOverride = sharedHandle;
    final oldRequest = source.subscribe('conversation-a');
    port.nextHandleOverride = sharedHandle;
    final latestRequest = source.subscribe('conversation-a');

    port.completeSubscribe(0);
    expect(await oldRequest, ChatRealtimeSubscribeResult.stale);
    port.completeSubscribe(1);
    expect(await latestRequest, ChatRealtimeSubscribeResult.invalidHandle);

    expect(source.trustedHandle, isNull);
    expect(port.quarantineCalls, hasLength(1));
    expect(port.unsubscribeCalls[sharedHandle], 1);
  });

  test(
    'disposed owner does not transfer one raw handle to a new source',
    () async {
      final sharedHandle = RealtimeSubscriptionHandle(
        attemptId: const RealtimeAttemptId(803),
        generation: const RealtimeConversationGeneration(1),
        conversationId: 'conversation-a',
      );
      port.nextHandleOverride = sharedHandle;
      expect(
        await source.subscribe('conversation-a'),
        ChatRealtimeSubscribeResult.trusted,
      );
      source.dispose();

      final otherPort = FakeRealtimeReadPort()
        ..nextHandleOverride = sharedHandle;
      final otherSource = ChatRealtimeSource(port: otherPort);
      addTearDown(() async {
        otherSource.dispose();
        await otherPort.close();
      });

      expect(
        await otherSource.subscribe('conversation-a'),
        ChatRealtimeSubscribeResult.invalidHandle,
      );
      expect(otherSource.trustedHandle, isNull);
      expect(otherPort.quarantineCalls, isEmpty);
      expect(otherPort.unsubscribeCalls, isEmpty);
    },
  );

  test(
    'distinct raw handles with equal values keep distinct ownership',
    () async {
      final otherPort = FakeRealtimeReadPort();
      final otherSource = ChatRealtimeSource(port: otherPort);
      addTearDown(() async {
        otherSource.dispose();
        await otherPort.close();
      });
      final first = RealtimeSubscriptionHandle(
        attemptId: const RealtimeAttemptId(804),
        generation: const RealtimeConversationGeneration(1),
        conversationId: 'conversation-a',
      );
      final second = RealtimeSubscriptionHandle(
        attemptId: const RealtimeAttemptId(804),
        generation: const RealtimeConversationGeneration(1),
        conversationId: 'conversation-a',
      );
      port.nextHandleOverride = first;
      otherPort.nextHandleOverride = second;

      expect(identical(first, second), isFalse);
      expect(
        await source.subscribe('conversation-a'),
        ChatRealtimeSubscribeResult.trusted,
      );
      expect(
        await otherSource.subscribe('conversation-a'),
        ChatRealtimeSubscribeResult.trusted,
      );
      expect(source.trustedHandle, same(first));
      expect(otherSource.trustedHandle, same(second));
    },
  );

  test('attempt ID is consumed across conversation generations', () async {
    await source.subscribe('conversation-a');
    final original = source.trustedHandle!;
    port.nextHandleOverride = RealtimeSubscriptionHandle(
      attemptId: original.attemptId,
      generation: const RealtimeConversationGeneration(2),
      conversationId: 'conversation-b',
    );

    expect(
      await source.subscribe('conversation-b'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );
    expect(source.trustedHandle, isNull);
    expect(port.unsubscribeCalls.values.fold<int>(0, (a, b) => a + b), 2);
  });

  test('attempt ID is also consumed across same-generation retries', () async {
    await source.subscribe('conversation-a');
    final original = source.trustedHandle!;
    port.nextHandleOverride = RealtimeSubscriptionHandle(
      attemptId: original.attemptId,
      generation: original.generation,
      conversationId: original.conversationId,
    );

    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.invalidHandle,
    );
    expect(source.trustedHandle, isNull);
    expect(port.unsubscribeCalls.values.fold<int>(0, (a, b) => a + b), 2);
  });

  test('stream cancel failure is redacted and stays uncertain', () async {
    port.nextCancelError = StateError('raw-cancel-private-canary');
    await source.subscribe('conversation-a');
    final handle = source.trustedHandle!;

    final first = source.unsubscribe(handle);
    final second = source.unsubscribe(handle);

    expect(identical(first, second), isTrue);
    expect(await first, RealtimeUnsubscribeObservation.uncertain);
    expect(await second, RealtimeUnsubscribeObservation.uncertain);
    expect(source.trustedHandle, isNull);
    expect(source.diagnostics.quarantinedHandleCount, 1);
    expect(port.unsubscribeCalls[handle], 1);
    expect(
      source.diagnostics.toString(),
      isNot(contains('raw-cancel-private-canary')),
    );
  });

  test('completed is not returned before stream cancel succeeds', () async {
    final cancelGate = Completer<void>();
    port.nextCancelGate = cancelGate;
    await source.subscribe('conversation-a');
    final handle = source.trustedHandle!;
    var completed = false;

    final cleanup = source.unsubscribe(handle)..then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    expect(source.diagnostics.quarantinedHandleCount, 1);
    cancelGate.complete();
    expect(await cleanup, RealtimeUnsubscribeObservation.completed);
    expect(completed, isTrue);
  });

  test('synchronous terminal callback still fences cancel failure', () async {
    port.nextOnListenStatus = RealtimeChannelStatus.channelError;
    port.nextCancelError = StateError('raw-sync-cancel-private-canary');

    expect(
      await source.subscribe('conversation-a'),
      ChatRealtimeSubscribeResult.stale,
    );
    final handle = port.subscribeCalls.single;

    expect(source.trustedHandle, isNull);
    expect(
      await source.unsubscribe(handle),
      RealtimeUnsubscribeObservation.uncertain,
    );
    expect(source.diagnostics.quarantinedHandleCount, 1);
    expect(port.unsubscribeCalls[handle], 1);
  });
}
