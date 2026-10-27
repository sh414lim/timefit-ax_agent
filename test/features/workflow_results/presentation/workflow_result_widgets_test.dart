import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/workflow_results/presentation/layer.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(432, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  for (final kind in WorkflowResultKind.values) {
    testWidgets('$kind renders a display-only fixture', (tester) async {
      await pump(tester, WorkflowResultCard(kind: kind));
      expect(tester.takeException(), isNull);
      expect(find.byType(WorkflowResultCard), findsOneWidget);
    });
  }

  testWidgets(
    'approval keeps three unequal request rows and automation preview',
    (tester) async {
      await pump(tester, const ApprovalResultBoard());
      expect(find.textContaining('연차 요청'), findsOneWidget);
      expect(find.textContaining('근무 변경'), findsOneWidget);
      expect(find.textContaining('영수증 확인'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      final SemanticsData approve = tester
          .getSemantics(find.bySemanticsLabel(RegExp('승인 미리보기')).first)
          .getSemanticsData();
      expect(approve.hasAction(SemanticsAction.tap), isFalse);
    },
  );

  testWidgets('analytics keeps unequal KPIs and source chart anatomy', (
    tester,
  ) async {
    await pump(tester, const AnalyticsResultCard());
    expect(find.text('4,820,000원'), findsOneWidget);
    expect(find.byKey(const Key('analytics-chart-unit')), findsOneWidget);
    expect(find.byKey(const Key('analytics-chart-axis-y-800')), findsOneWidget);
    expect(find.text('점심 피크'), findsOneWidget);
    expect(find.text('저녁 피크'), findsOneWidget);
    expect(find.text('09시'), findsOneWidget);
    expect(find.text('21시'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('시간대별 매출 차트.*점심 피크.*저녁 피크')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape analytics keeps labeled source peaks', (tester) async {
    await pump(
      tester,
      const LandscapeWorkflowResultPane(kind: WorkflowResultKind.analytics),
      size: const Size(760, 900),
    );
    expect(find.text('점심 피크\n620,000원'), findsOneWidget);
    expect(find.text('저녁 피크\n780,000원'), findsOneWidget);
    expect(find.text('800,000'), findsOneWidget);
    expect(find.text('인건비'), findsOneWidget);
    expect(find.text('근무 인원'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schedule preserves seven days and six fixture employees', (
    tester,
  ) async {
    await pump(tester, const ScheduleResultCard());
    expect(find.text('일\n10/19'), findsOneWidget);
    expect(find.textContaining('김민지'), findsOneWidget);
    expect(find.textContaining('한민수'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsWidgets);
  });

  testWidgets(
    'landscape schedule preserves toolbar and eight employee avatars',
    (tester) async {
      await pump(
        tester,
        const LandscapeWorkflowResultPane(kind: WorkflowResultKind.schedule),
        size: const Size(900, 1000),
      );
      expect(find.text('내보내기'), findsOneWidget);
      expect(find.text('공유'), findsOneWidget);
      expect(find.text('10/19\n(일)'), findsOneWidget);
      expect(find.text('10/25\n(토)'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNWidgets(8));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('landscape ratios remain workflow specific', (tester) async {
    await pump(
      tester,
      const LandscapeWorkflowColumns(
        kind: WorkflowResultKind.analytics,
        sidebar: ColoredBox(key: Key('side'), color: Colors.red),
        chat: ColoredBox(key: Key('chat'), color: Colors.green),
        result: ColoredBox(key: Key('result'), color: Colors.blue),
      ),
      size: const Size(1000, 600),
    );
    final side = tester.getSize(find.byKey(const Key('side'))).width;
    final chat = tester.getSize(find.byKey(const Key('chat'))).width;
    final result = tester.getSize(find.byKey(const Key('result'))).width;
    final total = side + chat + result;
    expect(side / total, closeTo(.1979, .0001));
    expect(chat / total, closeTo(.3164, .0001));
  });

  for (final kind in [
    WorkflowResultKind.approval,
    WorkflowResultKind.analytics,
    WorkflowResultKind.schedule,
  ]) {
    testWidgets('landscape $kind has its own result presentation', (
      tester,
    ) async {
      await pump(
        tester,
        LandscapeWorkflowResultPane(kind: kind),
        size: const Size(760, 900),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LandscapeWorkflowResultPane), findsOneWidget);
    });
  }
}
