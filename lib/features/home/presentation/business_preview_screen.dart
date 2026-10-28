import 'package:flutter/material.dart';

import '../../../app/theme/timefit_ax_visual_tokens.dart';
import '../../../app/theme/tokens.dart';
import '../../workflow_results/presentation/layer.dart';
import 'demo_home_action.dart';
import 'widgets/brand_asset_slot.dart';
import 'widgets/demo_quick_composer.dart';
import 'widgets/reconstructed_action_glyph.dart';

/// Responsive, display-only shell around the source-mapped workflow cards.
///
/// The shell owns navigation and an in-memory draft only. It deliberately has
/// no repository, worker, RPC, or mutation callback.
class DemoBusinessPreviewScreen extends StatelessWidget {
  const DemoBusinessPreviewScreen({
    required this.action,
    required this.onBack,
    required this.draftController,
    required this.draftFocusNode,
    this.isApprovalPreview = false,
    super.key,
  });

  /// The supplied Home has no approval shortcut. This constructor exists only
  /// for the reusable presentation fixture and does not establish a route.
  const DemoBusinessPreviewScreen.approvals({
    required this.onBack,
    required this.draftController,
    required this.draftFocusNode,
    super.key,
  }) : action = DemoHomeAction.storeOverview,
       isApprovalPreview = true;

  final DemoHomeAction action;
  final VoidCallback onBack;
  final TextEditingController draftController;
  final FocusNode draftFocusNode;
  final bool isApprovalPreview;

  WorkflowResultKind get _kind {
    if (isApprovalPreview) return WorkflowResultKind.approval;
    return switch (action) {
      DemoHomeAction.storeOverview ||
      DemoHomeAction.costAnalysis => WorkflowResultKind.analytics,
      DemoHomeAction.weeklySchedule => WorkflowResultKind.schedule,
      DemoHomeAction.employeeAnnouncement => WorkflowResultKind.notice,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool expanded = MediaQuery.sizeOf(context).width >= 900;
    final tokens = TimeFitAxVisualTokens.of(context);
    final WorkflowResultStyle style = WorkflowResultStyle(
      primary: expanded ? tokens.expandedHomePrimary : tokens.mobileHomePrimary,
      canvas: tokens.surface,
      ink: tokens.deepText,
      muted: tokens.secondaryText,
      border: tokens.border,
      paleBlue: tokens.paleBlue,
      success: tokens.success,
    );
    return Material(
      color: tokens.canvas,
      child: expanded
          ? _ExpandedPreview(
              action: action,
              kind: _kind,
              style: style,
              onBack: onBack,
              draftController: draftController,
              draftFocusNode: draftFocusNode,
              isApprovalPreview: isApprovalPreview,
            )
          : _MobilePreview(
              action: action,
              kind: _kind,
              style: style,
              onBack: onBack,
              draftController: draftController,
              draftFocusNode: draftFocusNode,
              isApprovalPreview: isApprovalPreview,
            ),
    );
  }
}

class _MobilePreview extends StatelessWidget {
  const _MobilePreview({
    required this.action,
    required this.kind,
    required this.style,
    required this.onBack,
    required this.draftController,
    required this.draftFocusNode,
    required this.isApprovalPreview,
  });

  final DemoHomeAction action;
  final WorkflowResultKind kind;
  final WorkflowResultStyle style;
  final VoidCallback onBack;
  final TextEditingController draftController;
  final FocusNode draftFocusNode;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: <Widget>[
        _MobileHeader(
          title: _previewTitle(action, isApprovalPreview),
          onBack: onBack,
        ),
        Expanded(
          child: ListView(
            key: const Key('mobile-workflow-scroll'),
            cacheExtent: 1200,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            children: <Widget>[
              _ConversationExcerpt(
                action: action,
                isApprovalPreview: isApprovalPreview,
                compact: true,
              ),
              const SizedBox(height: AppSpacing.x8),
              _WorkflowResult(
                kind: kind,
                style: style,
                assetBuilder: _workflowAssetBuilder,
                landscape: false,
                compact: true,
              ),
              _PostResultConversation(
                action: action,
                isApprovalPreview: isApprovalPreview,
                compact: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: DemoQuickComposer(
            controller: draftController,
            focusNode: draftFocusNode,
            placeholder: isApprovalPreview
                ? '승인 요청에 대해 질문하세요'
                : action.composerPlaceholder,
            variant: _composerVariant(action, isApprovalPreview),
          ),
        ),
      ],
    ),
  );
}

class _ExpandedPreview extends StatelessWidget {
  const _ExpandedPreview({
    required this.action,
    required this.kind,
    required this.style,
    required this.onBack,
    required this.draftController,
    required this.draftFocusNode,
    required this.isApprovalPreview,
  });

