import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/chat_session_coordinator.dart';

import '../../../support/manual_chat_cleanup_boundary.dart';

void main() {
  test('every pending stage stays fail-closed until manual release', () async {
    final boundary = ManualChatCleanupBoundary();
    final run = boundary.beginRun();
    final lifecycle = run.control(ManualCleanupStage.stopLifecycleAndOutbox);
    final purge = run.control(ManualCleanupStage.purgeLocalData);
    final coordinator = LocalChatSessionCoordinator();
    final session = coordinator.openSession(
      namespace: 'opaque-a',
      stopLifecycleAndOutbox: lifecycle.call,
      purgeLocalData: purge.call,
    );
    final mutationStarted = Completer<void>();
    final releaseMutation = Completer<void>();
    final mutation = session.repository.withAttachmentDraftMutation(
      'opaque-draft',
      () async {
        mutationStarted.complete();
        await releaseMutation.future;
      },
    );
    await mutationStarted.future;

    final logout = coordinator.logout();
    final repeatedLogout = coordinator.logout();
    final dispose = coordinator.dispose();
    expect(identical(logout, repeatedLogout), isTrue);
    expect(identical(logout, dispose), isTrue);
    expect(coordinator.state, LocalChatSessionState.loggingOut);
    await expectLater(
      session.repository.read(() async => 1),
      throwsA(isA<LocalRepositoryException>()),
    );
    await _flushAsync();
    expect(lifecycle.isStarted, isFalse);

    releaseMutation.complete();
    await mutation;
    await lifecycle.started;
    expect(coordinator.state, LocalChatSessionState.loggingOut);
    expect(boundary.observeTimedOut(lifecycle), isTrue);
    expect(lifecycle.timedOutObserved, isTrue);
    expect(lifecycle.isCompleted, isFalse);
    expect(purge.isStarted, isFalse);

    lifecycle.succeed();
    await purge.started;
    expect(
      () => coordinator.openSession(
        namespace: 'opaque-b',
        stopLifecycleAndOutbox: () async {},
        purgeLocalData: () async {},
      ),
      throwsA(isA<LocalChatSessionException>()),
    );
    expect(boundary.observeTimedOut(purge), isTrue);
    expect(coordinator.state, LocalChatSessionState.loggingOut);

    purge.succeed();
    await Future.wait<void>(<Future<void>>[logout, repeatedLogout, dispose]);
    expect(coordinator.state, LocalChatSessionState.disposed);
  });

  test(
    'late lifecycle failure becomes cleanupPending and retries stage',
    () async {
      final boundary = ManualChatCleanupBoundary();
      final firstRun = boundary.beginRun();
      final firstLifecycle = firstRun.control(
        ManualCleanupStage.stopLifecycleAndOutbox,
      );
      final retryLifecycle = firstRun.control(
        ManualCleanupStage.stopLifecycleAndOutbox,
      );
      final purge = firstRun.control(ManualCleanupStage.purgeLocalData);
      final lifecycleQueue = <ManualCleanupControl>[
        firstLifecycle,
        retryLifecycle,
      ];
      var lifecycleIndex = 0;
      final coordinator = LocalChatSessionCoordinator();
      coordinator.openSession(
        namespace: 'opaque-a',
        stopLifecycleAndOutbox: () => lifecycleQueue[lifecycleIndex++].call(),
        purgeLocalData: purge.call,
      );

      final logout = coordinator.logout();
      await firstLifecycle.started;
      boundary.observeTimedOut(firstLifecycle);
      expect(coordinator.state, LocalChatSessionState.loggingOut);
      firstLifecycle.fail();
      await expectLater(logout, throwsA(isA<ManualCleanupException>()));
      expect(coordinator.state, LocalChatSessionState.cleanupPending);
      expect(
        coordinator.lastFailedStage,
        LocalChatSessionCleanupStage.stopLifecycleAndOutbox,
      );

      final retry = coordinator.retryCleanup();
      final repeated = coordinator.retryCleanup();
      expect(identical(retry, repeated), isTrue);
      await retryLifecycle.started;
      retryLifecycle.succeed();
      await purge.started;
      purge.succeed();
      await Future.wait<void>(<Future<void>>[retry, repeated]);
      expect(coordinator.state, LocalChatSessionState.idle);
    },
  );

  test(
    'purge failure stays pending and retry never repeats lifecycle',
    () async {
      final boundary = ManualChatCleanupBoundary();
      final run = boundary.beginRun();
      final lifecycle = run.control(ManualCleanupStage.stopLifecycleAndOutbox)
        ..succeed();
      final firstPurge = run.control(ManualCleanupStage.purgeLocalData);
      final retryPurge = run.control(ManualCleanupStage.purgeLocalData);
      final purgeQueue = <ManualCleanupControl>[firstPurge, retryPurge];
      var purgeIndex = 0;
      var lifecycleCalls = 0;
      final coordinator = LocalChatSessionCoordinator();
      coordinator.openSession(
        namespace: 'opaque-a',
        stopLifecycleAndOutbox: () {
          lifecycleCalls += 1;
          return lifecycle.call();
        },
        purgeLocalData: () => purgeQueue[purgeIndex++].call(),
      );

      final logout = coordinator.logout();
      await firstPurge.started;
      boundary.observeTimedOut(firstPurge);
      expect(coordinator.state, LocalChatSessionState.loggingOut);
      firstPurge.fail();
      await expectLater(logout, throwsA(isA<ManualCleanupException>()));
      expect(coordinator.state, LocalChatSessionState.cleanupPending);
      expect(
        coordinator.lastFailedStage,
        LocalChatSessionCleanupStage.purgeLocalData,
      );

      final retry = coordinator.retryCleanup();
      await retryPurge.started;
      retryPurge.succeed();
      await retry;
      expect(lifecycleCalls, 1);
      expect(coordinator.state, LocalChatSessionState.idle);
    },
  );

  test('manual timeout observation never completes an operation', () async {
    final boundary = ManualChatCleanupBoundary();
    final run = boundary.beginRun();
    final control = run.control(ManualCleanupStage.purgeLocalData);
    var completed = false;
    final pending = control.call().then((_) => completed = true);
    await control.started;

    expect(boundary.observeTimedOut(control), isTrue);
    await _flushAsync();
    expect(completed, isFalse);
    expect(control.isCompleted, isFalse);

    control.succeed();
    await pending;
    expect(completed, isTrue);
  });

  test('late completion is stale after boundary generation changes', () async {
    final boundary = ManualChatCleanupBoundary();
    final oldRun = boundary.beginRun();
    final old = oldRun.control(ManualCleanupStage.purgeLocalData);
    final oldFuture = old.call();
    await old.started;
    final currentRun = boundary.beginRun();
    final current = currentRun.control(ManualCleanupStage.purgeLocalData);

    expect(oldRun.accepts(old), isFalse);
    expect(currentRun.accepts(current), isTrue);
    expect(boundary.observeTimedOut(old), isFalse);
    old.succeed();
    await oldFuture;
    expect(current.isCompleted, isFalse);
    current.succeed();
  });
}

Future<void> _flushAsync() => Future<void>.delayed(Duration.zero);
