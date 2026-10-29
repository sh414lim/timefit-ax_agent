enum DemoHomeAction {
  storeOverview(
    '오늘 매장 현황',
    '매출 방문객 운영 현황을 한눈에 확인하세요',
    previewTitle: '오늘 매장 분석',
    userPrompt: '오늘 매장 운영 상황을 한눈에 보여줘.',
    assistantReply: '합성 매출과 인건비 지표를 분석했어요.',
    resultTitle: '오늘의 핵심 지표',
    composerPlaceholder: '데이터에 대해 질문하세요',
    expandedSidebarRatio: .195,
    expandedChatRatio: .311,
  ),
  weeklySchedule(
    '이번 주 근무표',
    '직원 근무 일정과 변경사항을 확인하세요',
    previewTitle: '근무표 만들기',
    userPrompt: '다음 주 근무표를 만들어줘. 주말에는 4명 이상 배치해줘.',
    assistantReply: '조건을 반영한 합성 근무표 초안을 만들었어요.',
    resultTitle: '10월 19일 - 10월 25일',
    composerPlaceholder: '추가 요청을 입력하세요',
    expandedSidebarRatio: .207,
    expandedChatRatio: .314,
  ),
  costAnalysis(
    '비용 분석',
    '인건비 운영비 등 비용을 분석해보세요',
    previewTitle: '비용 분석',
    userPrompt: '이번 주 비용 구조를 합성 데이터로 보여줘.',
    assistantReply: '합성 인건비와 운영비 지표를 정리했어요.',
    resultTitle: '비용 핵심 지표',
    composerPlaceholder: '비용 데이터에 대해 질문하세요',
    expandedSidebarRatio: .195,
    expandedChatRatio: .311,
  ),
  employeeAnnouncement(
    '직원 공지 작성',
    '직원들에게 전달할 공지사항을 작성하세요',
    previewTitle: '직원 공지 작성',
    userPrompt: '이번 주 금요일 재고조사 공지 초안을 작성해줘.',
    assistantReply: '직원들이 이해하기 쉬운 합성 공지 초안을 만들었어요.',
    resultTitle: '재고조사 안내',
    composerPlaceholder: '공지 내용을 추가로 요청하세요',
    expandedSidebarRatio: .184,
    expandedChatRatio: .419,
  );

  const DemoHomeAction(
    this.label,
    this.description, {
    required this.previewTitle,
    required this.userPrompt,
    required this.assistantReply,
    required this.resultTitle,
    required this.composerPlaceholder,
    required this.expandedSidebarRatio,
    required this.expandedChatRatio,
  });

  final String label;
  final String description;
  final String previewTitle;
  final String userPrompt;
  final String assistantReply;
  final String resultTitle;
  final String composerPlaceholder;
  final double expandedSidebarRatio;
  final double expandedChatRatio;
}
