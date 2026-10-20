import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';
import 'delivery_badge.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, this.onRetry, super.key});

  final ChatMessage message;
  final Future<bool> Function(String clientMessageId)? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool canRetry =
        message.isMine &&
        message.deliveryState == MessageDeliveryState.failed &&
        onRetry != null;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = message.isMine
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    return Semantics(
      container: true,
      excludeSemantics: !canRetry,
      explicitChildNodes: canRetry,
      label:
          '${message.isMine ? '내 메시지' : '받은 메시지'}, '
          '${message.body}, ${DeliveryBadge(state: message.deliveryState).label}',
      child: Align(
        alignment: message.isMine
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320, minHeight: 44),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(message.body),
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: DeliveryBadge(state: message.deliveryState),
              ),
              if (canRetry)
                TextButton(
                  onPressed: () {
                    unawaited(
                      onRetry!(
                        message.clientMessageId,
                      ).catchError((Object _) => false),
                    );
                  },
                  child: const Text('재시도'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
