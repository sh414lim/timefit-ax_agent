import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../conversations/application/conversation_list_controller.dart';
import 'demo_home_action.dart';

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({
    required this.conversationController,
    required this.onOpenConversation,
    required this.onOpenConversationList,
    required this.onOpenArchive,
    required this.onNewConversation,
    this.draftController,
    this.draftFocusNode,
    this.onPreviewAction,
    super.key,
  });

  final ConversationListController conversationController;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onOpenConversationList;
  final VoidCallback onOpenArchive;
  final VoidCallback onNewConversation;
  final TextEditingController? draftController;
  final FocusNode? draftFocusNode;
  final ValueChanged<DemoHomeAction>? onPreviewAction;

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  late ConversationListState _recent = widget.conversationController.state;
  late final TextEditingController _draft =
      widget.draftController ?? TextEditingController();
  late final FocusNode _draftFocus = widget.draftFocusNode ?? FocusNode();
  DemoHomeAction? _preview;

  @override
  void initState() {
    super.initState();
    widget.conversationController.addListener(_handleRecent);
  }

  @override
  void didUpdateWidget(DemoHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationController != widget.conversationController) {
      oldWidget.conversationController.removeListener(_handleRecent);
      _recent = widget.conversationController.state;
      widget.conversationController.addListener(_handleRecent);
    }
  }

  void _handleRecent(ConversationListState state) {
    if (mounted) setState(() => _recent = state);
  }

  void _select(DemoHomeAction action) {
    setState(() => _preview = action);
    widget.onPreviewAction?.call(action);
  }

  @override
  void dispose() {
    widget.conversationController.removeListener(_handleRecent);
    if (widget.draftController == null) _draft.dispose();
    if (widget.draftFocusNode == null) _draftFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool expanded = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? AppPalette.lightCanvas
          : AppPalette.darkCanvas,
      body: SafeArea(
        child: Row(
          children: <Widget>[
            if (expanded)
              _HomeNavigation(
                recent: _recent,
                onOpenConversation: widget.onOpenConversation,
                onNewConversation: widget.onNewConversation,
                onShowAll: widget.onOpenConversationList,
                onShowArchive: widget.onOpenArchive,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    Column(
                      children: <Widget>[
                        Expanded(
                          child: SingleChildScrollView(
                            primary: false,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: _HomeContent(
                              expanded: expanded,
                              preview: _preview,
                              onSelected: _select,
                              onOpenConversationList:
                                  widget.onOpenConversationList,
                              onNewConversation: widget.onNewConversation,
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                (constraints.maxHeight - AppTouchTarget.minimum)
                                    .clamp(0, double.infinity),
                          ),
                          child: SingleChildScrollView(
                            primary: false,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: _QuickComposer(
                              controller: _draft,
                              focusNode: _draftFocus,
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.expanded,
    required this.preview,
    required this.onSelected,
    required this.onOpenConversationList,
    required this.onNewConversation,
  });

  final bool expanded;
  final DemoHomeAction? preview;
  final ValueChanged<DemoHomeAction> onSelected;
  final VoidCallback onOpenConversationList;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(expanded ? AppSpacing.x32 : AppSpacing.x16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!expanded)
              _MobileHomeHeader(onOpenConversationList: onOpenConversationList),
            if (!expanded)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onNewConversation,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, AppTouchTarget.minimum),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('새 대화 시작'),
                ),
              ),
            SizedBox(height: expanded ? AppSpacing.x16 : AppSpacing.x8),
            _HomeHero(expanded: expanded),
            SizedBox(height: expanded ? AppSpacing.x24 : AppSpacing.x12),
            _ActionGrid(expanded: expanded, onSelected: onSelected),
            if (preview case final action?) ...<Widget>[
              const SizedBox(height: AppSpacing.x16),
              _PreviewNotice(action: action),
            ],
          ],
        ),
      ),
    ),
  );
}

class _MobileHomeHeader extends StatelessWidget {
  const _MobileHomeHeader({required this.onOpenConversationList});

