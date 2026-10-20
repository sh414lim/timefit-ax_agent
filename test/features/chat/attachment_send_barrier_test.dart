import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
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
    );

    final command = await claimedCommand();
    final first = await executor.execute(command);
    expect(first.disposition, ExecutionDisposition.retryable);
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
    );

    final command = await claimedCommand();
    final failed = await executor.execute(command);
    expect(failed.disposition, ExecutionDisposition.permanent);
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
      session: session,
    );
    await session.dispose();

    final result = await executor.execute(await claimedCommand());

    expect(result.disposition, ExecutionDisposition.authRequired);
    expect(result.errorCode, 'message_session_closed');
    expect(sender.calls, isEmpty);
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
      expect(controller.attachments, isEmpty);
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
