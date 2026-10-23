import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/attachments/data/dev_local_attachment_drafts.dart';
import 'package:timefit_native/features/attachments/data/local_attachment_store.dart';
import 'package:timefit_native/features/attachments/domain/attachment_policy.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/drift_attachment_composer_source.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';

const List<int> _pdf = <int>[37, 80, 68, 70, 45, 49, 46, 55];

AttachmentInput _input({String name = 'fixture.pdf', List<int> bytes = _pdf}) =>
    AttachmentInput(
      name: name,
      declaredMime: 'application/pdf',
      openRead: () => Stream<List<int>>.value(bytes),
    );

void main() {
  late Directory sandbox;
  late Directory root;
  late AppDatabase database;
  late LocalRepositorySession session;
  late DevLocalAttachmentDrafts drafts;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('timefit-dev-draft-');
    root = await Directory('${sandbox.path}/attachments').create();
    database = AppDatabase(NativeDatabase.memory());
    session = LocalRepositorySession.forDatabase(database);
    drafts = DevLocalAttachmentDrafts(
      database: database,
      session: session,
      store: LocalAttachmentStore(privateRoot: root),
    );
  });

  tearDown(() async {
    await session.dispose();
    await database.close();
    await sandbox.delete(recursive: true);
  });

  test(
    'selection persists queued private copies without remote state',
    () async {
      await drafts.add(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        inputs: <AttachmentInput>[_input()],
      );

      final LocalAttachment row = await database
          .select(database.localAttachments)
          .getSingle();
      expect(row.uploadState, 'queued');
      expect(row.attachmentId, isNull);
      expect(row.uploadObjectPath, isNull);
      expect(row.bytesSent, 0);
      expect(row.sha256, sha256.convert(_pdf).toString());
      expect(
        await File.fromUri(Uri.parse(row.localFileUri!)).readAsBytes(),
        _pdf,
      );
      expect(await database.messageDao.getAll(), isEmpty);
      expect(await database.outboxDao.getAll(), isEmpty);
    },
  );

  test('private copy and draft restore after store reconstruction', () async {
    await drafts.add(
      conversationId: 'conversation-1',
      clientMessageId: 'draft-1',
      inputs: <AttachmentInput>[_input()],
    );
    final LocalAttachment row = await database
        .select(database.localAttachments)
        .getSingle();
    final File privateCopy = File.fromUri(Uri.parse(row.localFileUri!));

    final DevLocalAttachmentDrafts restarted = DevLocalAttachmentDrafts(
      database: database,
      session: session,
      store: LocalAttachmentStore(privateRoot: root),
    );
    expect(
      await restarted.findDraftClientMessageId('conversation-1'),
      'draft-1',
    );
    expect(await privateCopy.exists(), isTrue);
    expect(
      sha256.convert(await privateCopy.readAsBytes()).toString(),
      row.sha256,
    );

    await restarted.remove(
      conversationId: 'conversation-1',
      clientMessageId: 'draft-1',
      localId: row.localId,
    );
    expect(await database.select(database.localAttachments).get(), isEmpty);
    expect(await privateCopy.exists(), isFalse);
  });

  test(
    'repeated selection enforces aggregate count before source reads',
    () async {
      await drafts.add(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        inputs: List<AttachmentInput>.generate(4, (_) => _input()),
      );
      var opened = 0;
      final AttachmentInput counted = AttachmentInput(
        name: 'counted.pdf',
        declaredMime: 'application/pdf',
        openRead: () {
          opened += 1;
          return Stream<List<int>>.value(_pdf);
        },
      );
      await expectLater(
        drafts.add(
          conversationId: 'conversation-1',
          clientMessageId: 'draft-1',
          inputs: <AttachmentInput>[counted, counted],
        ),
        throwsA(
          isA<AttachmentException>().having(
            (AttachmentException error) => error.failure,
            'failure',
            AttachmentFailure.invalidCount,
          ),
        ),
      );
      expect(opened, 0);
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(4),
      );
    },
  );

  test(
    'message aggregate keeps every queued local attachment identity',
    () async {
      await drafts.add(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        inputs: <AttachmentInput>[_input(), _input()],
      );
      final List<LocalAttachment> rows = await database
          .select(database.localAttachments)
          .get();
      final SendMessage send = SendMessage(
        database: database,
        session: session,
        clock: () => DateTime.utc(2026, 10, 23),
      );
      final LocalAttachmentMessageCommand command = await send
          .submitWithAttachments(
            clientMessageId: 'draft-1',
            conversationId: 'conversation-1',
            bodyText: 'body',
            localAttachmentIds: rows
                .map((LocalAttachment row) => row.localId)
                .toList(),
          );
      expect(command.localAttachmentIds, hasLength(2));
      expect(
        command.localAttachmentIds.toSet(),
        rows.map((row) => row.localId).toSet(),
      );
      expect((await database.outboxDao.getAll()).single.state, 'queued');
      expect(rows.every((row) => row.uploadState == 'queued'), isTrue);

      await drafts.remove(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        localId: rows.first.localId,
      );
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(2),
      );
    },
  );

  test(
    'submitted aggregate rejects another picker result without reading it',
    () async {
      await drafts.add(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        inputs: <AttachmentInput>[_input()],
      );
      final LocalAttachment row = await database
          .select(database.localAttachments)
          .getSingle();
      await SendMessage(
        database: database,
        session: session,
        clock: () => DateTime.utc(2026, 10, 23),
      ).submitWithAttachments(
        clientMessageId: 'draft-1',
        conversationId: 'conversation-1',
        bodyText: 'body',
        localAttachmentIds: <String>[row.localId],
      );
      final String payload =
          (await database.outboxDao.getAll()).single.payloadJson;
      var opened = 0;
      final AttachmentInput lateInput = AttachmentInput(
        name: 'late.pdf',
        declaredMime: 'application/pdf',
        openRead: () {
          opened += 1;
          return Stream<List<int>>.value(_pdf);
        },
      );

      await expectLater(
        drafts.add(
          conversationId: 'conversation-1',
          clientMessageId: 'draft-1',
          inputs: <AttachmentInput>[lateInput],
        ),
        throwsA(isA<StateError>()),
      );
      expect(opened, 0);
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(1),
      );
      expect((await database.outboxDao.getAll()).single.payloadJson, payload);
      expect(await root.list().toList(), hasLength(1));
    },
  );

  test('direct submit waits for the first private copy aggregate', () async {
    final ComposerController controller = ComposerController(
      conversationId: 'conversation-1',
      attachmentClientMessageId: 'draft-1',
      attachmentSource: DriftAttachmentComposerSource(
        database: database,
        session: session,
        clock: () => DateTime.utc(2026, 10, 23),
      ),
      submitter: SendMessage(
        database: database,
        session: session,
        clock: () => DateTime.utc(2026, 10, 23),
      ),
    );
    addTearDown(controller.dispose);
    controller.updateDraft('body');
    await _waitUntil(() => controller.canSubmit);
    final Completer<void> opened = Completer<void>();
    final Completer<void> release = Completer<void>();
    final Future<List<PrivateAttachment>> copying = drafts.add(
      conversationId: 'conversation-1',
      clientMessageId: 'draft-1',
      inputs: <AttachmentInput>[
        AttachmentInput(
          name: 'pending.pdf',
          declaredMime: 'application/pdf',
          openRead: () async* {
            opened.complete();
            await release.future;
            yield _pdf;
          },
        ),
      ],
    );
    await opened.future;

    expect(controller.canSubmit, isFalse);
    await controller.submit();
    expect(await database.messageDao.getAll(), isEmpty);
    expect(await database.outboxDao.getAll(), isEmpty);

    release.complete();
    await copying;
    await _waitUntil(() => controller.attachments.length == 1);
    expect(controller.canSubmit, isTrue);
    await controller.submit();
    expect(await database.messageDao.getAll(), hasLength(1));
    expect(await database.outboxDao.getAll(), hasLength(1));
  });

  test(
    'submit immediately after copy reads the committed draft snapshot',
    () async {
      final ComposerController controller = ComposerController(
        conversationId: 'conversation-1',
        attachmentClientMessageId: 'draft-1',
        attachmentSource: DriftAttachmentComposerSource(
          database: database,
          session: session,
          clock: () => DateTime.utc(2026, 10, 23),
        ),
        submitter: SendMessage(
          database: database,
          session: session,
          clock: () => DateTime.utc(2026, 10, 23),
          clientMessageId: () => 'detached-text-id',
        ),
      );
      addTearDown(controller.dispose);
      controller.updateDraft('body');
      await _waitUntil(() => controller.canSubmit);

      await drafts.add(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        inputs: <AttachmentInput>[_input()],
      );
      await controller.submit();

      final messages = await database.messageDao.getAll();
      expect(messages, hasLength(1));
      expect(messages.single.clientMessageId, 'draft-1');
      expect(messages.single.messageKind, 'mixed');
      final command = LocalAttachmentMessageCommand.decode(
        (await database.outboxDao.getAll()).single.payloadJson,
      );
      expect(command.localAttachmentIds, hasLength(1));
    },
  );

  test(
    'failed and cancelled copies release the shared mutation boundary',
    () async {
      await expectLater(
        drafts.add(
          conversationId: 'conversation-1',
          clientMessageId: 'draft-1',
          inputs: <AttachmentInput>[_input(name: 'bad.txt')],
        ),
        throwsA(isA<AttachmentException>()),
      );
      expect(session.isAttachmentDraftMutating('draft-1'), isFalse);

      final AttachmentCancellation cancellation = AttachmentCancellation()
        ..cancel();
      await expectLater(
        drafts.add(
          conversationId: 'conversation-1',
          clientMessageId: 'draft-1',
          inputs: <AttachmentInput>[_input()],
          cancellation: cancellation,
        ),
        throwsA(
          isA<AttachmentException>().having(
            (AttachmentException error) => error.failure,
            'failure',
            AttachmentFailure.cancelled,
          ),
        ),
      );
      expect(session.isAttachmentDraftMutating('draft-1'), isFalse);

      await drafts.add(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        inputs: <AttachmentInput>[_input()],
      );
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(1),
      );
    },
  );

  test(
    'pending add fences removal then releases for a later removal',
    () async {
      await drafts.add(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        inputs: <AttachmentInput>[_input()],
      );
      final LocalAttachment first = await database
          .select(database.localAttachments)
          .getSingle();
      final Completer<void> opened = Completer<void>();
      final Completer<void> release = Completer<void>();
      final Future<List<PrivateAttachment>> adding = drafts.add(
        conversationId: 'conversation-1',
        clientMessageId: 'draft-1',
        inputs: <AttachmentInput>[
          AttachmentInput(
            name: 'second.pdf',
            declaredMime: 'application/pdf',
            openRead: () async* {
              opened.complete();
              await release.future;
              yield _pdf;
            },
          ),
        ],
      );
      await opened.future;

      var removalComplete = false;
      final Future<void> removal = drafts
          .remove(
            conversationId: 'conversation-1',
            clientMessageId: 'draft-1',
            localId: first.localId,
          )
          .then((_) => removalComplete = true);
      await Future<void>.delayed(Duration.zero);
      expect(removalComplete, isFalse);
      release.complete();
      await adding;
      await removal;
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(1),
      );
    },
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}
