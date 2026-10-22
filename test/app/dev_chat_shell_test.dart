import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/app.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/src/app_environment.dart';

void main() {
  testWidgets('staging keeps placeholder and never opens the dev database', (
    WidgetTester tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      TimeFitApp(
        environment: AppEnvironment.staging,
        devDatabaseFactory: () async {
          opens += 1;
          throw StateError('must_not_open_dev_database');
        },
      ),
    );
    await tester.pump();

    expect(find.text('TimeFit Staging'), findsOneWidget);
    expect(find.text('개발용 로컬 모드 · 로그인/서버 연결 없음'), findsNothing);
    expect(opens, 0);
  });

  testWidgets(
    'dev entry creates on tap, fences double tap, and persists queued message',
    (WidgetTester tester) async {
      final sandbox = await tester.runAsync(
        () => Directory.systemTemp.createTemp('timefit-dev-shell-'),
      );
      if (sandbox == null) throw StateError('temp_directory_unavailable');
      final file = File('${sandbox.path}/chat.sqlite');
      AppDatabase? openedDatabase;
      final openedDatabases = <AppDatabase>[];
      var disposalComplete = false;

      Future<AppDatabase> openDatabase() async {
        final database = AppDatabase(NativeDatabase(file));
        openedDatabase = database;
        openedDatabases.add(database);
        return database;
      }

      try {
        await tester.pumpWidget(
          TimeFitApp(
            environment: AppEnvironment.dev,
            devDatabaseFactory: openDatabase,
            devDisposalObserver: (future) {
              future.whenComplete(() => disposalComplete = true);
            },
          ),
        );
        await _settleFileIo(tester);

        expect(find.text('개발용 로컬 모드 · 로그인/서버 연결 없음'), findsOneWidget);
        expect(
          await _runFileIo(
            tester,
            () => openedDatabase!.conversationDao.getAll(),
          ),
          isEmpty,
        );

        final create = find.text('새 대화 시작');
        await tester.tap(create);
        await tester.tap(create);
        await _settleFileIo(tester);

        final conversations = await _runFileIo(
          tester,
          () => openedDatabase!.conversationDao.getAll(),
        );
        expect(conversations, hasLength(1));
        expect(find.text('서버 미연결 · 이 기기에 대기 중'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '재시작 뒤에도 남는 메시지');
        await tester.pump();
        await tester.tap(find.byTooltip('메시지 보내기'));
        await _settleFileIo(tester);

        final messages = await _runFileIo(
          tester,
          () => openedDatabase!.messageDao.getAll(),
        );
        final outbox = await _runFileIo(
          tester,
          () => openedDatabase!.outboxDao.getAll(),
        );
        expect(messages, hasLength(1));
        expect(messages.single.deliveryState, 'pending');
        expect(messages.single.serverId, isNull);
        expect(messages.single.sequence, isNull);
        expect(outbox, hasLength(1));
        expect(outbox.single.state, 'queued');
        expect(find.text('전송 대기 중'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await _settleFileIo(tester);
        await _pumpUntilFinder(tester, find.text('재시작 뒤에도 남는 메시지'));
        expect(find.text('새 대화'), findsNWidgets(2));
        expect(find.text('재시작 뒤에도 남는 메시지'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpUntil(tester, () => disposalComplete);
        disposalComplete = false;

        await tester.pumpWidget(
          TimeFitApp(
            environment: AppEnvironment.dev,
            devDatabaseFactory: openDatabase,
            devDisposalObserver: (future) {
              future.whenComplete(() => disposalComplete = true);
            },
          ),
        );
        await _settleFileIo(tester);
        await _pumpUntilFinder(tester, find.text('재시작 뒤에도 남는 메시지'));
        expect(find.text('새 대화'), findsNWidgets(2));
        expect(find.text('재시작 뒤에도 남는 메시지'), findsOneWidget);

        await tester.tap(find.text('새 대화').first);
        await _settleFileIo(tester);
        expect(find.text('재시작 뒤에도 남는 메시지'), findsOneWidget);
        expect(find.text('전송 대기 중'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpUntil(tester, () => disposalComplete);
        await tester.runAsync(() async {
          for (final database in openedDatabases) {
            try {
              await database.close();
            } on Object {
              // The shell normally closed it first.
            }
          }
          await sandbox.delete(recursive: true);
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _settleFileIo(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

Future<T> _runFileIo<T>(
  WidgetTester tester,
  Future<T> Function() operation,
) async {
  final result = await tester.runAsync(operation);
  return result as T;
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

Future<void> _pumpUntilFinder(WidgetTester tester, Finder finder) async {
  for (
    var attempt = 0;
    attempt < 20 && finder.evaluate().isEmpty;
    attempt += 1
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}
