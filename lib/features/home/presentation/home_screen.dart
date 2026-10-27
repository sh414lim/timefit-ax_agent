import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../conversations/application/conversation_list_controller.dart';
import '../../conversations/domain/conversation_summary.dart';
import '../../conversations/presentation/widgets/conversation_list_row.dart';
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
    final bool keyboardConstrained =
        View.of(context).viewInsets.bottom > 0 &&
        MediaQuery.sizeOf(context).height < 720;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? AppPalette.lightCanvas
          : AppPalette.darkCanvas,
      body: SafeArea(
        child: Row(
          children: <Widget>[
            if (expanded)
              _HomeNavigation(
                onShowAll: widget.onOpenConversationList,
                onShowArchive: widget.onOpenArchive,
              ),
            Expanded(
              child: keyboardConstrained
                  ? SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        children: <Widget>[
                          _HomeContent(
                            expanded: expanded,
                            preview: _preview,
                            recent: _recent,
                            onSelected: _select,
                            onOpenConversation: widget.onOpenConversation,
                            onOpenConversationList:
                                widget.onOpenConversationList,
                            onOpenArchive: widget.onOpenArchive,
                            onNewConversation: widget.onNewConversation,
                          ),
                          _QuickComposer(
                            controller: _draft,
                            focusNode: _draftFocus,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: <Widget>[
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: _HomeContent(
                              expanded: expanded,
                              preview: _preview,
                              recent: _recent,
                              onSelected: _select,
                              onOpenConversation: widget.onOpenConversation,
                              onOpenConversationList:
                                  widget.onOpenConversationList,
                              onOpenArchive: widget.onOpenArchive,
                              onNewConversation: widget.onNewConversation,
                            ),
                          ),
                        ),
                        _QuickComposer(
                          controller: _draft,
                          focusNode: _draftFocus,
                        ),
                      ],
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
    required this.recent,
    required this.onSelected,
    required this.onOpenConversation,
    required this.onOpenConversationList,
    required this.onOpenArchive,
    required this.onNewConversation,
  });

  final bool expanded;
  final DemoHomeAction? preview;
  final ConversationListState recent;
  final ValueChanged<DemoHomeAction> onSelected;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onOpenConversationList;
  final VoidCallback onOpenArchive;
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
            if (!expanded) const _MobileHomeHeader(),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onNewConversation,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('새 대화 시작'),
              ),
            ),
            const SizedBox(height: AppSpacing.x16),
            const _HomeHero(),
            const SizedBox(height: AppSpacing.x24),
            _ActionGrid(expanded: expanded, onSelected: onSelected),
            if (preview case final action?) ...<Widget>[
              const SizedBox(height: AppSpacing.x16),
              _PreviewNotice(action: action),
            ],
            const SizedBox(height: AppSpacing.x24),
            _RecentConversations(
              state: recent,
              onOpen: onOpenConversation,
              onShowAll: onOpenConversationList,
              onShowArchive: onOpenArchive,
              onNewConversation: onNewConversation,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileHomeHeader extends StatelessWidget {
  const _MobileHomeHeader();

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
        onPressed: () {},
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({required this.onShowAll, required this.onShowArchive});

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
          ListTile(
            leading: const Icon(Icons.add_comment_outlined),
            title: const Text('로컬 새 대화'),
            onTap: onShowAll,
          ),
          const ListTile(leading: Icon(Icons.home_outlined), title: Text('홈')),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('최근 대화'),
            onTap: onShowAll,
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
  const _HomeHero();

  @override
  Widget build(BuildContext context) => Semantics(
    label: '임시 브랜드 이미지',
    child: Column(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.hero),
          ),
          child: const Icon(Icons.smart_toy_outlined, size: 38),
        ),
        const SizedBox(height: AppSpacing.x16),
        const Text(
          '무엇을 도와드릴까요?',
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
          '임시 vector 이미지 · 정식 로고와 로봇 자산은 아직 적용되지 않았습니다.',
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
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.x12,
        mainAxisSpacing: AppSpacing.x12,
        childAspectRatio: columns == 1
            ? 0.95
            : columns == 4
            ? 1.25
            : 1.35,
        children: <Widget>[
          for (final action in DemoHomeAction.values)
            _ActionCard(action: action, onTap: () => onSelected(action)),
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
      color: Theme.of(context).colorScheme.surface,
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
          padding: const EdgeInsets.all(AppSpacing.x8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(action.icon),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle,
              ),
              Text(
                action.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

class _RecentConversations extends StatelessWidget {
  const _RecentConversations({
    required this.state,
    required this.onOpen,
    required this.onShowAll,
    required this.onShowArchive,
    required this.onNewConversation,
  });
  final ConversationListState state;
  final ValueChanged<String> onOpen;
  final VoidCallback onShowAll;
  final VoidCallback onShowArchive;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final List<ConversationSummary> recent = state.conversations
        .take(3)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('최근 대화', style: Theme.of(context).textTheme.titleLarge),
        Wrap(
          alignment: WrapAlignment.end,
          children: <Widget>[
            TextButton(onPressed: onShowArchive, child: const Text('보관된 대화')),
            TextButton(onPressed: onShowAll, child: const Text('모든 대화')),
          ],
        ),
        if (state.phase == ConversationListPhase.loading)
          const LinearProgressIndicator()
        else if (state.phase == ConversationListPhase.error)
          const Text('최근 대화를 표시하지 못했습니다.')
        else if (recent.isEmpty)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[Text('저장된 로컬 대화가 없습니다.')],
          )
        else
          for (final conversation in recent)
            ConversationListRow(
              conversation: conversation,
              updatedAtLabel: '이 기기에 저장됨',
              onTap: () => onOpen(conversation.id),
            ),
      ],
    );
  }
}

class _QuickComposer extends StatelessWidget {
  const _QuickComposer({required this.controller, required this.focusNode});
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppPalette.lightBorder
                      : AppPalette.darkBorder,
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x12000000), blurRadius: 8),
                ],
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
  );
}
