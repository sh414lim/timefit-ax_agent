import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/message_dao.dart';
import '../../../core/database/local_repository_session.dart';
import '../application/send_message.dart';

/// Domain input seam for synthetic/local canonical fixtures. No wire decoder.
final class CanonicalTextMessage {
  const CanonicalTextMessage({
    required this.serverId,
    required this.conversationId,
    required this.clientMessageId,
    required this.sequence,
    required this.bodyText,
    required this.serverCreatedAt,
  });
  final String serverId;
  final String conversationId;
  final String clientMessageId;
  final int sequence;
  final String bodyText;
  final DateTime serverCreatedAt;
}

enum ReconciliationResult { applied, cancelled, permanentFailure }

final class MessageReconciler {
  MessageReconciler({
    required AppDatabase database,
    required DateTime Function() clock,
    LocalRepositorySession? session,
  }) : _database = database,
       _session = session ?? LocalRepositorySession.forDatabase(database),
       _clock = clock;
  final AppDatabase _database;
  final LocalRepositorySession _session;
  final DateTime Function() _clock;

  Future<ReconciliationResult> reconcile({
    required String commandId,
    required CanonicalTextMessage canonical,
  }) => _session.write(_database, () async {
    final command = await (_database.select(
      _database.outboxCommands,
    )..where((row) => row.id.equals(commandId))).getSingle();
    final message = await (_database.select(
      _database.localMessages,
    )..where((row) => row.localId.equals(commandId))).getSingle();
    if (command.commandType != 'local_send_text_v1' ||
        command.aggregateId != canonical.conversationId ||
        command.clientRequestId != canonical.clientMessageId ||
        message.conversationId != canonical.conversationId ||
        message.clientMessageId != canonical.clientMessageId) {
      throw const CanonicalIdentityConflict(
        'canonical does not belong to the local command',
      );
    }
    if (command.state == 'cancelled') return ReconciliationResult.cancelled;
    if (command.state == 'failed_permanent')
      return ReconciliationResult.permanentFailure;
    // Validate canonical identity before any mismatch writes; a conflicting
    // server/sequence must never mutate even the failure state of another row.
    if ((message.serverId != null && message.serverId != canonical.serverId) ||
        (message.sequence != null && message.sequence != canonical.sequence)) {
      throw const CanonicalIdentityConflict(
        'canonical rewrites local identity',
      );
    }
    final identityRows =
        await (_database.select(_database.localMessages)..where(
              (row) =>
                  row.serverId.equals(canonical.serverId) |
                  (row.conversationId.equals(canonical.conversationId) &
                      row.sequence.equals(canonical.sequence)),
            ))
            .get();
    if (identityRows.any((row) => row.localId != message.localId)) {
      throw const CanonicalIdentityConflict(
        'canonical identity belongs to another row',
      );
    }
    final expected = LocalTextCommand(
      id: commandId,
      conversationId: message.conversationId,
      bodyText: message.bodyText ?? '',
    ).encode();
    if (command.payloadJson != expected ||
        message.bodyText != canonical.bodyText) {
      if (command.state == 'completed')
        throw const CanonicalIdentityConflict(
          'completed canonical payload changed',
        );
      await (_database.update(
        _database.outboxCommands,
      )..where((row) => row.id.equals(commandId))).write(
        OutboxCommandsCompanion(
          state: const Value('failed_permanent'),
          lastErrorCode: const Value('payload_mismatch'),
          leaseOwner: const Value(null),
          leaseUntil: const Value(null),
          updatedAt: Value(_clock()),
        ),
      );
      await (_database.update(_database.localMessages)
            ..where((row) => row.localId.equals(commandId)))
          .write(const LocalMessagesCompanion(deliveryState: Value('failed')));
      return ReconciliationResult.permanentFailure;
    }
    await _database.messageDao.upsertCanonical(
      CanonicalLocalMessage(
        serverId: canonical.serverId,
        conversationId: canonical.conversationId,
        clientMessageId: canonical.clientMessageId,
        sequence: canonical.sequence,
        senderKind: 'user',
        bodyText: canonical.bodyText,
        messageKind: 'text',
        serverCreatedAt: canonical.serverCreatedAt,
      ),
      fallbackLocalId: commandId,
      fallbackClientCreatedAt: message.clientCreatedAt,
    );
    await (_database.update(_database.localMessages)
          ..where((row) => row.localId.equals(commandId)))
        .write(const LocalMessagesCompanion(deliveryState: Value('sent')));
    await (_database.update(
      _database.outboxCommands,
    )..where((row) => row.id.equals(commandId))).write(
      OutboxCommandsCompanion(
        state: const Value('completed'),
        lastErrorCode: const Value(null),
        leaseOwner: const Value(null),
        leaseUntil: const Value(null),
        updatedAt: Value(_clock()),
      ),
    );
    return ReconciliationResult.applied;
  });
}
