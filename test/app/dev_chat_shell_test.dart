import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/app.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/attachments/application/attachment_picker.dart';
import 'package:timefit_native/features/attachments/domain/attachment_policy.dart';
import 'package:timefit_native/features/conversations/presentation/widgets/conversation_list_row.dart';
import 'package:timefit_native/src/app_environment.dart';

const List<int> _pdfFixture = <int>[37, 80, 68, 70, 45, 49, 46, 55];

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
    'full dev chrome keeps long draft actions above landscape keyboard',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      final Directory? createdRoot = await tester.runAsync(
        () => Directory.systemTemp.createTemp('timefit-landscape-keyboard-'),
      );
      if (createdRoot == null) throw StateError('temp_directory_unavailable');
      final Directory attachmentRoot = createdRoot;
      addTearDown(() async {
        if (await attachmentRoot.exists()) {
          await attachmentRoot.delete(recursive: true);
        }
      });

      await tester.pumpWidget(
        TimeFitApp(
          environment: AppEnvironment.dev,
          devDatabaseFactory: () async => database,
          devAttachmentRootFactory: () async => attachmentRoot,
        ),
      );
      await _settleFileIo(tester);
      await _pumpUntilFinder(tester, find.text('새 대화 시작'));
      await tester.tap(find.text('새 대화 시작'));
      await _settleFileIo(tester);
      await _pumpUntilFinder(tester, find.byType(TextField));
      final String draft = List<String>.filled(464, '긴').join();
      await tester.enterText(find.byType(TextField), draft);
      await tester.pump();

      tester.view.physicalSize = const Size(852, 393);
      tester.view.viewInsets = const FakeViewPadding(bottom: 216);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.widget<TextField>(find.byType(TextField)).maxLines, isNull);
      final RenderEditable editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      expect(
        editable.size.height,
        greaterThanOrEqualTo(editable.preferredLineHeight),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        draft,
      );
      final Finder attach = find.byTooltip('첨부 추가');
      final Finder send = find.byTooltip('메시지 보내기');
      expect(attach, findsOneWidget);
      expect(send, findsOneWidget);
      expect(tester.getBottomRight(attach).dy, lessThanOrEqualTo(177));
      expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(177));
      expect(await _runFileIo(tester, database.messageDao.getAll), isEmpty);
      expect(await _runFileIo(tester, database.outboxDao.getAll), isEmpty);

      await tester.tap(find.byType(TextField));
      await tester.showKeyboard(find.byType(TextField));
      expect(
        tester.widget<TextField>(find.byType(TextField)).textInputAction,
        TextInputAction.newline,
      );
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$draft\n',
          selection: TextSelection.collapsed(offset: draft.length + 1),
        ),
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '$draft\n',
      );
      expect(tester.binding.focusManager.primaryFocus, isNotNull);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await _settleFileIo(tester);
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

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
            devAttachmentRootFactory: () =>
                Directory('${sandbox.path}/attachments').create(),
            devDisposalObserver: (future) {
              future.whenComplete(() => disposalComplete = true);
            },
          ),
        );
        await _settleFileIo(tester);
        await _pumpUntilFinder(tester, find.text('새 대화 시작'));

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

        await tester.tap(find.byType(BackButton).last);
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
            devAttachmentRootFactory: () =>
                Directory('${sandbox.path}/attachments').create(),
            devDisposalObserver: (future) {
              future.whenComplete(() => disposalComplete = true);
            },
          ),
        );
        await _settleFileIo(tester);
        await _pumpUntilFinder(tester, find.text('재시작 뒤에도 남는 메시지'));
        expect(find.text('새 대화'), findsNWidgets(2));
        expect(find.text('재시작 뒤에도 남는 메시지'), findsOneWidget);

        await tester.tap(find.byType(ConversationListRow).first);
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

  testWidgets(
    'dev entry renames, confirms soft archive, and restores it after restart',
    (WidgetTester tester) async {
      final sandbox = await tester.runAsync(
        () => Directory.systemTemp.createTemp('timefit-dev-actions-'),
      );
      if (sandbox == null) throw StateError('temp_directory_unavailable');
      final file = File('${sandbox.path}/chat.sqlite');
      final openedDatabases = <AppDatabase>[];
      AppDatabase? openedDatabase;
      var disposalComplete = false;

      Future<AppDatabase> openDatabase() async {
        final database = AppDatabase(NativeDatabase(file));
        openedDatabase = database;
        openedDatabases.add(database);
        return database;
      }

      Future<void> mount() async {
        await tester.pumpWidget(
          TimeFitApp(
            environment: AppEnvironment.dev,
            devDatabaseFactory: openDatabase,
            devAttachmentRootFactory: () =>
                Directory('${sandbox.path}/attachments').create(),
            devDisposalObserver: (future) {
              future.whenComplete(() => disposalComplete = true);
            },
          ),
        );
        await _settleFileIo(tester);
      }

      try {
        await mount();
        await _pumpUntilFinder(tester, find.text('새 대화 시작'));
        await tester.tap(find.text('새 대화 시작'));
        await _settleFileIo(tester);
        await tester.tap(find.byType(BackButton).last);
        await _settleFileIo(tester);

        await tester.tap(find.byTooltip('대화 메뉴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('이름 변경'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '  로컬 이름  ');
        await tester.tap(find.text('저장'));
        await _settleFileIo(tester);
        expect(find.text('로컬 이름'), findsOneWidget);
        expect(
          (await _runFileIo(
            tester,
            () => openedDatabase!.conversationDao.getAll(),
          )).single.title,
          '로컬 이름',
        );

        await tester.tap(find.byTooltip('대화 메뉴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('보관'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '취소'));
        await tester.pumpAndSettle();
        expect(find.text('로컬 이름'), findsOneWidget);

        await tester.tap(find.byTooltip('대화 메뉴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('보관'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '보관'));
        await _settleFileIo(tester);
        expect(find.text('로컬 이름'), findsNothing);
        final archived = (await _runFileIo(
          tester,
          () => openedDatabase!.conversationDao.getAll(),
        )).single;
        expect(archived.status, 'archived');

        await tester.tap(find.text('보관된 대화'));
        await _settleFileIo(tester);
        expect(find.text('로컬 이름'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpUntil(tester, () => disposalComplete);
        disposalComplete = false;
        await mount();
        await _pumpUntilFinder(tester, find.text('보관된 대화'));
        await tester.tap(find.text('보관된 대화'));
        await _settleFileIo(tester);
        expect(find.text('로컬 이름'), findsOneWidget);
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

  testWidgets(
    'dev picker cancellation, private draft restore, removal, and barrier',
    (WidgetTester tester) async {
      final Directory? sandbox = await tester.runAsync(
        () => Directory.systemTemp.createTemp('timefit-dev-picker-'),
      );
      if (sandbox == null) throw StateError('temp_directory_unavailable');
      final File databaseFile = File('${sandbox.path}/chat.sqlite');
      final Directory attachmentRoot = Directory('${sandbox.path}/attachments');
      final List<AppDatabase> openedDatabases = <AppDatabase>[];
      AppDatabase? openedDatabase;
      var disposalComplete = false;
      final _FakeAttachmentPicker picker = _FakeAttachmentPicker(
        <List<AttachmentInput>?>[
          null,
          <AttachmentInput>[_pdfInput()],
          <AttachmentInput>[_pdfInput()],
          <AttachmentInput>[_pdfInput()],
        ],
      );

      Future<AppDatabase> openDatabase() async {
        final AppDatabase database = AppDatabase(NativeDatabase(databaseFile));
        openedDatabase = database;
        openedDatabases.add(database);
        return database;
      }

      Future<void> mount() async {
        await tester.pumpWidget(
          TimeFitApp(
            environment: AppEnvironment.dev,
            devDatabaseFactory: openDatabase,
            devAttachmentRootFactory: () => attachmentRoot.create(),
            devAttachmentPicker: picker,
            devPreviewPdfRenderer: (_, File file, _) =>
                Text('private-preview:${file.uri.pathSegments.last}'),
            devDisposalObserver: (Future<void> future) {
              future.whenComplete(() => disposalComplete = true);
            },
          ),
        );
        await _settleFileIo(tester);
      }

      Future<void> pickFile() async {
        await tester.tap(find.byTooltip('첨부 추가'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('파일 선택'));
        await _settleFileIo(tester);
      }

      try {
        await mount();
        await _pumpUntilFinder(tester, find.text('새 대화 시작'));
        await tester.tap(find.text('새 대화 시작'));
        await _settleFileIo(tester);
        await _pumpUntilFinder(tester, find.byTooltip('첨부 추가'));

        await pickFile();
        expect(
          await _runFileIo(
            tester,
            () =>
                openedDatabase!.select(openedDatabase!.localAttachments).get(),
          ),
          isEmpty,
        );

        await pickFile();
        await _waitForAttachmentCount(tester, openedDatabase!, 1);
        final List<LocalAttachment> selected = await _runFileIo(
          tester,
          () => openedDatabase!.select(openedDatabase!.localAttachments).get(),
        );
        expect(selected, hasLength(1));
        expect(selected.single.uploadState, 'queued');
        expect(selected.single.attachmentId, isNull);
        expect(selected.single.displayName, 'synthetic.pdf');
        expect(find.textContaining('로컬 준비됨 · 서버 업로드 안 됨'), findsOneWidget);
        final File privateCopy = File.fromUri(
          Uri.parse(selected.single.localFileUri!),
        );
        expect(await _runFileIo(tester, privateCopy.exists), isTrue);

        await tester.tap(find.text('application/pdf · 대기 중'));
        await _pumpUntilFinder(tester, find.text('synthetic.pdf'));
        expect(find.text('synthetic.pdf'), findsOneWidget);
        expect(find.text('로컬 파일 미리보기 · 서버 미업로드'), findsOneWidget);
        expect(
          find.text('private-preview:${selected.single.localId}'),
          findsOneWidget,
        );
        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpUntil(tester, () => disposalComplete);
        disposalComplete = false;
        await mount();
        await _pumpUntilFinder(tester, find.byType(ConversationListRow));
        await tester.tap(find.byType(ConversationListRow).first);
        await _settleFileIo(tester);
        await _pumpUntilFinder(tester, find.byTooltip('첨부 추가'));
        expect(
          await _runFileIo(
            tester,
            () =>
                openedDatabase!.select(openedDatabase!.localAttachments).get(),
          ),
          hasLength(1),
        );
        await _pumpUntilFinder(
          tester,
          find.textContaining('로컬 준비됨 · 서버 업로드 안 됨'),
        );
        expect(await _runFileIo(tester, privateCopy.readAsBytes), _pdfFixture);
        await tester.tap(find.text('application/pdf · 대기 중'));
        await _pumpUntilFinder(tester, find.text('synthetic.pdf'));
        expect(find.text('synthetic.pdf'), findsOneWidget);
        expect(
          find.text('private-preview:${selected.single.localId}'),
          findsOneWidget,
        );
        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('로컬 첨부 제거'));
        await _settleFileIo(tester);
        expect(
          await _runFileIo(
            tester,
            () =>
                openedDatabase!.select(openedDatabase!.localAttachments).get(),
          ),
          isEmpty,
        );
        await _waitForFileExistence(tester, privateCopy, false);

        await pickFile();
        await _waitForAttachmentCount(tester, openedDatabase!, 1);
        await tester.enterText(find.byType(TextField), '첨부 로컬 대기');
        await tester.pump();
        await tester.tap(find.byTooltip('메시지 보내기'));
        await _settleFileIo(tester);
        final List<LocalAttachment> queued = await _runFileIo(
          tester,
          () => openedDatabase!.select(openedDatabase!.localAttachments).get(),
        );
        final outbox = await _runFileIo(
          tester,
          () => openedDatabase!.outboxDao.getAll(),
        );
        expect(queued, hasLength(1));
        expect(queued.single.uploadState, 'queued');
        expect(queued.single.attachmentId, isNull);
        expect(outbox, hasLength(1));
        expect(outbox.single.commandType, 'local_send_message_v2');
        expect(outbox.single.state, 'queued');
        final String submittedPayload = outbox.single.payloadJson;

        await pickFile();
        await _settleFileIo(tester);
        expect(
          await _runFileIo(
            tester,
            () =>
                openedDatabase!.select(openedDatabase!.localAttachments).get(),
          ),
          hasLength(1),
        );
        expect(
          (await _runFileIo(
            tester,
            () => openedDatabase!.outboxDao.getAll(),
          )).single.payloadJson,
          submittedPayload,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpUntil(tester, () => disposalComplete);
        await tester.runAsync(() async {
          for (final AppDatabase database in openedDatabases) {
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

  testWidgets('late picker result is discarded after shell disposal', (
    WidgetTester tester,
  ) async {
    final Directory? sandbox = await tester.runAsync(
      () => Directory.systemTemp.createTemp('timefit-dev-picker-dispose-'),
    );
    if (sandbox == null) throw StateError('temp_directory_unavailable');
    final File databaseFile = File('${sandbox.path}/chat.sqlite');
    final Directory attachmentRoot = Directory('${sandbox.path}/attachments');
    final _PendingAttachmentPicker picker = _PendingAttachmentPicker();
    var disposalComplete = false;

    try {
      await tester.pumpWidget(
        TimeFitApp(
          environment: AppEnvironment.dev,
          devDatabaseFactory: () async =>
              AppDatabase(NativeDatabase(databaseFile)),
          devAttachmentRootFactory: () => attachmentRoot.create(),
          devAttachmentPicker: picker,
          devDisposalObserver: (Future<void> future) {
            future.whenComplete(() => disposalComplete = true);
          },
        ),
      );
      await _settleFileIo(tester);
      await _pumpUntilFinder(tester, find.text('새 대화 시작'));
      await tester.tap(find.text('새 대화 시작'));
      await _settleFileIo(tester);
      await _pumpUntilFinder(tester, find.byTooltip('첨부 추가'));
      await tester.tap(find.byTooltip('첨부 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('파일 선택'));
      await tester.pump();
      expect(picker.calls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUntil(tester, () => disposalComplete);
      picker.complete(<AttachmentInput>[_pdfInput()]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      final AppDatabase reopened = AppDatabase(NativeDatabase(databaseFile));
      try {
        expect(
          await _runFileIo(
            tester,
            () => reopened.select(reopened.localAttachments).get(),
          ),
          isEmpty,
        );
      } finally {
        await reopened.close();
      }
      expect(
        await _runFileIo(tester, () => attachmentRoot.list().toList()),
        isEmpty,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        if (await sandbox.exists()) await sandbox.delete(recursive: true);
      });
    }
  });
}

AttachmentInput _pdfInput() => AttachmentInput(
  name: 'synthetic.pdf',
  declaredMime: 'application/pdf',
  openRead: () => Stream<List<int>>.value(_pdfFixture),
);

final class _FakeAttachmentPicker implements AttachmentPicker {
  _FakeAttachmentPicker(this.results);

  final List<List<AttachmentInput>?> results;
  var calls = 0;

  @override
  Future<List<AttachmentInput>?> pick(AttachmentPickerKind kind) async {
    calls += 1;
    return results.removeAt(0);
  }
}

final class _PendingAttachmentPicker implements AttachmentPicker {
  final Completer<List<AttachmentInput>?> _result =
      Completer<List<AttachmentInput>?>();
  var calls = 0;

  void complete(List<AttachmentInput>? value) => _result.complete(value);

  @override
  Future<List<AttachmentInput>?> pick(AttachmentPickerKind kind) {
    calls += 1;
    return _result.future;
  }
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

Future<void> _waitForAttachmentCount(
  WidgetTester tester,
  AppDatabase database,
  int expected,
) async {
  for (var attempt = 0; attempt < 40; attempt += 1) {
    final int count = await _runFileIo(
      tester,
      () async =>
          (await database.select(database.localAttachments).get()).length,
    );
    if (count == expected) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(
    await _runFileIo(
      tester,
      () async =>
          (await database.select(database.localAttachments).get()).length,
    ),
    expected,
  );
}

Future<void> _waitForFileExistence(
  WidgetTester tester,
  File file,
  bool expected,
) async {
  for (var attempt = 0; attempt < 40; attempt += 1) {
    if (await _runFileIo(tester, file.exists) == expected) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(await _runFileIo(tester, file.exists), expected);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
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
