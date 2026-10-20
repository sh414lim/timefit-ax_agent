import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../domain/chat_message.dart';
import 'message_bubble.dart';

class MessageList extends StatefulWidget {
  const MessageList({
    required this.messages,
    this.scrollController,
    this.onRetry,
    super.key,
  });

  final List<ChatMessage> messages;
  final ScrollController? scrollController;
  final Future<bool> Function(String clientMessageId)? onRetry;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  static const double _latestThreshold = 80;
  late final ScrollController _controller =
      widget.scrollController ?? ScrollController();
  bool _showNewMessages = false;
  bool _userScrollActive = false;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.messages, oldWidget.messages) ||
        widget.messages.isEmpty) {
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
    });
  }

  @override
  void dispose() {
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
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
