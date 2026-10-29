import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/app.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/home/presentation/demo_home_action.dart';
import 'package:timefit_native/features/home/presentation/home_screen.dart';
import 'package:timefit_native/src/app_environment.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 30; index += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 2));
  }
}

Future<(AppDatabase, bool Function())> _mount(WidgetTester tester) async {
  final database = AppDatabase(NativeDatabase.memory());
  var disposed = false;
  await tester.pumpWidget(
    TimeFitApp(
      environment: AppEnvironment.dev,
      devDatabaseFactory: () async => database,
      devAttachmentRootFactory: () async => Directory.systemTemp,
      devDisposalObserver: (future) {
        future.whenComplete(() => disposed = true);
      },
    ),
  );
  await _settle(tester);
  return (database, () => disposed);
}

Future<void> _unmount(WidgetTester tester, bool Function() disposed) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var index = 0; index < 30 && !disposed(); index += 1) {
    await _settle(tester);
  }
  expect(disposed(), isTrue);
}

void main() {
  testWidgets('preview hit target cannot create a local conversation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.reset);
    final (database, disposed) = await _mount(tester);
    final preview = find.byTooltip('샘플 미리보기');

    expect(preview.hitTestable(), findsOneWidget);
    await tester.tap(preview);
    await _settle(tester);
    expect(await tester.runAsync(database.conversationDao.getAll), isEmpty);
    await _unmount(tester, disposed);
  });

  testWidgets('home draft survives all-conversations roundtrip', (
    tester,
  ) async {
    final (_, disposed) = await _mount(tester);
    await tester.enterText(find.byType(TextField), 'HOME MEMORY QA');
    await tester.tap(find.byTooltip('메뉴 샘플'));
    await _settle(tester);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    expect(find.byType(DemoHomeScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'HOME MEMORY QA',
    );
    await _unmount(tester, disposed);
  });

  for (final size in <Size>[const Size(320, 640), const Size(852, 393)]) {
    testWidgets('${size.width} keyboard and text 200 percent do not overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.width == 320 ? 280 : 216,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (_, disposed) = await _mount(tester);

      await tester.pump();
      await tester.enterText(find.byType(TextField), 'long home draft ' * 30);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _unmount(tester, disposed);
    });
  }

  for (final width in <double>[320, 390, 430]) {
    for (final height in <double>[719, 720, 721]) {
      testWidgets(
        '$width x $height keyboard transition uses available constraints',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, height);
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final (_, disposed) = await _mount(tester);

          await tester.showKeyboard(find.byType(TextField));
          await tester.enterText(find.byType(TextField), '높이 경계 초안 ' * 20);
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.byTooltip('샘플 첨부 자리'), findsOneWidget);
          expect(find.byTooltip('샘플 미리보기'), findsOneWidget);
          await _unmount(tester, disposed);
        },
      );
    }
  }

  for (final size in <Size>[
    const Size(320, 640),
    const Size(320, 720),
    const Size(852, 393),
  ]) {
    testWidgets('$size keeps Home action and composer scroll-reachable', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.width == 852 ? 216 : 280,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (_, disposed) = await _mount(tester);
      final field = find.byType(TextField);

      await tester.showKeyboard(field);
      const value = TextEditingValue(
        text: '접근 가능한 긴 Home 초안',
        selection: TextSelection(baseOffset: 3, extentOffset: 8),
      );
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
      final action = find.text(DemoHomeAction.costAnalysis.label);
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      expect(tester.widget<TextField>(field).controller!.value, value);
      await _unmount(tester, disposed);
    });
  }
}
