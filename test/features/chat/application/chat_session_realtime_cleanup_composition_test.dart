import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/network/realtime_client.dart';
import 'package:timefit_native/features/chat/application/chat_connection_coordinator.dart';
import 'package:timefit_native/features/chat/application/chat_session_coordinator.dart';
import 'package:timefit_native/features/chat/application/reconnect_policy.dart';
import 'package:timefit_native/features/chat/data/chat_realtime_source.dart';

import '../data/support/fake_realtime_port.dart';

// Test-only candidate composition. It proves local ordering and fences without
// choosing an Auth, wire, timeout, SDK, app-entry, or server adapter contract.
// Product code intentionally does not construct this harness.
void main() {
  test(
    'logout fences hints before repository drain and shares delayed cleanup',
    () async {
      final realtimePort = FakeRealtimeReadPort();
      final realtime = ChatRealtimeSource(port: realtimePort);
      final lifecyclePort = _DelayedLifecyclePort();
      final lifecycle = _lifecycle(lifecyclePort);
      final sourceUnsubscribe = Completer<RealtimeUnsubscribeObservation>();
      var purgeCalls = 0;
      final composition = _TestOnlySessionRealtimeComposition(
        realtime: realtime,
        lifecycle: lifecycle,
        purgeLocalData: () async {
          purgeCalls += 1;
        },
      );
      addTearDown(() async {
        await composition.close();
        await realtimePort.close();
      });

      expect(
        await composition.subscribe('conversation-a'),
        ChatRealtimeSubscribeResult.trusted,
      );
      final handle = realtime.trustedHandle!;
      realtimePort.unsubscribeGates[handle] = sourceUnsubscribe;
      final hints = <int>[];
      final hintSubscription = realtime.hints.listen(
        (hint) => hints.add(hint.sequence),
      );
      addTearDown(hintSubscription.cancel);
      realtimePort.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: 'before-logout',
          conversationId: 'conversation-a',
          sequence: 1,
        ),
      );
      expect(hints, <int>[1]);

      final mutationStarted = Completer<void>();
      final releaseMutation = Completer<void>();
      final mutation = composition.session.repository
          .withAttachmentDraftMutation('draft-a', () async {
            mutationStarted.complete();
            await releaseMutation.future;
          });
      await mutationStarted.future;

      final firstLogout = composition.logout();
      final secondLogout = composition.logout();
      expect(identical(firstLogout, secondLogout), isTrue);
      expect(composition.coordinator.state, LocalChatSessionState.loggingOut);
      expect(realtime.trustedHandle, isNull);
      expect(
        realtimePort.quarantineCalls
            .where(
              (entry) =>
                  identical(entry.handle, handle) &&
                  entry.reason == RealtimeQuarantineReason.sessionRevoked,
            )
            .length,
        1,
      );

      realtimePort.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: 'during-repository-drain',
          conversationId: 'conversation-a',
          sequence: 2,
        ),
      );
      expect(hints, <int>[1]);
      expect(lifecyclePort.pauseCalls, 0);

      releaseMutation.complete();
      await mutation;
      await _flushAsync();
      expect(lifecyclePort.pauseCalls, 0);

      sourceUnsubscribe.complete(RealtimeUnsubscribeObservation.completed);
      await lifecyclePort.logoutStarted.future;
      expect(lifecyclePort.pauseCalls, 1);
      expect(lifecyclePort.unsubscribeCalls, 1);
      expect(lifecyclePort.logoutCleanupCalls, 1);
      expect(purgeCalls, 0);

      lifecyclePort.releaseLogout();
      await Future.wait<void>(<Future<void>>[firstLogout, secondLogout]);

      expect(composition.coordinator.state, LocalChatSessionState.idle);
      expect(purgeCalls, 1);
      expect(realtimePort.unsubscribeCalls[handle], 1);
      expect(lifecyclePort.pauseCalls, 1);
      expect(lifecyclePort.unsubscribeCalls, 1);
      expect(lifecyclePort.logoutCleanupCalls, 1);
    },
  );

  test(
    'cleanupPending keeps the source fenced and retry does not re-close it',
    () async {
      final realtimePort = FakeRealtimeReadPort();
      final realtime = ChatRealtimeSource(port: realtimePort);
      final lifecyclePort = _DelayedLifecyclePort(autoReleaseLogout: true);
      final lifecycle = _lifecycle(lifecyclePort);
      var failPurge = true;
      var purgeCalls = 0;
      final retryPurge = Completer<void>();
      final composition = _TestOnlySessionRealtimeComposition(
        realtime: realtime,
        lifecycle: lifecycle,
        purgeLocalData: () async {
          purgeCalls += 1;
          if (failPurge) throw const _CandidatePurgeFailure();
          await retryPurge.future;
        },
      );
      addTearDown(() async {
        await composition.close();
        await realtimePort.close();
      });

      await composition.subscribe('conversation-a');
      final handle = realtime.trustedHandle!;
      final hints = <int>[];
      final hintSubscription = realtime.hints.listen(
        (hint) => hints.add(hint.sequence),
      );
      addTearDown(hintSubscription.cancel);

      await expectLater(
        composition.logout(),
        throwsA(isA<_CandidatePurgeFailure>()),
      );
      expect(
        composition.coordinator.state,
        LocalChatSessionState.cleanupPending,
      );
      expect(
        composition.coordinator.lastFailedStage,
        LocalChatSessionCleanupStage.purgeLocalData,
      );
      expect(realtime.trustedHandle, isNull);
      expect(realtimePort.unsubscribeCalls[handle], 1);
      expect(lifecyclePort.logoutCleanupCalls, 1);

      realtimePort.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: 'cleanup-pending',
          conversationId: 'conversation-a',
          sequence: 3,
        ),
      );
      expect(hints, isEmpty);
      expect(
        await composition.subscribe('conversation-b'),
        ChatRealtimeSubscribeResult.disposed,
      );

      failPurge = false;
      final firstRetry = composition.retryCleanup();
      final secondRetry = composition.retryCleanup();
      expect(identical(firstRetry, secondRetry), isTrue);
      await _flushAsync();
      expect(purgeCalls, 2);
      expect(realtimePort.unsubscribeCalls[handle], 1);
      expect(lifecyclePort.logoutCleanupCalls, 1);

      retryPurge.complete();
      await Future.wait<void>(<Future<void>>[firstRetry, secondRetry]);
      expect(composition.coordinator.state, LocalChatSessionState.idle);
    },
  );

  test(
    'dispose joins an in-flight logout and cannot revive a late callback',
    () async {
      final realtimePort = FakeRealtimeReadPort();
      final realtime = ChatRealtimeSource(port: realtimePort);
      final lifecyclePort = _DelayedLifecyclePort();
      final lifecycle = _lifecycle(lifecyclePort);
      final sourceUnsubscribe = Completer<RealtimeUnsubscribeObservation>();
      final composition = _TestOnlySessionRealtimeComposition(
        realtime: realtime,
        lifecycle: lifecycle,
        purgeLocalData: () async {},
      );
      addTearDown(() async {
        await composition.close();
        await realtimePort.close();
      });

      await composition.subscribe('conversation-a');
      final handle = realtime.trustedHandle!;
      realtimePort.unsubscribeGates[handle] = sourceUnsubscribe;
      final hints = <int>[];
      final hintSubscription = realtime.hints.listen(
        (hint) => hints.add(hint.sequence),
      );
      addTearDown(hintSubscription.cancel);

      final logout = composition.logout();
      final disposal = composition.dispose();
      final repeatedDisposal = composition.dispose();
      expect(identical(logout, disposal), isTrue);
      expect(identical(disposal, repeatedDisposal), isTrue);
      expect(realtime.diagnostics.disposed, isTrue);

      realtimePort.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: 'after-dispose',
          conversationId: 'conversation-a',
          sequence: 4,
        ),
      );
      expect(hints, isEmpty);

      sourceUnsubscribe.complete(RealtimeUnsubscribeObservation.completed);
      await lifecyclePort.logoutStarted.future;
      lifecyclePort.releaseLogout();
      await Future.wait<void>(<Future<void>>[
        logout,
        disposal,
        repeatedDisposal,
      ]);

      expect(composition.coordinator.state, LocalChatSessionState.disposed);
      expect(realtimePort.unsubscribeCalls[handle], 1);
      expect(lifecyclePort.logoutCleanupCalls, 1);
      expect(
        () => composition.coordinator.openSession(
          namespace: 'after-dispose',
          stopLifecycleAndOutbox: () async {},
          purgeLocalData: () async {},
        ),
        throwsA(isA<LocalChatSessionException>()),
      );
    },
  );
}

