import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/lifecycle.dart';
import 'package:timefit_native/features/chat/application/chat_connection_coordinator.dart';
import 'package:timefit_native/features/chat/application/reconnect_policy.dart';

void main() {
  group('ReconnectPolicy', () {
    test('uses 1 2 4 8 16 30 second bases and caps later attempts', () {
      final policy = ReconnectPolicy(randomUnit: () => 0.5);

      expect(
        <int>[
          for (var attempt = 1; attempt <= 8; attempt += 1)
            policy.delayForAttempt(attempt).inSeconds,
        ],
        <int>[1, 2, 4, 8, 16, 30, 30, 30],
      );
    });

    test('keeps jitter inside the exact twenty percent boundaries', () {
      expect(
        ReconnectPolicy(randomUnit: () => 0).delayForAttempt(1).inMilliseconds,
        800,
      );
      expect(
        ReconnectPolicy(randomUnit: () => 1).delayForAttempt(6).inMilliseconds,
        36000,
      );
      expect(
        () => ReconnectPolicy(randomUnit: () => -0.01).delayForAttempt(1),
        throwsStateError,
      );
      expect(
        () => ReconnectPolicy(randomUnit: () => double.nan).delayForAttempt(1),
        throwsStateError,
      );
      expect(
        () => ReconnectPolicy(randomUnit: () => 0.5).delayForAttempt(0),
        throwsArgumentError,
      );
    });
  });

  group('ChatConnectionCoordinator', () {
    late _FakeScheduler scheduler;
    late _FakeLifecyclePort port;
    late ChatConnectionCoordinator coordinator;

    setUp(() {
      scheduler = _FakeScheduler();
      port = _FakeLifecyclePort();
      coordinator = ChatConnectionCoordinator(
        port: port,
        scheduler: scheduler,
        reconnectPolicy: ReconnectPolicy(randomUnit: () => 0.5),
      );
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('resume runs auth subscribe gap-fill and Outbox in order', () async {
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);

      expect(port.events, <String>[
        'auth',
        'subscribe',
        'gap:connection',
        'gap-write:connection',
        'outbox-resume',
      ]);
      expect(coordinator.isSubscribed, isTrue);
      expect(scheduler.activeTimerCount, 0);
    });

    test('inactive four second return preserves the active channel', () async {
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      port.events.clear();

      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await scheduler.advance(const Duration(seconds: 4));
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await scheduler.advance(const Duration(seconds: 2));

      expect(port.events, isEmpty);
      expect(coordinator.isSubscribed, isTrue);
      expect(scheduler.activeTimerCount, 0);
    });

    test(
      'six second background pauses work then resume restores order',
      () async {
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        port.events.clear();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 6));

        expect(port.events, <String>['outbox-pause', 'unsubscribe']);
        expect(coordinator.isSubscribed, isFalse);

        port.events.clear();
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        expect(port.events, <String>[
          'auth',
          'subscribe',
          'gap:connection',
          'gap-write:connection',
          'outbox-resume',
        ]);
      },
    );

    test('direct hidden state receives the same five second grace', () async {
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      port.events.clear();

      await coordinator.handleLifecycleState(AppLifecycleState.hidden);
      await scheduler.advance(const Duration(milliseconds: 4999));
      expect(port.events, isEmpty);
      await scheduler.advance(const Duration(milliseconds: 1));

      expect(port.events, <String>['outbox-pause', 'unsubscribe']);
    });

    test(
      'pause after an elapsed inactive grace cleans up immediately',
      () async {
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        port.events.clear();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await scheduler.advance(const Duration(seconds: 6));
        expect(port.events, isEmpty);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(Duration.zero);

        expect(port.events, <String>['outbox-pause', 'unsubscribe']);
      },
    );

    test('repeated resume shares one in-flight sequence', () async {
      port.authenticationGate = Completer<bool>();

      final first = coordinator.handleLifecycleState(AppLifecycleState.resumed);
      final second = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      expect(identical(first, second), isTrue);
      expect(port.events, <String>['auth']);

      port.authenticationGate!.complete(true);
      await Future.wait(<Future<void>>[first, second]);

      expect(port.events.where((event) => event == 'subscribe'), hasLength(1));
      expect(
        port.events.where((event) => event == 'gap:connection'),
        hasLength(1),
      );
      expect(
        port.events.where((event) => event == 'outbox-resume'),
        hasLength(1),
      );
    });

    test('pause fences a late subscribe before gap-fill and Outbox', () async {
      port.subscriptionGate = Completer<bool>();
      final resume = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      await _flushAsync();
      expect(port.events, <String>['auth', 'subscribe']);

      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      port.subscriptionGate!.complete(true);
      await resume;

      expect(
        port.events,
        containsAllInOrder(<String>['outbox-pause', 'unsubscribe']),
      );
      expect(port.events.where((event) => event == 'gap:connection'), isEmpty);
      expect(port.events.where((event) => event == 'outbox-resume'), isEmpty);
      expect(port.cancelledSubscriptionCompletions, 1);
      expect(
        port.events.where((event) => event == 'unsubscribe'),
        hasLength(2),
        reason: 'a late successful subscribe is closed again',
      );
    });

    test('pause fences a delayed gap write and Outbox resume', () async {
      port.connectionGapGate = Completer<void>();
      final resume = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      await _flushAsync();
      expect(port.events, contains('gap:connection'));

      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      port.connectionGapGate!.complete();
      await resume;

      expect(port.connectionGapWrites, 0);
      expect(port.events, contains('gap-cancelled:connection'));
      expect(port.events.where((event) => event == 'outbox-resume'), isEmpty);
    });

    test('pause fences a delayed Outbox resume completion', () async {
      port.outboxResumeGate = Completer<void>();
      final resume = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      await _flushAsync();
      expect(port.events, contains('outbox-resume'));

      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      port.outboxResumeGate!.complete();
      await resume;

      expect(port.outboxResumeCalls, 0);
      expect(port.events, contains('outbox-cancelled'));
    });

    test('late background pause cannot undo a completed resume', () async {
      port.pauseGate = Completer<void>();
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      port.events.clear();

      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      expect(port.events, <String>['outbox-pause']);

      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      expect(port.subscriptionActive, isTrue);
      expect(port.outboxPaused, isFalse);
      port.pauseGate!.complete();
      await _flushAsync();

      expect(port.subscriptionActive, isTrue);
      expect(port.outboxPaused, isFalse);
      expect(coordinator.isSubscribed, isTrue);
      expect(
        port.events.where((event) => event == 'unsubscribe'),
        isEmpty,
        reason: 'stale cleanup must not unsubscribe the resumed generation',
      );
    });

    test(
      'late background unsubscribe repairs the resumed generation',
      () async {
        port.unsubscribeGate = Completer<void>();
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        port.events.clear();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        expect(port.events, <String>['outbox-pause', 'unsubscribe']);

        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        expect(port.subscriptionActive, isTrue);
        port.unsubscribeGate!.complete();
        await _flushAsync();

        expect(port.subscriptionActive, isTrue);
        expect(port.outboxPaused, isFalse);
        expect(coordinator.isSubscribed, isTrue);
        expect(
          port.events.where((event) => event == 'subscribe'),
          hasLength(2),
          reason: 'resume plus one repair after the stale unsubscribe',
        );
      },
    );

    test(
      'ambiguous late unsubscribe error repairs the resumed generation',
      () async {
        port.unsubscribeGate = Completer<void>();
        port.unsubscribeSideEffectThenError = true;
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        expect(port.subscriptionActive, isTrue);

        port.unsubscribeGate!.complete();
        await _flushAsync();

        expect(port.subscriptionActive, isTrue);
        expect(port.outboxPaused, isFalse);
        expect(coordinator.isSubscribed, isTrue);
        expect(port.subscribeCalls, 3);
      },
    );

    test('stalled reconnect repair does not hold logout cleanup', () async {
      port.unsubscribeGate = Completer<void>();
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);

      final repairGate = Completer<bool>();
      port.subscriptionGates.add(repairGate);
      port.unsubscribeGate!.complete();
      await _flushAsync();
      expect(port.subscribeCalls, 3);

      final firstResume = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      final secondResume = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      expect(identical(firstResume, secondResume), isTrue);

      var logoutCompleted = false;
      final logout = coordinator.logout().whenComplete(() {
        logoutCompleted = true;
      });
      await _flushAsync();

      expect(logoutCompleted, isTrue);
      expect(port.logoutCleanupCalls, 1);
      expect(port.subscriptionActive, isFalse);
      expect(port.outboxPaused, isTrue);

      repairGate.complete(true);
      await Future.wait(<Future<void>>[firstResume, secondResume, logout]);
      expect(port.subscriptionActive, isFalse);
      expect(port.outboxPaused, isTrue);
      expect(coordinator.isSubscribed, isFalse);
    });

    test('dispose is not held behind a stalled reconnect repair', () async {
      port.unsubscribeGate = Completer<void>();
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);

      final repairGate = Completer<bool>();
      port.subscriptionGates.add(repairGate);
      port.unsubscribeGate!.complete();
      await _flushAsync();
      expect(port.subscribeCalls, 3);

      final repair = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      coordinator.dispose();
      await _flushAsync();

      expect(port.subscriptionActive, isFalse);
      expect(port.outboxPaused, isTrue);
      expect(scheduler.activeTimerCount, 0);

      repairGate.complete(true);
      await repair;
      expect(port.subscriptionActive, isFalse);
      expect(port.outboxPaused, isTrue);
      expect(coordinator.isDisposed, isTrue);
    });

    test('expired auth leaves an ambiguous cleanup fail closed', () async {
      port.unsubscribeGate = Completer<void>();
      port.unsubscribeSideEffectThenError = true;
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);

      port.defaultAuthenticationResult = false;
      port.unsubscribeGate!.complete();
      await _flushAsync();

      expect(port.subscriptionActive, isFalse);
      expect(port.outboxPaused, isTrue);
      expect(coordinator.isSubscribed, isFalse);
      expect(scheduler.activeTimerCount, greaterThan(0));
    });

    test('partial subscribe side effect is closed before retry', () async {
      port.subscribeSideEffectThenError = true;

      await coordinator.handleLifecycleState(AppLifecycleState.resumed);

      expect(port.subscriptionActive, isFalse);
      expect(coordinator.isSubscribed, isFalse);
      expect(port.outboxResumeCalls, 0);
      expect(
        port.events,
        containsAllInOrder(<String>['subscribe', 'unsubscribe']),
      );
      expect(scheduler.activeTimerCount, greaterThan(0));
    });

    test(
      'late subscribe from an old generation reconverges the current one',
      () async {
        final oldSubscribe = Completer<bool>();
        port.subscriptionGates.add(oldSubscribe);
        final oldResume = coordinator.handleLifecycleState(
          AppLifecycleState.resumed,
        );
        await _flushAsync();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        expect(port.subscriptionActive, isTrue);
        expect(coordinator.isSubscribed, isTrue);

        oldSubscribe.complete(true);
        await oldResume;
        await _flushAsync();

        expect(port.subscriptionActive, isTrue);
        expect(port.outboxPaused, isFalse);
        expect(coordinator.isSubscribed, isTrue);
        expect(port.subscribeCalls, 3);
      },
    );

    test(
      'stale unsubscribe during inactive grace reconnects on resume',
      () async {
        final oldSubscribe = Completer<bool>();
        port.subscriptionGates.add(oldSubscribe);
        final oldResume = coordinator.handleLifecycleState(
          AppLifecycleState.resumed,
        );
        await _flushAsync();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        expect(port.subscriptionActive, isTrue);
        expect(coordinator.isSubscribed, isTrue);

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        oldSubscribe.complete(true);
        await oldResume;
        await _flushAsync();

        expect(port.subscriptionActive, isFalse);
        expect(port.outboxPaused, isTrue);
        expect(coordinator.isSubscribed, isFalse);

        await scheduler.advance(const Duration(seconds: 4));
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);

        expect(port.subscriptionActive, isTrue);
        expect(port.outboxPaused, isFalse);
        expect(coordinator.isSubscribed, isTrue);
        expect(port.subscribeCalls, 3);
      },
    );

    test(
      'ambiguous stale unsubscribe during inactive grace reconnects on resume',
      () async {
        final oldSubscribe = Completer<bool>();
        port.subscriptionGates.add(oldSubscribe);
        final oldResume = coordinator.handleLifecycleState(
          AppLifecycleState.resumed,
        );
        await _flushAsync();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        await coordinator.handleLifecycleState(AppLifecycleState.inactive);

        port.unsubscribeSideEffectThenError = true;
        oldSubscribe.complete(true);
        await oldResume;
        await _flushAsync();

        expect(port.subscriptionActive, isFalse);
        expect(port.outboxPaused, isTrue);
        expect(coordinator.isSubscribed, isFalse);

        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        expect(port.subscriptionActive, isTrue);
        expect(port.outboxPaused, isFalse);
        expect(coordinator.isSubscribed, isTrue);
      },
    );

    for (final backgroundState in <AppLifecycleState>[
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
    ]) {
      test(
        'inactive stale cleanup remains fenced through ${backgroundState.name}',
        () async {
          final oldSubscribe = Completer<bool>();
          port.subscriptionGates.add(oldSubscribe);
          final oldResume = coordinator.handleLifecycleState(
            AppLifecycleState.resumed,
          );
          await _flushAsync();

          await coordinator.handleLifecycleState(AppLifecycleState.inactive);
          await coordinator.handleLifecycleState(AppLifecycleState.paused);
          await scheduler.advance(const Duration(seconds: 5));
          await coordinator.handleLifecycleState(AppLifecycleState.resumed);
          await coordinator.handleLifecycleState(AppLifecycleState.inactive);

          oldSubscribe.complete(true);
          await oldResume;
          await _flushAsync();
          await coordinator.handleLifecycleState(backgroundState);
          await scheduler.advance(const Duration(seconds: 5));

          expect(port.subscriptionActive, isFalse);
          expect(port.outboxPaused, isTrue);
          expect(coordinator.isSubscribed, isFalse);

          await coordinator.handleLifecycleState(AppLifecycleState.resumed);
          expect(port.subscriptionActive, isTrue);
          expect(port.outboxPaused, isFalse);
          expect(coordinator.isSubscribed, isTrue);
          expect(port.subscribeCalls, 3);
        },
      );
    }

    test(
      'late subscribe error with a side effect reconverges the current one',
      () async {
        final oldSubscribe = Completer<bool>();
        port.subscriptionGates.add(oldSubscribe);
        port.subscribeSideEffectErrorCalls.add(1);
        final oldResume = coordinator.handleLifecycleState(
          AppLifecycleState.resumed,
        );
        await _flushAsync();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);

        oldSubscribe.complete(true);
        await oldResume;
        await _flushAsync();

        expect(port.subscriptionActive, isTrue);
        expect(port.outboxPaused, isFalse);
        expect(coordinator.isSubscribed, isTrue);
        expect(port.subscribeCalls, 3);
      },
    );

    test(
      'several stale generations converge to one active generation',
      () async {
        final firstSubscribe = Completer<bool>();
        final secondSubscribe = Completer<bool>();
        port.subscriptionGates.addAll(<Completer<bool>>[
          firstSubscribe,
          secondSubscribe,
        ]);
        final firstResume = coordinator.handleLifecycleState(
          AppLifecycleState.resumed,
        );
        await _flushAsync();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        final secondResume = coordinator.handleLifecycleState(
          AppLifecycleState.resumed,
        );
        await _flushAsync();

        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        expect(port.subscriptionActive, isTrue);

        firstSubscribe.complete(true);
        secondSubscribe.complete(true);
        await Future.wait(<Future<void>>[firstResume, secondResume]);
        await _flushAsync();

        expect(port.subscriptionActive, isTrue);
        expect(port.outboxPaused, isFalse);
        expect(coordinator.isSubscribed, isTrue);
        expect(port.subscribeCalls, 4);
      },
    );

    test('late old generation cannot resurrect after logout', () async {
      final oldSubscribe = Completer<bool>();
      port.subscriptionGates.add(oldSubscribe);
      final oldResume = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      await _flushAsync();

      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await coordinator.logout();

      oldSubscribe.complete(true);
      await oldResume;
      await _flushAsync();

      expect(port.subscriptionActive, isFalse);
      expect(port.outboxPaused, isTrue);
      expect(coordinator.isSubscribed, isFalse);
      expect(port.logoutCleanupCalls, 1);
    });

    test('late old generation cannot resurrect after dispose', () async {
      final oldSubscribe = Completer<bool>();
      port.subscriptionGates.add(oldSubscribe);
      final oldResume = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      await _flushAsync();

      coordinator.dispose();
      await _flushAsync();
      oldSubscribe.complete(true);
      await oldResume;
      await _flushAsync();

      expect(port.subscriptionActive, isFalse);
      expect(port.outboxPaused, isTrue);
      expect(coordinator.isSubscribed, isFalse);
      expect(scheduler.activeTimerCount, 0);
    });

    test('stalled Outbox repair does not hold logout cleanup', () async {
      port.pauseGate = Completer<void>();
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);

      port.outboxResumeGate = Completer<void>();
      port.pauseGate!.complete();
      await _flushAsync();

      final logout = coordinator.logout();
      await logout;
      expect(port.logoutCleanupCalls, 1);
      expect(port.outboxPaused, isTrue);

      port.outboxResumeGate!.complete();
      await _flushAsync();
      expect(port.outboxPaused, isTrue);
      expect(coordinator.isSubscribed, isFalse);
    });

    test('repeated background callbacks keep cleanup idempotent', () async {
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      port.events.clear();
      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));

      await coordinator.handleLifecycleState(AppLifecycleState.hidden);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(Duration.zero);

      expect(
        port.events.where((event) => event == 'outbox-pause'),
        hasLength(1),
      );
      expect(
        port.events.where((event) => event == 'unsubscribe'),
        hasLength(1),
      );
    });

    test('reconnect signals coalesce and follow the backoff series', () async {
      port.subscriptionResults.addAll(<bool>[false, false, true]);
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      coordinator.handleSubscriptionLost();
      coordinator.handleSubscriptionLost();

      expect(port.subscribeCalls, 1);
      await scheduler.advance(const Duration(milliseconds: 999));
      expect(port.subscribeCalls, 1);
      await scheduler.advance(const Duration(milliseconds: 1));
      expect(port.subscribeCalls, 2);
      await scheduler.advance(const Duration(seconds: 2));

      expect(port.subscribeCalls, 3);
      expect(coordinator.isSubscribed, isTrue);
      expect(port.connectionGapWrites, 1);
      expect(port.outboxResumeCalls, 1);
    });

    test(
      'foreground polling starts at thirty seconds and repeats at fifteen',
      () async {
        port.defaultSubscriptionResult = false;
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);

        await scheduler.advance(const Duration(seconds: 29));
        expect(port.pollingGapCalls, 0);
        await scheduler.advance(const Duration(seconds: 1));
        expect(port.pollingGapCalls, 1);
        await scheduler.advance(const Duration(seconds: 15));
        expect(port.pollingGapCalls, 2);
      },
    );

    test('successful reconnect cancels polling and its late write', () async {
      port.subscriptionResults.addAll(<bool>[
        false,
        false,
        false,
        false,
        false,
        true,
      ]);
      port.pollingGapGate = Completer<void>();
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);

      await scheduler.advance(const Duration(seconds: 30));
      expect(port.pollingGapCalls, 1);
      await scheduler.advance(const Duration(seconds: 1));
      expect(coordinator.isSubscribed, isTrue);
      expect(port.connectionGapWrites, 1);

      port.pollingGapGate!.complete();
      await _flushAsync();
      expect(port.pollingGapWrites, 0);
      expect(port.events, contains('gap-cancelled:polling'));
      await scheduler.advance(const Duration(seconds: 30));
      expect(port.pollingGapCalls, 1);
    });

    test('logout fences a late subscription and runs all cleanup', () async {
      port.subscriptionGate = Completer<bool>();
      final resume = coordinator.handleLifecycleState(
        AppLifecycleState.resumed,
      );
      await _flushAsync();

      await coordinator.logout();
      port.subscriptionGate!.complete(true);
      await resume;

      expect(
        port.events,
        containsAllInOrder(<String>[
          'outbox-pause',
          'unsubscribe',
          'logout-cleanup',
        ]),
      );
      expect(port.events.where((event) => event == 'outbox-resume'), isEmpty);
      expect(port.events.where((event) => event == 'gap:connection'), isEmpty);
      expect(coordinator.isSubscribed, isFalse);
    });

    test('repeated logout callers await the same cleanup future', () async {
      port.pauseGate = Completer<void>();
      final first = coordinator.logout();
      final second = coordinator.logout();
      var secondCompleted = false;
      unawaited(second.whenComplete(() => secondCompleted = true));
      await _flushAsync();

      expect(identical(first, second), isTrue);
      expect(secondCompleted, isFalse);
      expect(
        port.events.where((event) => event == 'outbox-pause'),
        hasLength(1),
      );

      port.pauseGate!.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(
        port.events.where((event) => event == 'unsubscribe'),
        hasLength(1),
      );
      expect(
        port.events.where((event) => event == 'logout-cleanup'),
        hasLength(1),
      );
    });

    test('detach and logout cleanup operations are serialized', () async {
      port.pauseGate = Completer<void>();
      final detach = coordinator.handleLifecycleState(
        AppLifecycleState.detached,
      );
      final logout = coordinator.logout();
      await _flushAsync();

      expect(port.activePauseCalls, 1);
      expect(port.pauseCalls, 1);
      port.pauseGate!.complete();
      await Future.wait(<Future<void>>[detach, logout]);

      expect(port.maximumPauseCalls, 1);
      expect(port.pauseCalls, 2);
      expect(
        port.events,
        containsAllInOrder(<String>['detach-cleanup', 'logout-cleanup']),
      );
    });

    test(
      'detached cleanup remains best effort after individual failures',
      () async {
        port.throwOnPause = true;
        port.throwOnUnsubscribe = true;

        await coordinator.handleLifecycleState(AppLifecycleState.detached);

        expect(port.events, <String>[
          'outbox-pause',
          'unsubscribe',
          'detach-cleanup',
        ]);
      },
    );

    test('dispose cancels reconnect and polling timers', () async {
      port.defaultSubscriptionResult = false;
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      expect(scheduler.activeTimerCount, 2);

      coordinator.dispose();
      expect(scheduler.activeTimerCount, 0);
      final authCalls = port.authCalls;
      await scheduler.advance(const Duration(minutes: 2));

      expect(port.authCalls, authCalls);
      expect(coordinator.isDisposed, isTrue);
    });

    test(
      'dispose queues cleanup behind an active background cleanup',
      () async {
        port.pauseGate = Completer<void>();
        await coordinator.handleLifecycleState(AppLifecycleState.resumed);
        await coordinator.handleLifecycleState(AppLifecycleState.inactive);
        await coordinator.handleLifecycleState(AppLifecycleState.paused);
        await scheduler.advance(const Duration(seconds: 5));
        expect(port.activePauseCalls, 1);

        coordinator.dispose();
        await _flushAsync();
        expect(port.pauseCalls, 1);
        expect(scheduler.activeTimerCount, 0);
        port.pauseGate!.complete();
        await _flushAsync();

        expect(port.maximumPauseCalls, 1);
        expect(port.pauseCalls, 2);
        expect(coordinator.isDisposed, isTrue);
      },
    );

    test('background never starts foreground polling', () async {
      port.defaultSubscriptionResult = false;
      await coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await coordinator.handleLifecycleState(AppLifecycleState.inactive);
      await coordinator.handleLifecycleState(AppLifecycleState.paused);
      await scheduler.advance(const Duration(seconds: 5));
      final authCalls = port.authCalls;

      await scheduler.advance(const Duration(minutes: 2));

      expect(port.pollingGapCalls, 0);
      expect(port.authCalls, authCalls);
    });

    test(
      'dispose fences an authentication request that completes late',
      () async {
        port.authenticationGate = Completer<bool>();
        final resume = coordinator.handleLifecycleState(
          AppLifecycleState.resumed,
        );
        coordinator.dispose();
        port.authenticationGate!.complete(true);
        await resume;

        expect(port.subscribeCalls, 0);
        expect(scheduler.activeTimerCount, 0);
      },
    );

    test(
      'Flutter observer forwards lifecycle without app bootstrap wiring',
      () async {
        final observer = TimeFitLifecycleObserver(coordinator: coordinator);

        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await _flushAsync();

        expect(port.events, containsAllInOrder(<String>['auth', 'subscribe']));
        observer.dispose();
      },
    );
  });
}

