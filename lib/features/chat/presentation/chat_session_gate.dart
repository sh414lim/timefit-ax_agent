import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../application/chat_session_coordinator.dart';

/// Presentation-only state source for [ChatSessionGate].
///
/// The production composition root is intentionally not selected here. A
/// future adapter may notify this boundary from the local session coordinator
/// once the Auth, routing, and lifecycle contracts are approved.
abstract interface class ChatSessionGateCoordinator implements Listenable {
  LocalChatSessionState get state;

  Future<void> retryCleanup();
}

/// Entry points for dialogs, bottom sheets, and routes owned by one active
/// chat session.
///
/// These methods deliberately target the nested navigator installed by
/// [ChatSessionGate]. A late callback whose context is unmounted, or a caller
/// outside the owned scope, is rejected without falling back to the app root.
/// Using Flutter's root navigator directly bypasses this ownership contract
/// and is therefore not covered by the gate.
abstract final class ChatSessionOwnedSurfaces {
  /// Captures whether [context] is outside a gate, inside its current active
  /// generation, or inside a generation that has already been blocked.
  ///
  /// A blocked scope must never be treated like an unscoped application
  /// surface. The distinction is synchronous, so a coordinator notification
  /// fences actions even before Flutter rebuilds the gate.
  static ChatSessionOwnedSurfaceAdmission admit(BuildContext context) {
    if (!context.mounted) {
      return const ChatSessionOwnedSurfaceAdmission._scoped(null);
    }
    final scope = context
        .getInheritedWidgetOfExactType<_ChatSessionOwnedSurfaceScope>();
    if (scope == null) {
      return const ChatSessionOwnedSurfaceAdmission._unscoped();
    }
    return ChatSessionOwnedSurfaceAdmission._scoped(scope.owner.capture());
  }

  static ChatSessionOwnedSurfaceHandle? capture(BuildContext context) {
    return admit(context).handle;
  }

  static Future<T?> showOwnedDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return capture(context)?.openDialog<T>(
          builder: builder,
          barrierDismissible: barrierDismissible,
        ) ??
        Future<T?>.value();
  }

  static Future<T?> showOwnedBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    return capture(context)?.openBottomSheet<T>(
          builder: builder,
          isScrollControlled: isScrollControlled,
        ) ??
        Future<T?>.value();
  }

  static Future<T?> pushOwnedRoute<T>({
    required BuildContext context,
    required Route<T> route,
  }) {
    return capture(context)?.pushRoute<T>(route) ?? Future<T?>.value();
  }
}

/// One operation's generation-fenced admission to chat-owned UI and writes.
///
/// Outside a gate this preserves the existing application Navigator behavior.
/// Inside a gate, a blocked or superseded generation always fails closed and
/// never falls back to the application root.
final class ChatSessionOwnedSurfaceAdmission {
  const ChatSessionOwnedSurfaceAdmission._unscoped()
    : _isScoped = false,
      handle = null;

  const ChatSessionOwnedSurfaceAdmission._scoped(this.handle)
    : _isScoped = true;

  final bool _isScoped;
  final ChatSessionOwnedSurfaceHandle? handle;

  bool get isAllowed => !_isScoped || (handle?.isCurrent ?? false);

  VoidCallback onInvalidated(VoidCallback callback) {
    if (!_isScoped) return () {};
    final current = handle;
    if (current == null) {
      callback();
      return () {};
    }
    return current.onInvalidated(callback);
  }

  Future<T?> openDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    if (!isAllowed || !context.mounted) return Future<T?>.value();
    final current = handle;
    if (current != null) {
      return current.openDialog<T>(
        builder: builder,
        barrierDismissible: barrierDismissible,
      );
    }
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }

  Future<T?> openBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    if (!isAllowed || !context.mounted) return Future<T?>.value();
    final current = handle;
    if (current != null) {
      return current.openBottomSheet<T>(
        builder: builder,
        isScrollControlled: isScrollControlled,
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
    );
  }

  Future<T?> pushRoute<T>({
    required BuildContext context,
    required Route<T> route,
  }) {
    if (!isAllowed || !context.mounted) return Future<T?>.value();
    final current = handle;
    if (current != null) return current.pushRoute<T>(route);
    return Navigator.of(context).push<T>(route);
  }
}

/// A generation-fenced capability for asynchronous chat-owned UI work.
///
/// Capture this while the active chat subtree is mounted. Once the gate leaves
/// the active state, every method becomes a no-op even if an old Future later
/// completes. The handle never falls back to the application root navigator.
final class ChatSessionOwnedSurfaceHandle {
  const ChatSessionOwnedSurfaceHandle._(this._owner, this._generation);

  final _ChatSessionSurfaceOwner _owner;
  final int _generation;

  bool get isCurrent => _owner.isCurrent(_generation);

  VoidCallback onInvalidated(VoidCallback callback) =>
      _owner.onInvalidated(_generation, callback);

