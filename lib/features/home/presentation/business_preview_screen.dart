import 'package:flutter/material.dart';

import '../../../app/theme/timefit_ax_visual_tokens.dart';
import '../../../app/theme/tokens.dart';
import 'demo_home_action.dart';
import 'widgets/brand_asset_slot.dart';
import 'widgets/demo_quick_composer.dart';
import 'widgets/reconstructed_action_glyph.dart';

class DemoBusinessPreviewScreen extends StatelessWidget {
  const DemoBusinessPreviewScreen({
    required this.action,
    required this.onBack,
    required this.draftController,
    required this.draftFocusNode,
    this.isApprovalPreview = false,
    super.key,
  });

  /// Reusable source-mapped approval presentation. The supplied Home does not
  /// invent an approval shortcut, so this remains component-only until a
  /// product route is approved.
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

  @override
  Widget build(BuildContext context) {
    final bool expanded = MediaQuery.sizeOf(context).width >= 900;
    final tokens = TimeFitAxVisualTokens.of(context);
    return ColoredBox(
      color: tokens.canvas,
      child: expanded
          ? _ExpandedPreview(
              action: action,
              onBack: onBack,
              draftController: draftController,
              draftFocusNode: draftFocusNode,
              isApprovalPreview: isApprovalPreview,
            )
          : _MobilePreview(
              action: action,
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
    required this.onBack,
    required this.draftController,
    required this.draftFocusNode,
    required this.isApprovalPreview,
  });

  final DemoHomeAction action;
  final VoidCallback onBack;
  final TextEditingController draftController;
  final FocusNode draftFocusNode;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return SafeArea(
      child: Column(
        children: <Widget>[
          SizedBox(
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
                    isApprovalPreview ? '승인 요청 검토' : action.previewTitle,
                    style: TextStyle(
                      color: tokens.deepText,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _DemoBadge(),
                const SizedBox(width: AppSpacing.x8),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              children: <Widget>[
                _ChatBubble(
                  text: isApprovalPreview
                      ? '오늘 검토할 승인 요청을 보여줘.'
                      : action.userPrompt,
                  outgoing: true,
                ),
                const SizedBox(height: AppSpacing.x16),
                _ChatBubble(
                  text: isApprovalPreview
                      ? '합성 승인 요청을 검토용 카드로 정리했어요.'
                      : action.assistantReply,
                  outgoing: false,
                ),
                const SizedBox(height: AppSpacing.x16),
                _PreviewResultCard(
                  action: action,
                  expanded: false,
                  isApprovalPreview: isApprovalPreview,
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
}

class _ExpandedPreview extends StatelessWidget {
  const _ExpandedPreview({
    required this.action,
    required this.onBack,
    required this.draftController,
    required this.draftFocusNode,
    required this.isApprovalPreview,
  });

  final DemoHomeAction action;
  final VoidCallback onBack;
  final TextEditingController draftController;
  final FocusNode draftFocusNode;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    final double width = MediaQuery.sizeOf(context).width;
    final double sidebarWidth =
        width * (isApprovalPreview ? .184 : action.expandedSidebarRatio);
    final double chatWidth =
        width * (isApprovalPreview ? .419 : action.expandedChatRatio);
    return SafeArea(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: sidebarWidth,
            child: ColoredBox(
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
                    _SidebarLabel(
                      action: action,
                      isApprovalPreview: isApprovalPreview,
                    ),
                    const Spacer(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _DemoBadge(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: chatWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    isApprovalPreview ? '승인 요청 검토' : action.previewTitle,
                    style: TextStyle(
                      color: tokens.deepText,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x24),
                  Expanded(
                    child: ListView(
                      children: <Widget>[
                        _ChatBubble(
                          text: isApprovalPreview
                              ? '오늘 검토할 승인 요청을 보여줘.'
                              : action.userPrompt,
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
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: tokens.subtleSurface,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.x24),
                child: _PreviewResultCard(
                  action: action,
                  expanded: true,
                  isApprovalPreview: isApprovalPreview,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel({required this.action, required this.isApprovalPreview});
  final DemoHomeAction action;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: TimeFitAxVisualTokens.of(context).paleBlue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: <Widget>[
        if (isApprovalPreview)
          const Icon(Icons.approval_outlined, size: 22)
        else
          ReconstructedHomeActionGlyph(
            action: action,
            color: TimeFitAxVisualTokens.of(context).expandedHomePrimary,
            size: 22,
          ),
        const SizedBox(width: AppSpacing.x12),
        Expanded(child: Text(isApprovalPreview ? '승인 요청' : action.label)),
      ],
    ),
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

class _PreviewResultCard extends StatelessWidget {
  const _PreviewResultCard({
    required this.action,
    required this.expanded,
    required this.isApprovalPreview,
  });
  final DemoHomeAction action;
  final bool expanded;
  final bool isApprovalPreview;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Semantics(
      container: true,
      label:
          '${isApprovalPreview ? '승인 요청' : action.label} 샘플 결과, 실제 업무 실행 안 됨',
      child: Container(
        padding: EdgeInsets.all(expanded ? 24 : 18),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10071A39),
              blurRadius: 22,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    isApprovalPreview ? '승인 대기 요청' : action.resultTitle,
                    style: TextStyle(
                      color: tokens.deepText,
                      fontSize: expanded ? 24 : 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const _DemoBadge(label: '샘플 데이터 · 실행 안 됨'),
              ],
            ),
            const SizedBox(height: AppSpacing.x16),
            if (isApprovalPreview)
              _ApprovalResult(expanded: expanded)
            else
              switch (action) {
                DemoHomeAction.storeOverview || DemoHomeAction.costAnalysis =>
                  _AnalyticsResult(expanded: expanded),
                DemoHomeAction.weeklySchedule => _ScheduleResult(
                  expanded: expanded,
                ),
                DemoHomeAction.employeeAnnouncement => _AnnouncementResult(
                  expanded: expanded,
                ),
              },
          ],
        ),
      ),
    );
  }
}

class _ApprovalResult extends StatelessWidget {
  const _ApprovalResult({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    const requests = <(String, String, String)>[
      ('근무 변경 요청', '합성 직원 A · 금요일 오후', '검토 대기'),
      ('휴가 요청', '합성 직원 B · 10월 23일', '검토 대기'),
      ('추가 근무 요청', '합성 직원 C · 토요일 오전', '확인 필요'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final request in requests)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.x12),
            padding: EdgeInsets.all(expanded ? 16 : 13),
            decoration: BoxDecoration(
              color: tokens.subtleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.paleBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fact_check_outlined, color: tokens.primary),
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        request.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      Text(
                        request.$2,
                        style: TextStyle(color: tokens.secondaryText),
                      ),
                      const SizedBox(height: AppSpacing.x8),
                      Text(
                        request.$3,
                        style: TextStyle(
                          color: tokens.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Tooltip(
                  message: '데모에서는 승인할 수 없음',
                  child: Icon(Icons.lock_outline, size: 20),
                ),
              ],
            ),
          ),
        const Text('검토용 합성 데이터입니다. 승인 상태는 변경되지 않습니다.'),
      ],
    );
  }
}

class _AnalyticsResult extends StatelessWidget {
  const _AnalyticsResult({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final item in const <(String, String)>[
              ('매출', '4,820,000원'),
              ('인건비율', '21.4%'),
              ('근무 인원', '8명'),
            ])
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.subtleSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.$1,
                        style: TextStyle(color: tokens.secondaryText),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.$2,
                          style: TextStyle(
                            color: tokens.primary,
                            fontSize: expanded ? 22 : 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x16),
        Container(
          height: expanded ? 250 : 170,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(painter: _SampleChartPainter(tokens: tokens)),
        ),
        const SizedBox(height: AppSpacing.x16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.paleBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('AI 인사이트\n저녁 시간대에 합성 매출 지표가 가장 높았습니다.'),
        ),
      ],
    );
  }
}

class _SampleChartPainter extends CustomPainter {
  const _SampleChartPainter({required this.tokens});
  final TimeFitAxVisualTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = tokens.border
      ..strokeWidth = 1;
    for (var index = 1; index < 5; index += 1) {
      final y = size.height * index / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final points = <Offset>[
      Offset(0, size.height * .82),
      Offset(size.width * .18, size.height * .62),
      Offset(size.width * .34, size.height * .35),
      Offset(size.width * .52, size.height * .68),
      Offset(size.width * .7, size.height * .48),
      Offset(size.width * .84, size.height * .23),
      Offset(size.width, size.height * .7),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tokens.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = tokens.primary);
    }
  }

  @override
  bool shouldRepaint(covariant _SampleChartPainter oldDelegate) =>
      oldDelegate.tokens != tokens;
}

class _ScheduleResult extends StatelessWidget {
  const _ScheduleResult({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    const shifts = <List<String>>[
      <String>['오전', '오전', '오후', '오후', '오전', '오전', '오후'],
      <String>['오전', '오후', '오후', '오전', '오전', '오후', '오후'],
      <String>['오후', '오전', '오전', '오후', '오후', '오전', '오전'],
      <String>['오전', '휴무', '오후', '오전', '오후', '오전', '오후'],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.check_circle, color: tokens.success),
            const SizedBox(width: AppSpacing.x8),
            const Text('샘플 검증: 충돌 없음'),
          ],
        ),
        const SizedBox(height: AppSpacing.x12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: FixedColumnWidth(expanded ? 66 : 56),
            border: TableBorder.all(color: tokens.border),
            children: <TableRow>[
              TableRow(
                children: <Widget>[
                  for (final day in const <String>[
                    '직원',
                    '월',
                    '화',
                    '수',
                    '목',
                    '금',
                    '토',
                    '일',
                  ])
                    _ScheduleCell(day, header: true),
                ],
              ),
              for (var row = 0; row < shifts.length; row += 1)
                TableRow(
                  children: <Widget>[
                    _ScheduleCell('직원 ${row + 1}', header: true),
                    for (final shift in shifts[row]) _ScheduleCell(shift),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell(this.value, {this.header = false});
  final String value;
  final bool header;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    constraints: const BoxConstraints(minHeight: 44),
    color: header ? TimeFitAxVisualTokens.of(context).subtleSurface : null,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: header ? FontWeight.w700 : FontWeight.w500),
    ),
  );
}

class _AnnouncementResult extends StatelessWidget {
  const _AnnouncementResult({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        '재고조사 안내',
        style: TextStyle(
          fontSize: expanded ? 24 : 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: AppSpacing.x12),
      const Text('이번 주 금요일 영업 종료 후 샘플 재고조사를 진행합니다.'),
      const Divider(height: 30),
      const _MetadataRow(icon: Icons.group_outlined, label: '전체 직원 · 합성 12명'),
      const _MetadataRow(
        icon: Icons.calendar_today_outlined,
        label: '샘플 일정 · 오후 6:00',
      ),
      const _MetadataRow(icon: Icons.notifications_outlined, label: '알림 채널 검토'),
      const SizedBox(height: AppSpacing.x16),
      OutlinedButton(onPressed: () {}, child: const Text('내용 검토')),
    ],
  );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 21),
        const SizedBox(width: AppSpacing.x12),
        Expanded(child: Text(label)),
      ],
    ),
  );
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
