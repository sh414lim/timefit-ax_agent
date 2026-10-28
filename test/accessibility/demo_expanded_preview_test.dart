import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/home/presentation/business_preview_screen.dart';
import 'package:timefit_native/features/home/presentation/demo_home_action.dart';
import 'package:timefit_native/features/home/presentation/widgets/demo_quick_composer.dart';

const _font = 'ExpandedPreviewKoreanControl';

void _view(WidgetTester tester, Size size, double keyboard) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
  tester.view.padding = FakeViewPadding(top: 24, bottom: keyboard > 0 ? 0 : 16);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

ThemeData _theme(bool korean, bool dark) {
  final base = dark ? AppTheme.dark() : AppTheme.light();
  return korean
      ? base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: _font),
          primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _font),
        )
      : base;
}

Widget _app({
  required DemoHomeAction action,
  required TextEditingController draft,
  required FocusNode focus,
  double scale = 2,
  bool korean = true,
  bool dark = true,
  VoidCallback? onBack,
}) => MaterialApp(
  theme: _theme(korean, dark),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: DemoBusinessPreviewScreen(
      action: action,
      onBack: onBack ?? () {},
      draftController: draft,
      draftFocusNode: focus,
    ),
  ),
);

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  final rect = tester.getRect(target);
  expect(rect.width, greaterThanOrEqualTo(44));
  expect(rect.height, greaterThanOrEqualTo(44));
  final visible = Rect.fromLTRB(
    0,
    tester.view.padding.top,
    tester.view.physicalSize.width,
    tester.view.physicalSize.height -
        tester.view.viewInsets.bottom -
        tester.view.padding.bottom,
  );
  expect(rect.intersect(visible), rect);
  await tester.tap(target);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    final bytes = File(
      'test/fixtures/fonts/nanum_gothic/NanumGothic-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      _font,
    )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
  });

  for (final korean in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('900x600 schedule scale$scale Korean=$korean', (
        tester,
      ) async {
        _view(tester, const Size(900, 600), 0);
        addTearDown(tester.view.reset);
        final draft = TextEditingController(text: '가독성 비교 입력\n' * 12);
        final focus = FocusNode();
        addTearDown(draft.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          _app(
            action: DemoHomeAction.weeklySchedule,
            draft: draft,
            focus: focus,
            scale: scale,
            korean: korean,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final action in DemoHomeAction.values) {
    for (final fixture in [
      (size: const Size(900, 600), scale: 1.0, keyboard: 0.0, dark: false),
      (size: const Size(900, 600), scale: 2.0, keyboard: 0.0, dark: true),
      (size: const Size(900, 600), scale: 2.0, keyboard: 280.0, dark: false),
      (size: const Size(1024, 768), scale: 1.0, keyboard: 0.0, dark: true),
      (size: const Size(1024, 768), scale: 2.0, keyboard: 0.0, dark: false),
      (size: const Size(1366, 768), scale: 1.0, keyboard: 0.0, dark: false),
      (size: const Size(1366, 768), scale: 2.0, keyboard: 0.0, dark: true),
    ]) {
      testWidgets('${action.name} expanded controls and content $fixture', (
        tester,
      ) async {
        _view(tester, fixture.size, fixture.keyboard);
        addTearDown(tester.view.reset);
        final value = '가독성 비교 입력\n' * 12;
        final draft = TextEditingController(text: value);
        final focus = FocusNode();
        addTearDown(draft.dispose);
        addTearDown(focus.dispose);
        var backs = 0;
        await tester.pumpWidget(
          _app(
            action: action,
            draft: draft,
            focus: focus,
            scale: fixture.scale,
            dark: fixture.dark,
            onBack: () => backs++,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byType(TextField)),
          ).scale(16),
          16 * fixture.scale,
        );
        final editable = tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        expect(
          editable.size.height,
          greaterThanOrEqualTo(editable.preferredLineHeight - 0.01),
        );
        expect(editable.maxScrollExtent, greaterThan(0));
        await _tap(tester, find.byKey(const Key('demo-composer-send')));
        await _tap(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                const ['샘플 첨부 자리', '샘플 추가 자리'].contains(widget.tooltip),
          ),
        );
        expect(draft.text, value);
        await _tap(tester, find.widgetWithText(OutlinedButton, '홈'));
        expect(backs, 1);

        if (action == DemoHomeAction.weeklySchedule) {
          for (final label in ['근무표 확정', '수정하기']) {
            final finder = find.text(label);
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            // The result pane is deliberately IgnorePointer/display-only.
            // Verify visual reachability, not a nonexistent business action.
            expect(finder, findsOneWidget);
            final rect = tester.getRect(finder);
            expect(rect.top, greaterThanOrEqualTo(tester.view.padding.top));
            expect(
              rect.bottom,
              lessThanOrEqualTo(
                tester.view.physicalSize.height -
                    tester.view.viewInsets.bottom -
                    tester.view.padding.bottom,
              ),
            );
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(paragraph.didExceedMaxLines, isFalse);
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length),
            );
            expect(boxes, isNotEmpty);
            expect(
              boxes.last.bottom,
              lessThanOrEqualTo(paragraph.size.height + .1),
            );
          }
          final actions = tester
              .widgetList<Semantics>(find.byType(Semantics))
              .where(
                (node) =>
                    node.properties.label?.contains('미리보기, 실제 작업은 실행하지 않음') ??
                    false,
              );
          expect(actions, isNotEmpty);
          for (final node in actions) {
            expect(node.properties.button, isTrue);
            expect(node.properties.enabled, isFalse);
            expect(node.properties.onTap, isNull);
          }
        }
        final composer = tester.widget<DemoQuickComposer>(
          find.byType(DemoQuickComposer),
        );
        expect(composer.controller, same(draft));
        expect(composer.focusNode, same(focus));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
