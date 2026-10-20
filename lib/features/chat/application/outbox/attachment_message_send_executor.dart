import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_repository_session.dart';
import '../send_message.dart';
import 'command_executor.dart';

final class LocalMessageSendRequest {
  LocalMessageSendRequest({
    required this.clientMessageId,
    required this.conversationId,
    required this.bodyText,
    required List<String> attachmentIds,
  }) : attachmentIds = List.unmodifiable(attachmentIds);

  final String clientMessageId;
  final String conversationId;
  final String bodyText;
  final List<String> attachmentIds;
}

/// An injected local seam only. CHAT-013/016 own the future RPC adapter and
/// wire contract; this port deliberately has no SDK or JSON dependency.
abstract interface class LocalMessageSendPort {
  Future<CommandExecutionResult> send(LocalMessageSendRequest request);
}

/// Prevents the injected send port from observing an aggregate until every
/// referenced local attachment is durably ready. A successful fake call does
/// not bind attachments or delete private copies.
final class AttachmentMessageSendExecutor implements CommandExecutor {
  AttachmentMessageSendExecutor({
    required AppDatabase database,
    required this.sender,
    required DateTime Function() clock,
    LocalRepositorySession? session,
  }) : _database = database,
       _clock = clock,
       _session = session ?? LocalRepositorySession.forDatabase(database);

  final AppDatabase _database;
  final DateTime Function() _clock;
  final LocalRepositorySession _session;
  final LocalMessageSendPort sender;

  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) async {
    try {
      if (command.commandType != 'local_send_message_v2' ||
          command.id != command.clientRequestId ||
          command.aggregateId.isEmpty) {
        return const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'message_aggregate_invalid',
        );
      }
      final payload = LocalAttachmentMessageCommand.decode(command.payloadJson);
      if (payload.id != command.id ||
          payload.conversationId != command.aggregateId ||
          payload.localAttachmentIds.isEmpty ||
          payload.localAttachmentIds.length > 5 ||
          payload.localAttachmentIds.toSet().length !=
              payload.localAttachmentIds.length) {
        return const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'message_aggregate_invalid',
        );
      }
      final snapshot = await _session.read(() async {
        final persistedCommand = await (_database.select(
          _database.outboxCommands,
        )..where((row) => row.id.equals(command.id))).getSingleOrNull();
        final message = await (_database.select(
          _database.localMessages,
        )..where((row) => row.localId.equals(command.id))).getSingleOrNull();
        final attachments = await (_database.select(
          _database.localAttachments,
        )..where((row) => row.localId.isIn(payload.localAttachmentIds))).get();
        return (persistedCommand, message, attachments);
      });
      final (persistedCommand, message, attachments) = snapshot;
      if (persistedCommand == null ||
          command.leaseToken == null ||
          persistedCommand.state != 'running' ||
          persistedCommand.leaseOwner != command.leaseToken ||
          persistedCommand.leaseUntil == null ||
          !persistedCommand.leaseUntil!.isAfter(_clock())) {
        return const CommandExecutionResult(
          ExecutionDisposition.retryable,
          errorCode: 'inactive_message_lease',
        );
      }
      if (persistedCommand.clientRequestId != command.clientRequestId ||
          persistedCommand.commandType != command.commandType ||
          persistedCommand.aggregateId != command.aggregateId ||
          persistedCommand.payloadJson != command.payloadJson ||
          message == null ||
          message.conversationId != payload.conversationId ||
          message.clientMessageId != payload.id ||
          (message.bodyText ?? '') != payload.bodyText ||
          attachments.length != payload.localAttachmentIds.length ||
          attachments.any(
            (row) =>
                row.conversationId != payload.conversationId ||
                row.clientMessageId != payload.id,
          )) {
        return const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'message_aggregate_invalid',
        );
      }
      if (attachments.any((row) => row.uploadState == 'failed')) {
        return const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'attachment_failed',
        );
      }
      if (attachments.any((row) => row.uploadState != 'ready')) {
        return const CommandExecutionResult(
          ExecutionDisposition.retryable,
          errorCode: 'attachments_not_ready',
        );
      }
      final byLocalId = {for (final row in attachments) row.localId: row};
      final attachmentIds = <String>[];
      for (final localId in payload.localAttachmentIds) {
        final attachmentId = byLocalId[localId]?.attachmentId;
        if (attachmentId == null || attachmentId.isEmpty) {
          return const CommandExecutionResult(
            ExecutionDisposition.permanent,
            errorCode: 'ready_attachment_identity_missing',
          );
        }
        attachmentIds.add(attachmentId);
      }
      return sender.send(
        LocalMessageSendRequest(
          clientMessageId: payload.id,
          conversationId: payload.conversationId,
          bodyText: payload.bodyText,
          attachmentIds: attachmentIds,
        ),
      );
    } on FormatException {
      return const CommandExecutionResult(
        ExecutionDisposition.permanent,
        errorCode: 'message_payload_invalid',
      );
    } on LocalRepositoryException catch (error) {
      return CommandExecutionResult(
        error.kind == LocalRepositoryFailure.sessionClosed
            ? ExecutionDisposition.authRequired
            : ExecutionDisposition.retryable,
        errorCode: error.kind == LocalRepositoryFailure.sessionClosed
            ? 'message_session_closed'
            : 'message_local_read_failed',
      );
    } on Object {
      return const CommandExecutionResult(
        ExecutionDisposition.retryable,
        errorCode: 'message_local_read_failed',
      );
    }
  }
}
