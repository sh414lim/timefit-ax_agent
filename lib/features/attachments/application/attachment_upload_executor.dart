import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;

import '../../../core/database/app_database.dart';
import '../../../core/database/local_repository_session.dart';
import '../../chat/application/outbox/command_executor.dart';
import '../data/attachment_remote_source.dart';
import '../domain/attachment_policy.dart';

final class _InactiveUpload implements Exception {
  const _InactiveUpload();
}

/// Explicitly injected; never installed in the app without a real port adapter.
/// One local_upload_attachment_v1 command per attachment, aggregateId=localId.
final class AttachmentUploadExecutor implements CommandExecutor {
  AttachmentUploadExecutor({
    required AppDatabase database,
    required this.remote,
    required this.privateRoot,
    required this.clock,
    LocalRepositorySession? session,
    AttachmentCancellation? cancellation,
  }) : _database = database,
       _session = session ?? LocalRepositorySession.forDatabase(database),
       cancellation = cancellation ?? AttachmentCancellation();
  final AppDatabase _database;
  final LocalRepositorySession _session;
  final AttachmentRemoteSource remote;
  final Directory privateRoot;
  final DateTime Function() clock;
  final AttachmentCancellation cancellation;
  static final _active = Expando<Map<String, String>>();
  final _snapshots = <String, LocalAttachment>{};

  Future<LocalAttachment> _read(OutboxExecutionCommand command) async {
    cancellation.check();
    final pair = await _session.read(() async {
      final lease = await (_database.select(
        _database.outboxCommands,
      )..where((r) => r.id.equals(command.id))).getSingle();
      final row = await (_database.select(
        _database.localAttachments,
      )..where((r) => r.localId.equals(command.aggregateId))).getSingle();
      return (lease, row);
    });
    final (lease, row) = pair;
    cancellation.check();
    if (command.commandType != 'local_upload_attachment_v1' ||
        command.leaseToken == null ||
        lease.commandType != command.commandType ||
        lease.aggregateId != command.aggregateId ||
        lease.clientRequestId != command.clientRequestId ||
        lease.payloadJson != command.payloadJson ||
        lease.state != 'running' ||
        lease.leaseOwner != command.leaseToken ||
        lease.leaseUntil == null ||
        !lease.leaseUntil!.isAfter(clock()))
      throw const _InactiveUpload();
    if (row.clientMessageId != command.clientRequestId)
      throw const _InactiveUpload();
    final expected = _snapshots['${command.id}:${command.leaseToken}'];
    if (expected != null &&
        (row.conversationId != expected.conversationId ||
            row.localFileUri != expected.localFileUri ||
            row.bytesTotal != expected.bytesTotal ||
            row.contentType != expected.contentType ||
            row.sha256 != expected.sha256))
      throw const _InactiveUpload();
    return row;
  }

  Future<T> _remoteCall<T>(Future<T> Function() operation) async {
    cancellation.check();
    final result = Completer<T>();
    final remove = cancellation.onCancel(() {
      if (!result.isCompleted)
        result.completeError(
          const AttachmentException(AttachmentFailure.cancelled),
        );
    });
    try {
      unawaited(
        Future<T>.sync(operation).then(
          (value) {
            if (!result.isCompleted) result.complete(value);
          },
          onError: (Object error, StackTrace stack) {
            if (!result.isCompleted) result.completeError(error, stack);
          },
        ),
      );
      return await result.future;
    } finally {
      remove();
    }
  }

