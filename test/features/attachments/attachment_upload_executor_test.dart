import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/attachments/application/attachment_upload_executor.dart';
import 'package:timefit_native/features/attachments/data/attachment_remote_source.dart';
import 'package:timefit_native/features/attachments/domain/attachment_policy.dart';
import 'package:timefit_native/features/chat/application/outbox/command_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';

class FakeRemote implements AttachmentRemoteSource {
  final trace = <String>[];
  String? failStage;
  AttachmentRemoteFailure failure = AttachmentRemoteFailure.retryable;
  int mismatches = 0;
  bool exists = false;
  Completer<void>? pause;
  Completer<void>? entered;
  Future<void> Function(Future<void> Function(int))? progress;
  void check(String stage) {
    if (failStage == stage) {
      failStage = null;
      throw AttachmentRemoteException(failure);
    }
  }

  @override
  Future<PreparedAttachment> prepare(
    AttachmentUploadInput input,
    AttachmentCancellation cancellation,
  ) async {
    trace.add('prepare:${input.localId}');
    check('prepare');
    if (pause != null && !(entered?.isCompleted ?? false)) {
      entered?.complete();
      await pause!.future;
    }
    return const PreparedAttachment(
      attachmentId: 'server-a',
      objectPath: 'opaque/object-a',
    );
  }

  @override
  Future<AttachmentUploadOutcome> upload(
    AttachmentUploadInput input,
    PreparedAttachment target, {
    required AttachmentCancellation cancellation,
    required Future<void> Function(int) onProgress,
  }) async {
    trace.add('upload:${target.attachmentId}:${target.objectPath}');
    check('upload');
    if (progress != null) {
      await progress!(onProgress);
    } else {
      await onProgress(input.file.bytesTotal);
    }
    if (exists) {
      exists = false;
      return AttachmentUploadOutcome.alreadyExists;
    }
    return AttachmentUploadOutcome.uploaded;
  }

  @override
  Future<AttachmentVerification> finalize(
    AttachmentUploadInput input,
    PreparedAttachment target,
    AttachmentCancellation cancellation,
  ) async {
    trace.add('finalize:${target.attachmentId}');
    check('finalize');
    if (mismatches > 0) {
      mismatches--;
      return AttachmentVerification.metadataMismatch;
    }
    return AttachmentVerification.ready;
  }
}

