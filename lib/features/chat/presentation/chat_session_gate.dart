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
  Future<void>? _retryRun;
  LocalChatSessionState? _lastState;
  var _operationGeneration = 0;
  var _isRetrying = false;
  var _retryFailed = false;

  @override
  void initState() {
    super.initState();
    _lastState = widget.coordinator.state;
    widget.coordinator.addListener(_handleCoordinatorChanged);
  }

  @override
  void didUpdateWidget(ChatSessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.coordinator, widget.coordinator)) return;
    oldWidget.coordinator.removeListener(_handleCoordinatorChanged);
    _operationGeneration += 1;
    _retryRun = null;
    _isRetrying = false;
    _retryFailed = false;
    _lastState = widget.coordinator.state;
    widget.coordinator.addListener(_handleCoordinatorChanged);
  }

  @override
  void dispose() {
    _operationGeneration += 1;
    widget.coordinator.removeListener(_handleCoordinatorChanged);
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    final next = widget.coordinator.state;
    if (next != _lastState) {
      _lastState = next;
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
      LocalChatSessionState.active => widget.child,
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
