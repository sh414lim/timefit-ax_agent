import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/message_dao.dart';
import '../../../core/database/local_repository_session.dart';
import '../application/history_controller.dart';
import '../application/send_message.dart';
import '../domain/chat_message.dart';

/// Local canonical metadata, never a network DTO or decoder. The ordinary
/// HistoryPage projection is validated by the existing keyset controller.
final class CanonicalHistoryPage extends HistoryPage {
  CanonicalHistoryPage({
    required super.conversationId,
    required List<CanonicalLocalMessage> canonicalMessages,
    required super.hasMoreBefore,
  }) : canonicalMessages = List.unmodifiable(canonicalMessages),
       super(
         messages: canonicalMessages
             .map(
               (message) => ChatMessage(
                 clientMessageId: message.clientMessageId,
                 sequence: message.sequence,
                 body: message.bodyText ?? '',
                 displayedAt: message.serverCreatedAt,
                 isMine: message.senderKind == 'user',
                 deliveryState: MessageDeliveryState.sent,
               ),
             )
             .toList(),
       );
  final List<CanonicalLocalMessage> canonicalMessages;
}

final class CancelledHistoryWrite implements Exception {
  const CancelledHistoryWrite();
}

final class DriftHistoryPageStore implements HistoryPagePersistence {
  DriftHistoryPageStore({
    required AppDatabase database,
    LocalRepositorySession? session,
  }) : _database = database,
       _session = session ?? LocalRepositorySession.forDatabase(database);
  final AppDatabase _database;
  final LocalRepositorySession _session;

  @override
  Future<void> persist(
    HistoryRequest request,
    HistoryPage originalPage,
    List<ChatMessage> acceptedMessages,
  ) => _session.write(_database, () async {
    void check() {
      if (request.isCancelled) throw const CancelledHistoryWrite();
    }

    check();
    if (originalPage is! CanonicalHistoryPage ||
        originalPage.conversationId != request.conversationId) {
      throw const FormatException('Canonical page metadata required');
    }
    final accepted = {
      for (final message in acceptedMessages) message.clientMessageId: message,
    };
    final canonical = <String, CanonicalLocalMessage>{};
    for (final message in originalPage.canonicalMessages) {
      if (message.conversationId != request.conversationId ||
          message.serverId.isEmpty) {
        throw const CanonicalIdentityConflict(
          'Canonical history conversation mismatch',
        );
      }
      final previous = canonical[message.clientMessageId];
      if (previous != null &&
          (previous.serverId != message.serverId ||
              previous.sequence != message.sequence ||
              previous.bodyText != message.bodyText ||
              previous.senderKind != message.senderKind ||
              previous.messageKind != message.messageKind ||
              previous.serverCreatedAt != message.serverCreatedAt)) {
        throw const CanonicalIdentityConflict(
          'Conflicting canonical duplicates',
        );
      }
      canonical[message.clientMessageId] = message;
    }
    for (final entry in accepted.entries) {
      check();
      final message = canonical[entry.key];
      if (message == null ||
          message.sequence != entry.value.sequence ||
          (message.bodyText ?? '') != entry.value.body ||
          message.sequence >= request.beforeSequence) {
        throw const CanonicalIdentityConflict(
          'Accepted projection differs from canonical metadata',
        );
      }
      final local =
          await (_database.select(_database.localMessages)..where(
                (row) =>
                    row.conversationId.equals(message.conversationId) &
                    row.clientMessageId.equals(message.clientMessageId),
              ))
              .getSingleOrNull();
      final command = local == null
          ? null
          : await (_database.select(
              _database.outboxCommands,
            )..where((row) => row.id.equals(local.localId))).getSingleOrNull();
      if (command != null && command.commandType == 'local_send_text_v1') {
        final expected = LocalTextCommand(
          id: local!.localId,
          conversationId: message.conversationId,
          bodyText: message.bodyText ?? '',
        ).encode();
        if (command.aggregateId != message.conversationId ||
            command.clientRequestId != message.clientMessageId ||
            command.payloadJson != expected ||
            command.lastErrorCode == 'payload_mismatch' ||
            message.senderKind != 'user' ||
            message.messageKind != 'text' ||
            command.state == 'cancelled') {
          throw const CanonicalIdentityConflict(
            'History conflicts with local command',
          );
        }
      }
      final row = await _database.messageDao.upsertCanonical(
        message,
        fallbackLocalId: 'history:${message.serverId}',
        fallbackClientCreatedAt: message.serverCreatedAt,
      );
      await (_database.update(_database.localMessages)
            ..where((m) => m.localId.equals(row.localId)))
          .write(const LocalMessagesCompanion(deliveryState: Value('sent')));
      if (command != null && command.commandType == 'local_send_text_v1') {
        await (_database.update(
          _database.outboxCommands,
        )..where((c) => c.id.equals(command.id))).write(
          OutboxCommandsCompanion(
            state: const Value('completed'),
            leaseOwner: const Value(null),
            leaseUntil: const Value(null),
            lastErrorCode: const Value(null),
            updatedAt: Value(message.serverCreatedAt),
          ),
        );
      }
    }
    check();
  });
}
