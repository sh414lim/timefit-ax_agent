import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';
import 'message_bubble.dart';

class MessageList extends StatefulWidget {
  const MessageList({required this.messages, this.scrollController, super.key});

  final List<ChatMessage> messages;
  final ScrollController? scrollController;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  static const double _latestThreshold = 80;
  late final ScrollController _controller =
      widget.scrollController ?? ScrollController();
  bool _showNewMessages = false;

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
    final int? oldMin = oldWidget.messages.isEmpty
        ? null
        : oldWidget.messages.first.sequence;
    final int? oldMax = oldWidget.messages.isEmpty
        ? null
        : oldWidget.messages.last.sequence;
    final bool prepended =
        oldMin != null && widget.messages.first.sequence < oldMin;
    final bool appended =
        oldMax == null || widget.messages.last.sequence > oldMax;
    final bool wasLatest =
        !_controller.hasClients ||
        _controller.position.extentAfter <= _latestThreshold;
    final double oldExtent = _controller.hasClients
        ? _controller.position.maxScrollExtent
        : 0;
    final double oldOffset = _controller.hasClients ? _controller.offset : 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (prepended && !wasLatest) {
        final double delta = _controller.position.maxScrollExtent - oldExtent;
        _controller.jumpTo(
          (oldOffset + delta).clamp(0, _controller.position.maxScrollExtent),
        );
      } else if (appended && wasLatest) {
        _jumpToLatest();
      } else if (appended && mounted) {
        setState(() => _showNewMessages = true);
      }
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ListView.builder(
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
              key: ValueKey<String>('message-${message.id}'),
              children: <Widget>[
                if (showDate) _DateDivider(date: message.displayedAt),
                MessageBubble(message: message),
              ],
            );
          },
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
