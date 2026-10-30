import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/presentation/widgets/chat_composer.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30);

  test(
    'disposed composer cannot create a local message or Outbox command',
    () async {
      final database = _database();
      final controller = ComposerController(
        conversationId: 'old-conversation',
        submitter: SendMessage(
          database: database,
          clock: () => now,
          clientMessageId: () => 'late-message',
        ),
      );
      controller.updateDraft('unsent draft');
      controller.dispose();

      await controller.submit();

      expect(await database.messageDao.getAll(), isEmpty);
      expect(await database.outboxDao.getAll(), isEmpty);
      expect(controller.draft, 'unsent draft');
      expect(controller.canSubmit, isFalse);
    },
  );

  test(
    'disposed composer leaves a failed message and retry identity unchanged',
    () async {
      final database = _database();
      final controller = ComposerController(
        conversationId: 'old-conversation',
        submitter: SendMessage(
          database: database,
          clock: () => now,
          clientMessageId: () => 'failed-message',
        ),
      );
      controller.updateDraft('failed draft');
      await controller.submit();
      final lease = (await database.outboxDao.claim(now, 'test-lease'))!;
      await database.outboxDao.finish(
        lease,
        now,
        state: 'failed_permanent',
        failures: 8,
        errorCode: 'retry_exhausted',
      );
      final messages = await database.messageDao.getAll();
      final commands = await database.outboxDao.getAll();
      controller.dispose();

      expect(await controller.retry('failed-message'), isFalse);
      expect(await database.messageDao.getAll(), messages);
      expect(await database.outboxDao.getAll(), commands);
    },
  );

  test(
    'disposed admission does not consult an expired external predicate',
    () async {
      var expired = false;
      final submitter = _ControlledSubmitter();
      final controller = ComposerController(
        conversationId: 'conversation',
        submitter: submitter,
        mutationAdmission: () {
          if (expired) throw StateError('expired admission must not be read');
          return true;
        },
      );
      controller.updateDraft('unsent');
      controller.dispose();
      expired = true;

      expect(controller.canSubmit, isFalse);
      await controller.submit();
      expect(await controller.retry('old-message'), isFalse);
      expect(submitter.submitCalls, 0);
      expect(submitter.retriedIds, isEmpty);
      controller.updateDraft('late edit');
      expect(controller.draft, 'unsent');
    },
  );

  test(
    'disposed canSubmit does not read a released attachment source',
    () async {
      final source = _ReleasedAttachmentSource();
      final controller = ComposerController(
        conversationId: 'conversation',
        attachmentClientMessageId: 'draft',
        attachmentSource: source,
        submitter: _ControlledSubmitter(),
      );
      controller.updateDraft('body');
      await Future<void>.delayed(Duration.zero);
      expect(controller.canSubmit, isTrue);
      controller.dispose();
      source.released = true;

      expect(controller.canSubmit, isFalse);
      await controller.submit();
      await controller.removeFailedAttachment('local-file');
      expect(source.removalCalls, 0);
    },
  );

  for (final action in ['canSubmit', 'submit', 'retry']) {
    test('synchronous admission disposal blocks $action', () async {
      final submitter = _ControlledSubmitter();
      late final ComposerController controller;
      controller = ComposerController(
        conversationId: 'conversation',
        submitter: submitter,
        mutationAdmission: () {
          controller.dispose();
          return true;
        },
      );
      controller.updateDraft('draft');

      switch (action) {
        case 'canSubmit':
          expect(controller.canSubmit, isFalse);
        case 'submit':
          await controller.submit();
        case 'retry':
          expect(await controller.retry('client'), isFalse);
      }
      expect(submitter.submitCalls, 0);
      expect(submitter.retriedIds, isEmpty);
    });
  }

  test(
    'synchronous admission disposal blocks failed attachment removal',
    () async {
      final source = _ReleasedAttachmentSource(
        attachments: const [
          ComposerAttachment(
            localId: 'failed-local',
            contentType: 'application/pdf',
            state: ComposerAttachmentState.failed,
            bytesSent: 0,
            bytesTotal: 8,
          ),
        ],
      );
      late final ComposerController controller;
      controller = ComposerController(
        conversationId: 'conversation',
        attachmentClientMessageId: 'draft',
        attachmentSource: source,
        submitter: _ControlledSubmitter(),
        mutationAdmission: () {
          controller.dispose();
          return true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.attachments, hasLength(1));

      await controller.removeFailedAttachment('failed-local');

      expect(source.removalCalls, 0);
    },
  );

  for (final fails in [false, true]) {
    test(
      'admitted submit drains once after dispose (failure: $fails)',
      () async {
        final gate = Completer<LocalTextCommand>();
        final submitter = _ControlledSubmitter(submitGate: gate);
        final controller = ComposerController(
          conversationId: 'conversation',
          submitter: submitter,
        );
        controller.updateDraft('admitted draft');
        final active = controller.submit();
        controller.dispose();

        expect(identical(controller.submit(), active), isTrue);
        if (fails) {
          final checked = expectLater(active, throwsA(isA<StateError>()));
          gate.completeError(StateError('local submission failed'));
          await checked;
          expect(controller.draft, 'admitted draft');
        } else {
          gate.complete(_command('admitted draft'));
          await active;
        }
        await controller.submit();
        expect(submitter.submitCalls, 1);
        expect(controller.canSubmit, isFalse);
      },
    );

    test(
      'admitted retry drains once after dispose (failure: $fails)',
      () async {
        final gate = Completer<bool>();
        final submitter = _ControlledSubmitter(retryGate: gate);
        final controller = ComposerController(
          conversationId: 'conversation',
          submitter: submitter,
        );
        final active = controller.retry('same-client-id');
        controller.dispose();

        expect(identical(controller.retry('same-client-id'), active), isTrue);
        if (fails) {
          final checked = expectLater(active, throwsA(isA<StateError>()));
          gate.completeError(StateError('local retry failed'));
          await checked;
        } else {
          gate.complete(true);
          expect(await active, isTrue);
        }
        expect(await controller.retry('same-client-id'), isFalse);
        expect(await controller.retry('different-client-id'), isFalse);
        expect(submitter.retriedIds, ['same-client-id']);
      },
    );
  }

  test(
    'a new conversation can still submit through the shared open DB session',
    () async {
      final database = _database();
      var nextId = 0;
      final send = SendMessage(
        database: database,
        clock: () => now,
        clientMessageId: () => 'client-${++nextId}',
      );
      final old = ComposerController(conversationId: 'old', submitter: send);
      old.updateDraft('old draft');
      old.dispose();
      final current = ComposerController(
        conversationId: 'current',
        submitter: send,
      );
      addTearDown(current.dispose);
      current.updateDraft('current draft');

      await old.submit();
      await current.submit();

      final messages = await database.messageDao.getAll();
      final commands = await database.outboxDao.getAll();
      expect(messages, hasLength(1));
      expect(messages.single.conversationId, 'current');
      expect(messages.single.bodyText, 'current draft');
      expect(messages.single.serverId, isNull);
      expect(messages.single.sequence, isNull);
      expect(commands, hasLength(1));
      expect(commands.single.state, 'queued');
      expect(commands.single.attemptCount, 0);
    },
  );

  testWidgets(
    'a retained send callback cannot write after the editor is closed',
    (tester) async {
      final database = _database();
      final submitter = _SpySubmitter(
        SendMessage(database: database, clock: () => now),
      );
      final controller = ComposerController(
        conversationId: 'closed-conversation',
        submitter: submitter,
      );
      controller.updateDraft('closed editor draft');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatComposer(controller: controller)),
        ),
      );
      final callback = tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send))
          .onPressed!;
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();

      await tester.runAsync(() async {
        callback();
        await submitter.lastSubmit;
        expect(await database.messageDao.getAll(), isEmpty);
        expect(await database.outboxDao.getAll(), isEmpty);
      });
      expect(submitter.submitCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

AppDatabase _database() {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(() async {
    await LocalRepositorySession.forDatabase(database).dispose();
    await database.close();
  });
  return database;
}

LocalTextCommand _command(String body) => LocalTextCommand(
  id: 'client',
  conversationId: 'conversation',
  bodyText: body,
);

final class _ControlledSubmitter implements TextMessageSubmitter {
  _ControlledSubmitter({this.submitGate, this.retryGate});

  final Completer<LocalTextCommand>? submitGate;
  final Completer<bool>? retryGate;
  int submitCalls = 0;
  final retriedIds = <String>[];

  @override
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) {
    submitCalls += 1;
    return submitGate?.future ?? Future.value(_command(bodyText));
  }

  @override
  Future<bool> retry(String commandId) {
    retriedIds.add(commandId);
    return retryGate?.future ?? Future.value(true);
  }
}

final class _SpySubmitter implements TextMessageSubmitter {
  _SpySubmitter(this.send);
  final SendMessage send;
  Future<LocalTextCommand>? lastSubmit;
  int submitCalls = 0;

  @override
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) {
    submitCalls += 1;
    return lastSubmit = send.submit(
      conversationId: conversationId,
      bodyText: bodyText,
    );
  }

  @override
  Future<bool> retry(String commandId) => send.retry(commandId);
}

final class _ReleasedAttachmentSource
    implements AttachmentComposerSource, AttachmentDraftMutationState {
  _ReleasedAttachmentSource({this.attachments = const []});

  final List<ComposerAttachment> attachments;
  bool released = false;
  int removalCalls = 0;

  @override
  bool isAttachmentDraftMutating(String clientMessageId) {
    if (released) throw StateError('released source must not be read');
    return false;
  }

  @override
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  }) => Stream.value(attachments);

  @override
  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) async {
    removalCalls += 1;
  }
}