  final DemoHomeAction action;
  final WorkflowResultKind kind;
  final WorkflowResultStyle style;
  final VoidCallback onBack;
  final TextEditingController draftController;
  final FocusNode draftFocusNode;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) {
    final Widget sidebar = _ExpandedSidebar(
      action: action,
      onBack: onBack,
      isApprovalPreview: isApprovalPreview,
    );
    final Widget chat = _ExpandedChat(
      action: action,
      draftController: draftController,
      draftFocusNode: draftFocusNode,
      isApprovalPreview: isApprovalPreview,
    );
    final Widget result = ColoredBox(
      color: TimeFitAxVisualTokens.of(context).subtleSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: _WorkflowResult(
          kind: kind,
          style: style,
          assetBuilder: _workflowAssetBuilder,
          landscape: true,
        ),
      ),
    );
    final double sidebarRatio = isApprovalPreview
        ? .1849
        : action.expandedSidebarRatio;
    final double chatRatio = isApprovalPreview
        ? .4141
        : action.expandedChatRatio;
    return SafeArea(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Row(
          children: <Widget>[
            SizedBox(
              width: constraints.maxWidth * sidebarRatio,
              child: sidebar,
            ),
            SizedBox(width: constraints.maxWidth * chatRatio, child: chat),
            Expanded(child: result),
          ],
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Positioned(
          left: 0,
          child: IconButton(
            tooltip: '홈으로 돌아가기',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 54),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const TimeFitAssetSlot(
                kind: TimeFitAssetKind.squareLogo,
                width: 38,
                height: 38,
                keyName: 'mobile-preview-logo-slot',
              ),
              const SizedBox(width: AppSpacing.x8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TimeFitAxVisualTokens.of(context).deepText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.action,
    required this.onBack,
    required this.isApprovalPreview,
  });
  final DemoHomeAction action;
  final VoidCallback onBack;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return ColoredBox(
      color: tokens.sidebar,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            TimeFitAssetSlot(
                              kind:
                                  !isApprovalPreview &&
                                      action == DemoHomeAction.storeOverview
                                  ? TimeFitAssetKind.tabletSymbol
                                  : TimeFitAssetKind.squareLogo,
                              width: 48,
                              height: 48,
                              keyName: 'expanded-preview-logo-slot',
                            ),
                            const SizedBox(width: AppSpacing.x12),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children:
                                      action == DemoHomeAction.weeklySchedule
                                      ? <InlineSpan>[
                                          TextSpan(
                                            text: 'TimeFit ',
                                            style: TextStyle(
                                              color: tokens.deepText,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'AX',
                                            style: TextStyle(
                                              color: tokens.expandedHomePrimary,
                                            ),
                                          ),
                                        ]
                                      : const <InlineSpan>[
                                          TextSpan(text: 'TimeFit AX'),
                                        ],
                                ),
                                style: TextStyle(
                                  color:
                                      !isApprovalPreview &&
                                          action == DemoHomeAction.storeOverview
                                      ? tokens.analysisExpandedPrimary
                                      : tokens.deepText,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x20),
                        OutlinedButton.icon(
                          onPressed: onBack,
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('홈'),
                        ),
                        const SizedBox(height: AppSpacing.x16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.paleBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              ReconstructedHomeActionGlyph(
                                action: action,
                                color: tokens.expandedHomePrimary,
                                size: 22,
                              ),
                              const SizedBox(width: AppSpacing.x12),
                              Expanded(
                                child: Text(
                                  isApprovalPreview ? '승인 요청' : action.label,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x20),
                        Text(
                          '최근 대화',
                          style: TextStyle(
                            color: tokens.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x8),
                        _PreviewSidebarRow(
                          title: isApprovalPreview ? '승인 업무' : action.label,
                          detail: '오늘 10:24',
                          selected: true,
                        ),
                        const _PreviewSidebarRow(
                          title: '직원 휴가 조정',
                          detail: '10월 13일',
                        ),
                        const _PreviewSidebarRow(
                          title: '9월 근무 분석',
                          detail: '10월 10일',
                        ),
                        const Spacer(),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _DemoBadge(),
                        ),
                        const SizedBox(height: AppSpacing.x8),
                        const _PreviewSidebarRow(
                          title: '설정',
                          icon: Icons.settings_outlined,
                        ),
                        const _PreviewSidebarRow(
                          title: '내 계정',
                          icon: Icons.person_outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _PreviewSidebarRow extends StatelessWidget {
  const _PreviewSidebarRow({
    required this.title,
    this.detail,
    this.selected = false,
    this.icon = Icons.chat_bubble_outline,
  });

  final String title;
  final String? detail;
  final bool selected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? tokens.paleBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 17,
            color: selected ? tokens.primary : tokens.secondaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.deepText,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: TextStyle(color: tokens.secondaryText, fontSize: 9),
                  ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.more_horiz, size: 16, color: tokens.secondaryText),
        ],
      ),
    );
  }
}

class _ExpandedChat extends StatelessWidget {
  const _ExpandedChat({
    required this.action,
    required this.draftController,
    required this.draftFocusNode,
    required this.isApprovalPreview,
  });
  final DemoHomeAction action;
  final TextEditingController draftController;
  final FocusNode draftFocusNode;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) {
    final bool sourceStoreAnalysis =
        !isApprovalPreview && action == DemoHomeAction.storeOverview;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sourceStoreAnalysis ? 14 : 28,
        32,
        sourceStoreAnalysis ? 14 : 24,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _expandedPreviewTitle(action, isApprovalPreview),
            style: TextStyle(
              color: TimeFitAxVisualTokens.of(context).deepText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.x24),
          Expanded(
            child: ListView(
              children: <Widget>[
                if (!isApprovalPreview &&
                    action == DemoHomeAction.storeOverview)
                  const _ExpandedStoreAnalysisConversation()
                else
                  _ConversationExcerpt(
                    action: action,
                    isApprovalPreview: isApprovalPreview,
                    solidAnalysisOutgoing: false,
                  ),
                if (isApprovalPreview ||
                    action == DemoHomeAction.employeeAnnouncement)
                  _PostResultConversation(
                    action: action,
                    isApprovalPreview: isApprovalPreview,
                  ),
              ],
            ),
          ),
          DemoQuickComposer(
            controller: draftController,
            focusNode: draftFocusNode,
            placeholder: isApprovalPreview
                ? '승인 요청에 대해 질문하세요'
                : action.composerPlaceholder,
            variant: _expandedComposerVariant(action, isApprovalPreview),
          ),
          if (!isApprovalPreview &&
              action == DemoHomeAction.weeklySchedule) ...<Widget>[
            const SizedBox(height: AppSpacing.x12),
            const _SuggestionChips(
              labels: <String>['직원 교대 요청 반영', '다른 주도 만들어줘', '근무 시간 규칙 변경'],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpandedStoreAnalysisConversation extends StatelessWidget {
  const _ExpandedStoreAnalysisConversation();

  static const List<String> questions = <String>[
    '어제와 비교해서 어떤가요',
    '시간대별 상세 매출을 보여줘',
    '인건비를 더 줄일 수 있는 방법이 있을까',
    '인기 메뉴 순위를 알려줘',
  ];

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _ChatBubble(
        text: '오늘 매장 운영 상황을 한눈에 보여줘.',
        outgoing: true,
        timestamp: '오전 10:24',
      ),
      SizedBox(height: AppSpacing.x16),
      _ChatBubble(
        text: '매출과 인건비를 분석했어요.',
        outgoing: false,
        timestamp: '오전 10:24',
      ),
      SizedBox(height: AppSpacing.x16),
      _ChatBubble(
        text:
            '오늘은 전반적으로 안정적인 운영 흐름을\n'
            '보였고 점심과 저녁 시간대에 매출이\n'
            '크게 상승했어요 주요 지표와 시간대별 추이를\n'
            '오른쪽에서 확인할 수 있어요',
        outgoing: false,
        timestamp: '오전 10:25',
        // The source establishes four compact rows and a bubble field, but
        // not an em size or font family. Preserve the complete copy with a
        // readable normal-tracking candidate instead of deriving tiny glyphs
        // from the raster ink box.
        fontSize: 10.5,
        lineHeight: 1.45,
        horizontalPadding: 15,
        verticalPadding: 16,
      ),
      SizedBox(height: AppSpacing.x20),
      _StackedSuggestionQuestions(labels: questions),
    ],
  );
}

class _ConversationExcerpt extends StatelessWidget {
  const _ConversationExcerpt({
    required this.action,
    required this.isApprovalPreview,
    this.compact = false,
    this.solidAnalysisOutgoing = true,
  });
  final DemoHomeAction action;
  final bool isApprovalPreview;
  final bool compact;
  final bool solidAnalysisOutgoing;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      _ChatBubble(
        text: isApprovalPreview ? '오늘 검토할 승인 요청을 보여줘.' : action.userPrompt,
        outgoing: true,
        solidOutgoing:
            solidAnalysisOutgoing &&
            !isApprovalPreview &&
            action == DemoHomeAction.storeOverview,
        timestamp: '오전 10:24',
        compact: compact,
      ),
      SizedBox(height: compact ? AppSpacing.x8 : AppSpacing.x16),
      _ChatBubble(
        text: isApprovalPreview
            ? '합성 승인 요청을 검토용 카드로 정리했어요.'
            : action.assistantReply,
        outgoing: false,
        timestamp: '오전 10:24',
        compact: compact,
      ),
    ],
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.outgoing,
    this.solidOutgoing = false,
    this.timestamp,
    this.compact = false,
    this.fontSize,
    this.lineHeight,
    this.horizontalPadding,
    this.verticalPadding,
  });
  final String text;
  final bool outgoing;
  final bool solidOutgoing;
  final String? timestamp;
  final bool compact;
  final double? fontSize;
  final double? lineHeight;
  final double? horizontalPadding;
  final double? verticalPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: outgoing
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!outgoing) ...<Widget>[
                TimeFitAssetSlot(
                  kind: TimeFitAssetKind.assistantMark,
                  width: compact ? 32 : 36,
                  height: compact ? 32 : 36,
                  keyName: 'assistant-mark-slot',
                ),
                SizedBox(width: compact ? 6 : AppSpacing.x8),
              ],
              Flexible(
                child: Container(
                  key: outgoing
                      ? const Key('workflow-user-bubble-surface')
                      : null,
                  constraints: const BoxConstraints(maxWidth: 470),
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding ?? (compact ? 16 : 18),
                    vertical: verticalPadding ?? (compact ? 10 : 13),
                  ),
                  decoration: BoxDecoration(
                    color: outgoing
                        ? solidOutgoing
                              ? tokens.mobileHomePrimary
                              : tokens.paleBlue
                        : tokens.subtleSurface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: outgoing && solidOutgoing
                          ? Colors.white
                          : tokens.deepText,
                      fontSize: fontSize,
                      height: lineHeight,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (timestamp != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              timestamp!,
              style: TextStyle(color: tokens.secondaryText, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkflowResult extends StatelessWidget {
  const _WorkflowResult({
    required this.kind,
    required this.style,
    required this.assetBuilder,
    required this.landscape,
    this.compact = false,
  });
  final WorkflowResultKind kind;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder assetBuilder;
  final bool landscape;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget result = IgnorePointer(
      child: landscape && kind != WorkflowResultKind.notice
          ? LandscapeWorkflowResultPane(
              kind: kind,
              style: style,
              assetBuilder: assetBuilder,
            )
          : WorkflowResultCard(
              kind: kind,
              style: style,
              assetBuilder: assetBuilder,
              compact: compact,
            ),
    );
    return Semantics(
      container: true,
      label: '${kind.name} 합성 결과, 실제 업무 실행 안 됨',
      child: compact
          ? Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                result,
                const Positioned(
                  top: -8,
                  right: 10,
                  child: _DemoBadge(label: '데모 · 실행 안 됨'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerRight,
                  child: _DemoBadge(label: '샘플 데이터 · 실행 안 됨'),
                ),
                const SizedBox(height: AppSpacing.x12),
                result,
              ],
            ),
    );
  }
}

class _PostResultConversation extends StatelessWidget {
  const _PostResultConversation({
    required this.action,
    required this.isApprovalPreview,
    this.compact = false,
  });

  final DemoHomeAction action;
  final bool isApprovalPreview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (isApprovalPreview) {
      return Padding(
        key: const Key('approval-final-assistant-bubble'),
        padding: EdgeInsets.only(top: compact ? AppSpacing.x8 : AppSpacing.x16),
        child: _ChatBubble(
          text: '검토할 요청을 선택해 주세요.',
          outgoing: false,
          timestamp: '오전 10:25',
          compact: compact,
        ),
      );
    }
    if (action == DemoHomeAction.employeeAnnouncement) {
      return Padding(
        key: const Key('notice-final-assistant-bubble'),
        padding: EdgeInsets.only(top: compact ? AppSpacing.x8 : AppSpacing.x16),
        child: _ChatBubble(
          text: '발송 전 최종 내용을 확인해 주세요.',
          outgoing: false,
          timestamp: '오전 10:25',
          compact: compact,
        ),
      );
    }
    if (action == DemoHomeAction.storeOverview) {
      return Padding(
        key: const Key('analytics-follow-up-chips'),
        padding: EdgeInsets.only(top: compact ? AppSpacing.x8 : AppSpacing.x12),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('오전 10:25', style: TextStyle(fontSize: 10)),
            SizedBox(height: AppSpacing.x12),
            _SuggestionChips(labels: <String>['어제와 비교', '비용 절감 제안']),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}

class _StackedSuggestionQuestions extends StatelessWidget {
  const _StackedSuggestionQuestions({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Column(
      key: const Key('expanded-analysis-suggestion-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String label in labels) ...<Widget>[
          Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: tokens.deepText, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: tokens.primary,
                ),
              ],
            ),
          ),
          if (label != labels.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

Widget _workflowAssetBuilder(BuildContext context, String role, double size) {
  final tokens = TimeFitAxVisualTokens.of(context);
  if (role.contains('.automation')) {
    final bool landscape = role.endsWith('.landscape');
    return Semantics(
      image: true,
      label: landscape ? '승인 자동화 반짝임 재구성 아이콘' : '승인 자동화 설정 재구성 아이콘',
      child: Container(
        key: Key('workflow-$role'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tokens.paleBlue,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size.square(size * .52),
          painter: landscape
              ? _InsightSparklePainter(color: tokens.primary)
              : _ApprovalGearPainter(color: tokens.primary),
        ),
      ),
    );
  }
  if (role.contains('.insight')) {
    return Semantics(
      image: true,
      label: 'AI 인사이트 반짝임 재구성 아이콘',
      child: SizedBox.square(
        key: const Key('workflow-analytics-insight-icon'),
        dimension: size,
        child: CustomPaint(
          painter: _InsightSparklePainter(color: tokens.primary),
        ),
      ),
    );
  }
  final bool approvalRole = role.startsWith('workflow.approval.');
  if (approvalRole) {
    final (Color field, Color glyph) = switch (role) {
      'workflow.approval.leave' => (tokens.orange, const Color(0xFFE4893B)),
      'workflow.approval.shift' => (tokens.mint, const Color(0xFF3DA17D)),
      'workflow.approval.receipt' => (tokens.lavender, const Color(0xFF755AC4)),
      _ => (tokens.paleBlue, tokens.primary),
    };
    return Semantics(
      image: true,
      label: '$role 재구성 아이콘',
      child: Container(
        key: Key('workflow-$role'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: field,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size.square(size * .52),
          painter: _WorkflowRoleGlyphPainter(role: role, color: glyph),
        ),
      ),
    );
  }
  final bool notice = role.endsWith('.megaphone');
  return Semantics(
    image: true,
    label: notice ? '공지 확성기 재구성 아이콘' : '$role 재구성 아이콘',
    child: Container(
      key: notice
          ? const Key('workflow-notice-megaphone-icon')
          : Key('workflow-$role'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.paleBlue,
        shape: notice ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: notice ? null : BorderRadius.circular(size / 3),
      ),
      alignment: Alignment.center,
      child: notice
          ? CustomPaint(
              size: Size.square(size * .52),
              painter: _NoticeMegaphonePainter(color: tokens.primary),
            )
          : CustomPaint(
              size: Size.square(size * .52),
              painter: _WorkflowRoleGlyphPainter(
                role: role,
                color: tokens.primary,
              ),
            ),
    ),
  );
}

final class _ApprovalGearPainter extends CustomPainter {
  const _ApprovalGearPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .09
      ..strokeCap = StrokeCap.round;
    final Offset center = size.center(Offset.zero);
    canvas.drawCircle(center, size.shortestSide * .24, stroke);
    canvas.drawCircle(center, size.shortestSide * .075, stroke);
    for (var index = 0; index < 8; index++) {
      final double angle = index * 3.1415926535 / 4;
      final Offset inner =
          center + Offset.fromDirection(angle, size.shortestSide * .3);
      final Offset outer =
          center + Offset.fromDirection(angle, size.shortestSide * .43);
      canvas.drawLine(inner, outer, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _ApprovalGearPainter oldDelegate) =>
      oldDelegate.color != color;
}

final class _NoticeMegaphonePainter extends CustomPainter {
  const _NoticeMegaphonePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path horn = Path()
      ..moveTo(size.width * .25, size.height * .35)
      ..lineTo(size.width * .74, size.height * .17)
      ..quadraticBezierTo(
        size.width * .82,
        size.height * .15,
        size.width * .82,
        size.height * .27,
      )
      ..lineTo(size.width * .82, size.height * .69)
      ..quadraticBezierTo(
        size.width * .82,
        size.height * .81,
        size.width * .74,
        size.height * .79,
      )
      ..lineTo(size.width * .25, size.height * .61)
      ..close();
    canvas.drawPath(horn, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .12,
          size.height * .34,
          size.width * .22,
          size.height * .29,
        ),
        Radius.circular(size.width * .07),
      ),
      fill,
    );
    final Path handle = Path()
      ..moveTo(size.width * .34, size.height * .61)
      ..lineTo(size.width * .52, size.height * .67)
      ..lineTo(size.width * .46, size.height * .91)
      ..quadraticBezierTo(
        size.width * .43,
        size.height * .96,
        size.width * .37,
        size.height * .91,
      )
      ..lineTo(size.width * .28, size.height * .64)
      ..close();
    canvas.drawPath(handle, fill);
    canvas.drawLine(
      Offset(size.width * .9, size.height * .27),
      Offset(size.width * .98, size.height * .22),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .91, size.height * .47),
      Offset(size.width, size.height * .47),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _NoticeMegaphonePainter oldDelegate) =>
      oldDelegate.color != color;
}

final class _InsightSparklePainter extends CustomPainter {
  const _InsightSparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Path sparkle = Path()
      ..moveTo(size.width * .46, size.height * .08)
      ..cubicTo(
        size.width * .5,
        size.height * .35,
        size.width * .61,
        size.height * .44,
        size.width * .88,
        size.height * .5,
      )
      ..cubicTo(
        size.width * .61,
        size.height * .56,
        size.width * .5,
        size.height * .65,
        size.width * .46,
        size.height * .92,
      )
      ..cubicTo(
        size.width * .41,
        size.height * .65,
        size.width * .31,
        size.height * .56,
        size.width * .04,
        size.height * .5,
      )
      ..cubicTo(
        size.width * .31,
        size.height * .44,
        size.width * .41,
        size.height * .35,
        size.width * .46,
        size.height * .08,
      )
      ..close();
    canvas.drawPath(sparkle, fill);
    canvas.drawCircle(
      Offset(size.width * .86, size.height * .18),
      size.shortestSide * .07,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _InsightSparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

final class _WorkflowRoleGlyphPainter extends CustomPainter {
  const _WorkflowRoleGlyphPainter({required this.role, required this.color});
  final String role;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (role.endsWith('.leave')) {
      final Rect calendar = Rect.fromLTWH(
        size.width * .12,
        size.height * .2,
        size.width * .76,
        size.height * .68,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(calendar, Radius.circular(size.width * .1)),
        stroke,
      );
      canvas.drawLine(
        Offset(calendar.left, size.height * .4),
        Offset(calendar.right, size.height * .4),
        stroke,
      );
      return;
    }
    if (role.endsWith('.shift')) {
      canvas.drawLine(
        Offset(size.width * .16, size.height * .34),
        Offset(size.width * .82, size.height * .34),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * .82, size.height * .34),
        Offset(size.width * .66, size.height * .19),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * .84, size.height * .67),
        Offset(size.width * .18, size.height * .67),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * .18, size.height * .67),
        Offset(size.width * .34, size.height * .82),
        stroke,
      );
      return;
    }
    final Path receipt = Path()
      ..moveTo(size.width * .22, size.height * .12)
      ..lineTo(size.width * .78, size.height * .12)
      ..lineTo(size.width * .78, size.height * .88)
      ..lineTo(size.width * .66, size.height * .8)
      ..lineTo(size.width * .55, size.height * .88)
      ..lineTo(size.width * .44, size.height * .8)
      ..lineTo(size.width * .33, size.height * .88)
      ..lineTo(size.width * .22, size.height * .8)
      ..close();
    canvas.drawPath(receipt, stroke);
    for (final double y in <double>[.36, .55]) {
      canvas.drawLine(
        Offset(size.width * .36, size.height * y),
        Offset(size.width * .64, size.height * y),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WorkflowRoleGlyphPainter oldDelegate) =>
      oldDelegate.role != role || oldDelegate.color != color;
}

String _previewTitle(DemoHomeAction action, bool isApprovalPreview) =>
    isApprovalPreview ? '승인 업무 도우미' : action.previewTitle;

String _expandedPreviewTitle(DemoHomeAction action, bool isApprovalPreview) =>
    isApprovalPreview
    ? '승인 업무 도우미'
    : action == DemoHomeAction.storeOverview
    ? '매장 분석'
    : action.previewTitle;

DemoComposerVariant _composerVariant(
  DemoHomeAction action,
  bool isApprovalPreview,
) {
  if (isApprovalPreview) return DemoComposerVariant.approval;
  return switch (action) {
    DemoHomeAction.storeOverview => DemoComposerVariant.analysis,
    DemoHomeAction.weeklySchedule => DemoComposerVariant.schedule,
    DemoHomeAction.employeeAnnouncement => DemoComposerVariant.notice,
    // No supplied cost screen establishes a distinct composer treatment.
    DemoHomeAction.costAnalysis => DemoComposerVariant.home,
  };
}

DemoComposerVariant _expandedComposerVariant(
  DemoHomeAction action,
  bool isApprovalPreview,
) {
  if (isApprovalPreview || action == DemoHomeAction.storeOverview) {
    return DemoComposerVariant.home;
  }
  return _composerVariant(action, isApprovalPreview);
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge({this.label = '데모'});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Semantics(
      label: '데모 화면, 실제 업무 시스템에 연결되지 않음',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.paleBlue,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tokens.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