ChatConnectionCoordinator _lifecycle(_DelayedLifecyclePort port) =>
    ChatConnectionCoordinator(
      port: port,
      scheduler: const SystemLifecycleScheduler(),
      reconnectPolicy: ReconnectPolicy(randomUnit: () => 0.5),
    );

final class _TestOnlySessionRealtimeComposition {
  _TestOnlySessionRealtimeComposition({
    required this.realtime,
    required this.lifecycle,
    required Future<void> Function() purgeLocalData,
  }) : coordinator = LocalChatSessionCoordinator() {
    session = coordinator.openSession(
      namespace: 'opaque-test-namespace',
      stopLifecycleAndOutbox: _stopLifecycleAndRealtime,
      purgeLocalData: purgeLocalData,
    );
  }

  final ChatRealtimeSource realtime;
  final ChatConnectionCoordinator lifecycle;
  final LocalChatSessionCoordinator coordinator;
  late final LocalChatSession session;
  RealtimeSubscriptionHandle? _cleanupHandle;
  bool _fenced = false;
  bool _realtimeDisposed = false;

  Future<ChatRealtimeSubscribeResult> subscribe(String conversationId) {
    if (_fenced) {
      return Future<ChatRealtimeSubscribeResult>.value(
        ChatRealtimeSubscribeResult.disposed,
      );
    }
    return realtime.subscribe(conversationId);
  }

