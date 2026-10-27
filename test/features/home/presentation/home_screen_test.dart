import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/conversations/application/conversation_list_controller.dart';
import 'package:timefit_native/features/conversations/domain/conversation_repository.dart';
import 'package:timefit_native/features/conversations/domain/conversation_summary.dart';
import 'package:timefit_native/features/home/presentation/business_preview_screen.dart';
import 'package:timefit_native/features/home/presentation/demo_home_action.dart';
import 'package:timefit_native/features/home/presentation/home_screen.dart';
import 'package:timefit_native/features/workflow_results/presentation/layer.dart';

final class _Repository implements ConversationRepository {
  _Repository(this.items);
  final List<ConversationSummary> items;
  int reads = 0;
  int refreshes = 0;

  @override
  Future<List<ConversationSummary>> readCachedConversations() async {
    reads += 1;
    return items;
  }

  @override
  Future<List<ConversationSummary>> refreshConversations() async {
    refreshes += 1;
    return items;
  }
}

void main() {
  testWidgets('actions and composer remain presentation-only', (tester) async {
    final repository = _Repository(const <ConversationSummary>[]);
    final controller = ConversationListController(repository: repository);
    await controller.load();
    addTearDown(controller.dispose);
    var previews = 0;
    var opens = 0;
    var newConversations = 0;
    final draft = TextEditingController();
    addTearDown(draft.dispose);

    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DemoHomeScreen(
          conversationController: controller,
          onOpenConversation: (_) => opens += 1,
          onOpenConversationList: () => opens += 1,
          onOpenArchive: () => opens += 1,
          onNewConversation: () => newConversations += 1,
          onPreviewAction: (_) => previews += 1,
          draftController: draft,
        ),
      ),
    );

    await pump();
    await tester.ensureVisible(find.text(DemoHomeAction.costAnalysis.label));
    await tester.tap(find.text(DemoHomeAction.costAnalysis.label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '메모리에만 남는 요청');
    await tester.pump();

    expect(previews, 1);
    expect(opens, 0);
    expect(newConversations, 0);
    expect(find.text('샘플 데이터 · 실행 안 됨'), findsOneWidget);
    expect(draft.text, '메모리에만 남는 요청');
    expect(repository.reads, 1);
    expect(repository.refreshes, 1);

    await tester.tap(find.byTooltip('홈으로 돌아가기'));
    await tester.pump();
    expect(draft.text, '메모리에만 남는 요청');
  });

  testWidgets(
    'workflow previews use source-specific notice and insight glyphs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(432, 900);
      addTearDown(tester.view.reset);
      final draft = TextEditingController();
      final focus = FocusNode();
      addTearDown(draft.dispose);
      addTearDown(focus.dispose);

      Widget preview(DemoHomeAction action) => MaterialApp(
        theme: AppTheme.light(),
        home: DemoBusinessPreviewScreen(
          action: action,
          onBack: () {},
          draftController: draft,
          draftFocusNode: focus,
        ),
      );

      await tester.pumpWidget(preview(DemoHomeAction.employeeAnnouncement));
      expect(
        find.byKey(const Key('workflow-notice-megaphone-icon')),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('workflow-notice-megaphone-icon')),
            )
            .getSemanticsData()
            .label,
        contains('공지 확성기 재구성 아이콘'),
      );

      await tester.pumpWidget(preview(DemoHomeAction.storeOverview));
      expect(
        find.byKey(const Key('workflow-analytics-insight-icon')),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('workflow-analytics-insight-icon')),
            )
            .getSemanticsData()
            .label,
        contains('AI 인사이트 반짝임 재구성 아이콘'),
      );
      expect(
        find.byKey(const Key('workflow-notice-megaphone-icon')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final testCase in <({Size size, double keyboard})>[
    (size: const Size(320, 640), keyboard: 280),
    (size: const Size(852, 393), keyboard: 216),
    (size: const Size(1024, 576), keyboard: 0),
  ]) {
    testWidgets('analytics preview remains scrollable at ${testCase.size} '
        'keyboard ${testCase.keyboard} and text 200 percent', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = testCase.size;
      tester.view.viewInsets = FakeViewPadding(bottom: testCase.keyboard);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final draft = TextEditingController(text: '반응형 확인 문장');
      final focus = FocusNode();
      addTearDown(draft.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: DemoBusinessPreviewScreen(
            action: DemoHomeAction.storeOverview,
            onBack: () {},
            draftController: draft,
            draftFocusNode: focus,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('반응형 확인 문장'), findsOneWidget);
      expect(find.byType(Scrollable), findsWidgets);
      if (testCase.size.width < 900) {
        await tester.scrollUntilVisible(
          find.text('시간대별 매출'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
      }
      expect(
        find.byKey(const Key('analytics-sales-chart-painter')),
        findsOneWidget,
      );
      if (testCase.size.width < 900) {
        await tester.scrollUntilVisible(
          find.text('AI 인사이트'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
      }
      expect(
        find.byKey(const Key('workflow-analytics-insight-icon')),
        findsOneWidget,
      );
    });
  }

  for (final width in <double>[320, 390, 430, 1024, 1366]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$width ${brightness.name} text 200 percent has no overflow',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, width < 600 ? 760 : 900);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final repository = _Repository(<ConversationSummary>[
            ConversationSummary(
              id: 'recent',
              title: '로컬 최근 대화',
              preview: '미리보기',
              updatedAt: DateTime(2026),
            ),
          ]);
          final controller = ConversationListController(repository: repository);
          await controller.load();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: DemoHomeScreen(
                conversationController: controller,
                onOpenConversation: (_) {},
                onOpenConversationList: () {},
                onOpenArchive: () {},
                onNewConversation: () {},
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel(RegExp('오늘 매장 현황')), findsOneWidget);
          expect(
            tester
                .getSemantics(find.bySemanticsLabel(RegExp('오늘 매장 현황')))
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isTrue,
          );
          expect(find.bySemanticsLabel(RegExp('이번 주 근무표')), findsOneWidget);
          expect(find.bySemanticsLabel(RegExp('비용 분석')), findsOneWidget);
          expect(find.bySemanticsLabel(RegExp('직원 공지 작성')), findsOneWidget);
          expect(
            tester.getSize(find.byTooltip('샘플 첨부 자리')).width,
            greaterThanOrEqualTo(44),
          );
          expect(
            tester.getSize(find.byTooltip('샘플 미리보기')).width,
            greaterThanOrEqualTo(44),
          );
          expect(find.text('데모'), findsWidgets);
          expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
        },
      );
    }
  }

  testWidgets('keyboard keeps memory draft and home remains scrollable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = ConversationListController(
      repository: _Repository(const <ConversationSummary>[]),
    );
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DemoHomeScreen(
          conversationController: controller,
          onOpenConversation: (_) {},
          onOpenConversationList: () {},
          onOpenArchive: () {},
          onNewConversation: () {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '보존되는 데모 초안');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('보존되는 데모 초안'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('320dp cards size to their default-scale content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    final controller = ConversationListController(
      repository: _Repository(const <ConversationSummary>[]),
    );
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DemoHomeScreen(
          conversationController: controller,
          onOpenConversation: (_) {},
          onOpenConversationList: () {},
          onOpenArchive: () {},
          onNewConversation: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final action in DemoHomeAction.values) {
      expect(find.bySemanticsLabel(RegExp(action.label)), findsOneWidget);
    }
  });

  testWidgets('external draft survives a route-style unmount and remount', (
    tester,
  ) async {
    final draft = TextEditingController();
    final focus = FocusNode();
    addTearDown(draft.dispose);
    addTearDown(focus.dispose);
    final controller = ConversationListController(
      repository: _Repository(const <ConversationSummary>[]),
    );
    await controller.load();
    addTearDown(controller.dispose);

    Widget home() => MaterialApp(
      home: DemoHomeScreen(
        conversationController: controller,
        onOpenConversation: (_) {},
        onOpenConversationList: () {},
        onOpenArchive: () {},
        onNewConversation: () {},
        draftController: draft,
        draftFocusNode: focus,
      ),
    );

    await tester.pumpWidget(home());
    await tester.enterText(find.byType(TextField), 'HOME MEMORY QA');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(home());

    expect(draft.text, 'HOME MEMORY QA');
    expect(find.text('HOME MEMORY QA'), findsOneWidget);
  });

  testWidgets('expanded sidebar routes recent and archive', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 900);
    addTearDown(tester.view.reset);
    final controller = ConversationListController(
      repository: _Repository(const <ConversationSummary>[]),
    );
    await controller.load();
    addTearDown(controller.dispose);
    var all = 0;
    var archive = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DemoHomeScreen(
          conversationController: controller,
          onOpenConversation: (_) {},
          onOpenConversationList: () => all += 1,
          onOpenArchive: () => archive += 1,
          onNewConversation: () {},
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ListTile, '모든 대화'));
    await tester.tap(find.widgetWithText(ListTile, '보관'));

    expect(all, 1);
    expect(archive, 1);
  });

  testWidgets('preview action is hit-testable without invoking new chat', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.reset);
    final controller = ConversationListController(
      repository: _Repository(const <ConversationSummary>[]),
    );
    await controller.load();
    addTearDown(controller.dispose);
    var previews = 0;
    var newChats = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DemoHomeScreen(
          conversationController: controller,
          onOpenConversation: (_) {},
          onOpenConversationList: () {},
          onOpenArchive: () {},
          onNewConversation: () => newChats += 1,
          onPreviewAction: (_) => previews += 1,
        ),
      ),
    );

    expect(find.byTooltip('샘플 미리보기').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('샘플 미리보기'));

    expect(previews, 0);
    expect(newChats, 0);
  });

  testWidgets('source viewports preserve measured Home geometry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(432, 768);
    addTearDown(tester.view.reset);
    final controller = ConversationListController(
      repository: _Repository(const <ConversationSummary>[]),
    );
    await controller.load();
    addTearDown(controller.dispose);

    Widget home() => MaterialApp(
      theme: AppTheme.light(),
      home: DemoHomeScreen(
        conversationController: controller,
        onOpenConversation: (_) {},
        onOpenConversationList: () {},
        onOpenArchive: () {},
        onNewConversation: () {},
      ),
    );

    await tester.pumpWidget(home());
    final Size robot = tester.getSize(
      find.byKey(const Key('mobile-home-robot-slot')),
    );
    final Size mobileCard = tester.getSize(
      find.bySemanticsLabel(RegExp('오늘 매장 현황')),
    );
    expect(robot.width / 432, closeTo(.398, .002));
    expect(mobileCard.width / mobileCard.height, closeTo(2.15, .02));

    tester.view.physicalSize = const Size(1024, 576);
    await tester.pumpWidget(home());
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('expanded-home-sidebar'))).width /
          1024,
      closeTo(.178, .001),
    );
    expect(
      tester.getSize(find.byKey(const Key('expanded-home-symbol-slot'))),
      const Size(90, 78),
    );
  });

  for (final size in <Size>[const Size(390, 760), const Size(1366, 768)]) {
    testWidgets('$size renders the component-only approval source anatomy', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final draft = TextEditingController();
      final focus = FocusNode();
      addTearDown(draft.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: DemoBusinessPreviewScreen.approvals(
            onBack: () {},
            draftController: draft,
            draftFocusNode: focus,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('승인 요청 검토'), findsOneWidget);
      expect(find.textContaining('연차 요청'), findsOneWidget);
      expect(find.textContaining('근무 변경'), findsOneWidget);
      expect(find.textContaining('영수증 확인'), findsOneWidget);
      expect(find.text('샘플 데이터 · 실행 안 됨'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('승인 미리보기')), findsNWidgets(3));
      expect(
        find.byType(LandscapeWorkflowResultPane),
        size.width >= 900 ? findsOneWidget : findsNothing,
      );
    });
  }

  for (final width in <double>[402, 432]) {
    testWidgets(
      '$width mobile Home paints every description without ellipsis',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final controller = ConversationListController(
          repository: _Repository(const <ConversationSummary>[]),
        );
        await controller.load();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: DemoHomeScreen(
              conversationController: controller,
              onOpenConversation: (_) {},
              onOpenConversationList: () {},
              onOpenArchive: () {},
              onNewConversation: () {},
            ),
          ),
        );

        for (final action in DemoHomeAction.values) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byKey(Key('home-action-description-${action.name}')),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: action.name);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('workflow screens preserve source-specific composer variants', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(432, 900);
    addTearDown(tester.view.reset);
    final draft = TextEditingController();
    final focus = FocusNode();
    addTearDown(draft.dispose);
    addTearDown(focus.dispose);

    Future<void> pumpAction(DemoHomeAction action) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DemoBusinessPreviewScreen(
          action: action,
          onBack: () {},
          draftController: draft,
          draftFocusNode: focus,
        ),
      ),
    );

    await pumpAction(DemoHomeAction.storeOverview);
    expect(find.byTooltip('샘플 추가 자리'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(find.text('어제와 비교'), findsOneWidget);

    await pumpAction(DemoHomeAction.employeeAnnouncement);
    expect(find.byTooltip('샘플 첨부 자리'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(find.text('발송 전 최종 내용을 확인해 주세요.'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DemoBusinessPreviewScreen.approvals(
          onBack: () {},
          draftController: draft,
          draftFocusNode: focus,
        ),
      ),
    );
    expect(find.byTooltip('샘플 추가 자리'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(find.text('검토할 요청을 선택해 주세요.'), findsOneWidget);
  });
}
