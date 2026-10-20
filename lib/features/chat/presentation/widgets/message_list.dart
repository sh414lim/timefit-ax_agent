import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../application/history_controller.dart';
import '../../domain/chat_message.dart';
import 'message_bubble.dart';

class MessageList extends StatefulWidget {
  const MessageList({
    required this.messages,
    this.scrollController,
    this.onRetry,
    this.historyState,
    this.onTopDistance,
    this.onHistoryRetry,
    super.key,
  });

  final List<ChatMessage> messages;
  final ScrollController? scrollController;
  final Future<bool> Function(String clientMessageId)? onRetry;
  final HistoryState? historyState;
  final Future<HistoryPage?> Function(double distance)? onTopDistance;
  final Future<HistoryPage?> Function()? onHistoryRetry;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> with WidgetsBindingObserver {
  static const double _latestThreshold = 80;
  late final ScrollController _controller =
      widget.scrollController ?? ScrollController();
  bool _showNewMessages = false;
  bool _userScrollActive = false;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  _VisibleAnchor? _metricAnchor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToLatest();
      _maybeRequestHistory();
    });
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool messagesChanged =
        !identical(widget.messages, oldWidget.messages) &&
        widget.messages.isNotEmpty;
    final bool historyChanged = widget.historyState != oldWidget.historyState;
    if (!messagesChanged && !historyChanged) {
      return;
    }
    if (!messagesChanged) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeRequestHistory(),
      );
      return;
    }
    final Set<String> oldIdentities = oldWidget.messages
        .map((ChatMessage message) => message.clientMessageId)
        .toSet();
    final int? oldMax = oldWidget.messages
        .map((ChatMessage message) => message.sequence)
        .whereType<int>()
        .fold<int?>(
          null,
          (int? max, int value) => max == null || value > max ? value : max,
        );
    final bool appended = widget.messages.any(
      (ChatMessage message) =>
          !oldIdentities.contains(message.clientMessageId) &&
          (message.sequence == null ||
              oldMax == null ||
              message.sequence! > oldMax),
    );
    final bool wasLatest =
        !_controller.hasClients ||
        _controller.position.extentAfter <= _latestThreshold;
    final _VisibleAnchor? anchor = wasLatest ? null : _captureVisibleAnchor();
    final bool allowAutoScroll =
        wasLatest &&
        !_userScrollActive &&
        (!_controller.hasClients ||
            !_controller.position.isScrollingNotifier.value);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (anchor != null) {
        _restoreAnchor(anchor);
      }
      if (appended && allowAutoScroll) {
        _jumpToLatest();
      } else if (appended) {
        setState(() => _showNewMessages = true);
      }
      final Set<String> current = widget.messages
          .map((ChatMessage message) => message.clientMessageId)
          .toSet();
      _messageKeys.removeWhere(
        (String identity, _) => !current.contains(identity),
      );
      _maybeRequestHistory();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleScroll);
    if (widget.scrollController == null) _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_controller.hasClients) return;
    final bool atLatest = _controller.position.extentAfter <= _latestThreshold;
    if (atLatest && _showNewMessages) {
      setState(() => _showNewMessages = false);
    }
    _maybeRequestHistory();
  }

  void _maybeRequestHistory() {
    if (!mounted || !_controller.hasClients) return;
    final HistoryState? state = widget.historyState;
    if (state == null ||
        state.isLoading ||
        state.failure != null ||
        !state.hasMoreBefore) {
      return;
    }
    widget.onTopDistance?.call(_controller.position.extentBefore);
  }

  @override
  void didChangeMetrics() {
    _metricAnchor ??= _captureVisibleAnchor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final _VisibleAnchor? anchor = _metricAnchor;
      _metricAnchor = null;
      if (anchor != null && _controller.hasClients) _restoreAnchor(anchor);
    });
  }

  void _jumpToLatest() {
    if (!mounted || !_controller.hasClients) return;
    _controller.jumpTo(_controller.position.maxScrollExtent);
    if (_showNewMessages) setState(() => _showNewMessages = false);
  }

  _VisibleAnchor? _captureVisibleAnchor() {
    for (final ChatMessage message in widget.messages) {
      final BuildContext? rowContext =
          _messageKeys[message.clientMessageId]?.currentContext;
      final RenderObject? renderObject = rowContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final double y = renderObject.localToGlobal(Offset.zero).dy;
      if (y + renderObject.size.height >= 0 &&
          y <= MediaQuery.sizeOf(context).height) {
        return _VisibleAnchor(message.clientMessageId, y);
      }
    }
    return null;
  }

  void _restoreAnchor(_VisibleAnchor anchor) {
    final BuildContext? rowContext =
        _messageKeys[anchor.clientMessageId]?.currentContext;
    final RenderObject? renderObject = rowContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final double newY = renderObject.localToGlobal(Offset.zero).dy;
    final double target = (_controller.offset + newY - anchor.globalY).clamp(
      0,
      _controller.position.maxScrollExtent,
    );
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        NotificationListener<UserScrollNotification>(
          onNotification: (UserScrollNotification notification) {
            _userScrollActive = notification.direction != ScrollDirection.idle;
            return false;
          },
          child: ListView.builder(
            key: const ValueKey<String>('message-timeline'),
            controller: _controller,
            padding: EdgeInsets.fromLTRB(
              16,
              widget.historyState == null ? 12 : 56,
              16,
              88,
            ),
            itemCount: widget.messages.length,
            itemBuilder: (BuildContext context, int index) {
              final ChatMessage message = widget.messages[index];
              final bool showDate =
                  index == 0 ||
                  !_sameDay(
                    widget.messages[index - 1].displayedAt,
                    message.displayedAt,
                  );
              return Column(
                key: _messageKeys.putIfAbsent(
                  message.clientMessageId,
                  GlobalKey.new,
                ),
                children: <Widget>[
                  if (showDate) _DateDivider(date: message.displayedAt),
                  MessageBubble(message: message, onRetry: widget.onRetry),
                ],
              );
            },
          ),
        ),
        if (widget.historyState case final HistoryState state)
          Positioned(
            top: 4,
            left: 16,
            right: 16,
            child: _HistoryStatus(state: state, onRetry: widget.onHistoryRetry),
          ),
        if (_showNewMessages)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: FilledButton(
                onPressed: _jumpToLatest,
                child: const Text('새 메시지'),
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryStatus extends StatelessWidget {
  const _HistoryStatus({required this.state, required this.onRetry});

  final HistoryState state;
  final Future<HistoryPage?> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const _HistoryStatusSurface(
        key: ValueKey<String>('history-loading'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('이전 메시지를 불러오는 중'),
          ],
        ),
      );
    }
    if (state.failure != null) {
      return _HistoryStatusSurface(
        key: const ValueKey<String>('history-error'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Flexible(child: Text('이전 메시지를 불러오지 못했습니다')),
            TextButton(
              onPressed: onRetry == null ? null : () => onRetry!.call(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (!state.hasMoreBefore) {
      return const _HistoryStatusSurface(
        key: ValueKey<String>('history-complete'),
        child: Text('가장 오래된 메시지입니다'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _HistoryStatusSurface extends StatelessWidget {
  const _HistoryStatusSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: child,
      ),
    ),
  );
}

class _VisibleAnchor {
  const _VisibleAnchor(this.clientMessageId, this.globalY);

  final String clientMessageId;
  final double globalY;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final String label = '${date.year}년 ${date.month}월 ${date.day}일';
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
