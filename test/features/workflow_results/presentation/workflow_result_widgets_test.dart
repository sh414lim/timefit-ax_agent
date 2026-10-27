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

  testWidgets('analytics keeps visibly unequal KPI flexes', (tester) async {
    await pump(tester, const AnalyticsResultCard());
    expect(find.text('4,820,000원'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('schedule preserves seven days and six fixture employees', (
    tester,
  ) async {
    await pump(tester, const ScheduleResultCard());
    expect(find.text('일\n10/19'), findsOneWidget);
    expect(find.textContaining('김민지'), findsOneWidget);
    expect(find.textContaining('한민수'), findsOneWidget);
  });

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
}