final class _FakeLifecyclePort implements ChatConnectionLifecyclePort {
  final events = <String>[];
  final subscriptionResults = <bool>[];
  bool defaultAuthenticationResult = true;
  bool defaultSubscriptionResult = true;
  bool throwOnPause = false;
  bool throwOnUnsubscribe = false;
  bool subscribeSideEffectThenError = false;
  bool unsubscribeSideEffectThenError = false;
  final subscribeSideEffectErrorCalls = <int>{};
  Completer<bool>? authenticationGate;
  Completer<bool>? subscriptionGate;
  final subscriptionGates = <Completer<bool>>[];
  Completer<void>? connectionGapGate;
  Completer<void>? pollingGapGate;
  Completer<void>? outboxResumeGate;
  Completer<void>? pauseGate;
  Completer<void>? unsubscribeGate;
  int authCalls = 0;
  int subscribeCalls = 0;
  int cancelledSubscriptionCompletions = 0;
  int connectionGapWrites = 0;
  int pollingGapCalls = 0;
  int pollingGapWrites = 0;
  int outboxResumeCalls = 0;
  int pauseCalls = 0;
  int activePauseCalls = 0;
  int maximumPauseCalls = 0;
  int logoutCleanupCalls = 0;
  bool subscriptionActive = false;
  bool outboxPaused = false;

