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
    this.onPreviewAction,
    super.key,
  });

  final ConversationListController conversationController;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onOpenConversationList;
  final VoidCallback onOpenArchive;
  final VoidCallback onNewConversation;
  final ValueChanged<DemoHomeAction>? onPreviewAction;

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  late ConversationListState _recent = widget.conversationController.state;
  final TextEditingController _draft = TextEditingController();
  final FocusNode _draftFocus = FocusNode();
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
    _draft.dispose();
    _draftFocus.dispose();
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
            if (expanded) const _HomeNavigation(),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.all(
                        expanded ? AppSpacing.x32 : AppSpacing.x16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1040),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const _HomeHero(),
                              const SizedBox(height: AppSpacing.x24),
                              _ActionGrid(
                                expanded: expanded,
                                onSelected: _select,
                              ),
                              if (_preview case final action?) ...<Widget>[
                                const SizedBox(height: AppSpacing.x16),
                                _PreviewNotice(action: action),
                              ],
                              const SizedBox(height: AppSpacing.x24),
                              _RecentConversations(
                                state: _recent,
                                onOpen: widget.onOpenConversation,
                                onShowAll: widget.onOpenConversationList,
                                onShowArchive: widget.onOpenArchive,
                                onNewConversation: widget.onNewConversation,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _QuickComposer(controller: _draft, focusNode: _draftFocus),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onNewConversation,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('새 대화 시작'),
      ),
    );
  }
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 248,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        children: const <Widget>[
          ListTile(leading: Icon(Icons.home_outlined), title: Text('홈')),
          ListTile(leading: Icon(Icons.chat_outlined), title: Text('최근 대화')),
          ListTile(leading: Icon(Icons.archive_outlined), title: Text('보관')),
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
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.hero),
          ),
          child: const Icon(Icons.smart_toy_outlined, size: 48),
        ),
        const SizedBox(height: AppSpacing.x16),
        const Text(
          '오늘 어떤 업무를 도와드릴까요?',
          textAlign: TextAlign.center,
          style: AppTypography.hero,
        ),
        const SizedBox(height: AppSpacing.x8),
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
            : 0.8,
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(action.icon),
              ),
              const Spacer(),
              Text(action.label, style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.x4),
              Text(action.description, maxLines: 2),
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
            Row(
              children: <Widget>[
                IconButton.outlined(
                  tooltip: '샘플 첨부 자리',
                  onPressed: () {},
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.attach_file),
                ),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '업무를 요청해 보세요',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x8),
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
          ],
        ),
      ),
    ),
  );
}
