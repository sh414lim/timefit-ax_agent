import 'dart:async';

import 'package:flutter/widgets.dart';

import 'reconnect_policy.dart';

enum ChatLifecycleOperation { connection, polling }

abstract interface class ChatLifecycleCancellation {
  ChatLifecycleOperation get operation;
  bool get isCancelled;
}

/// Local lifecycle seam. A future server adapter may implement this interface,
/// but this ticket intentionally provides no Auth, Realtime, or RPC wiring.
abstract interface class ChatConnectionLifecyclePort {
  Future<bool> refreshAuthentication(ChatLifecycleCancellation cancellation);

  Future<bool> subscribe(ChatLifecycleCancellation cancellation);

  Future<void> gapFill(ChatLifecycleCancellation cancellation);

  Future<void> resumeOutbox(ChatLifecycleCancellation cancellation);

  Future<void> pauseNewOutboxWork();

  Future<void> unsubscribe();

  Future<void> cleanupAfterDetach();

  Future<void> cleanupAfterLogout();
}

abstract interface class LifecycleTimer {
  bool get isActive;
  void cancel();
}

abstract interface class LifecycleScheduler {
  DateTime get now;

  LifecycleTimer schedule(Duration delay, void Function() callback);
}

final class SystemLifecycleScheduler implements LifecycleScheduler {
  const SystemLifecycleScheduler();

  @override
  DateTime get now => DateTime.now().toUtc();

  @override
  LifecycleTimer schedule(Duration delay, void Function() callback) {
    return _SystemLifecycleTimer(Timer(delay, callback));
  }
}

final class _SystemLifecycleTimer implements LifecycleTimer {
  _SystemLifecycleTimer(this._timer);

  final Timer _timer;

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() => _timer.cancel();
}

/// Coordinates local lifecycle ordering without choosing a server SDK or wire
/// contract. Every asynchronous port call receives a cancellation fence so a
/// future adapter can reject stale writes after pause, logout, or dispose.
final class ChatConnectionCoordinator {
  ChatConnectionCoordinator({
    required ChatConnectionLifecyclePort port,
    required LifecycleScheduler scheduler,
    required ReconnectPolicy reconnectPolicy,
  }) : _port = port,
       _scheduler = scheduler,
       _reconnectPolicy = reconnectPolicy;

  static const backgroundGrace = Duration(seconds: 5);
  static const pollingThreshold = Duration(seconds: 30);
  static const pollingInterval = Duration(seconds: 15);

  final ChatConnectionLifecyclePort _port;
  final LifecycleScheduler _scheduler;
  final ReconnectPolicy _reconnectPolicy;

  AppLifecycleState? _lifecycleState;
  DateTime? _backgroundGraceStartedAt;
  DateTime? _disconnectedSince;
  LifecycleTimer? _backgroundGraceTimer;
  LifecycleTimer? _reconnectTimer;
  LifecycleTimer? _pollingThresholdTimer;
  LifecycleTimer? _pollingTimer;
  Future<void>? _connectionRun;
  int? _connectionRunGeneration;
  Future<void>? _pollingRun;
  int _generation = 0;
  int _pollingGeneration = 0;
  int _reconnectAttempt = 0;
  bool _foreground = false;
  bool _subscribed = false;
  bool _loggedOut = false;
  bool _disposed = false;

  bool get isSubscribed => _subscribed;
  bool get isDisposed => _disposed;

  Future<void> handleLifecycleState(AppLifecycleState state) {
    if (_disposed || _loggedOut) return Future<void>.value();
    final previous = _lifecycleState;
    _lifecycleState = state;
    return switch (state) {
      AppLifecycleState.resumed => _handleResumed(previous),
      AppLifecycleState.inactive => _handleInactive(),
      AppLifecycleState.paused ||
      AppLifecycleState.hidden => _handleBackgroundPending(),
      AppLifecycleState.detached => _handleDetached(),
    };
  }

  /// Called only from a future Realtime adapter when an active subscription is
  /// lost. Repeated signals coalesce into the existing reconnect timer.
  void handleSubscriptionLost() {
    if (_disposed || _loggedOut || !_foreground) return;
    final alreadyDisconnected = !_subscribed && _disconnectedSince != null;
    _subscribed = false;
    if (!alreadyDisconnected) _generation += 1;
    _beginDisconnectedWindow();
    _scheduleReconnect();
  }

