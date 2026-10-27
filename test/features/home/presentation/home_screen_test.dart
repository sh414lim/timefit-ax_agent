import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/conversations/application/conversation_list_controller.dart';
import 'package:timefit_native/features/conversations/domain/conversation_repository.dart';
import 'package:timefit_native/features/conversations/domain/conversation_summary.dart';
import 'package:timefit_native/features/home/presentation/demo_home_action.dart';
import 'package:timefit_native/features/home/presentation/home_screen.dart';

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
        ),
      ),
    );

    await pump();
    await tester.ensureVisible(find.text(DemoHomeAction.costAnalysis.label));
    await tester.tap(find.text(DemoHomeAction.costAnalysis.label));
    await tester.enterText(find.byType(TextField), '메모리에만 남는 요청');
    await pump();

    expect(previews, 1);
    expect(opens, 0);
    expect(newConversations, 0);
    expect(find.textContaining('실제 업무 처리는 없습니다'), findsOneWidget);
    expect(find.text('메모리에만 남는 요청'), findsOneWidget);
    expect(repository.reads, 1);
    expect(repository.refreshes, 1);
  });

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
          expect(tester.getSize(find.byTooltip('샘플 첨부 자리')).width, 48);
          expect(tester.getSize(find.byTooltip('샘플 미리보기')).width, 48);
          expect(find.textContaining('실제 업무 시스템에 전송되지 않습니다'), findsOneWidget);
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
    await tester.tap(find.widgetWithText(ListTile, '최근 대화'));
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
}
