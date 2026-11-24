import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/timefit_ax_visual_tokens.dart';
import '../../../home/presentation/widgets/brand_asset_slot.dart';
import '../../domain/chat_message.dart';
import 'delivery_badge.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.onRetry,
    this.axBranding = false,
    super.key,
  });

  final ChatMessage message;
  final bool axBranding;
  final Future<bool> Function(String clientMessageId)? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool canRetry =
        message.isMine &&
        message.deliveryState == MessageDeliveryState.failed &&
        onRetry != null;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final tokens = TimeFitAxVisualTokens.of(context);
    final brandedMine = axBranding && message.isMine;
    final Color background = message.isMine
        ? (brandedMine ? tokens.paleBlue : colors.primaryContainer)
        : axBranding
        ? tokens.surface
        : colors.surfaceContainerHighest;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 44),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: brandedMine ? tokens.deepText : null,
            displayColor: brandedMine ? tokens.deepText : null,
          ),
          colorScheme: brandedMine
              ? colors.copyWith(
                  primary: tokens.primary,
                  onSurfaceVariant: tokens.secondaryText,
                )
              : colors,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message.body,
              style: brandedMine ? TextStyle(color: tokens.deepText) : null,
            ),
            if (!axBranding) ...[
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: DeliveryBadge(state: message.deliveryState),
              ),
            ],
            if (canRetry)
              TextButton(
                onPressed: () => unawaited(
                  onRetry!(
                    message.clientMessageId,
                  ).catchError((Object _) => false),
                ),
                child: const Text('다시 시도'),
              ),
          ],
        ),
      ),
    );
    final content =
        axBranding && message.deliveryState != MessageDeliveryState.sent
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              bubble,
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 4),
                child: ExcludeSemantics(
                  child: DeliveryBadge(state: message.deliveryState),
                ),
              ),
            ],
          )
        : bubble;
    return Semantics(
      container: true,
      liveRegion: message.deliveryState != MessageDeliveryState.sent,
      excludeSemantics: !canRetry,
      explicitChildNodes: canRetry,
      label:
          '${message.isMine ? '내 메시지' : '받은 메시지'}, '
          '${message.body}, ${DeliveryBadge(state: message.deliveryState).label}',
      child: message.isMine || !axBranding
          ? Align(
              alignment: message.isMine
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: content,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 4, right: 8),
                  child: TimeFitAssetSlot(
                    kind: TimeFitAssetKind.assistantMark,
                    width: 30,
                    height: 30,
                  ),
                ),
                Flexible(child: content),
              ],
            ),
    );
  }
}
