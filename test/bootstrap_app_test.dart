import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/src/app_environment.dart';
import 'package:timefit_native/src/bootstrap_app.dart';

void main() {
  testWidgets('dev bootstrap renders an explicit environment label', (
    WidgetTester tester,
  ) async {
    var disposalComplete = false;
    final Directory? attachmentRoot = await tester.runAsync(
      () => Directory.systemTemp.createTemp('timefit-bootstrap-attachments-'),
    );
    if (attachmentRoot == null) {
      throw StateError('temp_directory_unavailable');
    }
    await tester.pumpWidget(
      TimeFitBootstrapApp(
        environment: AppEnvironment.dev,
        devDatabaseFactory: () async => AppDatabase(NativeDatabase.memory()),
        devAttachmentRootFactory: () async => attachmentRoot,
        devDisposalObserver: (future) {
          future.whenComplete(() => disposalComplete = true);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('개발용 로컬 모드 · 로그인/서버 연결 없음'), findsNothing);
    expect(find.text('데모'), findsWidgets);
    expect(find.text('무엇을 도와드릴까요?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUntil(tester, () => disposalComplete);
    await tester.runAsync(() => attachmentRoot.delete(recursive: true));
  });

  testWidgets('staging bootstrap renders its local chat surface', (
    WidgetTester tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('timefit-staging-bootstrap-'),
    ))!;
    addTearDown(() => root.delete(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    messenger.setMockMethodCallHandler(pathProvider, (_) async => root.path);
    addTearDown(() => messenger.setMockMethodCallHandler(pathProvider, null));

    var disposed = false;
    await tester.pumpWidget(
      TimeFitBootstrapApp(
        environment: AppEnvironment.staging,
        stagingDisposalObserver: (future) {
          future.whenComplete(() => disposed = true);
        },
      ),
    );
    final label = find.text('스테이징 로컬 모드 · 로그인/서버 연결 없음');
    final home = find.text('무엇을 도와드릴까요?');
    await _pumpUntil(tester, () => home.evaluate().isNotEmpty);
    expect(label, findsOneWidget);
    expect(home, findsOneWidget);
    expect(find.textContaining('Mac 서버 연결'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUntil(tester, () => disposed);
  });

  test('production bootstrap fails closed', () {
    expect(
      () => runTimeFitBootstrap(AppEnvironment.production),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'production_configuration_unavailable',
        ),
      ),
    );
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 20 && !condition(); attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}
