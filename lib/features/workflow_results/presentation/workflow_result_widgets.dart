import 'package:flutter/material.dart';
import 'workflow_result_fixtures.dart';
import 'workflow_result_style.dart';

class WorkflowResultCard extends StatelessWidget {
  const WorkflowResultCard({
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
    WorkflowResultKind.notice => NoticeResultCard(
      style: style,
      assetBuilder: assetBuilder,
    ),
    WorkflowResultKind.approval => ApprovalResultBoard(
      style: style,
      assetBuilder: assetBuilder,
    ),
    WorkflowResultKind.analytics => AnalyticsResultCard(
      style: style,
      assetBuilder: assetBuilder,
    ),
    WorkflowResultKind.schedule => ScheduleResultCard(
      style: style,
      assetBuilder: assetBuilder,
    ),
  };
}

class NoticeResultCard extends StatelessWidget {
  const NoticeResultCard({
    super.key,
    this.style = const WorkflowResultStyle(),
    this.assetBuilder,
  });
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;

  @override
  Widget build(BuildContext context) => _Frame(
    style: style,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          role: 'workflow.notice.megaphone',
          title: '재고조사 안내',
          style: style,
          assetBuilder: assetBuilder,
        ),
        const SizedBox(height: 22),
        Text(
          '이번 주 금요일 영업 종료 후 재고조사를 진행합니다.\n담당 구역을 확인하고 오후 10시까지 매장에 도착해\n주세요.',
          style: TextStyle(
            color: style.ink,
            height: 1.55,
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Divider(color: style.border, height: 1),
        const SizedBox(height: 16),
        _Meta(icon: Icons.people_outline, text: '전체 직원 · 12명', style: style),
        const SizedBox(height: 13),
        _Meta(
          icon: Icons.calendar_today_outlined,
          text: '10월 23일 오후 6:00',
          style: style,
        ),
        const SizedBox(height: 18),
        Divider(color: style.border, height: 1),
        const SizedBox(height: 12),
        _Check(text: '카카오 알림', style: style),
        const SizedBox(height: 10),
        _Check(text: '앱 푸시', style: style),
        const SizedBox(height: 20),
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
  });
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in WorkflowResultFixtures.approvals) ...[
        _ApprovalRow(item: item, style: style, assetBuilder: assetBuilder),
        const SizedBox(height: 10),
      ],
      _Frame(
        style: style,
        tint: style.paleBlue,
        child: Row(
          children: [
            _RoleAsset(
              role: 'workflow.approval.automation',
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
                    '자주 발생하는 승인 요청을 자동으로 처리하면\n더 중요한 업무에 집중할 수 있어요.',
                    style: TextStyle(
                      color: style.muted,
                      fontSize: 12,
                      height: 1.45,
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
  });
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  @override
  Widget build(BuildContext context) => _Frame(
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
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '2024년 11월 15일 (금)',
              style: TextStyle(color: style.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(flex: 27, child: _Kpi('매출', '4,820,000원', style)),
            const SizedBox(width: 8),
            Expanded(flex: 22, child: _Kpi('인건비율', '21.4%', style)),
            const SizedBox(width: 8),
            Expanded(flex: 23, child: _Kpi('근무 인원', '8명', style)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 210,
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          decoration: BoxDecoration(
            border: Border.all(color: style.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '시간대별 매출',
                style: TextStyle(color: style.ink, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CustomPaint(
                  painter: _ChartPainter(style.primary, style.border),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: style.paleBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _RoleAsset(
                role: 'workflow.analytics.insight',
                size: 42,
                style: style,
                assetBuilder: assetBuilder,
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 5),
                    Text(
                      '오후 7시에 매출이 가장 높았어요.',
                      style: TextStyle(
                        color: style.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '저녁 시간대(18시~21시)에 전체 매출의 38%가 발생했어요.',
                      style: TextStyle(color: style.muted, fontSize: 11),
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
  });
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Frame(
        style: style,
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
                      fontSize: 18,
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
            const SizedBox(height: 14),
            _ScheduleGrid(style: style),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
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
      const SizedBox(height: 12),
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

class _Frame extends StatelessWidget {
  const _Frame({required this.child, required this.style, this.tint});
  final Widget child;
  final WorkflowResultStyle style;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
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
  });
  final String role, title;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _RoleAsset(
        role: role,
        size: 50,
        style: style,
        assetBuilder: assetBuilder,
      ),
      const SizedBox(width: 13),
      Text(
        title,
        style: TextStyle(
          color: style.ink,
          fontSize: 23,
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
      child: Text(
        label,
        style: TextStyle(
          color: primary ? Colors.white : style.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.item,
    required this.style,
    this.assetBuilder,
  });
  final ApprovalFixture item;
  final WorkflowResultStyle style;
  final WorkflowAssetBuilder? assetBuilder;
  @override
  Widget build(BuildContext context) {
    final roles = [
      'workflow.approval.leave',
      'workflow.approval.shift',
      'workflow.approval.receipt',
    ];
    return _Frame(
      style: style,
      child: Row(
        children: [
          _RoleAsset(
            role: roles[item.tone],
            size: 52,
            style: style,
            assetBuilder: assetBuilder,
          ),
          const SizedBox(width: 13),
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
                const SizedBox(height: 5),
                Text(
                  item.detail,
                  style: TextStyle(color: style.muted, fontSize: 13),
                ),
                if (item.deadline != null) ...[
                  const SizedBox(height: 5),
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
  const _Kpi(this.label, this.value, this.style);
  final String label, value;
  final WorkflowResultStyle style;
  @override
  Widget build(BuildContext context) => Container(
    height: 88,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FBFE),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: style.muted, fontSize: 11)),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: style.primary,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.primary, this.grid);
  final Color primary, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = 18 + (size.height - 38) * i / 4;
      canvas.drawLine(Offset(28, y), Offset(size.width - 6, y), g);
    }
    final points = <Offset>[];
    const values = [
      0.12,
      .22,
      .34,
      .55,
      .74,
      .55,
      .31,
      .33,
      .47,
      .61,
      .78,
      .96,
      .74,
      .38,
      .22,
    ];
    for (var i = 0; i < values.length; i++) {
      points.add(
        Offset(
          28 + (size.width - 38) * i / (values.length - 1),
          size.height - 20 - values[i] * (size.height - 48),
        ),
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in points) {
      canvas.drawCircle(p, 2.6, Paint()..color = primary);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.primary != primary || old.grid != grid;
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({required this.style});
  final WorkflowResultStyle style;
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
              const SizedBox(height: 42),
              for (final d in days)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: style.muted,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 7,
                  ),
                  child: Text(
                    '${p.name}\n${p.role}',
                    style: TextStyle(
                      color: style.ink,
                      fontSize: 8,
                      height: 1.3,
                    ),
                  ),
                ),
                for (final shift in p.shifts)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
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