  @override
  Future<bool> refreshAuthentication(
    ChatLifecycleCancellation cancellation,
  ) async {
    authCalls += 1;
    events.add('auth');
    final gate = authenticationGate;
    if (gate != null) return gate.future;
    return defaultAuthenticationResult;
  }

  @override
  Future<bool> subscribe(ChatLifecycleCancellation cancellation) async {
    subscribeCalls += 1;
    final call = subscribeCalls;
    events.add('subscribe');
    if (subscribeSideEffectThenError) {
      subscriptionActive = true;
      throw StateError('ambiguous subscribe failure');
    }
    final gate = subscriptionGates.isNotEmpty
        ? subscriptionGates.removeAt(0)
        : subscriptionGate;
    final result = gate != null
        ? await gate.future
        : subscriptionResults.isNotEmpty
        ? subscriptionResults.removeAt(0)
        : defaultSubscriptionResult;
    if (subscribeSideEffectErrorCalls.remove(call)) {
      subscriptionActive = true;
      throw StateError('ambiguous subscribe failure');
    }
    if (cancellation.isCancelled) cancelledSubscriptionCompletions += 1;
    if (result) subscriptionActive = true;
    return result;
  }

  @override
  Future<void> gapFill(ChatLifecycleCancellation cancellation) async {
    events.add('gap:${cancellation.operation.name}');
    if (cancellation.operation == ChatLifecycleOperation.polling) {
      pollingGapCalls += 1;
      final gate = pollingGapGate;
      if (gate != null) await gate.future;
      if (cancellation.isCancelled) {
        events.add('gap-cancelled:polling');
        return;
      }
      pollingGapWrites += 1;
      events.add('gap-write:polling');
      return;
    }
    final gate = connectionGapGate;
    if (gate != null) await gate.future;
    if (cancellation.isCancelled) {
      events.add('gap-cancelled:connection');
      return;
    }
    connectionGapWrites += 1;
    events.add('gap-write:connection');
  }