  Future<void> logout() {
    if (_disposed || _loggedOut) return Future<void>.value();
    _loggedOut = true;
    _foreground = false;
    _subscribed = false;
    _generation += 1;
    _cancelAllTimers();
    _stopPolling(resetWindow: true);
    return _runBestEffort(<Future<void> Function()>[
      _port.pauseNewOutboxWork,
      _port.unsubscribe,
      _port.cleanupAfterLogout,
    ]);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _foreground = false;
    _subscribed = false;
    _generation += 1;
    _cancelAllTimers();
    _stopPolling(resetWindow: true);
    unawaited(
      _runBestEffort(<Future<void> Function()>[
        _port.pauseNewOutboxWork,
        _port.unsubscribe,
      ]),
    );
  }

  Future<void> _handleResumed(AppLifecycleState? previous) {
    _foreground = true;
    _cancelBackgroundGrace(clearStart: true);
    if (_subscribed) return Future<void>.value();
    if (_connectionRun != null && _connectionRunGeneration == _generation) {
      return _connectionRun!;
    }
    if (previous == AppLifecycleState.resumed &&
        _reconnectTimer?.isActive == true) {
      return Future<void>.value();
    }
    _generation += 1;
    _reconnectAttempt = 0;
    _cancelReconnectTimer();
    _stopPolling(resetWindow: true);
    _beginDisconnectedWindow();
    return _beginConnectionRun(_generation);
  }

  Future<void> _handleInactive() {
    _foreground = false;
    _backgroundGraceStartedAt ??= _scheduler.now;
    _ensureBackgroundGraceTimer();
    return Future<void>.value();
  }

  Future<void> _handleBackgroundPending() {
    _foreground = false;
    _backgroundGraceStartedAt ??= _scheduler.now;
    _ensureBackgroundGraceTimer();
    return Future<void>.value();
  }

  Future<void> _handleDetached() {
    _foreground = false;
    _subscribed = false;
    _generation += 1;
    _cancelAllTimers();
    _stopPolling(resetWindow: true);
    return _runBestEffort(<Future<void> Function()>[
      _port.pauseNewOutboxWork,
      _port.unsubscribe,
      _port.cleanupAfterDetach,
    ]);
  }

