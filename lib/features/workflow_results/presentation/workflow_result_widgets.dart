import 'package:flutter/material.dart';
import 'workflow_result_fixtures.dart';
import 'workflow_result_style.dart';

class WorkflowResultCard extends StatelessWidget {
  const WorkflowResultCard({
    super.key,
    required this.kind,
    this.style = const WorkflowResultStyle(),
    this.assetBuilder,
    this.compact = false,
  });
  final WorkflowResultKind kind;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  final bool compact;

  @override
  Widget build(BuildContext context) => switch (kind) {
    WorkflowResultKind.notice => NoticeResultCard(
      style: style,
      assetBuilder: assetBuilder,
      compact: compact,
    ),
    WorkflowResultKind.approval => ApprovalResultBoard(
      style: style,
      assetBuilder: assetBuilder,
      compact: compact,
    ),
    WorkflowResultKind.analytics => AnalyticsResultCard(
      style: style,
      assetBuilder: assetBuilder,
      compact: compact,
    ),
    WorkflowResultKind.schedule => ScheduleResultCard(
      style: style,
      assetBuilder: assetBuilder,
      compact: compact,
    ),
  };
}

class NoticeResultCard extends StatelessWidget {
  const NoticeResultCard({
    super.key,
    this.style = const WorkflowResultStyle(),
    this.assetBuilder,
    this.compact = false,
  });
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  final bool compact;

  @override
  Widget build(BuildContext context) => _Frame(
    style: style,
    compact: compact,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          role: 'workflow.notice.megaphone',
          title: '재고조사 안내',
          style: style,
          assetBuilder: assetBuilder,
          compact: compact,
        ),
        SizedBox(height: compact ? 12 : 22),
        Text(
          '이번 주 금요일 영업 종료 후 재고조사를 진행합니다.\n담당 구역을 확인하고 오후 10시까지 매장에 도착해\n주세요.',
          style: TextStyle(
            color: style.ink,
            height: compact ? 1.4 : 1.55,
            fontSize: compact ? 14 : 15.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        Divider(color: style.border, height: 1),
        SizedBox(height: compact ? 10 : 16),
        _Meta(icon: Icons.people_outline, text: '전체 직원 · 12명', style: style),
        SizedBox(height: compact ? 8 : 13),
        _Meta(
          icon: Icons.calendar_today_outlined,
          text: '10월 23일 오후 6:00',
          style: style,
        ),
        SizedBox(height: compact ? 10 : 18),
        Divider(color: style.border, height: 1),
        SizedBox(height: compact ? 8 : 12),
        _Check(text: '카카오 알림', style: style),
        SizedBox(height: compact ? 6 : 10),
        _Check(text: '앱 푸시', style: style),
        SizedBox(height: compact ? 12 : 20),
        Row(
          children: [
            Expanded(
              child: _Action(label: '내용 수정', style: style, primary: false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Action(label: '공지 보내기', style: style, primary: true),
            ),
          ],
        ),
      ],
    ),
  );
}

