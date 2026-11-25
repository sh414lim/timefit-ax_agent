import 'package:flutter/material.dart';

import '../../../../app/theme/timefit_conversation_visual.dart';

class ConversationStatePanel extends StatelessWidget {
  const ConversationStatePanel({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
    this.icon = Icons.forum_outlined,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final visual = TimeFitConversationVisual.of(context);
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
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: visual.fill,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(icon, size: 28, color: visual.accent),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: compact
                          ? visual.text(20, weight: FontWeight.w700)
                          : Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: compact
                          ? visual.text(15, color: visual.secondary)
                          : null,
                    ),
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
