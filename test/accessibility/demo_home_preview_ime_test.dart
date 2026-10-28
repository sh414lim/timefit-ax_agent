import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/conversations/application/conversation_list_controller.dart';
import 'package:timefit_native/features/conversations/domain/conversation_repository.dart';
import 'package:timefit_native/features/conversations/domain/conversation_summary.dart';
import 'package:timefit_native/features/home/presentation/business_preview_screen.dart';
import 'package:timefit_native/features/home/presentation/demo_home_action.dart';
import 'package:timefit_native/features/home/presentation/home_screen.dart';

final class _Repository implements ConversationRepository {
  @override
  Future<List<ConversationSummary>> readCachedConversations() async => [];

  @override
  Future<List<ConversationSummary>> refreshConversations() async => [];
}

void _view(WidgetTester tester, Size size, double keyboard) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
  tester.view.padding = FakeViewPadding(top: 24, bottom: keyboard > 0 ? 0 : 16);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

void _expectConnection(
  WidgetTester tester,
  EditableTextState editor,
  TextEditingController draft,
  FocusNode focus,
  TextEditingValue value,
) {
  expect(
    tester.state<EditableTextState>(find.byType(EditableText)),
    same(editor),
  );
  expect(draft.value, value);
  expect(focus.hasFocus, isTrue);
  expect(tester.testTextInput.hasAnyClients, isTrue);
  expect(tester.testTextInput.isVisible, isTrue);
  expect(tester.takeException(), isNull);
}

void _expectNoDisconnect(WidgetTester tester, int logStart) {
  expect(
    tester.testTextInput.log
        .skip(logStart)
        .where(
          (call) => const {
            'TextInput.clearClient',
            'TextInput.setClient',
            'TextInput.hide',
          }.contains(call.method),
        ),
    isEmpty,
    reason: 'Do not replace or hide the live platform editor during navigation',
  );
}

void main() {
  testWidgets('focused Home to preview keeps the live IME connection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    final controller = ConversationListController(repository: _Repository());
    await controller.load();
    final draft = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(draft.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DemoHomeScreen(
          conversationController: controller,
          draftController: draft,
          draftFocusNode: focus,
          onOpenConversation: (_) => fail('No local mutation'),
          onOpenConversationList: () => fail('No local mutation'),
          onOpenArchive: () => fail('No local mutation'),
          onNewConversation: () => fail('No local mutation'),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(TextField));
    const value = TextEditingValue(
      text: '합성 한글 조합 입력',
      selection: TextSelection(baseOffset: 3, extentOffset: 7),
      composing: TextRange(start: 2, end: 8),
    );
    tester.testTextInput.updateEditingValue(value);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    final editor = tester.state<EditableTextState>(find.byType(EditableText));
    final shortcut = find.text('오늘 매장 현황');
    await tester.ensureVisible(shortcut);
    await tester.pumpAndSettle();
    await tester.tap(shortcut.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(DemoBusinessPreviewScreen), findsOneWidget);
    expect(draft.value, value);
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editor),
    );
    expect(tester.takeException(), isNull);
  });

  for (final action in DemoHomeAction.values) {
    for (final fixture in [
      (size: const Size(393, 852), keyboard: 280.0, scale: 1.0, dark: false),
      (size: const Size(320, 640), keyboard: 280.0, scale: 2.0, dark: true),
      (size: const Size(852, 393), keyboard: 216.0, scale: 2.0, dark: true),
      (size: const Size(1024, 900), keyboard: 280.0, scale: 1.0, dark: false),
    ]) {
      testWidgets('${action.name} focused roundtrip $fixture', (tester) async {
        _view(tester, fixture.size, fixture.keyboard);
        addTearDown(tester.view.reset);
        final controller = ConversationListController(
          repository: _Repository(),
        );
        await controller.load();
        final draft = TextEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(draft.dispose);
        addTearDown(focus.dispose);
        var selections = 0;
        Widget app() => MaterialApp(
          theme: fixture.dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(fixture.scale)),
            child: child!,
          ),
          home: DemoHomeScreen(
            conversationController: controller,
            draftController: draft,
            draftFocusNode: focus,
            onPreviewAction: (_) => selections++,
            onOpenConversation: (_) => fail('No local mutation'),
            onOpenConversationList: () => fail('No local mutation'),
            onOpenArchive: () => fail('No local mutation'),
            onNewConversation: () => fail('No local mutation'),
          ),
        );
        await tester.pumpWidget(app());
        await tester.showKeyboard(find.byType(TextField));
        final value = TextEditingValue(
          text: '합성 한글 조합 입력\n' * 12,
          selection: const TextSelection(baseOffset: 3, extentOffset: 7),
          composing: const TextRange(start: 2, end: 8),
        );
        tester.testTextInput.updateEditingValue(value);
        await tester.pumpAndSettle();
        final editor = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        _expectConnection(tester, editor, draft, focus, value);
        final logStart = tester.testTextInput.log.length;
        for (var repeat = 0; repeat < 2; repeat++) {
          final shortcut = find.text(action.label);
          await tester.ensureVisible(shortcut);
          await tester.pumpAndSettle();
          await tester.tap(shortcut.hitTestable());
          await tester.pumpAndSettle();
          expect(find.byType(DemoBusinessPreviewScreen), findsOneWidget);
          _expectConnection(tester, editor, draft, focus, value);
          _view(tester, const Size(390, 844), 280);
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          _expectConnection(tester, editor, draft, focus, value);
          _view(tester, const Size(852, 393), 216);
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          _expectConnection(tester, editor, draft, focus, value);
          final back = find.byTooltip('홈으로 돌아가기');
          await tester.ensureVisible(back);
          await tester.pumpAndSettle();
          await tester.tap(back.hitTestable());
          await tester.pumpAndSettle();
          expect(find.byType(DemoBusinessPreviewScreen), findsNothing);
          _expectConnection(tester, editor, draft, focus, value);
          _view(tester, fixture.size, fixture.keyboard);
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          _expectConnection(tester, editor, draft, focus, value);
        }
        _expectNoDisconnect(tester, logStart);
        expect(selections, 2);
        final edited = TextEditingValue(
          text: '${value.text}\n추가 편집',
          selection: TextSelection.collapsed(offset: value.text.length + 6),
        );
        tester.testTextInput.updateEditingValue(edited);
        await tester.pumpAndSettle();
        _expectConnection(tester, editor, draft, focus, edited);
        expect(
          tester.widget<TextField>(find.byType(TextField)).textInputAction,
          TextInputAction.newline,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(editor.mounted, isFalse);
        expect(tester.testTextInput.hasAnyClients, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${action.name} does not open an unfocused Home editor', (
      tester,
    ) async {
      _view(tester, const Size(393, 852), 0);
      addTearDown(tester.view.reset);
      final controller = ConversationListController(repository: _Repository());
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
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      expect(tester.testTextInput.hasAnyClients, isFalse);
      final shortcut = find.text(action.label);
      await tester.ensureVisible(shortcut);
      await tester.pumpAndSettle();
      await tester.tap(shortcut.hitTestable());
      await tester.pumpAndSettle();
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editor),
      );
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
