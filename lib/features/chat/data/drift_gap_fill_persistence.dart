import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/message_dao.dart';
import '../../../core/database/local_repository_session.dart';
import '../application/gap_fill_controller.dart';
import '../application/send_message.dart';

final class CancelledGapFillWrite implements Exception {
  const CancelledGapFillWrite();
}

/// Drift implementation for already-decoded canonical domain messages. This
/// owns no network adapter and never persists the triggering hint payload.
final class DriftGapFillPersistence implements GapFillPersistence {
  DriftGapFillPersistence({
    required AppDatabase database,
    LocalRepositorySession? session,
  }) : _database = database,
       _session = session ?? LocalRepositorySession.forDatabase(database);

  final AppDatabase _database;
  final LocalRepositorySession _session;

  @override
  Future<int> readLatestSequence(String conversationId) => _session.read(
    () async {
      final expression = _database.localMessages.sequence.max();
      final row =
          await (_database.selectOnly(_database.localMessages)
                ..addColumns([expression])
                ..where(
                  _database.localMessages.conversationId.equals(conversationId),
                ))
              .getSingle();
      return row.read(expression) ?? 0;
    },
  );

  @override
  Future<void> persist(
    GapFillRequest request,
    GapFillPage originalPage,
    List<CanonicalLocalMessage> acceptedMessages,
  ) => _session.write(_database, () async {
    void check() {
      if (request.isCancelled) throw const CancelledGapFillWrite();
    }

    check();
    if (originalPage.conversationId != request.conversationId) {
      throw const CanonicalIdentityConflict(
        'gap-fill page conversation changed before persistence',
      );
    }
    final originals = <int, CanonicalLocalMessage>{};
    for (final message in originalPage.messages) {
      if (message.conversationId != request.conversationId) {
        throw const CanonicalIdentityConflict(
          'gap-fill canonical conversation mismatch',
        );
      }
      originals[message.sequence] = message;
    }
    for (final message in acceptedMessages) {
      check();
      if (!identical(originals[message.sequence], message)) {
        throw const CanonicalIdentityConflict(
          'accepted gap-fill message differs from source page',
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
            'gap-fill conflicts with local send command',
          );
        }
      }
      final row = await _database.messageDao.upsertCanonical(
        message,
        fallbackLocalId: 'gap:${message.serverId}',
        fallbackClientCreatedAt: message.serverCreatedAt,
      );
      await (_database.update(_database.localMessages)
            ..where((candidate) => candidate.localId.equals(row.localId)))
          .write(const LocalMessagesCompanion(deliveryState: Value('sent')));
      if (command != null && command.commandType == 'local_send_text_v1') {
        await (_database.update(
          _database.outboxCommands,
        )..where((candidate) => candidate.id.equals(command.id))).write(
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
