import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/drift_attachment_composer_source.dart';
import 'package:timefit_native/features/chat/application/outbox/command_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';

const String _conversationId = 'chat-074-conversation';

void registerLocalChatFaultScenarios() {
  testWidgets(
    'offline UI writes survive reopen and unknown commit converges once',
    (WidgetTester tester) async {
      var now = DateTime.utc(2026, 10, 22, 12);
      // Deliberately reverse lexical ID order and keep one clock value. The
      // durable queue must follow insertion order, not UUID/text ordering.
      const ids = <String>['offline-3', 'offline-2', 'offline-1'];
      var idIndex = 0;
      var composerDisposed = false;
      late Directory sandbox;
      late File databaseFile;
      late AppDatabase database;
      late MessageRepositoryImpl repository;
      late ComposerController composer;
      await tester.runAsync(() async {
        sandbox = await Directory.systemTemp.createTemp(
          'timefit-chat-074-offline-',
        );
        databaseFile = File('${sandbox.path}/chat.sqlite');
        database = AppDatabase(NativeDatabase(databaseFile));
        repository = MessageRepositoryImpl(database: database);
        composer = ComposerController(
          conversationId: _conversationId,
          submitter: SendMessage(
            database: database,
            clock: () => now,
            clientMessageId: () => ids[idIndex++],
          ),
        );
      });
      try {
        await _pumpChat(tester, repository, composer);
        for (var index = 0; index < ids.length; index += 1) {
          await tester.enterText(
            find.byType(TextField),
            'offline message ${index + 1}',
          );
          await tester.pump();
          await tester.tap(find.byTooltip('메시지 보내기'));
          await tester.pump();
          await tester.runAsync(() => _waitForComposer(composer));
          await _settleAsyncUi(tester);
        }
        expect(find.text('offline message 1'), findsOneWidget);
        expect(find.text('offline message 3'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await _settleAsyncUi(tester);
        composer.dispose();
        composerDisposed = true;
        await tester.runAsync(() async {
          await repository.dispose();
          await database.close();

          database = AppDatabase(NativeDatabase(databaseFile));
          repository = MessageRepositoryImpl(database: database);
          final persisted = await repository.readCachedMessages(
            _conversationId,
          );
          expect(
            persisted.map((message) => message.clientMessageId),
            orderedEquals(ids),
          );
          expect(
            persisted.map((message) => message.body),
            orderedEquals(const <String>[
              'offline message 1',
              'offline message 2',
              'offline message 3',
            ]),
          );

          final ledger = ScriptedRemoteLedger(
            unknownCommitOnce: const <String>{'offline-2'},
          );
          final firstExecutor = ScriptedFaultExecutor(
            database: database,
            ledger: ledger,
          );
          await _worker(
            database,
            firstExecutor,
            () => now,
            scope: '${sandbox.path}:first-open',
          ).wake();

          final afterUnknown = await database.outboxDao.getAll();
          expect(
            afterUnknown.singleWhere((row) => row.id == 'offline-2').state,
            'retry_wait',
          );
          expect(ledger.remoteCommitOrder, orderedEquals(ids));
          expect(ledger.commitCountById, <String, int>{
            'offline-1': 1,
            'offline-2': 1,
            'offline-3': 1,
          });

          final retryDeadline = afterUnknown
              .singleWhere((row) => row.id == 'offline-2')
              .nextAttemptAt;
          now = retryDeadline.subtract(const Duration(microseconds: 1));
          final earlyRetryExecutor = ScriptedFaultExecutor(
            database: database,
            ledger: ledger,
          );
          await _worker(
            database,
            earlyRetryExecutor,
            () => now,
            scope: '${sandbox.path}:before-retry-deadline',
          ).wake();
          expect(earlyRetryExecutor.calls, isEmpty);

          now = retryDeadline;
          final retryExecutor = ScriptedFaultExecutor(
            database: database,
            ledger: ledger,
          );
          await _worker(
            database,
            retryExecutor,
            () => now,
            scope: '${sandbox.path}:reconstructed-worker',
          ).wake();

          final convergedCommands = await database.outboxDao.getAll();
          expect(
            convergedCommands.map((row) => row.state),
            everyElement('completed'),
          );
          expect(
            <String>[
              ...firstExecutor.calls.map((call) => call.clientRequestId),
              ...retryExecutor.calls.map((call) => call.clientRequestId),
            ],
            orderedEquals(const <String>[
              'offline-3',
              'offline-2',
              'offline-1',
              'offline-2',
            ]),
          );
          expect(ledger.remoteCommitOrder, orderedEquals(ids));
          expect(ledger.commitCountById.values, everyElement(1));
          expect(
            (await database.messageDao.getAll()).map(
              (message) => message.deliveryState,
            ),
            everyElement('sent'),
          );
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        if (!composerDisposed) composer.dispose();
        await tester.runAsync(() async {
          await repository.dispose();
          await database.close();
          await sandbox.delete(recursive: true);
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('upload at sixty percent survives worker interruption', () async {
    final Directory sandbox = await Directory.systemTemp.createTemp(
      'timefit-chat-074-upload-',
    );
    final File databaseFile = File('${sandbox.path}/chat.sqlite');
    var now = DateTime.utc(2026, 10, 22, 13);
    var database = AppDatabase(NativeDatabase(databaseFile));
    try {
      await database
          .into(database.localAttachments)
          .insert(
            LocalAttachmentsCompanion.insert(
              localId: 'upload-attachment',
              conversationId: _conversationId,
              clientMessageId: 'upload-message',
              uploadState: const Value('uploading'),
              bytesTotal: const Value(100),
              bytesSent: const Value(60),
              contentType: 'application/pdf',
              sha256: 'fixture-upload-sha',
            ),
          );
      await database
          .into(database.outboxCommands)
          .insert(
            OutboxCommandsCompanion.insert(
              id: 'upload-command',
              commandType: 'local_upload_attachment_v1',
              aggregateId: 'upload-attachment',
              clientRequestId: 'upload-message',
              payloadJson: '{"localVersion":1}',
              nextAttemptAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final started = Completer<void>();
      final release = Completer<void>();
      final interruptedExecutor = ScriptedFaultExecutor(
        database: database,
        ledger: ScriptedRemoteLedger(),
        blockedCommandId: 'upload-command',
        blockedStarted: started,
        blockedRelease: release,
      );
      final firstWorker = _worker(
        database,
        interruptedExecutor,
        () => now,
        scope: '${sandbox.path}:upload-first',
      );
      final activeWake = firstWorker.wake();
      await started.future;
      firstWorker.stop();
      release.complete();
      await activeWake;
      expect((await database.outboxDao.getAll()).single.state, 'running');

      await database.close();
      database = AppDatabase(NativeDatabase(databaseFile));
      final restored = await database
          .select(database.localAttachments)
          .getSingle();
      expect(restored.uploadState, 'uploading');
      expect(restored.bytesSent, 60);
      expect(restored.bytesTotal, 100);
      expect((await database.outboxDao.getAll()).single.state, 'running');

      now = now.add(const Duration(seconds: 61));
      final recoveryExecutor = ScriptedFaultExecutor(
        database: database,
        ledger: ScriptedRemoteLedger(),
      );
      await _worker(
        database,
        recoveryExecutor,
        () => now,
        scope: '${sandbox.path}:upload-reconstructed',
      ).wake();
      final recovered = await database
          .select(database.localAttachments)
          .getSingle();
      expect(recovered.uploadState, 'ready');
      expect(recovered.bytesSent, 100);
      expect((await database.outboxDao.getAll()).single.state, 'completed');
    } finally {
      await database.close();
      await sandbox.delete(recursive: true);
    }
  });

  testWidgets('one failed file prevents message and send command creation', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = MessageRepositoryImpl(database: database);
    final now = DateTime.utc(2026, 10, 22, 14);
    const aggregateId = 'partial-attachment-message';
    await database.batch((batch) {
      batch.insertAll(database.localAttachments, <LocalAttachmentsCompanion>[
        LocalAttachmentsCompanion.insert(
          localId: 'ready-file',
          attachmentId: const Value('ready-attachment-id'),
          conversationId: _conversationId,
          clientMessageId: aggregateId,
          uploadState: const Value('ready'),
          bytesTotal: const Value(100),
          bytesSent: const Value(100),
          contentType: 'application/pdf',
          sha256: 'ready-sha',
        ),
        LocalAttachmentsCompanion.insert(
          localId: 'failed-file',
          conversationId: _conversationId,
          clientMessageId: aggregateId,
          uploadState: const Value('failed'),
          bytesTotal: const Value(100),
          bytesSent: const Value(40),
          contentType: 'image/png',
          sha256: 'failed-sha',
          failureCode: const Value('scripted_upload_failure'),
        ),
      ]);
    });
    final composer = ComposerController(
      conversationId: _conversationId,
      submitter: SendMessage(database: database, clock: () => now),
      attachmentClientMessageId: aggregateId,
      attachmentSource: DriftAttachmentComposerSource(
        database: database,
        clock: () => now,
      ),
    );
    try {
      await _pumpChat(tester, repository, composer);
      await tester.enterText(find.byType(TextField), 'message with two files');
      await _settleAsyncUi(tester);
      expect(find.textContaining('업로드 실패'), findsOneWidget);
      final sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(sendButton.onPressed, isNull);
      await composer.submit();
      expect(await database.messageDao.getAll(), isEmpty);
      expect(await database.outboxDao.getAll(), isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      composer.dispose();
      await _settleAsyncUi(tester);
      await tester.runAsync(() async {
        await repository.dispose();
        await database.close();
      });
    }
  });
}

final class ScriptedRemoteLedger {
  ScriptedRemoteLedger({Set<String> unknownCommitOnce = const <String>{}})
    : unknownCommitOnce = Set.unmodifiable(unknownCommitOnce);

  final Set<String> unknownCommitOnce;
  final Set<String> _unknownReturned = <String>{};
  final List<String> remoteCommitOrder = <String>[];
  final Map<String, int> commitCountById = <String, int>{};

  void commitOnce(String clientRequestId) {
    if (commitCountById.containsKey(clientRequestId)) return;
    commitCountById[clientRequestId] = 1;
    remoteCommitOrder.add(clientRequestId);
  }
}

final class ScriptedFaultExecutor implements CommandExecutor {
  ScriptedFaultExecutor({
    required AppDatabase database,
    required this.ledger,
    this.blockedCommandId,
    this.blockedStarted,
    this.blockedRelease,
  }) : _database = database;

  final AppDatabase _database;
  final ScriptedRemoteLedger ledger;
  final String? blockedCommandId;
  final Completer<void>? blockedStarted;
  final Completer<void>? blockedRelease;
  final List<OutboxExecutionCommand> calls = <OutboxExecutionCommand>[];

  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) async {
    calls.add(command);
    if (command.id == blockedCommandId) {
      if (blockedStarted?.isCompleted == false) blockedStarted!.complete();
      await blockedRelease!.future;
      return const CommandExecutionResult(
        ExecutionDisposition.retryable,
        errorCode: 'scripted_upload_interruption',
      );
    }
    if (command.commandType == 'local_upload_attachment_v1') {
      final attachment = await (_database.select(
        _database.localAttachments,
      )..where((row) => row.localId.equals(command.aggregateId))).getSingle();
      await (_database.update(
        _database.localAttachments,
      )..where((row) => row.localId.equals(command.aggregateId))).write(
        LocalAttachmentsCompanion(
          uploadState: const Value('ready'),
          bytesSent: Value(attachment.bytesTotal),
          attachmentId: Value('fixture-${attachment.localId}'),
        ),
      );
      return const CommandExecutionResult(ExecutionDisposition.completed);
    }
    if (command.commandType != 'local_send_text_v1') {
      return const CommandExecutionResult(
        ExecutionDisposition.permanent,
        errorCode: 'fixture_command_unsupported',
      );
    }
    final payload = jsonDecode(command.payloadJson) as Map<String, Object?>;
    final clientMessageId = payload['clientMessageId']! as String;
    expect(clientMessageId, command.clientRequestId);
    expect(payload['localMessageId'], command.id);
    ledger.commitOnce(clientMessageId);
    if (ledger.unknownCommitOnce.contains(clientMessageId) &&
        ledger._unknownReturned.add(clientMessageId)) {
      return const CommandExecutionResult(
        ExecutionDisposition.retryable,
        errorCode: 'unknown_commit_timeout',
      );
    }
    await (_database.update(_database.localMessages)
          ..where((row) => row.clientMessageId.equals(clientMessageId)))
        .write(const LocalMessagesCompanion(deliveryState: Value('sent')));
    return const CommandExecutionResult(ExecutionDisposition.completed);
  }
}

OutboxWorker _worker(
  AppDatabase database,
  CommandExecutor executor,
  DateTime Function() clock, {
  required String scope,
}) {
  var lease = 0;
  return OutboxWorker(
    dao: database.outboxDao,
    executor: executor,
    clock: clock,
    retryPolicy: RetryPolicy(() => 0.5),
    scope: scope,
    leaseToken: () => '$scope:lease-${lease++}',
  );
}

Future<void> _pumpChat(
  WidgetTester tester,
  MessageRepositoryImpl repository,
  ComposerController composer,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatScreen.repository(
        title: 'CHAT-074 local fault fixture',
        repository: repository,
        conversationId: _conversationId,
        composerController: composer,
      ),
    ),
  );
  await _settleAsyncUi(tester);
}

Future<void> _settleAsyncUi(WidgetTester tester) async {
  for (var attempt = 0; attempt < 5; attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _waitForComposer(ComposerController composer) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (composer.isSubmitting && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (composer.isSubmitting) {
    throw StateError('composer_submission_timeout');
  }
}
