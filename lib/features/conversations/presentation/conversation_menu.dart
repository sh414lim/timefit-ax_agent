import 'package:flutter/material.dart';

enum ConversationMenuAction { rename, archive }

class ConversationMenu extends StatelessWidget {
  const ConversationMenu({
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<ConversationMenuAction> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '대화 메뉴',
      excludeSemantics: true,
      child: PopupMenuButton<ConversationMenuAction>(
        enabled: enabled,
        tooltip: '대화 메뉴',
        onSelected: onSelected,
        itemBuilder: (BuildContext context) =>
            const <PopupMenuEntry<ConversationMenuAction>>[
              PopupMenuItem<ConversationMenuAction>(
                value: ConversationMenuAction.rename,
                child: Text('이름 변경'),
              ),
              PopupMenuItem<ConversationMenuAction>(
                value: ConversationMenuAction.archive,
                child: Text('보관'),
              ),
            ],
      ),
    );
  }
}
