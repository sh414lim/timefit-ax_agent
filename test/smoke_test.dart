import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/src/app_environment.dart';
import 'package:timefit_native/src/bootstrap_app.dart';

void main() {
  testWidgets('unsigned dev bootstrap renders the local chat shell', (
    WidgetTester tester,
  ) async {
    var disposalComplete = false;
    final Directory? attachmentRoot = await tester.runAsync(
      () => Directory.systemTemp.createTemp('timefit-smoke-attachments-'),
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
    expect(find.text('아직 대화가 없습니다'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    for (var attempt = 0; attempt < 20 && !disposalComplete; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(disposalComplete, isTrue);
    await tester.runAsync(() => attachmentRoot.delete(recursive: true));
  });
}