  Future<T?> openDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    final context = _owner.contextFor(_generation);
    if (context == null) return Future<T?>.value();
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      useRootNavigator: false,
    );
  }

  Future<T?> openBottomSheet<T>({
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    final context = _owner.contextFor(_generation);
    if (context == null) return Future<T?>.value();
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useRootNavigator: false,
    );
  }

  Future<T?> pushRoute<T>(Route<T> route) {
    final navigator = _owner.navigatorFor(_generation);
    if (navigator == null) return Future<T?>.value();
    return navigator.push<T>(route);
  }
}

final class _ChatSessionSurfaceOwner {
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final Set<VoidCallback> _invalidationListeners = <VoidCallback>{};
  var _generation = 0;
  var _active = false;

  void activate() {
    if (_active) return;
    _generation += 1;
    // A blocked generation may still have dialog routes in its Navigator when
    // logout and re-entry notifications arrive before the next frame. A fresh
    // key prevents those routes and their focus tree from crossing sessions.
    navigatorKey = GlobalKey<NavigatorState>();
    _active = true;
  }

  void block() {
    if (!_active) return;
    _active = false;
    _generation += 1;
    final listeners = _invalidationListeners.toList();
    _invalidationListeners.clear();
    for (final listener in listeners) {
      try {
        listener();
      } on Object {
        // One consumer must not prevent the remaining session work from being
        // synchronously invalidated.
      }
    }
  }

  ChatSessionOwnedSurfaceHandle? capture() =>
      _active ? ChatSessionOwnedSurfaceHandle._(this, _generation) : null;

  BuildContext? contextFor(int generation) {
    if (!_isCurrent(generation)) return null;
    return navigatorKey.currentContext;
  }

  NavigatorState? navigatorFor(int generation) {
    if (!_isCurrent(generation)) return null;
    return navigatorKey.currentState;
  }

  VoidCallback onInvalidated(int generation, VoidCallback callback) {
    if (!_isCurrent(generation)) {
      callback();
      return () {};
    }
    _invalidationListeners.add(callback);
    return () => _invalidationListeners.remove(callback);
  }

  bool isCurrent(int generation) => _isCurrent(generation);

  bool _isCurrent(int generation) =>
      _active && generation == _generation && navigatorKey.currentState != null;
}

/// Hides local chat content whenever its repository session is not active.
///
/// Errors are deliberately reduced to fixed copy. Namespace, filenames,
/// message bodies, exception strings, and cleanup implementation details must
/// never cross this presentation boundary.
final class ChatSessionGate extends StatefulWidget {
  const ChatSessionGate({
    required this.coordinator,
    required this.child,
    super.key,
  });

  final ChatSessionGateCoordinator coordinator;
  final Widget child;

  @override
  State<ChatSessionGate> createState() => _ChatSessionGateState();
}

final class _ChatSessionGateState extends State<ChatSessionGate> {
  final _surfaceOwner = _ChatSessionSurfaceOwner();
  Future<void>? _retryRun;
  LocalChatSessionState? _lastState;
  var _operationGeneration = 0;
  var _isRetrying = false;
  var _retryFailed = false;

  @override
  void initState() {
    super.initState();
    _lastState = widget.coordinator.state;
    if (_lastState == LocalChatSessionState.active) {
      _surfaceOwner.activate();
    }
    widget.coordinator.addListener(_handleCoordinatorChanged);
  }

