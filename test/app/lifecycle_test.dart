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
  Completer<bool>? authenticationGate;
  Completer<bool>? subscriptionGate;
  Completer<void>? connectionGapGate;
  Completer<void>? pollingGapGate;
  Completer<void>? outboxResumeGate;
  int authCalls = 0;
  int subscribeCalls = 0;
  int cancelledSubscriptionCompletions = 0;
  int connectionGapWrites = 0;
  int pollingGapCalls = 0;
  int pollingGapWrites = 0;
  int outboxResumeCalls = 0;

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
    events.add('subscribe');
    final gate = subscriptionGate;
    final result = gate != null
        ? await gate.future
        : subscriptionResults.isNotEmpty
        ? subscriptionResults.removeAt(0)
        : defaultSubscriptionResult;
    if (cancellation.isCancelled) cancelledSubscriptionCompletions += 1;
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
  }

  @override
  Future<void> pauseNewOutboxWork() async {
    events.add('outbox-pause');
    if (throwOnPause) throw StateError('pause failed');
  }

  @override
  Future<void> unsubscribe() async {
    events.add('unsubscribe');
    if (throwOnUnsubscribe) throw StateError('unsubscribe failed');
  }

  @override
  Future<void> cleanupAfterDetach() async {
    events.add('detach-cleanup');
  }

  @override
  Future<void> cleanupAfterLogout() async {
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
