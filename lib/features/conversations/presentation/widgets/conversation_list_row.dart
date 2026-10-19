import 'package:flutter/material.dart';

import '../../domain/conversation_summary.dart';

class ConversationListRow extends StatelessWidget {
  const ConversationListRow({
    required this.conversation,
    required this.updatedAtLabel,
    required this.onTap,
    super.key,
  });

  final ConversationSummary conversation;
  final String updatedAtLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String semanticLabel = <String>[
      conversation.title,
      if (conversation.displayPreview.isNotEmpty) conversation.displayPreview,
      updatedAtLabel,
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                const SizedBox(width: 12),
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
  }
}
