import 'package:flutter/material.dart';

import '../../../../app/theme/timefit_conversation_visual.dart';

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
    final visual = TimeFitConversationVisual.of(context);
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
            ? showAvatar
                  ? visual.accentFill
                  : Theme.of(context).colorScheme.secondaryContainer
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: showAvatar
                ? const EdgeInsetsDirectional.fromSTEB(20, 14, 8, 14)
                : trailing == null
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                : const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showAvatar) ...<Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: visual.accentFill,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: TimeFitAssetSlot(
                        kind: TimeFitAssetKind.mobileRobot,
                        width: 28,
                        height: 28,
                      ),
                    ),
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
                            ? visual.rowTitle
                            : Theme.of(context).textTheme.titleMedium,
                      ),
                      if (conversation.displayPreview.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          conversation.displayPreview,
                          maxLines: showAvatar ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: showAvatar
                              ? visual.summary
                              : Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: Text(
                    updatedAtLabel,
                    textAlign: TextAlign.end,
                    style: showAvatar
                        ? visual.detail
                        : Theme.of(context).textTheme.labelMedium,
                  ),
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
