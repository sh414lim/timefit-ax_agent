import 'package:flutter/material.dart';

import '../../domain/conversation_summary.dart';

class ConversationListRow extends StatelessWidget {
  const ConversationListRow({
    required this.conversation,
    required this.updatedAtLabel,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final ConversationSummary conversation;
  final String updatedAtLabel;
  final VoidCallback onTap;
  final Widget? trailing;

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
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: trailing == null
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
              : const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (conversation.displayPreview.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        conversation.displayPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
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