  @override
  Future<void> resumeOutbox(ChatLifecycleCancellation cancellation) async {
    events.add('outbox-resume');
    final gate = outboxResumeGate;
    if (gate != null) await gate.future;
    if (cancellation.isCancelled) {
      events.add('outbox-cancelled');
      return;
    }
    outboxResumeCalls += 1;
    outboxPaused = false;
  }

  @override
  Future<void> pauseNewOutboxWork() async {
    pauseCalls += 1;
    activePauseCalls += 1;
    if (activePauseCalls > maximumPauseCalls) {
      maximumPauseCalls = activePauseCalls;
    }
    events.add('outbox-pause');
    try {
      final gate = pauseGate;
      if (gate != null) await gate.future;
      if (throwOnPause) throw StateError('pause failed');
      outboxPaused = true;
    } finally {
      activePauseCalls -= 1;
    }
  }

  @override
  Future<void> unsubscribe() async {
    events.add('unsubscribe');
    final gate = unsubscribeGate;
    if (gate != null) await gate.future;
    if (unsubscribeSideEffectThenError) {
      subscriptionActive = false;
      throw StateError('ambiguous unsubscribe failure');
    }
    if (throwOnUnsubscribe) throw StateError('unsubscribe failed');
    subscriptionActive = false;
  }

