import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/local_repository_session.dart';

/// Persisted local command format only; this is not an RPC DTO.
final class LocalTextCommand {
  const LocalTextCommand({
    required this.id,
    required this.conversationId,
    required this.bodyText,
  });
  final String id;
  final String conversationId;
  final String bodyText;

  String encode() => jsonEncode({
    'localVersion': 1,
    'localMessageId': id,
    'clientMessageId': id,
    'conversationId': conversationId,
    'bodyText': bodyText,
  });
}

abstract interface class TextMessageSubmitter {
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  });

  Future<bool> retry(String commandId);
}

final class SendMessage implements TextMessageSubmitter {
  SendMessage({
    required AppDatabase database,
    required DateTime Function() clock,
    String Function()? clientMessageId,
    LocalRepositorySession? session,
  }) : _database = database,
       _session = session ?? LocalRepositorySession.forDatabase(database),
       _clock = clock,
       _clientMessageId = clientMessageId ?? (() => const Uuid().v4());
  final AppDatabase _database;
  final LocalRepositorySession _session;
  final DateTime Function() _clock;
  final String Function() _clientMessageId;

  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) => _session.write(_database, () async {
    final normalized = bodyText.replaceAll('\r\n', '\n');
    if (conversationId.isEmpty ||
        normalized.trim().isEmpty ||
        normalized.runes.length > 12000) {
      throw ArgumentError('Invalid local text submission');
    }
    final command = LocalTextCommand(
      id: _clientMessageId(),
      conversationId: conversationId,
      bodyText: normalized,
    );
    final now = _clock();
    await _database.outboxDao.enqueueMessage(
      LocalMessagesCompanion.insert(
        localId: command.id,
        conversationId: conversationId,
        clientMessageId: command.id,
        senderKind: 'user',
        bodyText: Value(normalized),
        messageKind: 'text',
        clientCreatedAt: now,
      ),
      OutboxCommandsCompanion.insert(
        id: command.id,
        commandType: 'local_send_text_v1',
        aggregateId: conversationId,
        clientRequestId: command.id,
        payloadJson: command.encode(),
        nextAttemptAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return command;
  });

  /// Requeues the stored command without replacing its identity or payload.
  Future<bool> retry(String commandId) => _session.write(_database, () async {
    final command = await (_database.select(
      _database.outboxCommands,
    )..where((row) => row.id.equals(commandId))).getSingleOrNull();
    if (command == null ||
        command.commandType != 'local_send_text_v1' ||
        command.lastErrorCode == 'payload_mismatch')
      return false;
    final changed = await _database.outboxDao.retryFailed(commandId, _clock());
    if (!changed) return false;
    await (_database.update(_database.localMessages)..where(
          (row) =>
              row.localId.equals(commandId) &
              row.conversationId.equals(command.aggregateId) &
              row.clientMessageId.equals(command.clientRequestId) &
              row.serverId.isNull(),
        ))
        .write(const LocalMessagesCompanion(deliveryState: Value('pending')));
    return true;
  });
}