  final VoidCallback onOpenConversationList;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: AppSpacing.x8),
      const Expanded(child: Text('TimeFit AX', style: AppTypography.cardTitle)),
      IconButton(
        tooltip: '알림 샘플',
        onPressed: () {},
        icon: const Icon(Icons.notifications_none),
      ),
      IconButton(
        tooltip: '메뉴 샘플',
        onPressed: onOpenConversationList,
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({
    required this.recent,
    required this.onOpenConversation,
    required this.onNewConversation,
    required this.onShowAll,
    required this.onShowArchive,
  });

  final ConversationListState recent;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onNewConversation;
  final VoidCallback onShowAll;
  final VoidCallback onShowArchive;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 248,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        children: <Widget>[
          const ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text('TimeFit AX', style: AppTypography.cardTitle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
            child: FilledButton.icon(
              onPressed: onNewConversation,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('새 대화'),
            ),
          ),
          const ListTile(leading: Icon(Icons.home_outlined), title: Text('홈')),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('최근 대화'),
            onTap: onShowAll,
          ),
          for (final conversation in recent.conversations.take(3))
            ListTile(
              dense: true,
              leading: const Icon(Icons.chat_bubble_outline, size: 18),
              title: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onOpenConversation(conversation.id),
            ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('보관'),
            onTap: onShowArchive,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('설정'),
          ),
        ],
      ),
    ),
  );
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '임시 브랜드 이미지',
    child: Column(
      children: <Widget>[
        Container(
          width: expanded ? 72 : 80,
          height: expanded ? 72 : 80,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? AppPalette.lightBrandTint
                : AppPalette.darkBrandTint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            expanded ? Icons.auto_awesome : Icons.smart_toy_outlined,
            size: expanded ? 42 : 46,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(text: '무엇을 '),
              TextSpan(
                text: '도와드릴까요?',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: AppTypography.hero,
        ),
        const SizedBox(height: AppSpacing.x4),
        Text(
          '매장 운영부터 근무, 비용, 커뮤니케이션까지',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.x4),
        Text(
          '임시 이미지',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.expanded, required this.onSelected});
  final bool expanded;
  final ValueChanged<DemoHomeAction> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
      final int columns = largeText
          ? 1
          : expanded && constraints.maxWidth >= 900
          ? 4
          : 2;
      final double cardWidth =
          (constraints.maxWidth - (columns - 1) * AppSpacing.x12) / columns;
      return Wrap(
        spacing: AppSpacing.x12,
        runSpacing: AppSpacing.x12,
        children: <Widget>[
          for (final action in DemoHomeAction.values)
            SizedBox(
              width: cardWidth,
              child: _ActionCard(
                action: action,
                onTap: () => onSelected(action),
              ),
            ),
        ],
      );
    },
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});
  final DemoHomeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${action.label}, ${action.description}, 샘플 미리보기',
    onTap: onTap,
    excludeSemantics: true,
    child: Card(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : AppPalette.darkSurfaceSubtle,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.feature),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.light
              ? AppPalette.lightBorder
              : AppPalette.darkBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppPalette.lightBrandTint
                          : AppPalette.darkBrandTint,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Icon(
                      action.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 22),
                ],
              ),
              const SizedBox(height: AppSpacing.x8),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle,
              ),
              Text(
                action.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({required this.action});
  final DemoHomeAction action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x16),
      child: Text('${action.label} · 합성 미리보기만 선택했습니다. 실제 업무 처리는 없습니다.'),
    ),
  );
}

class _QuickComposer extends StatelessWidget {
  const _QuickComposer({required this.controller, required this.focusNode});
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : AppPalette.darkSurfaceSubtle,
          elevation: 4,
          shadowColor: const Color(0x24000000),
          borderRadius: BorderRadius.circular(AppRadius.feature),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  '샘플 화면 · 입력 내용은 실제 업무 시스템에 전송되지 않습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppPalette.lightSurfaceSubtle
                        : AppPalette.darkCanvas,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppPalette.lightBorder
                          : AppPalette.darkBorder,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: '샘플 첨부 자리',
                        onPressed: () {},
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: const Icon(Icons.attach_file),
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: '업무를 요청해 보세요',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: '샘플 미리보기',
                        onPressed: () {},
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
