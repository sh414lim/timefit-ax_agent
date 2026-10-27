import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/app.dart';
import 'package:timefit_native/core/database/app_database.dart';
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
    await tester.ensureVisible(find.text('모든 대화'));
    await tester.tap(find.text('모든 대화'));
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
}