  Future<void> _write(
    OutboxExecutionCommand command,
    LocalAttachmentsCompanion changes,
  ) => _session.write(_database, () async {
    await _read(command);
    await (_database.update(
      _database.localAttachments,
    )..where((r) => r.localId.equals(command.aggregateId))).write(changes);
    cancellation.check();
    await _read(command);
  });

  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) async {
    final active = _active[_database] ??= <String, String>{};
    final snapshotKey = '${command.id}:${command.leaseToken}';
    var owns = false;
    try {
      var row = await _read(command);
      if (active[command.id] == command.leaseToken)
        return const CommandExecutionResult(
          ExecutionDisposition.retryable,
          errorCode: 'upload_in_progress',
        );
      active[command.id] = command.leaseToken!;
      owns = true;
      _snapshots[snapshotKey] = row;
      if (row.uploadState == 'ready' || row.uploadState == 'bound')
        return const CommandExecutionResult(ExecutionDisposition.completed);
      if (row.uploadState == 'failed')
        return const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'attachment_failed',
        );
      final uri = Uri.tryParse(row.localFileUri ?? '');
      if (uri == null || uri.scheme != 'file')
        throw const AttachmentException(AttachmentFailure.unsafePath);
      final file = File.fromUri(uri);
      final root = await privateRoot.resolveSymbolicLinks();
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          !path.isWithin(root, await file.resolveSymbolicLinks()) ||
          await file.length() != row.bytesTotal) {
        throw const AttachmentException(AttachmentFailure.unsafePath);
      }
      final input = AttachmentUploadInput(
        localId: row.localId,
        conversationId: row.conversationId,
        clientMessageId: row.clientMessageId,
        file: PrivateAttachment(
          uri: uri,
          contentType: row.contentType,
          bytesTotal: row.bytesTotal,
          sha256: row.sha256,
        ),
      );
      while (true) {
        if (row.attachmentId == null) {
          await _write(
            command,
            const LocalAttachmentsCompanion(uploadState: Value('preparing')),
          );
          final prepared = await _remoteCall(
            () => remote.prepare(input, cancellation),
          );
          if (prepared.attachmentId.isEmpty ||
              prepared.objectPath.isEmpty ||
              prepared.objectPath.startsWith('/') ||
              prepared.objectPath.split('/').contains('..') ||
              prepared.objectPath.contains('://'))
            throw const AttachmentRemoteException(
              AttachmentRemoteFailure.permanent,
            );
          await _write(
            command,
            LocalAttachmentsCompanion(
              attachmentId: Value(prepared.attachmentId),
              uploadObjectPath: Value(prepared.objectPath),
              uploadState: const Value('uploading'),
            ),
          );
          row = await _read(command);
        }
        if (row.uploadObjectPath == null)
          throw const AttachmentRemoteException(
            AttachmentRemoteFailure.permanent,
          );
        final target = PreparedAttachment(
          attachmentId: row.attachmentId!,
          objectPath: row.uploadObjectPath!,
        );
        if (row.uploadState != 'finalizing') {
          await _write(
            command,
            const LocalAttachmentsCompanion(
              uploadState: Value('uploading'),
              bytesSent: Value(0),
            ),
          );
          var last = clock();
          var bytes = 0;
          final outcome = await _remoteCall(
            () => remote.upload(
              input,
              target,
              cancellation: cancellation,
              onProgress: (sent) async {
                if (sent < bytes || sent < 0 || sent > row.bytesTotal)
                  throw const AttachmentRemoteException(
                    AttachmentRemoteFailure.permanent,
                  );
                bytes = sent;
                if (sent == row.bytesTotal ||
                    clock().difference(last) >=
                        const Duration(milliseconds: 250)) {
                  await _write(
                    command,
                    LocalAttachmentsCompanion(bytesSent: Value(sent)),
                  );
                  last = clock();
                }
              },
            ),
          );
          if (outcome == AttachmentUploadOutcome.alreadyExists) {
            await _write(
              command,
              const LocalAttachmentsCompanion(
                uploadState: Value('failed'),
                failureCode: Value('reprepare_required'),
              ),
            );
            return const CommandExecutionResult(
              ExecutionDisposition.permanent,
              errorCode: 'reprepare_required',
            );
          }
          await _write(
            command,
            LocalAttachmentsCompanion(
              uploadState: const Value('finalizing'),
              bytesSent: Value(row.bytesTotal),
            ),
          );
        }
        await _read(command);
        final verification = await _remoteCall(
          () => remote.finalize(input, target, cancellation),
        );
        if (verification == AttachmentVerification.ready) {
          await _write(
            command,
            const LocalAttachmentsCompanion(
              uploadState: Value('ready'),
              failureCode: Value(null),
            ),
          );
          return const CommandExecutionResult(ExecutionDisposition.completed);
        }
        final failures = row.verificationFailures + 1;
        await _write(
          command,
          LocalAttachmentsCompanion(
            verificationFailures: Value(failures),
            uploadState: const Value('failed'),
            bytesSent: const Value(0),
            failureCode: const Value('reprepare_required'),
          ),
        );
        // Automatic reprepare and old-orphan/identity replacement are deferred
        // until CHAT-016 defines that contract. Never overwrite this object.
        return const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'reprepare_required',
        );
      }
    } on AttachmentRemoteException catch (error) {
      if (error.failure == AttachmentRemoteFailure.permanent) {
        try {
          await _write(
            command,
            const LocalAttachmentsCompanion(
              uploadState: Value('failed'),
              failureCode: Value('attachment_permanent'),
            ),
          );
        } on Object {
          /* A cancelled/expired lease must not write failure either. */
        }
      }
      return CommandExecutionResult(switch (error.failure) {
        AttachmentRemoteFailure.retryable => ExecutionDisposition.retryable,
        AttachmentRemoteFailure.authRequired =>
          ExecutionDisposition.authRequired,
        AttachmentRemoteFailure.permanent => ExecutionDisposition.permanent,
      }, errorCode: 'attachment_${error.failure.name}');
    } on _InactiveUpload {
      return const CommandExecutionResult(
        ExecutionDisposition.retryable,
        errorCode: 'inactive_upload_lease',
      );
    } on LocalRepositoryException catch (error) {
      return CommandExecutionResult(
        error.kind == LocalRepositoryFailure.sessionClosed
            ? ExecutionDisposition.authRequired
            : ExecutionDisposition.retryable,
        errorCode: error.kind == LocalRepositoryFailure.sessionClosed
            ? 'attachment_session_closed'
            : 'attachment_local_read_failed',
      );
    } on AttachmentException catch (error) {
      return CommandExecutionResult(
        error.failure == AttachmentFailure.cancelled
            ? ExecutionDisposition.retryable
            : ExecutionDisposition.permanent,
        errorCode: 'attachment_${error.failure.name}',
      );
    } on Object {
      return const CommandExecutionResult(
        ExecutionDisposition.retryable,
        errorCode: 'attachment_local_failure',
      );
    } finally {
      if (owns) {
        _snapshots.remove(snapshotKey);
        if (active[command.id] == command.leaseToken) active.remove(command.id);
      }
    }
  }
}
