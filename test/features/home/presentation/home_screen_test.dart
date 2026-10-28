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
import 'package:timefit_native/features/home/presentation/widgets/demo_quick_composer.dart';
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

int _paintedLineCount(RenderParagraph paragraph, String text) => paragraph
    .getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    )
    .map((TextBox box) => (box.top * 100).round())
    .toSet()
    .length;

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
    expect(find.text('데모 · 실행 안 됨'), findsOneWidget);
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
      expect(find.text('승인 업무 도우미'), findsOneWidget);
      expect(find.textContaining('연차 요청'), findsOneWidget);
      expect(find.textContaining('근무 변경'), findsOneWidget);
      expect(find.textContaining('영수증 확인'), findsOneWidget);
      expect(
        find.text(size.width >= 900 ? '샘플 데이터 · 실행 안 됨' : '데모 · 실행 안 됨'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('승인 미리보기')), findsNWidgets(3));
      expect(
        find.byType(LandscapeWorkflowResultPane),
        size.width >= 900 ? findsOneWidget : findsNothing,
      );
    });
  }

  for (final width in <double>[402, 432]) {
    testWidgets(
      '$width mobile Home keeps source two-line descriptions without clipping',
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
          final Text description = tester.widget<Text>(
            find.byKey(Key('home-action-description-${action.name}')),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: action.name);
          expect(
            _paintedLineCount(paragraph, action.description),
            lessThanOrEqualTo(2),
            reason: action.name,
          );
          expect(
            description.style!.letterSpacing ?? 0,
            0,
            reason: '${action.name} keeps normal source tracking',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('mobile Home cards preserve source-scaled icon and copy size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(432, 900);
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

    expect(
      tester.getSize(
        find.byKey(const Key('home-action-icon-field-storeOverview')),
      ),
      const Size.square(48),
    );
    final Text description = tester.widget<Text>(
      find.byKey(const Key('home-action-description-storeOverview')),
    );
    expect(description.data, '매출 방문객 운영 현황을 한눈에 확인하세요');
    expect(description.style!.fontSize, 7.9);
    expect(description.style!.letterSpacing ?? 0, 0);
    final Text title = tester.widget<Text>(find.text('오늘 매장 현황'));
    expect(title.style!.fontSize, 12.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expanded store analysis preserves source conversation and questions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 576);
      addTearDown(tester.view.reset);
      final draft = TextEditingController();
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

      expect(find.text('매장 분석'), findsOneWidget);
      expect(find.text('오늘 매장 운영 상황을 한눈에 보여줘.'), findsOneWidget);
      expect(find.text('매출과 인건비를 분석했어요.'), findsOneWidget);
      const String sourceDetail =
          '오늘은 전반적으로 안정적인 운영 흐름을\n'
          '보였고 점심과 저녁 시간대에 매출이\n'
          '크게 상승했어요 주요 지표와 시간대별 추이를\n'
          '오른쪽에서 확인할 수 있어요';
      final Finder detail = find.text(sourceDetail);
      expect(detail, findsOneWidget);
      final Text detailText = tester.widget<Text>(detail);
      final RenderParagraph detailParagraph = tester
          .renderObject<RenderParagraph>(detail);
      expect(detailText.data, sourceDetail);
      expect(detailText.style!.fontSize, 9.1);
      expect(detailText.style!.letterSpacing ?? 0, 0);
      expect(
        _paintedLineCount(detailParagraph, detailText.data!),
        4,
        reason:
            '1024×576 source-matching fixture keeps the four-line analysis explanation',
      );
      for (final String question in const <String>[
        '어제와 비교해서 어떤가요',
        '시간대별 상세 매출을 보여줘',
        '인건비를 더 줄일 수 있는 방법이 있을까',
        '인기 메뉴 순위를 알려줘',
      ]) {
        expect(find.text(question), findsOneWidget);
      }
      expect(
        find.byKey(const Key('expanded-analysis-suggestion-list')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final Size size in const <Size>[Size(320, 760), Size(1024, 768)]) {
    testWidgets('approval deadline stays bounded at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final TextEditingController draft = TextEditingController();
      final FocusNode focus = FocusNode();
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
      await tester.pump();

      final Rect pill = tester.getRect(
        find.byKey(const Key('approval-deadline-pill')),
      );
      final Rect clock = tester.getRect(
        find.byKey(const Key('approval-deadline-clock')),
      );
      expect(pill.contains(clock.topLeft), isTrue);
      expect(pill.contains(clock.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expanded notice and approval keep their follow-up guidance', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 768);
    addTearDown(tester.view.reset);
    final draft = TextEditingController();
    final focus = FocusNode();
    addTearDown(draft.dispose);
    addTearDown(focus.dispose);

    Future<void> pump(Widget preview) =>
        tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: preview));

    await pump(
      DemoBusinessPreviewScreen(
        action: DemoHomeAction.employeeAnnouncement,
        onBack: () {},
        draftController: draft,
        draftFocusNode: focus,
      ),
    );
    expect(
      find.byKey(const Key('notice-final-assistant-bubble')),
      findsOneWidget,
    );

    await pump(
      DemoBusinessPreviewScreen.approvals(
        onBack: () {},
        draftController: draft,
        draftFocusNode: focus,
      ),
    );
    expect(
      find.byKey(const Key('approval-final-assistant-bubble')),
      findsOneWidget,
    );
    final List<Color?> roleColors =
        <String>[
          'workflow-workflow.approval.leave',
          'workflow-workflow.approval.shift',
          'workflow-workflow.approval.receipt',
        ].map((String key) {
          final Container field = tester.widget<Container>(
            find.byKey(Key(key)),
          );
          return (field.decoration! as BoxDecoration).color;
        }).toList();
    expect(roleColors.toSet(), hasLength(3));
    expect(tester.takeException(), isNull);
  });

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

  testWidgets(
    'source-height mobile workflows show completion before composer',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      final draft = TextEditingController();
      final focus = FocusNode();
      addTearDown(draft.dispose);
      addTearDown(focus.dispose);

      Future<void> pump({DemoHomeAction? action, bool approval = false}) async {
        final Widget preview = approval
            ? DemoBusinessPreviewScreen.approvals(
                onBack: () {},
                draftController: draft,
                draftFocusNode: focus,
              )
            : DemoBusinessPreviewScreen(
                action: action!,
                onBack: () {},
                draftController: draft,
                draftFocusNode: focus,
              );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(402, 874),
                padding: EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: preview,
            ),
          ),
        );
        await tester.pump();
      }

      double composerTop() =>
          tester.getTopLeft(find.byType(DemoQuickComposer)).dy;

      await pump(action: DemoHomeAction.employeeAnnouncement);
      expect(
        tester
            .getBottomLeft(
              find.byKey(const Key('notice-final-assistant-bubble')),
            )
            .dy,
        lessThan(composerTop()),
      );
      expect(
        tester.getBottomLeft(find.text('공지 보내기')).dy,
        lessThan(composerTop()),
      );

      await pump(action: DemoHomeAction.storeOverview);
      expect(
        tester.getBottomLeft(find.text('AI 인사이트')).dy,
        lessThan(composerTop()),
      );
      expect(
        tester
            .getBottomLeft(find.byKey(const Key('analytics-follow-up-chips')))
            .dy,
        lessThan(composerTop()),
      );

      await pump(action: DemoHomeAction.weeklySchedule);
      expect(
        tester.getBottomLeft(find.text('근무표 확정')).dy,
        lessThan(composerTop()),
      );

      await pump(approval: true);
      expect(
        tester
            .getBottomLeft(
              find.byKey(const Key('approval-final-assistant-bubble')),
            )
            .dy,
        lessThan(composerTop()),
      );
      expect(
        tester.getBottomLeft(find.text('반복 승인 규칙을 만들까요?')).dy,
        lessThan(composerTop()),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile and landscape keep distinct source composer variants', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = TextEditingController();
    final focus = FocusNode();
    addTearDown(draft.dispose);
    addTearDown(focus.dispose);

    Future<DemoQuickComposer> pump(
      Size size, {
      DemoHomeAction? action,
      bool approval = false,
    }) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: approval
              ? DemoBusinessPreviewScreen.approvals(
                  onBack: () {},
                  draftController: draft,
                  draftFocusNode: focus,
                )
              : DemoBusinessPreviewScreen(
                  action: action!,
                  onBack: () {},
                  draftController: draft,
                  draftFocusNode: focus,
                ),
        ),
      );
      return tester.widget<DemoQuickComposer>(find.byType(DemoQuickComposer));
    }

    expect(
      (await pump(
        const Size(402, 874),
        action: DemoHomeAction.storeOverview,
      )).variant,
      DemoComposerVariant.analysis,
    );
    expect(
      (await pump(const Size(402, 874), approval: true)).variant,
      DemoComposerVariant.approval,
    );
    expect(
      (await pump(
        const Size(1366, 768),
        action: DemoHomeAction.storeOverview,
      )).variant,
      DemoComposerVariant.home,
    );
    expect(
      (await pump(const Size(1366, 768), approval: true)).variant,
      DemoComposerVariant.home,
    );
    expect(find.text('시간대별 상세 매출을 보여줘'), findsNothing);
    await pump(const Size(1366, 768), action: DemoHomeAction.storeOverview);
    expect(find.text('시간대별 상세 매출을 보여줘'), findsOneWidget);
    expect(find.text('인건비를 더 줄일 수 있는 방법이 있을까'), findsOneWidget);
  });

  testWidgets('approval send plane remains inside its source field', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(432, 900);
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

    final Rect field = tester.getRect(
      find.byKey(const Key('demo-composer-input-field')),
    );
    final Rect send = tester.getRect(
      find.byKey(const Key('demo-composer-send')),
    );
    final Rect plus = tester.getRect(find.byTooltip('샘플 추가 자리'));
    expect(field.contains(send.center), isTrue);
    expect(plus.center.dx, lessThan(field.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis outgoing bubble follows mobile and expanded sources', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = TextEditingController();
    final focus = FocusNode();
    addTearDown(draft.dispose);
    addTearDown(focus.dispose);

    Future<Color> pump(Size size) async {
      tester.view.physicalSize = size;
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
      final Container bubble = tester.widget<Container>(
        find.byKey(const Key('workflow-user-bubble-surface')),
      );
      return (bubble.decoration! as BoxDecoration).color!;
    }

    final Color mobile = await pump(const Size(402, 874));
    final Color landscape = await pump(const Size(1366, 768));
    expect(mobile, isNot(landscape));
    expect(tester.takeException(), isNull);
  });
}