  @override
  Future<void> cleanupAfterDetach() async {
    events.add('detach-cleanup');
  }

  @override
  Future<void> cleanupAfterLogout() async {
    logoutCleanupCalls += 1;
    events.add('logout-cleanup');
  }
}

final class _FakeScheduler implements LifecycleScheduler {
  DateTime _now = DateTime.utc(2026, 10, 29);
  int _nextOrder = 0;
  final _timers = <_FakeTimer>[];

  @override
  DateTime get now => _now;

  int get activeTimerCount => _timers.where((timer) => timer.isActive).length;

  @override
  LifecycleTimer schedule(Duration delay, void Function() callback) {
    if (delay.isNegative) throw ArgumentError.value(delay, 'delay');
    final timer = _FakeTimer(
      deadline: _now.add(delay),
      order: _nextOrder,
      callback: callback,
    );
    _nextOrder += 1;
    _timers.add(timer);
    return timer;
  }

  Future<void> advance(Duration duration) async {
    final target = _now.add(duration);
    while (true) {
      final due =
          _timers
              .where(
                (timer) => timer.isActive && !timer.deadline.isAfter(target),
              )
              .toList()
            ..sort((left, right) {
              final byDeadline = left.deadline.compareTo(right.deadline);
              return byDeadline != 0
                  ? byDeadline
                  : left.order.compareTo(right.order);
            });
      if (due.isEmpty) break;
      final timer = due.first;
      _now = timer.deadline;
      timer.fire();
      await _flushAsync();
    }
    _now = target;
    await _flushAsync();
  }
}

final class _FakeTimer implements LifecycleTimer {
  _FakeTimer({
    required this.deadline,
    required this.order,
    required this.callback,
  });

  final DateTime deadline;
  final int order;
  final void Function() callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}

Future<void> _flushAsync() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