void main() {
  late Directory sandbox;
  late Directory root;
  late File dbFile;
  late AppDatabase db;
  late DateTime now;
  late FakeRemote remote;
  late String token;
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('timefit-upload-');
    root = await Directory('${sandbox.path}/private').create();
    final file = await File('${root.path}/file').writeAsBytes([1, 2, 3]);
    dbFile = File('${sandbox.path}/local.db');
    db = AppDatabase(NativeDatabase(dbFile));
    now = DateTime.utc(2026, 10, 20);
    remote = FakeRemote();
    token = 'lease-1';
    await db
        .into(db.localAttachments)
        .insert(
          LocalAttachmentsCompanion.insert(
            localId: 'a',
            conversationId: 'one',
            clientMessageId: 'client',
            localFileUri: Value(file.uri.toString()),
            bytesTotal: const Value(3),
            contentType: 'application/pdf',
            sha256: 'fixture-sha',
          ),
        );
    await db
        .into(db.outboxCommands)
        .insert(
          OutboxCommandsCompanion.insert(
            id: 'command',
            commandType: 'local_upload_attachment_v1',
            aggregateId: 'a',
            clientRequestId: 'client',
            payloadJson: 'opaque-local-payload',
            nextAttemptAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.outboxDao.claim(now, token);
  });
  tearDown(() async {
    await db.close();
    await sandbox.delete(recursive: true);
  });
  OutboxExecutionCommand command({String? lease}) => OutboxExecutionCommand(
    id: 'command',
    clientRequestId: 'client',
    commandType: 'local_upload_attachment_v1',
    aggregateId: 'a',
    payloadJson: 'opaque-local-payload',
    leaseToken: lease ?? token,
  );
  AttachmentUploadExecutor executor({AttachmentCancellation? cancellation}) =>
      AttachmentUploadExecutor(
        database: db,
        remote: remote,
        privateRoot: root,
        clock: () => now,
        cancellation: cancellation,
      );
  Future<LocalAttachment> row() => db.select(db.localAttachments).getSingle();
  Future<void> restart() async {
    await db.close();
    db = AppDatabase(NativeDatabase(dbFile));
    now = now.add(const Duration(seconds: 61));
    token = '$token-next';
    await db.outboxDao.claim(now, token);
  }

  test(
    'expired lease late prepare result cannot overwrite a reclaimed command',
    () async {
      remote.pause = Completer<void>();
      remote.entered = Completer<void>();
      final oldToken = token;
      final running = executor().execute(command());
      await remote.entered!.future;
      now = now.add(const Duration(seconds: 61));
      token = 'replacement';
      await db.outboxDao.claim(now, token);
      remote.pause!.complete();
      expect((await running).errorCode, 'inactive_upload_lease');
      expect((await row()).attachmentId, isNull);
      expect((await db.outboxDao.getAll()).single.leaseOwner, token);
      expect(
        (await executor().execute(command(lease: oldToken))).errorCode,
        'inactive_upload_lease',
      );
    },
  );
  test(
    'session closes during prepare without persisting late response',
    () async {
      remote.pause = Completer<void>();
      remote.entered = Completer<void>();
      final running = executor().execute(command());
      await remote.entered!.future;
      await LocalRepositorySession.forDatabase(db).dispose();
      remote.pause!.complete();
      await running;
      expect((await row()).attachmentId, isNull);
      expect(remote.trace, hasLength(1));
    },
  );
  test(
    'private file outside configured root is never passed to remote',
    () async {
      final outside = await File(
        '${sandbox.path}/outside',
      ).writeAsBytes([1, 2, 3]);
      await db
          .update(db.localAttachments)
          .write(
            LocalAttachmentsCompanion(
              localFileUri: Value(outside.uri.toString()),
            ),
          );
      expect(
        (await executor().execute(command())).disposition,
        ExecutionDisposition.permanent,
      );
      expect(remote.trace, isEmpty);
      expect(await outside.exists(), isTrue);
    },
  );
  test(
    'prepare upload finalize persists opaque identity and ready bytes',
    () async {
      expect(
        (await executor().execute(command())).disposition,
        ExecutionDisposition.completed,
      );
      final stored = await row();
      expect(stored.uploadState, 'ready');
      expect(stored.bytesSent, 3);
      expect(stored.attachmentId, 'server-a');
      expect(stored.uploadObjectPath, 'opaque/object-a');
      expect(remote.trace, [
        'prepare:a',
        'upload:server-a:opaque/object-a',
        'finalize:server-a',
      ]);
      await executor().execute(command());
      expect(remote.trace, hasLength(3));
    },
  );
  for (final stage in ['prepare', 'upload', 'finalize']) {
    test(
      '$stage interruption reopens database and resumes persisted checkpoint',
      () async {
        remote.failStage = stage;
        expect(
          (await executor().execute(command())).disposition,
          ExecutionDisposition.retryable,
        );
        final checkpoint = await row();
        expect(
          checkpoint.uploadState,
          {
            'prepare': 'preparing',
            'upload': 'uploading',
            'finalize': 'finalizing',
          }[stage],
        );
        final previousCalls = remote.trace.length;
        await restart();
        expect(
          (await executor().execute(command())).disposition,
          ExecutionDisposition.completed,
        );
        final after = remote.trace.skip(previousCalls).toList();
        if (stage != 'prepare')
          expect(after.where((s) => s.startsWith('prepare')), isEmpty);
        if (stage == 'finalize') expect(after, ['finalize:server-a']);
        expect((await row()).uploadState, 'ready');
      },
    );
  }
  test(
    'already exists preserves object and holds for reprepare contract',
    () async {
      remote.exists = true;
      expect(
        (await executor().execute(command())).errorCode,
        'reprepare_required',
      );
      expect((await row()).uploadState, 'failed');
      final calls = remote.trace.length;
      await restart();
      await executor().execute(command());
      expect((await row()).uploadState, 'failed');
      expect(remote.trace, hasLength(calls));
      expect((await row()).attachmentId, 'server-a');
      expect(remote.trace.where((s) => s.startsWith('finalize')), isEmpty);
    },
  );
  test(
    'metadata mismatch preserves ID path and requires explicit future reprepare',
    () async {
      remote.mismatches = 1;
      expect(
        (await executor().execute(command())).errorCode,
        'reprepare_required',
      );
      expect((await row()).verificationFailures, 1);
      expect((await row()).uploadState, 'failed');
      expect((await row()).failureCode, 'reprepare_required');
      expect((await row()).attachmentId, 'server-a');
      expect((await row()).uploadObjectPath, 'opaque/object-a');
      expect(remote.trace.where((s) => s.startsWith('prepare')), hasLength(1));
      expect(remote.trace.where((s) => s.startsWith('upload')), hasLength(1));
    },
  );
  test(
    'mismatch hold survives restart without automatic upload or prepare',
    () async {
      remote.mismatches = 2;
      expect(
        (await executor().execute(command())).disposition,
        ExecutionDisposition.permanent,
      );
      expect((await row()).uploadState, 'failed');
      expect((await row()).verificationFailures, 1);
      final calls = remote.trace.length;
      await restart();
      expect(
        (await executor().execute(command())).disposition,
        ExecutionDisposition.permanent,
      );
      expect(remote.trace, hasLength(calls));
      expect(await db.messageDao.getAll(), isEmpty);
    },
  );
  test(
    'progress throttles intermediate writes and always commits final count',
    () async {
      remote.progress = (progress) async {
        await progress(1);
        expect((await row()).bytesSent, 0);
        now = now.add(const Duration(milliseconds: 300));
        await progress(2);
        expect((await row()).bytesSent, 2);
        await progress(3);
        expect((await row()).bytesSent, 3);
      };
      await executor().execute(command());
      expect((await row()).bytesSent, 3);
    },
  );
  test(
    'auth pause preserves checkpoint command payload and private copy',
    () async {
      remote.failStage = 'upload';
      remote.failure = AttachmentRemoteFailure.authRequired;
      expect(
        (await executor().execute(command())).disposition,
        ExecutionDisposition.authRequired,
      );
      expect((await row()).uploadState, 'uploading');
      expect(
        await File.fromUri(Uri.parse((await row()).localFileUri!)).exists(),
        isTrue,
      );
      expect(
        (await db.outboxDao.getAll()).single.payloadJson,
        'opaque-local-payload',
      );
      await restart();
      await executor().execute(command());
      expect(remote.trace.where((s) => s.startsWith('prepare')), hasLength(1));
    },
  );
  test(
    'permanent remote validation failure persists failed attachment',
    () async {
      remote.failStage = 'prepare';
      remote.failure = AttachmentRemoteFailure.permanent;
      expect(
        (await executor().execute(command())).disposition,
        ExecutionDisposition.permanent,
      );
      expect((await row()).uploadState, 'failed');
      expect((await row()).failureCode, 'attachment_permanent');
      expect(remote.trace, hasLength(1));
    },
  );
  test(
    'invalid progress is rejected without byte overflow or ready state',
    () async {
      remote.progress = (progress) async {
        await progress(4);
      };
      expect(
        (await executor().execute(command())).disposition,
        ExecutionDisposition.permanent,
      );
      expect((await row()).bytesSent, 0);
      expect((await row()).uploadState, 'failed');
    },
  );
  test(
    'new valid lease replaces stalled old execution and old finally preserves new owner',
    () async {
      final subject = executor();
      final oldGate = Completer<void>();
      final oldEntered = Completer<void>();
      remote.pause = oldGate;
      remote.entered = oldEntered;
      final old = subject.execute(command());
      await oldEntered.future;
      now = now.add(const Duration(seconds: 61));
      token = 'new-lease';
      await db.outboxDao.claim(now, token);
      final newGate = Completer<void>();
      final newEntered = Completer<void>();
      remote.pause = newGate;
      remote.entered = newEntered;
      final fresh = subject.execute(command());
      await newEntered.future;
      oldGate.complete();
      expect((await old).errorCode, 'inactive_upload_lease');
      expect(
        (await subject.execute(command())).errorCode,
        'upload_in_progress',
      );
      newGate.complete();
      expect((await fresh).disposition, ExecutionDisposition.completed);
      expect((await row()).uploadState, 'ready');
      expect(remote.trace.where((s) => s.startsWith('prepare')), hasLength(2));
      expect(remote.trace.where((s) => s.startsWith('upload')), hasLength(1));
    },
  );
  test('duplicate execution does not call prepare twice', () async {
    remote.pause = Completer<void>();
    remote.entered = Completer<void>();
    final first = executor().execute(command());
    await remote.entered!.future;
    expect(
      (await executor().execute(command())).errorCode,
      'upload_in_progress',
    );
    remote.pause!.complete();
    await first;
    expect(remote.trace.where((s) => s.startsWith('prepare')), hasLength(1));
  });
  test(
    'cancelled or expired lease cannot apply a late prepare result',
    () async {
      remote.pause = Completer<void>();
      remote.entered = Completer<void>();
      final first = executor().execute(command());
      await remote.entered!.future;
      await db.outboxDao.cancel('command', now);
      remote.pause!.complete();
      await first;
      expect((await row()).attachmentId, isNull);
      expect((await row()).uploadState, 'preparing');
      expect(remote.trace, hasLength(1));
    },
  );
  test(
    'Outbox worker forwards fenced token and completes the local command',
    () async {
      now = now.add(const Duration(seconds: 61));
      final worker = OutboxWorker(
        dao: db.outboxDao,
        executor: executor(),
        clock: () => now,
        retryPolicy: RetryPolicy(() => 0.5),
        scope: 'upload-test',
      );
      await worker.wake();
      expect((await row()).uploadState, 'ready');
      expect((await db.outboxDao.getAll()).single.state, 'completed');
    },
  );

  test(
    'cancelling a stalled prepare returns and ignores its later result',
    () async {
      final cancellation = AttachmentCancellation();
      remote.pause = Completer<void>();
      remote.entered = Completer<void>();
      final running = executor(cancellation: cancellation).execute(command());
      await remote.entered!.future;
      cancellation.cancel();
      expect(
        (await running.timeout(const Duration(seconds: 2))).errorCode,
        'attachment_cancelled',
      );
      remote.pause!.complete();
      await Future<void>.delayed(Duration.zero);
      expect((await row()).attachmentId, isNull);
      expect(remote.trace, hasLength(1));
    },
  );

  test(
    'explicit cancellation preserves files and checkpoint without ready',
    () async {
      final cancellation = AttachmentCancellation()..cancel();
      expect(
        (await executor(
          cancellation: cancellation,
        ).execute(command())).disposition,
        isNot(ExecutionDisposition.completed),
      );
      expect((await row()).uploadState, 'queued');
      expect(remote.trace, isEmpty);
    },
  );
}