  void _ensureBackgroundGraceTimer() {
    if (_backgroundGraceTimer?.isActive == true) return;
    final startedAt = _backgroundGraceStartedAt ?? _scheduler.now;
    final elapsed = _scheduler.now.difference(startedAt);
    final remaining = backgroundGrace - elapsed;
    _backgroundGraceTimer = _scheduler.schedule(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        _backgroundGraceTimer = null;
        if (_disposed || _loggedOut) return;
        final state = _lifecycleState;
        if (state != AppLifecycleState.paused &&
            state != AppLifecycleState.hidden) {
          return;
        }
        _generation += 1;
        _subscribed = false;
        _cancelReconnectTimer();
        _stopPolling(resetWindow: true);
        unawaited(
          _runBestEffort(<Future<void> Function()>[
            _port.pauseNewOutboxWork,
            _port.unsubscribe,
          ]),
        );
      },
    );
  }

  Future<void> _beginConnectionRun(int generation) {
    if (_connectionRun != null && _connectionRunGeneration == generation) {
      return _connectionRun!;
    }
    late final Future<void> run;
    run = _runConnection(generation).whenComplete(() {
      if (identical(_connectionRun, run)) {
        _connectionRun = null;
        _connectionRunGeneration = null;
      }
    });
    _connectionRun = run;
    _connectionRunGeneration = generation;
    return run;
  }

  Future<void> _runConnection(int generation) async {
    final cancellation = _CoordinatorCancellation(
      operation: ChatLifecycleOperation.connection,
      cancelled: () => !_isCurrentConnection(generation),
    );
    var subscribedByThisRun = false;
    try {
      final authenticated = await _port.refreshAuthentication(cancellation);
      if (!_isCurrentConnection(generation)) return;
      if (!authenticated) {
        _scheduleReconnect();
        return;
      }

      final subscribed = await _port.subscribe(cancellation);
      if (!_isCurrentConnection(generation)) {
        if (subscribed) await _ignoreFailure(_port.unsubscribe);
        return;
      }
      if (!subscribed) {
        _scheduleReconnect();
        return;
      }

      subscribedByThisRun = true;
      _subscribed = true;
      _reconnectAttempt = 0;
      _cancelReconnectTimer();
      _stopPolling(resetWindow: true);

      await _port.gapFill(cancellation);
      if (!_isCurrentConnection(generation)) return;
      await _port.resumeOutbox(cancellation);
    } on Object {
      if (!_isCurrentConnection(generation)) return;
      if (_subscribed || subscribedByThisRun) {
        _subscribed = false;
        await _ignoreFailure(_port.unsubscribe);
      }
      if (!_isCurrentConnection(generation)) return;
      _beginDisconnectedWindow();
      _scheduleReconnect();
    }
  }

  bool _isCurrentConnection(int generation) {
    return !_disposed &&
        !_loggedOut &&
        _foreground &&
        _lifecycleState == AppLifecycleState.resumed &&
        _generation == generation;
  }

  void _scheduleReconnect() {
    if (_disposed ||
        _loggedOut ||
        !_foreground ||
        _lifecycleState != AppLifecycleState.resumed ||
        _subscribed ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    _beginDisconnectedWindow();
    _reconnectAttempt += 1;
    final delay = _reconnectPolicy.delayForAttempt(_reconnectAttempt);
    final generation = _generation;
    _reconnectTimer = _scheduler.schedule(delay, () {
      _reconnectTimer = null;
      if (!_isCurrentConnection(generation) || _subscribed) return;
      unawaited(_beginConnectionRun(generation));
    });
  }

  void _beginDisconnectedWindow() {
    if (!_foreground || _subscribed || _disposed || _loggedOut) return;
    _disconnectedSince ??= _scheduler.now;
    if (_pollingThresholdTimer?.isActive == true ||
        _pollingTimer?.isActive == true ||
        _pollingRun != null) {
      return;
    }
    final elapsed = _scheduler.now.difference(_disconnectedSince!);
    final remaining = pollingThreshold - elapsed;
    final pollingGeneration = _pollingGeneration;
    _pollingThresholdTimer = _scheduler.schedule(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        _pollingThresholdTimer = null;
        if (!_isCurrentPolling(pollingGeneration)) return;
        _startPollingRun(pollingGeneration);
      },
    );
  }

  void _startPollingRun(int pollingGeneration) {
    if (_pollingRun != null || !_isCurrentPolling(pollingGeneration)) return;
    final cancellation = _CoordinatorCancellation(
      operation: ChatLifecycleOperation.polling,
      cancelled: () => !_isCurrentPolling(pollingGeneration),
    );
    late final Future<void> run;
    run = _port.gapFill(cancellation).catchError((Object _) {}).whenComplete(
      () {
        if (!identical(_pollingRun, run)) return;
        _pollingRun = null;
        if (!_isCurrentPolling(pollingGeneration)) return;
        _pollingTimer = _scheduler.schedule(pollingInterval, () {
          _pollingTimer = null;
          _startPollingRun(pollingGeneration);
        });
      },
    );
    _pollingRun = run;
  }

  bool _isCurrentPolling(int pollingGeneration) {
    return !_disposed &&
        !_loggedOut &&
        _foreground &&
        _lifecycleState == AppLifecycleState.resumed &&
        !_subscribed &&
        _pollingGeneration == pollingGeneration;
  }

  void _cancelBackgroundGrace({required bool clearStart}) {
    _backgroundGraceTimer?.cancel();
    _backgroundGraceTimer = null;
    if (clearStart) _backgroundGraceStartedAt = null;
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _stopPolling({required bool resetWindow}) {
    _pollingGeneration += 1;
    _pollingThresholdTimer?.cancel();
    _pollingThresholdTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (resetWindow) _disconnectedSince = null;
  }

  void _cancelAllTimers() {
    _cancelBackgroundGrace(clearStart: true);
    _cancelReconnectTimer();
  }

  Future<void> _runBestEffort(Iterable<Future<void> Function()> actions) async {
    for (final action in actions) {
      await _ignoreFailure(action);
    }
  }

  Future<void> _ignoreFailure(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Lifecycle cleanup is best effort; later cleanup steps must still run.
    }
  }
}

final class _CoordinatorCancellation implements ChatLifecycleCancellation {
  const _CoordinatorCancellation({
    required this.operation,
    required bool Function() cancelled,
  }) : _cancelled = cancelled;

  @override
  final ChatLifecycleOperation operation;
  final bool Function() _cancelled;

  @override
  bool get isCancelled => _cancelled();
}
