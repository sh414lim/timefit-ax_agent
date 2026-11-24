import 'package:flutter/material.dart';

class ConversationStatePanel extends StatelessWidget {
  const ConversationStatePanel({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (compact) ...[
                      Icon(
                        Icons.forum_outlined,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: compact
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                    SizedBox(height: compact ? 16 : 24),
                    FilledButton(onPressed: onAction, child: Text(actionLabel)),
                    if (secondaryActionLabel
                        case final String label) ...<Widget>[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onSecondaryAction,
                        child: Text(label),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
