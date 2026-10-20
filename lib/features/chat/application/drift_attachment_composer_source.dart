import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/local_repository_session.dart';
import 'composer_controller.dart';
import 'send_message.dart';

/// Local-only composer membership backed by Drift. Removing a failed chip
/// excludes it from the logical message without deleting its private file.
final class DriftAttachmentComposerSource implements AttachmentComposerSource {
  DriftAttachmentComposerSource({
    required AppDatabase database,
    required DateTime Function() clock,
    LocalRepositorySession? session,
  }) : _database = database,
       _clock = clock,
       _session = session ?? LocalRepositorySession.forDatabase(database);

  final AppDatabase _database;
  final DateTime Function() _clock;
  final LocalRepositorySession _session;

  @override
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  }) =>
      (_database.select(_database.localAttachments)..where(
            (row) =>
                row.conversationId.equals(conversationId) &
                row.clientMessageId.equals(clientMessageId) &
                row.composerExcluded.equals(false),
          ))
          .watch()
          .map(
            (rows) => List<ComposerAttachment>.unmodifiable(
              rows.map(
                (row) => ComposerAttachment(
                  localId: row.localId,
                  contentType: row.contentType,
                  state: _composerState(row.uploadState),
                  bytesSent: row.bytesSent,
                  bytesTotal: row.bytesTotal,
                ),
              ),
            ),
          );

  @override
  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) => _session.write(
    _database,
    () => _database.transaction(() async {
      final attachment = await (_database.select(
        _database.localAttachments,
      )..where((row) => row.localId.equals(localId))).getSingleOrNull();
      if (attachment == null ||
          attachment.conversationId != conversationId ||
          attachment.clientMessageId != clientMessageId ||
          attachment.composerExcluded ||
          attachment.uploadState != 'failed') {
        return;
      }

      final command = await (_database.select(
        _database.outboxCommands,
      )..where((row) => row.id.equals(clientMessageId))).getSingleOrNull();
      if (command != null) {
        if (command.commandType != 'local_send_message_v2' ||
            command.aggregateId != conversationId ||
            command.clientRequestId != clientMessageId ||
            !const {
              'queued',
              'retry_wait',
              'failed_permanent',
            }.contains(command.state)) {
          throw StateError('Attachment aggregate cannot be edited');
        }
        final payload = LocalAttachmentMessageCommand.decode(
          command.payloadJson,
        );
        if (!payload.localAttachmentIds.contains(localId)) {
          throw StateError('Attachment is not part of the aggregate');
        }
        final remaining = payload.localAttachmentIds
            .where((id) => id != localId)
            .toList(growable: false);
        final now = _clock();
        if (remaining.isEmpty && payload.bodyText.isEmpty) {
          final changed =
              await (_database.update(_database.outboxCommands)..where(
                    (row) =>
                        row.id.equals(command.id) &
                        row.state.equals(command.state),
                  ))
                  .write(
                    OutboxCommandsCompanion(
                      state: const Value('cancelled'),
                      leaseOwner: const Value(null),
                      leaseUntil: const Value(null),
                      lastErrorCode: const Value(null),
                      updatedAt: Value(now),
                    ),
                  );
          if (changed != 1) {
            throw StateError('Attachment aggregate changed concurrently');
          }
          await (_database.update(
            _database.localMessages,
          )..where((row) => row.localId.equals(clientMessageId))).write(
            const LocalMessagesCompanion(deliveryState: Value('failed')),
          );
        } else {
          final revised = LocalAttachmentMessageCommand(
            id: payload.id,
            conversationId: payload.conversationId,
            bodyText: payload.bodyText,
            localAttachmentIds: remaining,
          );
          final changed =
              await (_database.update(_database.outboxCommands)..where(
                    (row) =>
                        row.id.equals(command.id) &
                        row.state.equals(command.state),
                  ))
                  .write(
                    OutboxCommandsCompanion(
                      payloadJson: Value(revised.encode()),
                      state: const Value('queued'),
                      nextAttemptAt: Value(now),
                      leaseOwner: const Value(null),
                      leaseUntil: const Value(null),
                      lastErrorCode: const Value(null),
                      updatedAt: Value(now),
                    ),
                  );
          if (changed != 1) {
            throw StateError('Attachment aggregate changed concurrently');
          }
          await (_database.update(
            _database.localMessages,
          )..where((row) => row.localId.equals(clientMessageId))).write(
            LocalMessagesCompanion(
              messageKind: Value(
                payload.bodyText.isEmpty ? 'attachment' : 'mixed',
              ),
            ),
          );
        }
      }

      await (_database.update(_database.localAttachments)..where(
            (row) =>
                row.localId.equals(localId) &
                row.uploadState.equals('failed') &
                row.composerExcluded.equals(false),
          ))
          .write(
            const LocalAttachmentsCompanion(composerExcluded: Value(true)),
          );
    }),
  );
}

ComposerAttachmentState _composerState(String value) => switch (value) {
  'failed' => ComposerAttachmentState.failed,
  'ready' || 'bound' => ComposerAttachmentState.ready,
  'uploading' || 'finalizing' => ComposerAttachmentState.uploading,
  _ => ComposerAttachmentState.queued,
};
