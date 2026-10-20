import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/drift_attachment_composer_source.dart';
import 'package:timefit_native/features/chat/application/outbox/attachment_message_send_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/command_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/presentation/widgets/chat_composer.dart';

void main() {
  late AppDatabase database;
  late DateTime now;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 20);
  });

  tearDown(() => database.close());

  Future<void> insertAttachment(
    String localId, {
    String state = 'queued',
    String? attachmentId,
    String conversationId = 'conversation',
    String clientMessageId = 'message-1',
  }) => database
      .into(database.localAttachments)
      .insert(
        LocalAttachmentsCompanion.insert(
          localId: localId,
          attachmentId: Value(attachmentId),
          conversationId: conversationId,
          clientMessageId: clientMessageId,
          uploadState: Value(state),
          bytesTotal: const Value(10),
          bytesSent: Value(state == 'ready' ? 10 : 0),
          contentType: 'application/pdf',
          sha256: 'sha-$localId',
        ),
      );

  SendMessage submitter() => SendMessage(
    database: database,
    clock: () => now,
    clientMessageId: () => 'unused-text-id',
  );

  Future<OutboxExecutionCommand> claimedCommand({
    String token = 'direct-lease',
  }) async {
    await database.outboxDao.claim(now, token);
    final row = (await database.outboxDao.getAll()).singleWhere(
      (command) => command.commandType == 'local_send_message_v2',
    );
    return OutboxExecutionCommand(
      id: row.id,
      clientRequestId: row.clientRequestId,
      commandType: row.commandType,
      aggregateId: row.aggregateId,
      payloadJson: row.payloadJson,
      leaseToken: row.leaseOwner,
    );
  }

  test('one uploading keeps fake send at zero; all ready sends once', () async {
    await insertAttachment(
      'slow',
      state: 'uploading',
      attachmentId: 'server-slow',
    );
    await insertAttachment(
      'ready',
      state: 'ready',
      attachmentId: 'server-ready',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: '안녕',
      localAttachmentIds: <String>['slow', 'ready'],
    );
    final _FakeMessageSender sender = _FakeMessageSender();
    final executor = AttachmentMessageSendExecutor(
      database: database,
      sender: sender,
      clock: () => now,
      executionScope: 'chat-052-test',
    );

    final command = await claimedCommand();
    final first = await executor.execute(command);
    expect(first.disposition, ExecutionDisposition.deferred);
    expect(first.errorCode, 'attachments_not_ready');
    expect(sender.calls, isEmpty);

    await (database.update(
      database.localAttachments,
    )..where((row) => row.localId.equals('slow'))).write(
      const LocalAttachmentsCompanion(
        uploadState: Value('ready'),
        bytesSent: Value(10),
      ),
    );
    final second = await executor.execute(command);

    expect(second.disposition, ExecutionDisposition.completed);
    expect(sender.calls, hasLength(1));
    expect(sender.calls.single.bodyText, '안녕');
    expect(sender.calls.single.attachmentIds, <String>[
      'server-slow',
      'server-ready',
    ]);
    expect(
      (await database.select(database.localAttachments).get()).map(
        (row) => row.uploadState,
      ),
      everyElement('ready'),
    );
  });

  test('whitespace file-only body uses one canonical empty value', () async {
    await insertAttachment(
      'ready',
      state: 'ready',
      attachmentId: 'server-ready',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: ' \n ',
      localAttachmentIds: const <String>['ready'],
    );
    final sender = _FakeMessageSender();
    final result = await AttachmentMessageSendExecutor(
      database: database,
      sender: sender,
      clock: () => now,
      executionScope: 'chat-052-test',
    ).execute(await claimedCommand());

    expect(result.disposition, ExecutionDisposition.completed);
    expect(sender.calls.single.bodyText, isEmpty);
    expect((await database.messageDao.getAll()).single.bodyText, isNull);
  });

  test(
    'two executors in one DB scope permit one in-flight fake send',
    () async {
      await insertAttachment(
        'ready',
        state: 'ready',
        attachmentId: 'server-ready',
      );
      await submitter().submitWithAttachments(
        clientMessageId: 'message-1',
        conversationId: 'conversation',
        bodyText: 'body',
        localAttachmentIds: const <String>['ready'],
      );
      final sender = _DelayedMessageSender();
      final firstExecutor = AttachmentMessageSendExecutor(
        database: database,
        sender: sender,
        clock: () => now,
        executionScope: 'chat-052-test',
      );
      final duplicateSender = _FakeMessageSender();
      final secondExecutor = AttachmentMessageSendExecutor(
        database: database,
        sender: duplicateSender,
        clock: () => now,
        executionScope: 'chat-052-test',
      );
      final command = await claimedCommand();

      final first = firstExecutor.execute(command);
      await sender.started.future;
      final second = await secondExecutor.execute(command);
      expect(second.errorCode, 'message_send_in_progress');
      expect(sender.calls, 1);
      expect(duplicateSender.calls, isEmpty);
      sender.result.complete(
        const CommandExecutionResult(ExecutionDisposition.completed),
      );
      expect((await first).disposition, ExecutionDisposition.completed);
      expect(sender.calls, 1);
    },
  );

  test('new lease replaces stalled owner and old finally is fenced', () async {
    await insertAttachment(
      'ready',
      state: 'ready',
      attachmentId: 'server-ready',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: 'body',
      localAttachmentIds: const <String>['ready'],
    );
    final oldSender = _DelayedMessageSender();
    final freshSender = _DelayedMessageSender();
    final oldExecutor = AttachmentMessageSendExecutor(
      database: database,
      sender: oldSender,
      clock: () => now,
      executionScope: 'chat-052-new-lease',
    );
    final freshExecutor = AttachmentMessageSendExecutor(
      database: database,
      sender: freshSender,
      clock: () => now,
      executionScope: 'chat-052-new-lease',
    );
    final oldCommand = await claimedCommand(token: 'old-lease');
    final oldRun = oldExecutor.execute(oldCommand);
    await oldSender.started.future;
    now = now.add(const Duration(seconds: 61));
    final freshRow = (await database.outboxDao.claim(now, 'fresh-lease'))!;
    final freshCommand = OutboxExecutionCommand(
      id: freshRow.id,
      clientRequestId: freshRow.clientRequestId,
      commandType: freshRow.commandType,
      aggregateId: freshRow.aggregateId,
      payloadJson: freshRow.payloadJson,
      leaseToken: freshRow.leaseOwner,
    );
    final freshRun = freshExecutor.execute(freshCommand);
    await freshSender.started.future;
    oldSender.result.complete(
      const CommandExecutionResult(ExecutionDisposition.completed),
    );
    expect((await oldRun).errorCode, 'inactive_message_lease');
    expect(
      (await oldExecutor.execute(freshCommand)).errorCode,
      'message_send_in_progress',
    );
    freshSender.result.complete(
      const CommandExecutionResult(ExecutionDisposition.completed),
    );
    expect((await freshRun).disposition, ExecutionDisposition.completed);
  });

  test(
    'removing the last failed attachment sends the remaining body',
    () async {
      await insertAttachment('failed', state: 'failed');
      await submitter().submitWithAttachments(
        clientMessageId: 'message-1',
        conversationId: 'conversation',
        bodyText: 'body remains',
        localAttachmentIds: const <String>['failed'],
      );
      await DriftAttachmentComposerSource(
        database: database,
        clock: () => now,
      ).removeFailed(
        conversationId: 'conversation',
        clientMessageId: 'message-1',
        localId: 'failed',
      );
      final sender = _FakeMessageSender();
      final result = await AttachmentMessageSendExecutor(
        database: database,
        sender: sender,
        clock: () => now,
        executionScope: 'chat-052-body-only',
      ).execute(await claimedCommand());

      expect(result.disposition, ExecutionDisposition.completed);
      expect(sender.calls.single.bodyText, 'body remains');
      expect(sender.calls.single.attachmentIds, isEmpty);
      expect((await database.messageDao.getAll()).single.messageKind, 'text');
    },
  );

  test('failed and cancelled aggregates never reach fake send', () async {
    await insertAttachment(
      'failed',
      state: 'failed',
      attachmentId: 'server-failed',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: 'body',
      localAttachmentIds: const <String>['failed'],
    );
    final _FakeMessageSender sender = _FakeMessageSender();
    final executor = AttachmentMessageSendExecutor(
      database: database,
      sender: sender,
      clock: () => now,
      executionScope: 'chat-052-test',
    );

    final command = await claimedCommand();
    final failed = await executor.execute(command);
    expect(failed.disposition, ExecutionDisposition.deferred);
    expect(failed.errorCode, 'attachment_failed');
    expect(sender.calls, isEmpty);
    expect(await database.outboxDao.cancel('message-1', now), isTrue);
    expect((await database.outboxDao.getAll()).last.state, 'cancelled');
    final cancelled = await executor.execute(command);
    expect(cancelled.errorCode, 'inactive_message_lease');
    expect(sender.calls, isEmpty);
  });

  test('double aggregate submission is idempotent in Drift', () async {
    await insertAttachment(
      'ready',
      state: 'ready',
      attachmentId: 'server-ready',
    );
    final SendMessage send = submitter();
    await Future.wait(<Future<LocalAttachmentMessageCommand>>[
      send.submitWithAttachments(
        clientMessageId: 'message-1',
        conversationId: 'conversation',
        bodyText: '',
        localAttachmentIds: const <String>['ready'],
      ),
      send.submitWithAttachments(
        clientMessageId: 'message-1',
        conversationId: 'conversation',
        bodyText: '',
        localAttachmentIds: const <String>['ready'],
      ),
    ]);

    expect(await database.messageDao.getAll(), hasLength(1));
    expect(
      (await database.outboxDao.getAll()).where(
        (row) => row.commandType == 'local_send_message_v2',
      ),
      hasLength(1),
    );
  });

  test(
    'worker sends one ready aggregate once and skips a cancelled one',
    () async {
      await insertAttachment(
        'ready-1',
        state: 'ready',
        attachmentId: 'server-1',
      );
      await insertAttachment(
        'ready-2',
        state: 'ready',
        attachmentId: 'server-2',
        clientMessageId: 'message-2',
      );
      final SendMessage send = submitter();
      await send.submitWithAttachments(
        clientMessageId: 'message-1',
        conversationId: 'conversation',
        bodyText: 'one',
        localAttachmentIds: const <String>['ready-1'],
      );
      await send.submitWithAttachments(
        clientMessageId: 'message-2',
        conversationId: 'conversation',
        bodyText: 'two',
        localAttachmentIds: const <String>['ready-2'],
      );
      expect(await database.outboxDao.cancel('message-2', now), isTrue);
      final _FakeMessageSender sender = _FakeMessageSender();
      final worker = OutboxWorker(
        dao: database.outboxDao,
        executor: AttachmentMessageSendExecutor(
          database: database,
          sender: sender,
          clock: () => now,
          executionScope: 'chat-052-worker',
        ),
        clock: () => now,
        retryPolicy: const RetryPolicy(_middleJitter),
        scope: 'chat-052-worker',
        leaseToken: () => 'lease-token',
      );

      await worker.wake();
      await worker.wake();

      expect(sender.calls, hasLength(1));
      expect(sender.calls.single.clientMessageId, 'message-1');
      final states = {
        for (final command in await database.outboxDao.getAll())
          command.id: command.state,
      };
      expect(states['message-1'], 'completed');
      expect(states['message-2'], 'cancelled');
    },
  );

  test('readiness deferral never consumes the eight-failure budget', () async {
    await insertAttachment(
      'slow',
      state: 'uploading',
      attachmentId: 'server-slow',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: 'body',
      localAttachmentIds: const <String>['slow'],
    );
    final sender = _FakeMessageSender();
    final worker = OutboxWorker(
      dao: database.outboxDao,
      executor: AttachmentMessageSendExecutor(
        database: database,
        sender: sender,
        clock: () => now,
        executionScope: 'chat-052-deferred',
      ),
      clock: () => now,
      retryPolicy: const RetryPolicy(_middleJitter),
      scope: 'chat-052-deferred',
      leaseToken: () => 'deferred-${now.microsecondsSinceEpoch}',
    );

    for (var wake = 0; wake < 8; wake++) {
      await worker.wake();
      final row = (await database.outboxDao.getAll()).single;
      expect(row.state, 'retry_wait');
      expect(row.attemptCount, 0);
      now = row.nextAttemptAt;
    }
    expect(sender.calls, isEmpty);
    await (database.update(
      database.localAttachments,
    )..where((row) => row.localId.equals('slow'))).write(
      const LocalAttachmentsCompanion(
        uploadState: Value('ready'),
        bytesSent: Value(10),
      ),
    );
    await worker.wake();

    expect(sender.calls, hasLength(1));
    expect((await database.outboxDao.getAll()).single.state, 'completed');
  });

  test(
    'failed exclusion persists and revises the aggregate after restart',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'timefit-chat-052-',
      );
      final file = File('${sandbox.path}/local.db');
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      await insertAttachment('failed', state: 'uploading');
      await insertAttachment(
        'ready',
        state: 'ready',
        attachmentId: 'server-ready',
      );
      await submitter().submitWithAttachments(
        clientMessageId: 'message-1',
        conversationId: 'conversation',
        bodyText: 'body',
        localAttachmentIds: const <String>['failed', 'ready'],
      );
      final waitingWorker = OutboxWorker(
        dao: database.outboxDao,
        executor: AttachmentMessageSendExecutor(
          database: database,
          sender: _FakeMessageSender(),
          clock: () => now,
          executionScope: 'chat-052-waiting-removal',
        ),
        clock: () => now,
        retryPolicy: const RetryPolicy(_middleJitter),
        scope: 'chat-052-waiting-removal',
      );
      await waitingWorker.wake();
      expect((await database.outboxDao.getAll()).single.state, 'retry_wait');
      await (database.update(database.localAttachments)
            ..where((row) => row.localId.equals('failed')))
          .write(const LocalAttachmentsCompanion(uploadState: Value('failed')));
      final source = DriftAttachmentComposerSource(
        database: database,
        clock: () => now,
      );
      await source.removeFailed(
        conversationId: 'conversation',
        clientMessageId: 'message-1',
        localId: 'failed',
      );
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      final restored =
          await DriftAttachmentComposerSource(
                database: database,
                clock: () => now,
              )
              .watch(
                conversationId: 'conversation',
                clientMessageId: 'message-1',
              )
              .first;
      final rows = await database.select(database.localAttachments).get();
      final command = LocalAttachmentMessageCommand.decode(
        (await database.outboxDao.getAll()).single.payloadJson,
      );

      expect(restored.map((item) => item.localId), <String>['ready']);
      expect(
        rows.singleWhere((row) => row.localId == 'failed').composerExcluded,
        isTrue,
      );
      expect(command.localAttachmentIds, <String>['ready']);
      final sender = _FakeMessageSender();
      final worker = OutboxWorker(
        dao: database.outboxDao,
        executor: AttachmentMessageSendExecutor(
          database: database,
          sender: sender,
          clock: () => now,
          executionScope: 'chat-052-restored-removal',
        ),
        clock: () => now,
        retryPolicy: const RetryPolicy(_middleJitter),
        scope: 'chat-052-restored-removal',
      );
      await worker.wake();
      expect(sender.calls.single.attachmentIds, <String>['server-ready']);
      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      await sandbox.delete(recursive: true);
    },
  );

  test('persisted barrier resumes after database restart', () async {
    final Directory sandbox = await Directory.systemTemp.createTemp(
      'timefit-chat-052-',
    );
    final File file = File('${sandbox.path}/local.db');
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    await insertAttachment(
      'restart',
      state: 'uploading',
      attachmentId: 'server-restart',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: '',
      localAttachmentIds: const <String>['restart'],
    );
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    await database
        .update(database.localAttachments)
        .write(
          const LocalAttachmentsCompanion(
            uploadState: Value('ready'),
            bytesSent: Value(10),
          ),
        );
    final _FakeMessageSender sender = _FakeMessageSender();
    final result = await AttachmentMessageSendExecutor(
      database: database,
      sender: sender,
      clock: () => now,
      executionScope: 'chat-052-restart',
    ).execute(await claimedCommand());

    expect(result.disposition, ExecutionDisposition.completed);
    expect(sender.calls, hasLength(1));
    expect(sender.calls.single.bodyText, isEmpty);
    expect(sender.calls.single.attachmentIds, <String>['server-restart']);
    expect(
      (await database.select(database.localAttachments).get())
          .single
          .uploadState,
      'ready',
    );
    await database.close();
    database = AppDatabase(NativeDatabase.memory());
    await sandbox.delete(recursive: true);
  });

  test('closed session prevents fake send during account transition', () async {
    await insertAttachment(
      'ready',
      state: 'ready',
      attachmentId: 'server-ready',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: 'body',
      localAttachmentIds: const <String>['ready'],
    );
    final LocalRepositorySession session = LocalRepositorySession();
    final _FakeMessageSender sender = _FakeMessageSender();
    final executor = AttachmentMessageSendExecutor(
      database: database,
      sender: sender,
      clock: () => now,
      executionScope: 'chat-052-session',
      session: session,
    );
    await session.dispose();

    final result = await executor.execute(await claimedCommand());

    expect(result.disposition, ExecutionDisposition.authRequired);
    expect(result.errorCode, 'message_session_closed');
    expect(sender.calls, isEmpty);
  });

  test('composer watch drops paused values after session disposal', () async {
    final session = LocalRepositorySession();
    final source = DriftAttachmentComposerSource(
      database: database,
      clock: () => now,
      session: session,
    );
    final values = <List<ComposerAttachment>>[];
    final subscription = source
        .watch(conversationId: 'conversation', clientMessageId: 'message-1')
        .listen(values.add);
    subscription.pause();
    await insertAttachment('queued');
    await session.dispose();
    subscription.resume();
    await Future<void>.delayed(Duration.zero);

    expect(values, isEmpty);
    await subscription.cancel();
  });

  test('session disposal fences a stalled fake send result', () async {
    await insertAttachment(
      'ready',
      state: 'ready',
      attachmentId: 'server-ready',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: 'body',
      localAttachmentIds: const <String>['ready'],
    );
    final session = LocalRepositorySession();
    final sender = _DelayedMessageSender();
    final executor = AttachmentMessageSendExecutor(
      database: database,
      sender: sender,
      clock: () => now,
      executionScope: 'chat-052-disposed-send',
      session: session,
    );
    final running = executor.execute(await claimedCommand());
    await sender.started.future;
    await session.dispose();
    sender.result.complete(
      const CommandExecutionResult(ExecutionDisposition.completed),
    );

    final result = await running;
    expect(result.disposition, ExecutionDisposition.authRequired);
    expect(result.errorCode, 'message_session_closed');
  });

  test('shared scope fences two database handles and cancellation', () async {
    final sandbox = await Directory.systemTemp.createTemp('timefit-chat-052-');
    final file = File('${sandbox.path}/local.db');
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    final secondDatabase = AppDatabase(NativeDatabase(file));
    await insertAttachment(
      'ready',
      state: 'ready',
      attachmentId: 'server-ready',
    );
    await submitter().submitWithAttachments(
      clientMessageId: 'message-1',
      conversationId: 'conversation',
      bodyText: 'body',
      localAttachmentIds: const <String>['ready'],
    );
    final command = await claimedCommand(token: 'shared-lease');
    final firstSender = _DelayedMessageSender();
    final secondSender = _FakeMessageSender();
    final firstRun = AttachmentMessageSendExecutor(
      database: database,
      sender: firstSender,
      clock: () => now,
      executionScope: 'chat-052-shared-file',
    ).execute(command);
    await firstSender.started.future;
    final duplicate = await AttachmentMessageSendExecutor(
      database: secondDatabase,
      sender: secondSender,
      clock: () => now,
      executionScope: 'chat-052-shared-file',
    ).execute(command);

    expect(duplicate.errorCode, 'message_send_in_progress');
    expect(secondSender.calls, isEmpty);
    expect(await secondDatabase.outboxDao.cancel('message-1', now), isTrue);
    firstSender.result.complete(
      const CommandExecutionResult(ExecutionDisposition.completed),
    );
    expect((await firstRun).errorCode, 'inactive_message_lease');
    await secondDatabase.close();
    await database.close();
    database = AppDatabase(NativeDatabase.memory());
    await sandbox.delete(recursive: true);
  });

  testWidgets(
    'chips show states; failed removal leaves one ready body aggregate',
    (WidgetTester tester) async {
      final _FakeAttachmentSource source =
          _FakeAttachmentSource(<ComposerAttachment>[
            _view('queued', ComposerAttachmentState.queued),
            _view('uploading', ComposerAttachmentState.uploading, sent: 4),
            _view('failed', ComposerAttachmentState.failed),
            _view('ready', ComposerAttachmentState.ready, sent: 10),
          ]);
      final _CapturingSubmitter submitter = _CapturingSubmitter();
      final ComposerController controller = ComposerController(
        conversationId: 'conversation',
        submitter: submitter,
        attachmentClientMessageId: 'message-1',
        attachmentSource: source,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatComposer(controller: controller)),
        ),
      );
      await tester.pump();

      expect(find.textContaining('대기 중'), findsOneWidget);
      expect(find.textContaining('업로드 중'), findsOneWidget);
      expect(find.textContaining('업로드 실패'), findsOneWidget);
      expect(find.textContaining('준비됨'), findsOneWidget);
      expect(controller.canSubmit, isFalse);

      await tester.tap(find.byTooltip('실패한 첨부 제거'));
      await tester.pump();
      expect(source.removed, <String>['failed']);
      expect(find.textContaining('업로드 실패'), findsNothing);
      controller.updateDraft('본문');
      source.replace(<ComposerAttachment>[
        _view('ready', ComposerAttachmentState.ready, sent: 10),
      ]);
      await tester.pump();
      expect(controller.canSubmit, isTrue);

      final Future<void> first = controller.submit();
      final Future<void> second = controller.submit();
      expect(identical(first, second), isTrue);
      expect(submitter.attachmentCalls, 1);
      expect(submitter.localIds, <String>['ready']);
      expect(submitter.body, '본문');
      submitter.pending.complete(
        LocalAttachmentMessageCommand(
          id: 'message-1',
          conversationId: 'conversation',
          bodyText: '본문',
          localAttachmentIds: const <String>['ready'],
        ),
      );
      await first;
      await tester.pump();
      expect(controller.attachments, hasLength(1));
      expect(controller.canSubmit, isFalse);
    },
  );

  test(
    'file-only composer aggregate is allowed after source restores',
    () async {
      final _FakeAttachmentSource source = _FakeAttachmentSource(
        <ComposerAttachment>[
          _view('ready', ComposerAttachmentState.ready, sent: 10),
        ],
      );
      final _CapturingSubmitter submitter = _CapturingSubmitter(
        immediate: true,
      );
      final ComposerController controller = ComposerController(
        conversationId: 'conversation',
        submitter: submitter,
        attachmentClientMessageId: 'message-1',
        attachmentSource: source,
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(controller.canSubmit, isTrue);
      await controller.submit();
      expect(submitter.body, isEmpty);
      expect(submitter.localIds, <String>['ready']);
    },
  );
}