  Future<void> logout() {
    _fenceRealtime(dispose: false);
    return coordinator.logout();
  }

  Future<void> retryCleanup() => coordinator.retryCleanup();

  Future<void> dispose() {
    _fenceRealtime(dispose: true);
    return coordinator.dispose();
  }

  Future<void> _stopLifecycleAndRealtime() async {
    final handle = _cleanupHandle;
    if (handle != null) await realtime.unsubscribe(handle);
    await lifecycle.logout();
  }

  void _fenceRealtime({required bool dispose}) {
    _cleanupHandle ??= realtime.trustedHandle;
    if (dispose) {
      if (!_realtimeDisposed) {
        _realtimeDisposed = true;
        realtime.dispose();
      }
      _fenced = true;
      return;
    }
    if (_fenced) return;
    _fenced = true;
    realtime.revokeSession();
  }

  Future<void> close() async {
    if (coordinator.state == LocalChatSessionState.active) {
      await dispose();
    }
    if (!_realtimeDisposed) {
      _realtimeDisposed = true;
      realtime.dispose();
    }
    lifecycle.dispose();
  }
}

final class _DelayedLifecyclePort implements ChatConnectionLifecyclePort {
  _DelayedLifecyclePort({this.autoReleaseLogout = false});

  final bool autoReleaseLogout;
  final Completer<void> logoutStarted = Completer<void>();
  final Completer<void> _logoutRelease = Completer<void>();
  int pauseCalls = 0;
  int unsubscribeCalls = 0;
  int logoutCleanupCalls = 0;

  @override
  Future<bool> refreshAuthentication(
    ChatLifecycleCancellation cancellation,
  ) async => true;

  @override
  Future<bool> subscribe(ChatLifecycleCancellation cancellation) async => true;

  @override
  Future<void> gapFill(ChatLifecycleCancellation cancellation) async {}

  @override
  Future<void> resumeOutbox(ChatLifecycleCancellation cancellation) async {}

  @override
  Future<void> pauseNewOutboxWork() async {
    pauseCalls += 1;
  }

  @override
  Future<void> unsubscribe() async {
    unsubscribeCalls += 1;
  }

  @override
  Future<void> cleanupAfterDetach() async {}

  @override
  Future<void> cleanupAfterLogout() async {
    logoutCleanupCalls += 1;
    if (!logoutStarted.isCompleted) logoutStarted.complete();
    if (!autoReleaseLogout) await _logoutRelease.future;
  }

  void releaseLogout() {
    if (!_logoutRelease.isCompleted) _logoutRelease.complete();
  }
}

final class _CandidatePurgeFailure implements Exception {
  const _CandidatePurgeFailure();
}

Future<void> _flushAsync() => Future<void>.delayed(Duration.zero);
