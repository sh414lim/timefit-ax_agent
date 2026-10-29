import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/dev_chat_shell.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/attachments/application/attachment_picker.dart';
import 'package:timefit_native/features/attachments/domain/attachment_policy.dart';
import 'package:timefit_native/features/chat/application/chat_session_coordinator.dart';
import 'package:timefit_native/features/chat/presentation/chat_session_gate.dart';
import 'package:timefit_native/features/conversations/presentation/widgets/conversation_list_row.dart';

void main() {
  testWidgets(
    'actual rename and archive dialogs are revoked without local mutation',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final harness = await tester.runAsync(_DevGateHarness.create);
      if (harness == null) throw StateError('surface_harness_unavailable');
      addTearDown(harness.dispose);
      try {
        await harness.mount(tester);
        await _createConversationAndReturn(tester);

        await _openConversationMenuAction(tester, '이름 변경');
        await tester.pumpAndSettle();
        expect(find.text('대화 이름 변경'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), _sensitiveCanary);
        await tester.pump();
        final oldSaveCenter = tester.getCenter(
          find.widgetWithText(FilledButton, '저장'),
        );
        final oldFocus = tester.binding.focusManager.primaryFocus;
        expect(oldFocus, isNotNull);

        harness.coordinator.state = LocalChatSessionState.cleanupPending;
        await tester.pump();

        expect(find.text('대화 이름 변경'), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text(_sensitiveCanary), findsNothing);
        expect(find.bySemanticsLabel(RegExp(_sensitiveCanary)), findsNothing);
        expect(oldFocus!.hasFocus, isFalse);
        await tester.tapAt(oldSaveCenter);
        await tester.pump();
        await harness.waitForDisposal(tester);
        final afterRename = await harness.readConversation(tester);
        expect(afterRename.title, isNull);
        expect(afterRename.status, 'active');

        harness.coordinator.state = LocalChatSessionState.active;
        await tester.pump();
        await _openConversationListFromHome(tester);
        await _pumpUntilFinder(tester, find.byType(ConversationListRow));
        await _openConversationMenuAction(tester, '보관');
        await tester.pumpAndSettle();
        expect(find.text('대화를 보관할까요?'), findsOneWidget);
        final oldArchiveCenter = tester.getCenter(
          find.widgetWithText(FilledButton, '보관'),
        );

        harness.coordinator.state = LocalChatSessionState.loggingOut;
        await tester.pump();

        expect(find.text('대화를 보관할까요?'), findsNothing);
        await tester.tapAt(oldArchiveCenter);
        await tester.pump();
        await harness.waitForDisposal(tester);
        final afterArchive = await harness.readConversation(tester);
        expect(afterArchive.title, isNull);
        expect(afterArchive.status, 'active');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'actual picker sheet and preview route stay chat-owned',
    (WidgetTester tester) async {
      final picker = _FixtureAttachmentPicker();
      final harness = await tester.runAsync(
        () => _DevGateHarness.create(picker: picker),
      );
      if (harness == null) throw StateError('surface_harness_unavailable');
      addTearDown(harness.dispose);
      await harness.mount(tester);
      await _createConversation(tester);

      await tester.tap(find.byTooltip('첨부 추가'));
      await tester.pumpAndSettle();
      expect(find.text('파일 선택'), findsOneWidget);
      harness.coordinator.state = LocalChatSessionState.loggingOut;
      await tester.tap(find.text('파일 선택'));
      await tester.pump();
      expect(find.text('파일 선택'), findsNothing);
      expect(picker.calls, 0);
      await harness.waitForDisposal(tester);

      harness.coordinator.state = LocalChatSessionState.active;
      await tester.pump();
      await _openConversationListFromHome(tester);
      await _pumpUntilFinder(tester, find.byType(ConversationListRow));
      await tester.tap(find.byType(ConversationListRow).first);
      await _settleFileIo(tester);
      await _pumpUntilFinder(tester, find.byTooltip('첨부 추가'));
      await tester.tap(find.byTooltip('첨부 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('파일 선택'));
      await _settleFileIo(tester);
      await _pumpUntilFinder(tester, find.text('application/pdf · 대기 중'));

      harness.coordinator.state = LocalChatSessionState.cleanupPending;
      await tester.tap(find.text('application/pdf · 대기 중'));
      await tester.pump();
      expect(find.text('fixture-private-preview'), findsNothing);
      expect(find.text('이 기기의 채팅 데이터를 정리하지 못했습니다'), findsOneWidget);
      await harness.waitForDisposal(tester);

      harness.coordinator.state = LocalChatSessionState.active;
      await tester.pump();
      await _openConversationListFromHome(tester);
      await _pumpUntilFinder(tester, find.byType(ConversationListRow));
      await tester.tap(find.byType(ConversationListRow).first);
      await _settleFileIo(tester);
      await _pumpUntilFinder(tester, find.text('application/pdf · 대기 중'));
      await tester.tap(find.text('application/pdf · 대기 중'));
      await _pumpUntilFinder(tester, find.text('synthetic.pdf'));
      expect(find.text('fixture-private-preview'), findsOneWidget);

      harness.coordinator.state = LocalChatSessionState.cleanupPending;
      await tester.pump();
      expect(find.text('synthetic.pdf'), findsNothing);
      expect(find.text('fixture-private-preview'), findsNothing);
      expect(find.text('이 기기의 채팅 데이터를 정리하지 못했습니다'), findsOneWidget);
      await harness.waitForDisposal(tester);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'blocked-before-frame menu action cannot fall back to root dialog',
    (WidgetTester tester) async {
      final harness = await tester.runAsync(_DevGateHarness.create);
      if (harness == null) throw StateError('surface_harness_unavailable');
      addTearDown(harness.dispose);
      await harness.mount(tester);
      await _createConversationAndReturn(tester);

      await tester.tap(find.byTooltip('대화 메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('이름 변경'), findsOneWidget);

      harness.coordinator.state = LocalChatSessionState.cleanupPending;
      await tester.tap(find.text('이름 변경'));
      await tester.pumpAndSettle();

      expect(find.text('대화 이름 변경'), findsNothing);
      expect(find.text('이 기기의 채팅 데이터를 정리하지 못했습니다'), findsOneWidget);
      await harness.waitForDisposal(tester);
      final row = await harness.readConversation(tester);
      expect(row.title, isNull);
      expect(row.status, 'active');
    },
  );

  testWidgets('blocked-before-frame save tap cannot rename local data', (
    WidgetTester tester,
  ) async {
    final harness = await tester.runAsync(_DevGateHarness.create);
    if (harness == null) throw StateError('surface_harness_unavailable');
    addTearDown(harness.dispose);
    await harness.mount(tester);
    await _createConversationAndReturn(tester);
    await tester.tap(find.byTooltip('대화 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'late-sensitive-title');

    harness.coordinator.state = LocalChatSessionState.loggingOut;
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pump();
    await harness.waitForDisposal(tester);

    final row = await harness.readConversation(tester);
    expect(
      row.title,
      isNull,
      reason: 'a blocked session must reject the same-frame dialog result',
    );
    expect(row.status, 'active');
    expect(find.text('late-sensitive-title'), findsNothing);
  });

  testWidgets('blocked-before-frame archive confirmation cannot mutate data', (
    WidgetTester tester,
  ) async {
    final harness = await tester.runAsync(_DevGateHarness.create);
    if (harness == null) throw StateError('surface_harness_unavailable');
    addTearDown(harness.dispose);
    await harness.mount(tester);
    await _createConversationAndReturn(tester);
    await _openConversationMenuAction(tester, '보관');
    await tester.pumpAndSettle();
    expect(find.text('대화를 보관할까요?'), findsOneWidget);

    harness.coordinator.state = LocalChatSessionState.loggingOut;
    await tester.tap(find.widgetWithText(FilledButton, '보관'));
    await tester.pump();
    await harness.waitForDisposal(tester);

    final row = await harness.readConversation(tester);
    expect(row.title, isNull);
    expect(row.status, 'active');
  });

  testWidgets('old dialog generation cannot mutate after active re-entry', (
    WidgetTester tester,
  ) async {
    final harness = await tester.runAsync(_DevGateHarness.create);
    if (harness == null) throw StateError('surface_harness_unavailable');
    addTearDown(harness.dispose);
    await harness.mount(tester);
    await _createConversationAndReturn(tester);
    await _openConversationMenuAction(tester, '이름 변경');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'stale-account-title');

    harness.coordinator.state = LocalChatSessionState.cleanupPending;
    harness.coordinator.state = LocalChatSessionState.active;
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pump();

    expect(find.text('stale-account-title'), findsNothing);
    await harness.waitForDisposal(tester);
    harness.coordinator.state = LocalChatSessionState.cleanupPending;
    await tester.pump();
    await harness.waitForDisposal(tester);

    final row = await harness.readConversation(tester);
    expect(row.title, isNull);
    expect(row.status, 'active');
  });

  testWidgets('late picker completion cannot write an attachment or file', (
    WidgetTester tester,
  ) async {
    final picker = _BlockingAttachmentPicker();
    final harness = await tester.runAsync(
      () => _DevGateHarness.create(picker: picker),
    );
    if (harness == null) throw StateError('surface_harness_unavailable');
    addTearDown(harness.dispose);
    await harness.mount(tester);
    await _createConversation(tester);
    await tester.tap(find.byTooltip('첨부 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('파일 선택'));
    await tester.pump();
    expect(picker.calls, 1);

    harness.coordinator.state = LocalChatSessionState.cleanupPending;
    await tester.pump();
    await harness.waitForDisposal(tester);
    picker.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(await harness.readAttachmentCount(tester), 0);
    final files = harness.attachmentRoot.existsSync()
        ? harness.attachmentRoot
              .listSync(recursive: true)
              .whereType<File>()
              .toList()
        : <File>[];
    expect(files, isEmpty);
    expect(find.textContaining('late-secret.pdf'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'blocked-before-frame remove tap cannot delete attachment data',
    (WidgetTester tester) async {
      final harness = await tester.runAsync(
        () => _DevGateHarness.create(picker: _FixtureAttachmentPicker()),
      );
      if (harness == null) throw StateError('surface_harness_unavailable');
      addTearDown(harness.dispose);
      await harness.mount(tester);
      await _createConversation(tester);
      await tester.tap(find.byTooltip('첨부 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('파일 선택'));
      await _settleFileIo(tester);
      await _pumpUntilFinder(tester, find.byTooltip('로컬 첨부 제거'));

      expect(await harness.readAttachmentCount(tester), 1);
      expect(harness.privateAttachmentFiles, hasLength(1));
      final Offset oldRemoveCenter = tester.getCenter(
        find.byTooltip('로컬 첨부 제거'),
      );

      harness.coordinator.state = LocalChatSessionState.cleanupPending;
      await tester.tapAt(oldRemoveCenter);
      await tester.pump();
      await harness.waitForDisposal(tester);

      expect(
        await harness.readAttachmentCount(tester),
        1,
        reason: 'a blocked old coordinate must not delete the local row',
      );
      expect(
        harness.privateAttachmentFiles,
        hasLength(1),
        reason: 'a blocked old coordinate must not delete the private copy',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'blocked-before-frame send cannot create message or outbox rows',
    (WidgetTester tester) async {
      final harness = await tester.runAsync(_DevGateHarness.create);
      if (harness == null) throw StateError('surface_harness_unavailable');
      addTearDown(harness.dispose);
      await harness.mount(tester);
      await _createConversation(tester);
      await tester.enterText(find.byType(TextField), 'same-frame blocked body');
      await tester.pump();
      final Offset oldSendCenter = tester.getCenter(find.byTooltip('메시지 저장'));

      harness.coordinator.state = LocalChatSessionState.loggingOut;
      await tester.tapAt(oldSendCenter);
      await tester.pump();
      await harness.waitForDisposal(tester);

      expect(await harness.readMessageCount(tester), 0);
      expect(await harness.readOutboxCount(tester), 0);
    },
  );

  testWidgets('blocked-before-frame new conversation cannot create a row', (
    WidgetTester tester,
  ) async {
    final harness = await tester.runAsync(_DevGateHarness.create);
    if (harness == null) throw StateError('surface_harness_unavailable');
    addTearDown(harness.dispose);
    await harness.mount(tester);
    final Offset oldCreateCenter = tester.getCenter(find.text('새 대화 시작'));

    harness.coordinator.state = LocalChatSessionState.cleanupPending;
    await tester.tapAt(oldCreateCenter);
    await tester.pump();
    await harness.waitForDisposal(tester);

    expect(await harness.readConversationCount(tester), 0);
  });
}

const _sensitiveCanary = 'private-payroll-dialog-canary';
const _pdfFixture = <int>[37, 80, 68, 70, 45, 49, 46, 55];

final class _DevGateHarness {
  _DevGateHarness._({required this.sandbox, required this.picker});

  final Directory sandbox;
  final AttachmentPicker picker;
  final coordinator = _FakeGateCoordinator(LocalChatSessionState.active);
  final List<Future<void>> _disposals = <Future<void>>[];
  var _consumedDisposals = 0;
  bool _mounted = false;

  File get databaseFile => File('${sandbox.path}/chat.sqlite');
  Directory get attachmentRoot => Directory('${sandbox.path}/attachments');
  List<File> get privateAttachmentFiles => attachmentRoot.existsSync()
      ? attachmentRoot.listSync(recursive: true).whereType<File>().toList()
      : <File>[];

  static Future<_DevGateHarness> create({AttachmentPicker? picker}) async {
    final sandbox = await Directory.systemTemp.createTemp(
      'timefit-chat047-surface-',
    );
    return _DevGateHarness._(
      sandbox: sandbox,
      picker: picker ?? _FixtureAttachmentPicker(),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    _mounted = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Scaffold(
          body: ChatSessionGate(
            coordinator: coordinator,
            child: DevChatShell(
              databaseFactory: () async =>
                  AppDatabase(NativeDatabase(databaseFile)),
              attachmentRootFactory: () => attachmentRoot.create(),
              attachmentPicker: picker,
              previewPdfRenderer: (_, __, ___) =>
                  const Text('fixture-private-preview'),
              disposalObserver: _disposals.add,
            ),
          ),
        ),
      ),
    );
    await _settleFileIo(tester);
    await _openConversationListFromHome(tester);
    await _pumpUntilFinder(tester, find.text('새 대화 시작'));
  }

  Future<void> waitForDisposal(WidgetTester tester) async {
    await _pumpUntil(tester, () => _disposals.length > _consumedDisposals);
    final disposal = _disposals[_consumedDisposals];
    _consumedDisposals += 1;
    Object? failure;
    var completed = false;
    unawaited(
      disposal.then<void>(
        (_) => completed = true,
        onError: (Object error, StackTrace _) {
          failure = error;
          completed = true;
        },
      ),
    );
    await _pumpUntil(tester, () => completed);
    if (failure != null) throw failure!;
  }

  Future<LocalConversation> readConversation(WidgetTester tester) async {
    final conversation = await tester.runAsync(() async {
      final database = AppDatabase(NativeDatabase(databaseFile));
      try {
        return (await database.conversationDao.getAll()).single;
      } finally {
        await database.close();
      }
    });
    return conversation!;
  }

  Future<int> readConversationCount(WidgetTester tester) async {
    final count = await tester.runAsync(() async {
      final database = AppDatabase(NativeDatabase(databaseFile));
      try {
        return (await database.conversationDao.getAll()).length;
      } finally {
        await database.close();
      }
    });
    return count!;
  }

  Future<int> readAttachmentCount(WidgetTester tester) async {
    final count = await tester.runAsync(() async {
      final database = AppDatabase(NativeDatabase(databaseFile));
      try {
        return (await database.select(database.localAttachments).get()).length;
      } finally {
        await database.close();
      }
    });
    return count!;
  }

  Future<int> readMessageCount(WidgetTester tester) async {
    final count = await tester.runAsync(() async {
      final database = AppDatabase(NativeDatabase(databaseFile));
      try {
        return (await database.messageDao.getAll()).length;
      } finally {
        await database.close();
      }
    });
    return count!;
  }

  Future<int> readOutboxCount(WidgetTester tester) async {
    final count = await tester.runAsync(() async {
      final database = AppDatabase(NativeDatabase(databaseFile));
      try {
        return (await database.outboxDao.getAll()).length;
      } finally {
        await database.close();
      }
    });
    return count!;
  }

  Future<void> dispose() async {
    coordinator.dispose();
    if (_mounted && _disposals.length > _consumedDisposals) {
      for (final disposal in _disposals.skip(_consumedDisposals)) {
        await disposal;
      }
    }
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  }
}

final class _FakeGateCoordinator extends ChangeNotifier
    implements ChatSessionGateCoordinator {
  _FakeGateCoordinator(this._state);

  LocalChatSessionState _state;

  @override
  LocalChatSessionState get state => _state;

  set state(LocalChatSessionState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  @override
  Future<void> retryCleanup() async {}
}

final class _FixtureAttachmentPicker implements AttachmentPicker {
  var calls = 0;

  @override
  Future<List<AttachmentInput>?> pick(AttachmentPickerKind kind) async {
    calls += 1;
    return <AttachmentInput>[
      AttachmentInput(
        name: 'synthetic.pdf',
        declaredMime: 'application/pdf',
        openRead: () => Stream<List<int>>.value(_pdfFixture),
      ),
    ];
  }
}

final class _BlockingAttachmentPicker implements AttachmentPicker {
  final completer = Completer<List<AttachmentInput>?>();
  var calls = 0;

  @override
  Future<List<AttachmentInput>?> pick(AttachmentPickerKind kind) {
    calls += 1;
    return completer.future;
  }

  void complete() {
    completer.complete(<AttachmentInput>[
      AttachmentInput(
        name: 'late-secret.pdf',
        declaredMime: 'application/pdf',
        openRead: () => Stream<List<int>>.value(_pdfFixture),
      ),
    ]);
  }
}

Future<void> _createConversationAndReturn(WidgetTester tester) async {
  await _createConversation(tester);
  await tester.tap(find.byType(BackButton).last);
  await _settleFileIo(tester);
  await _pumpUntilFinder(tester, find.byType(ConversationListRow));
}

Future<void> _createConversation(WidgetTester tester) async {
  final create = find.text('새 대화 시작');
  await tester.ensureVisible(create);
  await tester.pump();
  await tester.tap(create);
  await _settleFileIo(tester);
  await _pumpUntilFinder(tester, find.byTooltip('첨부 추가'));
}

Future<void> _openConversationMenuAction(
  WidgetTester tester,
  String action,
) async {
  await tester.tap(find.byTooltip('대화 메뉴'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
}

Future<void> _settleFileIo(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
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
    attempt < 30 && finder.evaluate().isEmpty;
    attempt += 1
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(finder, findsOneWidget);
}

Future<void> _openConversationListFromHome(WidgetTester tester) async {
  final menu = find.byTooltip('메뉴 샘플');
  await _pumpUntilFinder(tester, menu);
  await tester.tap(menu);
  await _settleFileIo(tester);
}
