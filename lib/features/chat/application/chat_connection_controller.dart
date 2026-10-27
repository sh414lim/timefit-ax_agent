import 'dart:async';

enum ChatConnectionPhase {
  connected,
  joining,
  disconnected,
  polling,
  background,
}

abstract interface class ChatConnectionDelay {
  void cancel();
}

typedef ChatConnectionDelayFactory =
    ChatConnectionDelay Function(Duration duration, void Function() callback);

final class ChatConnectionState {
  const ChatConnectionState({
    required this.phase,
    required this.rpcAvailable,
    required this.showBanner,
    this.isRetrying = false,
  });

  final ChatConnectionPhase phase;
  final bool rpcAvailable;
  final bool showBanner;
  final bool isRetrying;

  ChatConnectionState copyWith({
    ChatConnectionPhase? phase,
    bool? rpcAvailable,
    bool? showBanner,
    bool? isRetrying,
  }) => ChatConnectionState(
    phase: phase ?? this.phase,
    rpcAvailable: rpcAvailable ?? this.rpcAvailable,
    showBanner: showBanner ?? this.showBanner,
    isRetrying: isRetrying ?? this.isRetrying,
  );
}

/// Presentation-only state holder. It owns no socket, RPC, subscription, or
/// gap-fill adapter and never infers a successful reconnect from retry return.
final class ChatConnectionController {
  ChatConnectionController({
    required Future<void> Function() onRetry,
    ChatConnectionDelayFactory delayFactory = _scheduleDelay,
    Duration joiningGracePeriod = const Duration(seconds: 3),
    ChatConnectionPhase initialPhase = ChatConnectionPhase.connected,
    bool rpcAvailable = true,
  }) : _onRetry = onRetry,
       _delayFactory = delayFactory,
       _joiningGracePeriod = joiningGracePeriod,
       _state = ChatConnectionState(
         phase: initialPhase,
         rpcAvailable: rpcAvailable,
         showBanner: _showsImmediately(initialPhase),
       ) {
    if (joiningGracePeriod.isNegative) {
      throw ArgumentError.value(joiningGracePeriod, 'joiningGracePeriod');
    }
    if (initialPhase == ChatConnectionPhase.joining) _startJoiningGrace();
  }

  final Future<void> Function() _onRetry;
  final ChatConnectionDelayFactory _delayFactory;
  final Duration _joiningGracePeriod;
  final _listeners = <void Function(ChatConnectionState)>{};

  ChatConnectionState _state;
  ChatConnectionState get state => _state;
  ChatConnectionDelay? _joiningDelay;
  Future<void>? _retrying;
  int _generation = 0;
  bool _disposed = false;

  void addListener(void Function(ChatConnectionState) listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(void Function(ChatConnectionState) listener) =>
      _listeners.remove(listener);

  void update({
    required ChatConnectionPhase phase,
    required bool rpcAvailable,
  }) {
    if (_disposed) return;
    if (_state.phase == ChatConnectionPhase.joining &&
        phase == ChatConnectionPhase.joining) {
      _emit(_state.copyWith(rpcAvailable: rpcAvailable));
      return;
    }
    _generation += 1;
    _cancelJoiningDelay();
    _emit(
      ChatConnectionState(
        phase: phase,
        rpcAvailable: rpcAvailable,
        showBanner: _showsImmediately(phase),
        isRetrying: _state.isRetrying,
      ),
    );
    if (phase == ChatConnectionPhase.joining) _startJoiningGrace();
  }

  Future<void> retry() {
    if (_disposed) return Future<void>.value();
    if (_retrying case final Future<void> retrying) return retrying;
    final Future<void> retrying = Future<void>.sync(_runRetry);
    _retrying = retrying;
    unawaited(
      retrying.whenComplete(() {
        if (identical(_retrying, retrying)) _retrying = null;
      }),
    );
    return retrying;
  }

  Future<void> _runRetry() async {
    _emit(_state.copyWith(isRetrying: true));
    try {
      await _onRetry();
    } on Object {
      // Presentation retry remains available. Transport diagnostics belong to
      // the future adapter/observability layer and must not break the screen.
    } finally {
      if (!_disposed) {
        // The adapter must explicitly publish connected + gap-fill complete.
        // A returned retry future alone is not connection success evidence.
        _emit(_state.copyWith(isRetrying: false));
      }
    }
  }

  void _startJoiningGrace() {
    final generation = _generation;
    _joiningDelay = _delayFactory(_joiningGracePeriod, () {
      if (_disposed ||
          generation != _generation ||
          _state.phase != ChatConnectionPhase.joining) {
        return;
      }
      _joiningDelay = null;
      _emit(_state.copyWith(showBanner: true));
    });
  }

  void _cancelJoiningDelay() {
    _joiningDelay?.cancel();
    _joiningDelay = null;
  }

  void _emit(ChatConnectionState state) {
    _state = state;
    for (final listener in _listeners.toList()) {
      if (!_disposed) listener(state);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _cancelJoiningDelay();
    _listeners.clear();
  }

  static bool _showsImmediately(ChatConnectionPhase phase) =>
      phase == ChatConnectionPhase.disconnected ||
      phase == ChatConnectionPhase.polling;
}

final class _TimerDelay implements ChatConnectionDelay {
  _TimerDelay(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

ChatConnectionDelay _scheduleDelay(
  Duration duration,
  void Function() callback,
) => _TimerDelay(Timer(duration, callback));