  @override
  void didUpdateWidget(ChatSessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.coordinator, widget.coordinator)) return;
    oldWidget.coordinator.removeListener(_handleCoordinatorChanged);
    _surfaceOwner.block();
    _operationGeneration += 1;
    _retryRun = null;
    _isRetrying = false;
    _retryFailed = false;
    _lastState = widget.coordinator.state;
    if (_lastState == LocalChatSessionState.active) {
      _surfaceOwner.activate();
    }
    widget.coordinator.addListener(_handleCoordinatorChanged);
  }

  @override
  void dispose() {
    _operationGeneration += 1;
    _surfaceOwner.block();
    widget.coordinator.removeListener(_handleCoordinatorChanged);
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    final next = widget.coordinator.state;
    if (next != _lastState) {
      _lastState = next;
      if (next == LocalChatSessionState.active) {
        _surfaceOwner.activate();
      } else {
        _surfaceOwner.block();
      }
      if (next == LocalChatSessionState.active ||
          next == LocalChatSessionState.idle ||
          next == LocalChatSessionState.disposed) {
        _operationGeneration += 1;
        _retryRun = null;
        _isRetrying = false;
        _retryFailed = false;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _retryCleanup() {
    final running = _retryRun;
    if (running != null) return running;
    if (widget.coordinator.state != LocalChatSessionState.cleanupPending) {
      return Future<void>.value();
    }

    final coordinator = widget.coordinator;
    final generation = ++_operationGeneration;
    final completion = Completer<void>();
    _retryRun = completion.future;
    setState(() {
      _isRetrying = true;
      _retryFailed = false;
    });

    Future<void> source;
    try {
      source = coordinator.retryCleanup();
    } on Object {
      _finishRetry(
        coordinator: coordinator,
        generation: generation,
        failed: true,
      );
      completion.complete();
      return completion.future;
    }

    source.then(
      (_) {
        _finishRetry(
          coordinator: coordinator,
          generation: generation,
          failed: false,
        );
        completion.complete();
      },
      onError: (Object _, StackTrace __) {
        _finishRetry(
          coordinator: coordinator,
          generation: generation,
          failed: true,
        );
        completion.complete();
      },
    );
    return completion.future;
  }

  void _finishRetry({
    required ChatSessionGateCoordinator coordinator,
    required int generation,
    required bool failed,
  }) {
    if (!mounted ||
        !identical(widget.coordinator, coordinator) ||
        generation != _operationGeneration) {
      return;
    }
    _retryRun = null;
    setState(() {
      _isRetrying = false;
      _retryFailed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.coordinator.state) {
      // The nested Navigator owns default dialogs, sheets, routes, and
      // overlays. Do not add a LookupBoundary here: it also hides the View
      // inherited widget that EditableText needs for focus and IME access.
      // Explicit rootNavigator/rootOverlay calls remain outside this contract.
      LocalChatSessionState.active => _ChatSessionOwnedSurfaceScope(
        owner: _surfaceOwner,
        child: Navigator(
          key: _surfaceOwner.navigatorKey,
          pages: <Page<void>>[
            MaterialPage<void>(
              key: const ValueKey<String>('chat-session-owned-root'),
              child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              ),
            ),
          ],
          onDidRemovePage: (Page<Object?> _) {},
        ),
      ),
      LocalChatSessionState.loggingOut => const _GateStateSurface(
        key: ValueKey<String>('chat-session-gate-logging-out'),
        statusLabel: '채팅 데이터를 안전하게 정리하고 있습니다',
        title: '채팅 데이터를 정리하고 있습니다',
        message: '정리가 끝날 때까지 이전 채팅 내용은 표시되지 않습니다.',
        showProgress: true,
      ),
      LocalChatSessionState.cleanupPending => _GateStateSurface(
        key: const ValueKey<String>('chat-session-gate-cleanup-pending'),
        statusLabel: _isRetrying
            ? '채팅 데이터 정리를 다시 시도하고 있습니다'
            : _retryFailed
            ? '채팅 데이터 정리를 완료하지 못했습니다'
            : '이 기기의 채팅 데이터를 정리하지 못했습니다',
        title: '이 기기의 채팅 데이터를 정리하지 못했습니다',
        message: _retryFailed
            ? '정리를 완료하지 못했습니다. 다시 시도해 주세요.'
            : '이전 채팅 내용은 안전을 위해 숨겨져 있습니다.',
        showProgress: _isRetrying,
        action: _isRetrying
            ? null
            : FilledButton(
                key: const ValueKey<String>('chat-session-gate-retry'),
                onPressed: () {
                  unawaited(_retryCleanup());
                },
                child: const Text('다시 시도'),
              ),
      ),
      LocalChatSessionState.idle || LocalChatSessionState.disposed =>
        const SizedBox.expand(key: ValueKey<String>('chat-session-gate-empty')),
    };
  }
}

final class _ChatSessionOwnedSurfaceScope extends InheritedWidget {
  const _ChatSessionOwnedSurfaceScope({
    required this.owner,
    required super.child,
  });

  final _ChatSessionSurfaceOwner owner;

  @override
  bool updateShouldNotify(_ChatSessionOwnedSurfaceScope oldWidget) =>
      !identical(owner, oldWidget.owner);
}

final class _GateStateSurface extends StatelessWidget {
  const _GateStateSurface({
    required this.statusLabel,
    required this.title,
    required this.message,
    required this.showProgress,
    this.action,
    super.key,
  });

  final String statusLabel;
  final String title;
  final String message;
  final bool showProgress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const padding = EdgeInsets.all(AppSpacing.x24);
            final minHeight = math.max(
              0.0,
              constraints.maxHeight - padding.vertical,
            );
            return SingleChildScrollView(
              key: const ValueKey<String>('chat-session-gate-scroll'),
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Semantics(
                        container: true,
                        liveRegion: true,
                        label: statusLabel,
                        excludeSemantics: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (showProgress) ...<Widget>[
                              const ExcludeSemantics(
                                child: SizedBox.square(
                                  dimension: AppTouchTarget.minimum,
                                  child: Padding(
                                    padding: EdgeInsets.all(AppSpacing.x8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.x16),
                            ],
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.x8),
                            Text(message, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                      if (action case final Widget action) ...<Widget>[
                        const SizedBox(height: AppSpacing.x24),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
