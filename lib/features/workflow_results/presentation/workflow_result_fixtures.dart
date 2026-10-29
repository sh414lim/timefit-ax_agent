enum WorkflowResultKind { notice, approval, analytics, schedule }

class ApprovalFixture {
  const ApprovalFixture(this.title, this.detail, this.tone, {this.deadline});
  final String title;
  final String detail;
  final int tone;
  final String? deadline;
}

class SchedulePersonFixture {
  const SchedulePersonFixture(this.name, this.role, this.shifts);
  final String name;
  final String role;
  final List<String> shifts;
}

abstract final class WorkflowResultFixtures {
  static const approvals = <ApprovalFixture>[
    ApprovalFixture('김민지 · 연차 요청', '10월 23일', 0, deadline: '오늘 마감'),
    ApprovalFixture('이준호 · 근무 변경', '오후 → 오전', 1),
    ApprovalFixture('박서연 · 영수증 확인', '86,400원', 2),
  ];

  static const schedule = <SchedulePersonFixture>[
    SchedulePersonFixture('김민지', '매니저', [
      '오전',
      '오전',
      '휴무',
      '오전',
      '오전',
      '휴무',
      '오전',
    ]),
    SchedulePersonFixture('이준호', '주임', [
      '오후',
      '오후',
      '오전',
      '오전',
      '휴무',
      '오후',
      '오후',
    ]),
    SchedulePersonFixture('박서연', '사원', [
      '오후',
      '휴무',
      '오후',
      '오후',
      '오전',
      '오전',
      '오후',
    ]),
    SchedulePersonFixture('최지훈', '사원', [
      '오전',
      '오전',
      '오후',
      '휴무',
      '오후',
      '오후',
      '오전',
    ]),
    SchedulePersonFixture('정하은', '사원', [
      '오전',
      '오후',
      '휴무',
      '오후',
      '오후',
      '오전',
      '오전',
    ]),
    SchedulePersonFixture('한민수', '사원', [
      '오후',
      '오전',
      '오전',
      '오후',
      '휴무',
      '오전',
      '오후',
    ]),
  ];

  static const landscapeSchedule = <SchedulePersonFixture>[
    SchedulePersonFixture('김민지', '', [
      '오전',
      '오전',
      '오후',
      '오후',
      '오전',
      '오전',
      '오후',
    ]),
    SchedulePersonFixture('이준호', '', [
      '오전',
      '오후',
      '오후',
      '오전',
      '오전',
      '오후',
      '오후',
    ]),
    SchedulePersonFixture('박서연', '', [
      '오후',
      '오전',
      '오전',
      '오후',
      '오후',
      '오전',
      '오전',
    ]),
    SchedulePersonFixture('최현우', '', [
      '오후',
      '오후',
      '오전',
      '오전',
      '오후',
      '오후',
      '오전',
    ]),
    SchedulePersonFixture('정다은', '', [
      '오전',
      '휴무',
      '오후',
      '오전',
      '오후',
      '오전',
      '오후',
    ]),
    SchedulePersonFixture('한지민', '', [
      '오후',
      '오전',
      '휴무',
      '오후',
      '오전',
      '오후',
      '오전',
    ]),
    SchedulePersonFixture('오세훈', '', [
      '오전',
      '오후',
      '오전',
      '오후',
      '휴무',
      '오전',
      '오후',
    ]),
    SchedulePersonFixture('김도연', '', [
      '오후',
      '오전',
      '오후',
      '오전',
      '오후',
      '휴무',
      '오전',
    ]),
  ];
}
