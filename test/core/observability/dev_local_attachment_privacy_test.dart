import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';
import 'package:timefit_native/features/attachments/application/dev_local_attachment_observability.dart';
import 'package:timefit_native/features/attachments/application/dev_local_attachment_preview_controller.dart';
import 'package:timefit_native/features/attachments/data/dev_local_attachment_drafts.dart';
import 'package:timefit_native/features/attachments/data/local_attachment_store.dart';
import 'package:timefit_native/features/attachments/domain/attachment_policy.dart';

const String _messageId = '12345678-1234-4123-8123-123456789abc';
const String _attachmentId = '87654321-4321-4123-8123-123456789abc';
const String _conversationId = 'conversation-local';
const List<int> _pdf = <int>[37, 80, 68, 70, 45, 49, 46, 55];

void main() {
  late Directory sandbox;
  late Directory privateRoot;
  late AppDatabase database;
  late LocalRepositorySession session;
  late FakeAppLogSink sink;
  late DevLocalAttachmentObservability observability;
  late DevLocalAttachmentDrafts drafts;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('attachment-privacy-');
    privateRoot = await Directory('${sandbox.path}/private').create();
    database = AppDatabase(NativeDatabase.memory());
    session = LocalRepositorySession.forDatabase(database);
    sink = FakeAppLogSink();
    final AppLogger logger = AppLogger(
      context: AppLogContext(
        environment: 'test',
        app: 'timefit-native',
        build: '1.0.0',
      ),
      sink: sink,
    );
    observability = DevLocalAttachmentObservability(
      logger: logger,
      crashReporter: LocalCrashReporter(logger),
    );
    drafts = DevLocalAttachmentDrafts(
      database: database,
      session: session,
      store: LocalAttachmentStore(
        privateRoot: privateRoot,
        uuid: () => _attachmentId,
      ),
      observability: observability,
      uuid: () => _messageId,
    );
  });

  tearDown(() async {
    await session.dispose();
    await database.close();
    await sandbox.delete(recursive: true);
  });

  test(
    'real dev draft restore and preview export typed correlations only',
    () async {
      const String filename = 'canary-token-private-name.pdf';
      await drafts.add(
        conversationId: _conversationId,
        clientMessageId: _messageId,
        inputs: <AttachmentInput>[
          AttachmentInput(
            name: filename,
            openRead: () => Stream<List<int>>.value(_pdf),
          ),
        ],
      );
      expect(
        await drafts.findDraftClientMessageId(_conversationId),
        _messageId,
      );

      final DevLocalAttachmentPreviewController preview =
          DevLocalAttachmentPreviewController(
            database: database,
            session: session,
            privateRoot: privateRoot,
            conversationId: _conversationId,
            localId: _attachmentId,
            observability: observability,
          );
      addTearDown(preview.dispose);
      await preview.load();
      expect(preview.state, isA<DevLocalPreviewReady>());

      final String exported = jsonEncode(
        sink.records.map((AppLogRecord record) => record.export).toList(),
      );
      expect(exported, isNot(contains(filename)));
      expect(exported, isNot(contains(privateRoot.path)));
      expect(exported, isNot(contains('canary-token')));
      expect(exported, contains(_messageId));
      expect(exported, contains(_attachmentId));
      expect(exported, contains('attachment_private_copy_ready'));
      expect(exported, contains('attachment_draft_restored'));
      expect(exported, contains('attachment_local_preview_ready'));
    },
  );

  test(
    'cleanup failure reports stable codes without path or exception text',
    () async {
      await drafts.add(
        conversationId: _conversationId,
        clientMessageId: _messageId,
        inputs: <AttachmentInput>[
          AttachmentInput(
            name: 'canary-secret.pdf',
            openRead: () => Stream<List<int>>.value(_pdf),
          ),
        ],
      );
      final File privateCopy = File('${privateRoot.path}/$_attachmentId');
      await privateCopy.delete();
      await Directory(privateCopy.path).create();

      await expectLater(
        drafts.remove(
          conversationId: _conversationId,
          clientMessageId: _messageId,
          localId: _attachmentId,
        ),
        throwsA(isA<AttachmentException>()),
      );

      final String exported = jsonEncode(
        sink.records.map((AppLogRecord record) => record.export).toList(),
      );
      expect(exported, contains('attachment_cleanup_failed'));
      expect(exported, contains('private_copy_cleanup_failed'));
      expect(exported, contains('app_error'));
      expect(exported, isNot(contains(privateRoot.path)));
      expect(exported, isNot(contains('canary-secret.pdf')));
    },
  );

  test('preview URI query and fragment never enter failure export', () async {
    await drafts.add(
      conversationId: _conversationId,
      clientMessageId: _messageId,
      inputs: <AttachmentInput>[
        AttachmentInput(
          name: 'query-canary.pdf',
          openRead: () => Stream<List<int>>.value(_pdf),
        ),
      ],
    );
    final String privateUri = File(
      '${privateRoot.path}/$_attachmentId',
    ).uri.toString();
    await (database.update(
      database.localAttachments,
    )..where((row) => row.localId.equals(_attachmentId))).write(
      LocalAttachmentsCompanion(
        localFileUri: Value(
          '$privateUri?access_token=canary-query#canary-fragment',
        ),
      ),
    );

    final DevLocalAttachmentPreviewController preview =
        DevLocalAttachmentPreviewController(
          database: database,
          session: session,
          privateRoot: privateRoot,
          conversationId: _conversationId,
          localId: _attachmentId,
          observability: observability,
        );
    addTearDown(preview.dispose);
    await preview.load();
    expect(preview.state, isA<DevLocalPreviewFailed>());

    final String exported = jsonEncode(
      sink.records.map((AppLogRecord record) => record.export).toList(),
    );
    expect(exported, contains('attachment_local_preview_failed'));
    expect(exported, contains('local_preview_read_failed'));
    expect(exported, isNot(contains(privateRoot.path)));
    expect(exported, isNot(contains('access_token')));
    expect(exported, isNot(contains('canary-query')));
    expect(exported, isNot(contains('canary-fragment')));
  });

  test(
    'valid IDs reach a throwing sink without blocking draft or preview',
    () async {
      final _ThrowingSink throwingSink = _ThrowingSink();
      final AppLogger throwingLogger = AppLogger(
        context: AppLogContext(
          environment: 'test',
          app: 'timefit-native',
          build: '1.0.0',
        ),
        sink: throwingSink,
      );
      final DevLocalAttachmentObservability throwingObservability =
          DevLocalAttachmentObservability(
            logger: throwingLogger,
            crashReporter: LocalCrashReporter(throwingLogger),
          );
      final DevLocalAttachmentDrafts throwingDrafts = DevLocalAttachmentDrafts(
        database: database,
        session: session,
        store: LocalAttachmentStore(
          privateRoot: privateRoot,
          uuid: () => _attachmentId,
        ),
        observability: throwingObservability,
      );

      final List<PrivateAttachment> copied = await throwingDrafts.add(
        conversationId: _conversationId,
        clientMessageId: _messageId,
        inputs: <AttachmentInput>[
          AttachmentInput(
            name: 'sink-canary.pdf',
            openRead: () => Stream<List<int>>.value(_pdf),
          ),
        ],
      );
      expect(copied, hasLength(1));

      final DevLocalAttachmentPreviewController preview =
          DevLocalAttachmentPreviewController(
            database: database,
            session: session,
            privateRoot: privateRoot,
            conversationId: _conversationId,
            localId: _attachmentId,
            observability: throwingObservability,
          );
      addTearDown(preview.dispose);
      await preview.load();

      expect(preview.state, isA<DevLocalPreviewReady>());
      expect(throwingSink.writeCount, 2);
      expect(await database.select(database.outboxCommands).get(), isEmpty);
    },
  );

  test('malformed names, unsafe ids, and failing sinks never escape', () async {
    await expectLater(
      drafts.add(
        conversationId: _conversationId,
        clientMessageId: _messageId,
        inputs: <AttachmentInput>[
          AttachmentInput(
            name: 'canary-token/bad.pdf',
            openRead: () => Stream<List<int>>.value(_pdf),
          ),
        ],
      ),
      throwsA(isA<AttachmentException>()),
    );
    expect(jsonEncode(sink.records.first.export), isNot(contains('canary')));

    final AppLogger throwingLogger = AppLogger(
      context: AppLogContext(
        environment: 'test',
        app: 'timefit-native',
        build: '1.0.0',
      ),
      sink: _ThrowingSink(),
    );
    final DevLocalAttachmentObservability failing =
        DevLocalAttachmentObservability(
          logger: throwingLogger,
          crashReporter: LocalCrashReporter(throwingLogger),
        );
    expect(
      () => failing.cleanupFailed(
        exception: const FileSystemException(
          'canary exception',
          '/private/canary-token.pdf',
        ),
        clientMessageId: _messageId,
        attachmentId: 'canary-token.pdf',
      ),
      returnsNormally,
    );
  });
}

final class _ThrowingSink implements AppLogSink {
  int writeCount = 0;

  @override
  void write(AppLogRecord record) {
    writeCount += 1;
    throw StateError('sink-canary');
  }
}
