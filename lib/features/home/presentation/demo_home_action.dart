import 'package:flutter/material.dart';

enum DemoHomeAction {
  storeOverview('오늘 매장 현황', '합성 지표 미리보기', Icons.storefront_outlined),
  weeklySchedule('이번 주 근무표', '샘플 일정 미리보기', Icons.calendar_view_week_outlined),
  costAnalysis('비용 분석', '합성 비용 요약 보기', Icons.query_stats_outlined),
  employeeAnnouncement('직원 공지 작성', '전송 없는 초안 미리보기', Icons.campaign_outlined);

  const DemoHomeAction(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}