class ApprovalResultBoard extends StatelessWidget {
  const ApprovalResultBoard({
    super.key,
    this.style = const WorkflowResultStyle(),
    this.assetBuilder,
    this.compact = false,
  });
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in WorkflowResultFixtures.approvals) ...[
        _ApprovalRow(
          item: item,
          style: style,
          assetBuilder: assetBuilder,
          compact: compact,
        ),
        SizedBox(height: compact ? 7 : 10),
      ],
      _Frame(
        style: style,
        tint: style.paleBlue,
        compact: compact,
        child: Row(
          children: [
            _RoleAsset(
              role: 'workflow.approval.automation',
              size: compact ? 40 : 50,
              style: style,
              assetBuilder: assetBuilder,
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '반복 승인 규칙을 만들까요?',
                    style: TextStyle(
                      color: style.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 3 : 5),
                  Text(
                    '자주 발생하는 승인 요청을 자동으로 처리하면\n더 중요한 업무에 집중할 수 있어요.',
                    style: TextStyle(
                      color: style.muted,
                      fontSize: compact ? 11 : 12,
                      height: compact ? 1.3 : 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: '자동화 설정 예시, 실제로 변경하지 않음',
              child: Switch(
                value: true,
                onChanged: null,
                activeTrackColor: style.primary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class AnalyticsResultCard extends StatelessWidget {
  const AnalyticsResultCard({
    super.key,
    this.style = const WorkflowResultStyle(),
    this.assetBuilder,
    this.compact = false,
  });
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  final bool compact;
  @override
  Widget build(BuildContext context) => _Frame(
    style: style,
    compact: compact,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnalyticsHeader(style: style),
        SizedBox(height: compact ? 9 : 14),
        _KpiStrip(style: style, compact: compact),
        SizedBox(height: compact ? 9 : 14),
        Container(
          height: compact ? 142 : 210,
          padding: EdgeInsets.fromLTRB(
            compact ? 9 : 12,
            compact ? 8 : 12,
            8,
            compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: style.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '시간대별 매출',
                      style: TextStyle(
                        color: style.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '단위: 천원',
                    key: const Key('analytics-chart-unit'),
                    style: TextStyle(color: style.muted, fontSize: 9),
                  ),
                ],
              ),
              SizedBox(height: compact ? 4 : 8),
              Expanded(child: _SalesChart(style: style)),
            ],
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Container(
          padding: EdgeInsets.all(compact ? 9 : 14),
          decoration: BoxDecoration(
            color: style.paleBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _RoleAsset(
                role: 'workflow.analytics.insight',
                size: compact ? 32 : 42,
                style: style,
                assetBuilder: assetBuilder,
              ),
              SizedBox(width: compact ? 6 : 10),
              SizedBox(
                height: compact ? 46 : 58,
                child: VerticalDivider(color: style.border, width: 16),
              ),
              SizedBox(width: compact ? 2 : 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 인사이트',
                      style: TextStyle(
                        color: style.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 5),
                    Text(
                      '오후 7시에 매출이 가장 높았어요.',
                      style: TextStyle(
                        color: style.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '저녁 시간대(18시~21시)에 전체 매출의 38%가 발생했어요.',
                      style: TextStyle(
                        color: style.muted,
                        fontSize: compact ? 10 : 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ScheduleResultCard extends StatelessWidget {
  const ScheduleResultCard({
    super.key,
    this.style = const WorkflowResultStyle(),
    this.assetBuilder,
    this.compact = false,
  });
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Frame(
        style: style,
        compact: compact,
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: style.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '10월 19일 - 10월 25일',
                    style: TextStyle(
                      color: style.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 16 : 18,
                    ),
                  ),
                ),
                Icon(Icons.check_circle, color: style.success, size: 19),
                const SizedBox(width: 5),
                Text(
                  '충돌 없음',
                  style: TextStyle(
                    color: style.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 14),
            _ScheduleGrid(style: style, compact: compact),
            SizedBox(height: compact ? 7 : 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 6 : 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                'ⓘ  주말(10/19, 10/25) 모두 4명 이상 배치되어 있어요.',
                style: TextStyle(color: style.muted, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: compact ? 8 : 12),
      Row(
        children: [
          Expanded(
            child: _Action(label: '수정하기', style: style, primary: false),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Action(label: '근무표 확정', style: style, primary: true),
          ),
        ],
      ),
    ],
  );
}

class LandscapeWorkflowColumns extends StatelessWidget {
  const LandscapeWorkflowColumns({
    super.key,
    required this.kind,
    required this.sidebar,
    required this.chat,
    required this.result,
  });
  final WorkflowResultKind kind;
  final Widget sidebar;
  final Widget chat;
  final Widget result;
  static const ratios = {
    WorkflowResultKind.approval: [0.1849, 0.4141, 0.4010],
    WorkflowResultKind.analytics: [0.1979, 0.3164, 0.4857],
    WorkflowResultKind.schedule: [0.2070, 0.3138, 0.4792],
  };
  @override
  Widget build(BuildContext context) {
    assert(
      kind != WorkflowResultKind.notice,
      'The reference set has no landscape notice screen.',
    );
    final ratio = ratios[kind]!;
    return LayoutBuilder(
      builder: (_, box) => Row(
        children: [
          SizedBox(width: box.maxWidth * ratio[0], child: sidebar),
          SizedBox(width: box.maxWidth * ratio[1], child: chat),
          Expanded(child: result),
        ],
      ),
    );
  }
}

class LandscapeWorkflowResultPane extends StatelessWidget {
  const LandscapeWorkflowResultPane({
    super.key,
    required this.kind,
    this.style = const WorkflowResultStyle(),
    this.assetBuilder,
  });

  final WorkflowResultKind kind;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;

  @override
  Widget build(BuildContext context) => switch (kind) {
    WorkflowResultKind.approval => _LandscapeApproval(
      style: style,
      assetBuilder: assetBuilder,
    ),
    WorkflowResultKind.analytics => _LandscapeAnalytics(
      style: style,
      assetBuilder: assetBuilder,
    ),
    WorkflowResultKind.schedule => _LandscapeSchedule(style: style),
    WorkflowResultKind.notice => throw UnsupportedError(
      'No landscape notice reference exists.',
    ),
  };
}

class _LandscapeApproval extends StatelessWidget {
  const _LandscapeApproval({required this.style, this.assetBuilder});
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(23, 32, 23, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '오늘의 승인 요청',
                style: TextStyle(
                  color: style.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 25,
                ),
              ),
            ),
            Text(
              '3건',
              style: TextStyle(
                color: style.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('지금 처리하면 더 원활한 업무가 가능해요.', style: TextStyle(color: style.muted)),
        const SizedBox(height: 20),
        for (final item in WorkflowResultFixtures.approvals) ...[
          _ApprovalRow(item: item, style: style, assetBuilder: assetBuilder),
          const SizedBox(height: 10),
        ],
        _Frame(
          style: style,
          tint: const Color(0xFFE2EEFE),
          child: Row(
            children: [
              _RoleAsset(
                role: 'workflow.approval.automation.landscape',
                size: 50,
                style: style,
                assetBuilder: assetBuilder,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '반복 승인 규칙을 만들까요?',
                      style: TextStyle(
                        color: style.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '반복되는 승인 업무를 자동화하여\n더 중요한 일에 집중할 수 있어요.',
                      style: TextStyle(
                        color: style.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniButton('자동화 설정', style, true),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LandscapeAnalytics extends StatelessWidget {
  const _LandscapeAnalytics({required this.style, this.assetBuilder});
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Frame(
          style: style,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '오늘의 핵심 지표',
                      style: TextStyle(
                        color: style.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Flexible(
                    child: Text(
                      '● 실시간 기준  오전 10:24',
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Color(0xFF52B582), fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _KpiStrip(style: style, landscape: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Frame(
          style: style,
          child: SizedBox(
            height: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: <Widget>[
                    Text(
                      '시간대별 매출',
                      style: TextStyle(
                        color: style.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _AnalyticsSegments(style: style),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(child: _SalesChart(style: style, landscape: true)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Frame(
          style: style,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 4,
                      children: [
                        _RoleAsset(
                          role: 'workflow.analytics.insight.landscape',
                          size: 20,
                          style: style,
                          assetBuilder: assetBuilder,
                        ),
                        Text(
                          'AI 인사이트',
                          style: TextStyle(
                            color: style.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '오후 7시에 매출이 가장 높았어요.',
                      style: TextStyle(
                        color: style.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '저녁 시간대에 전체 매출의 28%가 발생했어요.',
                      style: TextStyle(color: style.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: style.paleBlue,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '저녁 시간대\n추가 매출 기회가 있어요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: style.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

class _AnalyticsSegments extends StatelessWidget {
  const _AnalyticsSegments({required this.style});

  final WorkflowResultStyle style;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF3F6FA),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final (index, label) in <String>['매출', '인건비', '근무 인원'].indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: index == 0 ? style.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: index == 0 ? Colors.white : style.muted,
                fontSize: 10,
              ),
            ),
          ),
      ],
    ),
  );
}

class _LandscapeSchedule extends StatelessWidget {
  const _LandscapeSchedule({required this.style});
  final WorkflowResultStyle style;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            _ScheduleToolbarButton(
              icon: Icons.download_outlined,
              label: '내보내기',
              style: style,
            ),
            const SizedBox(width: 8),
            _ScheduleToolbarButton(
              icon: Icons.calendar_month_outlined,
              label: '공유',
              style: style,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Frame(
          style: style,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '10월 19일 - 10월 25일',
                      style: TextStyle(
                        color: style.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: style.success,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '✓ 충돌 없음',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.more_horiz, color: style.muted),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '요청하신 조건이 모두 반영된 근무표 초안입니다.',
                style: TextStyle(color: style.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _LandscapeScheduleGrid(style: style),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                color: const Color(0xFFF7F9FC),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 92,
                      child: Text(
                        '일별 근무 인원',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    for (final count in const [
                      '4명',
                      '6명',
                      '6명',
                      '6명',
                      '6명',
                      '6명',
                      '4명',
                    ])
                      Expanded(
                        child: Text(
                          count,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _Action(
                      label: '✓  근무표 확정',
                      style: style,
                      primary: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Action(label: '수정하기', style: style, primary: false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ScheduleToolbarButton extends StatelessWidget {
  const _ScheduleToolbarButton({
    required this.icon,
    required this.label,
    required this.style,
  });

  final IconData icon;
  final String label;
  final WorkflowResultStyle style;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: style.canvas,
      border: Border.all(color: style.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: style.muted),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: style.ink, fontSize: 11)),
      ],
    ),
  );
}

class _LandscapeScheduleGrid extends StatelessWidget {
  const _LandscapeScheduleGrid({required this.style});
  final WorkflowResultStyle style;
  @override
  Widget build(BuildContext context) {
    const days = [
      '10/19\n(일)',
      '10/20\n(월)',
      '10/21\n(화)',
      '10/22\n(수)',
      '10/23\n(목)',
      '10/24\n(금)',
      '10/25\n(토)',
    ];
    return Table(
      border: TableBorder.all(color: style.border),
      columnWidths: const {0: FlexColumnWidth(1.8)},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF7F9FC)),
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '직원명',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    days[dayIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dayIndex == 0
                          ? const Color(0xFFD84F56)
                          : dayIndex == 6
                          ? style.primary
                          : style.ink,
                      fontSize: 9,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (final person in WorkflowResultFixtures.landscapeSchedule)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFFDCEBFC),
                      child: Text(
                        person.name.substring(0, 1),
                        style: TextStyle(
                          color: style.primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        person.name,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final shift in person.shifts)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: shift == '휴무'
                          ? const Color(0xFFEBEBED)
                          : (shift == '오후'
                                ? const Color(0xFF8FC1FE)
                                : const Color(0xFFD7EAFE)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      shift,
                      style: TextStyle(
                        color: shift == '휴무'
                            ? style.muted
                            : const Color(0xFF245EA8),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.child,
    required this.style,
    this.tint,
    this.compact = false,
  });
  final Widget child;
  final WorkflowResultStyle style;
  final Color? tint;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 12 : 18),
    decoration: BoxDecoration(
      color: tint ?? style.canvas,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: style.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0A2A55),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.role,
    required this.title,
    required this.style,
    this.assetBuilder,
    this.compact = false,
  });
  final String role, title;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _RoleAsset(
        role: role,
        size: compact ? 42 : 50,
        style: style,
        assetBuilder: assetBuilder,
      ),
      SizedBox(width: compact ? 10 : 13),
      Text(
        title,
        style: TextStyle(
          color: style.ink,
          fontSize: compact ? 21 : 23,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _RoleAsset extends StatelessWidget {
  const _RoleAsset({
    required this.role,
    required this.size,
    required this.style,
    this.assetBuilder,
  });
  final String role;
  final double size;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  @override
  Widget build(BuildContext context) =>
      assetBuilder?.call(context, role, size) ??
      Semantics(
        label: '$role asset pending',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: style.paleBlue,
            borderRadius: BorderRadius.circular(size / 3),
          ),
          child: Center(
            child: Text(
              '?',
              style: TextStyle(
                color: style.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.style});
  final IconData icon;
  final String text;
  final WorkflowResultStyle style;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFF818899), size: 22),
      const SizedBox(width: 13),
      Text(text, style: TextStyle(color: style.ink, fontSize: 14)),
    ],
  );
}

class _Check extends StatelessWidget {
  const _Check({required this.text, required this.style});
  final String text;
  final WorkflowResultStyle style;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.check_circle, color: style.primary, size: 23),
      const SizedBox(width: 12),
      Text(text, style: TextStyle(color: style.ink, fontSize: 14)),
    ],
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.style,
    required this.primary,
  });
  final String label;
  final WorkflowResultStyle style;
  final bool primary;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: false,
    label: '$label 미리보기, 실제 작업은 실행하지 않음',
    child: Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? style.primary : const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(9),
        border: primary ? null : Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label.contains('근무표 확정') || label.contains('수정')) ...<Widget>[
            Icon(
              label.contains('근무표 확정')
                  ? Icons.check_circle
                  : Icons.edit_outlined,
              size: 17,
              color: primary ? Colors.white : style.ink,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.replaceFirst('✓  ', ''),
            style: TextStyle(
              color: primary ? Colors.white : style.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.item,
    required this.style,
    this.assetBuilder,
    this.compact = false,
  });
  final ApprovalFixture item;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final roles = [
      'workflow.approval.leave',
      'workflow.approval.shift',
      'workflow.approval.receipt',
    ];
    return _Frame(
      style: style,
      compact: compact,
      child: Row(
        children: [
          _RoleAsset(
            role: roles[item.tone],
            size: compact ? 42 : 52,
            style: style,
            assetBuilder: assetBuilder,
          ),
          SizedBox(width: compact ? 9 : 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: style.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: compact ? 2 : 5),
                Text(
                  item.detail,
                  style: TextStyle(
                    color: style.muted,
                    fontSize: compact ? 11.5 : 13,
                  ),
                ),
                if (item.deadline != null) ...[
                  SizedBox(height: compact ? 2 : 5),
                  Text(
                    '◷ ${item.deadline}',
                    style: const TextStyle(
                      color: Color(0xFFA97818),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          _MiniButton('상세 보기', style, false),
          const SizedBox(width: 7),
          _MiniButton('승인', style, true),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton(this.label, this.style, this.primary);
  final String label;
  final WorkflowResultStyle style;
  final bool primary;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: false,
    label: '$label 미리보기, 실제 작업은 실행하지 않음',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: primary ? style.primary : Colors.white,
        border: Border.all(color: style.primary),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primary ? Colors.white : style.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi(
    this.label,
    this.value,
    this.style, {
    this.compact = false,
    this.showComparison = false,
  });
  final String label, value;
  final WorkflowResultStyle style;
  final bool compact;
  final bool showComparison;
  @override
  Widget build(BuildContext context) => Container(
    key: Key('analytics-kpi-$label'),
    constraints: BoxConstraints(minHeight: compact ? 78 : 96),
    padding: EdgeInsets.all(compact ? 8 : 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FBFE),
      borderRadius: BorderRadius.circular(9),
    ),
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget glyph = Container(
          width: compact ? 21 : 24,
          height: compact ? 21 : 24,
          decoration: BoxDecoration(
            color: style.paleBlue,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: Size.square(compact ? 12 : 14),
            painter: _KpiGlyphPainter(label: label, color: style.primary),
          ),
        );
        final Widget labelText = Text(
          label,
          key: Key('analytics-kpi-label-$label'),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(color: style.muted, fontSize: 11),
        );
        final Widget comparison = Container(
          key: Key('analytics-kpi-comparison-$label'),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7EF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            switch (label) {
              '매출' => '+12.5%',
              '인건비율' => '-1.2%',
              _ => '+1명',
            },
            style: const TextStyle(
              color: Color(0xFF379666),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        final bool compactHeader = constraints.maxWidth < 120;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: <Widget>[
                glyph,
                const SizedBox(width: 6),
                Expanded(child: labelText),
                if (showComparison && !compactHeader) comparison,
              ],
            ),
            if (showComparison && compactHeader) ...<Widget>[
              const SizedBox(height: 3),
              Align(alignment: Alignment.centerRight, child: comparison),
            ],
            SizedBox(height: compact ? 5 : 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: style.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 17 : 19,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

final class _KpiGlyphPainter extends CustomPainter {
  const _KpiGlyphPainter({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (label == '매출') {
      for (final (x, height) in <(double, double)>[
        (.15, .4),
        (.43, .62),
        (.71, .82),
      ]) {
        canvas.drawLine(
          Offset(size.width * x, size.height * .86),
          Offset(size.width * x, size.height * (1 - height)),
          stroke,
        );
      }
      return;
    }
    if (label == '인건비율') {
      canvas.drawArc(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        .5,
        4.4,
        false,
        stroke,
      );
      canvas.drawLine(
        size.center(Offset.zero),
        Offset(size.width * .7, size.height * .3),
        stroke,
      );
      return;
    }
    canvas.drawCircle(Offset(size.width * .36, size.height * .35), 2.2, stroke);
    canvas.drawCircle(Offset(size.width * .68, size.height * .4), 1.9, stroke);
    canvas.drawArc(
      Rect.fromLTWH(1, size.height * .42, size.width * .7, size.height * .5),
      3.5,
      2.6,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _KpiGlyphPainter oldDelegate) =>
      oldDelegate.label != label || oldDelegate.color != color;
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({required this.style});

  final WorkflowResultStyle style;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 4,
    children: <Widget>[
      Text(
        '오늘의 핵심 지표',
        style: TextStyle(
          color: style.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        '2024년 11월 15일 (금)',
        style: TextStyle(color: style.muted, fontSize: 11),
      ),
    ],
  );
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.style,
    this.landscape = false,
    this.compact = false,
  });

  final WorkflowResultStyle style;
  final bool landscape;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool stack =
          MediaQuery.textScalerOf(context).scale(16) >= 24 ||
          constraints.maxWidth < 300;
      if (stack) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Kpi(
              '매출',
              '4,820,000원',
              style,
              compact: compact,
              showComparison: landscape,
            ),
            const SizedBox(height: 8),
            _Kpi(
              '인건비율',
              '21.4%',
              style,
              compact: compact,
              showComparison: landscape,
            ),
            const SizedBox(height: 8),
            _Kpi(
              '근무 인원',
              '8명',
              style,
              compact: compact,
              showComparison: landscape,
            ),
          ],
        );
      }
      return Row(
        children: <Widget>[
          Expanded(
            flex: landscape ? 221 : 268,
            child: _Kpi(
              '매출',
              '4,820,000원',
              style,
              compact: compact,
              showComparison: landscape,
            ),
          ),
          SizedBox(width: landscape ? 10 : 8),
          Expanded(
            flex: landscape ? 210 : 220,
            child: _Kpi(
              '인건비율',
              '21.4%',
              style,
              compact: compact,
              showComparison: landscape,
            ),
          ),
          SizedBox(width: landscape ? 10 : 8),
          Expanded(
            flex: landscape ? 212 : 225,
            child: _Kpi(
              '근무 인원',
              '8명',
              style,
              compact: compact,
              showComparison: landscape,
            ),
          ),
        ],
      );
    },
  );
}

const List<double> _mobileChartValues = <double>[
  .07,
  .16,
  .24,
  .42,
  .58,
  .43,
  .27,
  .29,
  .38,
  .49,
  .64,
  .82,
  .68,
  .40,
  .24,
];

// The expanded source labels its two highlighted values as 620,000 and
// 780,000 on an 800,000-won axis. Keep those labels and their plotted anchors
// on the same scale instead of reusing the mobile normalized trace.
const List<double> _landscapeChartValues = <double>[
  .07,
  .16,
  .24,
  .42,
  .775,
  .43,
  .27,
  .29,
  .38,
  .49,
  .64,
  .975,
  .68,
  .40,
  .24,
];

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.style, this.landscape = false});

  final WorkflowResultStyle style;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final List<double> chartValues = landscape
        ? _landscapeChartValues
        : _mobileChartValues;
    return Semantics(
      image: true,
      label:
          '시간대별 매출 차트, 단위 ${landscape ? '원' : '천원'}, '
          '점심 피크와 저녁 피크가 표시된 샘플 데이터',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double axisWidth = landscape ? 48 : 29;
            const double rightInset = 5;
            final double topInset = landscape ? 31 : 22;
            const double bottomInset = 21;
            final double plotWidth =
                constraints.maxWidth - axisWidth - rightInset;
            final double plotHeight =
                constraints.maxHeight - topInset - bottomInset;
            final List<String> yLabels = landscape
                ? const <String>[
                    '800,000',
                    '600,000',
                    '400,000',
                    '200,000',
                    '0',
                  ]
                : const <String>['800', '600', '400', '200', '0'];
            final List<String> xLabels = landscape
                ? const <String>[
                    '09시',
                    '11시',
                    '13시',
                    '15시',
                    '17시',
                    '19시',
                    '21시',
                  ]
                : const <String>['09시', '12시', '15시', '18시', '21시'];
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    key: const Key('analytics-sales-chart-painter'),
                    painter: _ChartPainter(
                      primary: style.primary,
                      grid: style.border,
                      values: chartValues,
                      axisWidth: axisWidth,
                      rightInset: rightInset,
                      topInset: topInset,
                      bottomInset: bottomInset,
                    ),
                  ),
                ),
                for (var i = 0; i < yLabels.length; i++)
                  Positioned(
                    key: i == 0
                        ? const Key('analytics-chart-axis-y-800')
                        : null,
                    left: 0,
                    top: topInset + plotHeight * i / 4 - 6,
                    width: axisWidth - 6,
                    child: Text(
                      yLabels[i],
                      textAlign: TextAlign.right,
                      style: TextStyle(color: style.muted, fontSize: 8),
                    ),
                  ),
                for (var i = 0; i < xLabels.length; i++)
                  Positioned(
                    left: axisWidth + plotWidth * i / (xLabels.length - 1) - 18,
                    bottom: 0,
                    width: 36,
                    child: Text(
                      xLabels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(color: style.muted, fontSize: 8),
                    ),
                  ),
                _PeakBadge(
                  key: const Key('analytics-chart-peak-lunch'),
                  label: landscape ? '점심 피크\n620,000원' : '점심 피크',
                  pointIndex: 4,
                  values: chartValues,
                  axisWidth: axisWidth,
                  plotWidth: plotWidth,
                  plotHeight: plotHeight,
                  topInset: topInset,
                  style: style,
                  landscape: landscape,
                ),
                _PeakBadge(
                  key: const Key('analytics-chart-peak-evening'),
                  label: landscape ? '저녁 피크\n780,000원' : '저녁 피크',
                  pointIndex: 11,
                  values: chartValues,
                  axisWidth: axisWidth,
                  plotWidth: plotWidth,
                  plotHeight: plotHeight,
                  topInset: topInset,
                  style: style,
                  landscape: landscape,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PeakBadge extends StatelessWidget {
  const _PeakBadge({
    super.key,
    required this.label,
    required this.pointIndex,
    required this.values,
    required this.axisWidth,
    required this.plotWidth,
    required this.plotHeight,
    required this.topInset,
    required this.style,
    required this.landscape,
  });

  final String label;
  final int pointIndex;
  final List<double> values;
  final double axisWidth;
  final double plotWidth;
  final double plotHeight;
  final double topInset;
  final WorkflowResultStyle style;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final double width = landscape ? 74 : 57;
    final double pointX =
        axisWidth + plotWidth * pointIndex / (values.length - 1);
    final double pointY = topInset + plotHeight * (1 - values[pointIndex]);
    return Positioned(
      left: pointX - width / 2,
      top: (pointY - (landscape ? 42 : 27)).clamp(0, double.infinity),
      width: width,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: landscape ? 5 : 4,
          vertical: landscape ? 4 : 3,
        ),
        decoration: BoxDecoration(
          color: style.paleBlue,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: style.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: style.primary,
            fontSize: landscape ? 8 : 7.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.primary,
    required this.grid,
    required this.values,
    required this.axisWidth,
    required this.rightInset,
    required this.topInset,
    required this.bottomInset,
  });

  final Color primary;
  final Color grid;
  final List<double> values;
  final double axisWidth;
  final double rightInset;
  final double topInset;
  final double bottomInset;

  @override
  void paint(Canvas canvas, Size size) {
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final double plotWidth = size.width - axisWidth - rightInset;
    final double plotHeight = size.height - topInset - bottomInset;
    for (var i = 0; i < 5; i++) {
      final y = topInset + plotHeight * i / 4;
      canvas.drawLine(
        Offset(axisWidth, y),
        Offset(size.width - rightInset, y),
        g,
      );
    }
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      points.add(
        Offset(
          axisWidth + plotWidth * i / (values.length - 1),
          topInset + plotHeight * (1 - values[i]),
        ),
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final Offset previous = points[i - 1];
      final Offset current = points[i];
      final double controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, topInset + plotHeight)
      ..lineTo(points.first.dx, topInset + plotHeight)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                primary.withValues(alpha: .2),
                primary.withValues(alpha: .015),
              ],
            ).createShader(
              Rect.fromLTWH(axisWidth, topInset, plotWidth, plotHeight),
            ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < points.length; i++) {
      final bool peak = i == 4 || i == 11;
      if (peak) {
        canvas.drawCircle(
          points[i],
          5,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      }
      canvas.drawCircle(points[i], peak ? 3.6 : 2.6, Paint()..color = primary);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.primary != primary ||
      old.grid != grid ||
      old.values != values ||
      old.axisWidth != axisWidth ||
      old.rightInset != rightInset ||
      old.topInset != topInset ||
      old.bottomInset != bottomInset;
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({required this.style, this.compact = false});
  final WorkflowResultStyle style;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    const days = [
      '일\n10/19',
      '월\n10/20',
      '화\n10/21',
      '수\n10/22',
      '목\n10/23',
      '금\n10/24',
      '토\n10/25',
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Table(
        border: TableBorder.all(color: style.border),
        columnWidths: const {0: FlexColumnWidth(1.55)},
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8F9FB)),
            children: [
              SizedBox(height: compact ? 34 : 42),
              for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
                    child: Text(
                      days[dayIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dayIndex == 0
                            ? const Color(0xFFD84F56)
                            : dayIndex == 6
                            ? style.primary
                            : style.muted,
                        fontSize: 8,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final p in WorkflowResultFixtures.schedule)
            TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: compact ? 4 : 7,
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: const Color(0xFFDCEBFC),
                        child: Text(
                          p.name.substring(0, 1),
                          style: TextStyle(color: style.primary, fontSize: 7),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${p.name}\n${p.role}',
                          style: TextStyle(
                            color: style.ink,
                            fontSize: 8,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final shift in p.shifts)
                  Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        vertical: compact ? 5 : 8,
                        horizontal: 2,
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: compact ? 3 : 4,
                        horizontal: 3,
                      ),
                      decoration: BoxDecoration(
                        color: shift == '휴무'
                            ? const Color(0xFFEBEBED)
                            : const Color(0xFFE2EEFE),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        shift,
                        style: TextStyle(
                          color: shift == '휴무' ? style.muted : style.primary,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
