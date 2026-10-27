import 'dart:io';

import 'package:drift/native.dart';
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

    expect(find.text('개발용 로컬 모드 · 로그인/서버 연결 없음'), findsOneWidget);
    expect(find.text('무엇을 도와드릴까요?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUntil(tester, () => disposalComplete);
    await tester.runAsync(() => attachmentRoot.delete(recursive: true));
  });

  testWidgets('staging bootstrap renders an explicit environment label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TimeFitBootstrapApp(environment: AppEnvironment.staging),
    );
    await tester.pumpAndSettle();

    expect(find.text('TimeFit Staging'), findsOneWidget);
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
