import 'package:flutter/material.dart';

import '../../../home/presentation/widgets/brand_asset_slot.dart';
import '../../domain/conversation_summary.dart';

class ConversationListRow extends StatelessWidget {
  const ConversationListRow({
    required this.conversation,
    required this.updatedAtLabel,
    required this.onTap,
    this.trailing,
    this.showAvatar = false,
    this.selected = false,
    super.key,
  });

  final ConversationSummary conversation;
  final String updatedAtLabel;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showAvatar;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final String semanticLabel = <String>[
      conversation.title,
      if (conversation.displayPreview.isNotEmpty) conversation.displayPreview,
      updatedAtLabel,
    ].join(', ');

    final Widget rowButton = Semantics(
      button: true,
      label: semanticLabel,
      selected: selected ? true : null,
      excludeSemantics: true,
      child: Ink(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: trailing == null
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                : const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showAvatar) ...<Widget>[
                  const TimeFitAssetSlot(
                    kind: TimeFitAssetKind.mobileRobot,
                    width: 34,
                    height: 34,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: showAvatar
                            ? Theme.of(context).textTheme.titleSmall
                            : Theme.of(context).textTheme.titleMedium,
                      ),
                      if (conversation.displayPreview.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          conversation.displayPreview,
                          maxLines: showAvatar ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: showAvatar
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : null,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  updatedAtLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: trailing == null
          ? rowButton
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: rowButton),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: trailing!,
                ),
              ],
            ),
    );
  }
}