double _middleJitter() => 0.5;

ComposerAttachment _view(
  String id,
  ComposerAttachmentState state, {
  int sent = 0,
}) => ComposerAttachment(
  localId: id,
  contentType: 'application/pdf',
  state: state,
  bytesSent: sent,
  bytesTotal: 10,
);

final class _FakeMessageSender implements LocalMessageSendPort {
  final List<LocalMessageSendRequest> calls = <LocalMessageSendRequest>[];

  @override
  Future<CommandExecutionResult> send(LocalMessageSendRequest request) async {
    calls.add(request);
    return const CommandExecutionResult(ExecutionDisposition.completed);
  }
}

final class _DelayedMessageSender implements LocalMessageSendPort {
  final started = Completer<void>();
  final result = Completer<CommandExecutionResult>();
  int calls = 0;

  @override
  Future<CommandExecutionResult> send(LocalMessageSendRequest request) {
    calls += 1;
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

final class _FakeAttachmentSource implements AttachmentComposerSource {
  _FakeAttachmentSource(List<ComposerAttachment> initial)
    : _items = List<ComposerAttachment>.of(initial);

  List<ComposerAttachment> _items;
  final StreamController<List<ComposerAttachment>> _controller =
      StreamController<List<ComposerAttachment>>.broadcast();
  final List<String> removed = <String>[];

  void replace(List<ComposerAttachment> value) {
    _items = List<ComposerAttachment>.of(value);
    _controller.add(List.unmodifiable(_items));
  }

  @override
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  }) async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) async {
    removed.add(localId);
    replace(_items.where((item) => item.localId != localId).toList());
  }
}

final class _CapturingSubmitter
    implements TextMessageSubmitter, AttachmentMessageSubmitter {
  _CapturingSubmitter({this.immediate = false});

  final bool immediate;
  final Completer<LocalAttachmentMessageCommand> pending =
      Completer<LocalAttachmentMessageCommand>();
  int attachmentCalls = 0;
  String? body;
  List<String>? localIds;

  @override
  Future<bool> retry(String commandId) async => false;

  @override
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) => throw StateError('text-only not expected');

  @override
  Future<LocalAttachmentMessageCommand> submitWithAttachments({
    required String clientMessageId,
    required String conversationId,
    required String bodyText,
    required List<String> localAttachmentIds,
  }) {
    attachmentCalls += 1;
    body = bodyText;
    localIds = List<String>.of(localAttachmentIds);
    final command = LocalAttachmentMessageCommand(
      id: clientMessageId,
      conversationId: conversationId,
      bodyText: bodyText,
      localAttachmentIds: localAttachmentIds,
    );
    return immediate ? Future.value(command) : pending.future;
  }
}
