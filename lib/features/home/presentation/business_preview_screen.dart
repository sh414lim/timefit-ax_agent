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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: <Widget>[
              _ConversationExcerpt(
                action: action,
                isApprovalPreview: isApprovalPreview,
              ),
              const SizedBox(height: AppSpacing.x16),
              _WorkflowResult(
                kind: kind,
                style: style,
                assetBuilder: _workflowAssetBuilder,
                landscape: false,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: DemoQuickComposer(
            controller: draftController,
            focusNode: draftFocusNode,
            placeholder: isApprovalPreview
                ? '승인 요청에 대해 질문하세요'
                : action.composerPlaceholder,
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
    height: 58,
    child: Row(
      children: <Widget>[
        IconButton(
          tooltip: '홈으로 돌아가기',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const TimeFitAssetSlot(
          kind: TimeFitAssetKind.squareLogo,
          width: 42,
          height: 42,
          keyName: 'mobile-preview-logo-slot',
        ),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: TimeFitAxVisualTokens.of(context).deepText,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const _DemoBadge(),
        const SizedBox(width: AppSpacing.x8),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const TimeFitAssetSlot(
                  kind: TimeFitAssetKind.squareLogo,
                  width: 48,
                  height: 48,
                  keyName: 'expanded-preview-logo-slot',
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Text(
                    'TimeFit AX',
                    style: TextStyle(
                      color: tokens.deepText,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    child: Text(isApprovalPreview ? '승인 요청' : action.label),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Align(alignment: Alignment.centerLeft, child: _DemoBadge()),
          ],
        ),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 32, 24, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _previewTitle(action, isApprovalPreview),
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
              _ConversationExcerpt(
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
        ),
      ],
    ),
  );
}

class _ConversationExcerpt extends StatelessWidget {
  const _ConversationExcerpt({
    required this.action,
    required this.isApprovalPreview,
  });
  final DemoHomeAction action;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      _ChatBubble(
        text: isApprovalPreview ? '오늘 검토할 승인 요청을 보여줘.' : action.userPrompt,
        outgoing: true,
      ),
      const SizedBox(height: AppSpacing.x16),
      _ChatBubble(
        text: isApprovalPreview
            ? '합성 승인 요청을 검토용 카드로 정리했어요.'
            : action.assistantReply,
        outgoing: false,
      ),
    ],
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.outgoing});
  final String text;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!outgoing) ...<Widget>[
            const TimeFitAssetSlot(
              kind: TimeFitAssetKind.assistantMark,
              width: 36,
              height: 36,
              keyName: 'assistant-mark-slot',
            ),
            const SizedBox(width: AppSpacing.x8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 470),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: outgoing ? tokens.paleBlue : tokens.subtleSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(text),
            ),
          ),
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
  });
  final WorkflowResultKind kind;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder assetBuilder;
  final bool landscape;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '${kind.name} 합성 결과, 실제 업무 실행 안 됨',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Align(
          alignment: Alignment.centerRight,
          child: _DemoBadge(label: '샘플 데이터 · 실행 안 됨'),
        ),
        const SizedBox(height: AppSpacing.x12),
        IgnorePointer(
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
                ),
        ),
        const SizedBox(height: AppSpacing.x12),
        const Text(
          '검토용 합성 데이터입니다. 실제 업무 상태는 변경되지 않습니다.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget _workflowAssetBuilder(BuildContext context, String role, double size) {
  final tokens = TimeFitAxVisualTokens.of(context);
  if (role.contains('.automation') || role.contains('.insight')) {
    return TimeFitAssetSlot(
      kind: TimeFitAssetKind.assistantMark,
      width: size,
      height: size,
      keyName: 'workflow-$role',
    );
  }
  final bool notice = role.endsWith('.megaphone');
  return Semantics(
    image: true,
    label: '$role 재구성 아이콘',
    child: Container(
      key: Key('workflow-$role'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.paleBlue,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      alignment: Alignment.center,
      child: notice
          ? ReconstructedHomeActionGlyph(
              action: DemoHomeAction.employeeAnnouncement,
              color: tokens.primary,
              size: size * .5,
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
    isApprovalPreview ? '승인 요청 검토' : action.previewTitle;

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
