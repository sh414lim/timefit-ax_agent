import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/local_repository_session.dart';

String normalizeLocalTextBody(String value) => value.replaceAll('\r\n', '\n');

int normalizedLocalTextLength(String value) =>
    normalizeLocalTextBody(value).runes.length;

String truncateLocalTextBody(String value, int maximumLength) {
  if (normalizedLocalTextLength(value) <= maximumLength) return value;
  final List<int> runes = value.runes.toList(growable: false);
  final StringBuffer result = StringBuffer();
  var length = 0;
  for (var index = 0; index < runes.length && length < maximumLength; index++) {
    final int rune = runes[index];
    result.writeCharCode(rune);
    if (rune == 13 && index + 1 < runes.length && runes[index + 1] == 10) {
      result.writeCharCode(runes[++index]);
    }
    length += 1;
  }
  return result.toString();
}

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

/// Persisted local aggregate for CHAT-052. Attachment identifiers are local
/// row identities, never server/RPC identifiers.
final class LocalAttachmentMessageCommand {
  LocalAttachmentMessageCommand({
    required this.id,
    required this.conversationId,
    required this.bodyText,
    required List<String> localAttachmentIds,
  }) : localAttachmentIds = List.unmodifiable(localAttachmentIds);

  final String id;
  final String conversationId;
  final String bodyText;
  final List<String> localAttachmentIds;

  String encode() => jsonEncode({
    'localVersion': 1,
    'localMessageId': id,
    'clientMessageId': id,
    'conversationId': conversationId,
    'bodyText': bodyText,
    'localAttachmentIds': localAttachmentIds,
  });

  static LocalAttachmentMessageCommand decode(String value) {
    final Object? decoded = jsonDecode(value);
    if (decoded is! Map<String, Object?> ||
        decoded['localVersion'] != 1 ||
        decoded['localMessageId'] is! String ||
        decoded['clientMessageId'] != decoded['localMessageId'] ||
        decoded['conversationId'] is! String ||
        decoded['bodyText'] is! String ||
        decoded['localAttachmentIds'] is! List<Object?>) {
      throw const FormatException('Invalid local attachment message payload');
    }
    final ids = decoded['localAttachmentIds']! as List<Object?>;
    if (ids.any((id) => id is! String)) {
      throw const FormatException('Invalid local attachment identities');
    }
    return LocalAttachmentMessageCommand(
      id: decoded['localMessageId']! as String,
      conversationId: decoded['conversationId']! as String,
      bodyText: decoded['bodyText']! as String,
      localAttachmentIds: ids.cast<String>(),
    );
  }
}

abstract interface class AttachmentMessageSubmitter {
  Future<LocalAttachmentMessageCommand> submitWithAttachments({
    required String clientMessageId,
    required String conversationId,
    required String bodyText,
    required List<String> localAttachmentIds,
  });
}

abstract interface class TextMessageSubmitter {
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  });

  Future<bool> retry(String commandId);
}

final class SendMessage
    implements TextMessageSubmitter, AttachmentMessageSubmitter {
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

  @override
  Future<LocalAttachmentMessageCommand> submitWithAttachments({
    required String clientMessageId,
    required String conversationId,
    required String bodyText,
    required List<String> localAttachmentIds,
  }) => _session.write(_database, () async {
    final normalized = normalizeLocalTextBody(bodyText);
    final ids = List<String>.unmodifiable(localAttachmentIds);
    if (clientMessageId.isEmpty ||
        conversationId.isEmpty ||
        ids.isEmpty ||
        ids.length > 5 ||
        ids.toSet().length != ids.length ||
        ids.any((id) => id.isEmpty) ||
        normalizedLocalTextLength(bodyText) > 12000) {
      throw ArgumentError('Invalid local attachment submission');
    }
    final attachments = await (_database.select(
      _database.localAttachments,
    )..where((row) => row.localId.isIn(ids))).get();
    if (attachments.length != ids.length ||
        attachments.any(
          (row) =>
              row.conversationId != conversationId ||
              row.clientMessageId != clientMessageId,
        )) {
      throw ArgumentError('Attachment aggregate identity mismatch');
    }
    final command = LocalAttachmentMessageCommand(
      id: clientMessageId,
      conversationId: conversationId,
      bodyText: normalized,
      localAttachmentIds: ids,
    );
    final existingMessage = await (_database.select(
      _database.localMessages,
    )..where((row) => row.localId.equals(clientMessageId))).getSingleOrNull();
    final existingCommand = await (_database.select(
      _database.outboxCommands,
    )..where((row) => row.id.equals(clientMessageId))).getSingleOrNull();
    if (existingMessage != null || existingCommand != null) {
      if (existingMessage == null ||
          existingCommand == null ||
          existingMessage.conversationId != conversationId ||
          existingMessage.clientMessageId != clientMessageId ||
          (existingMessage.bodyText ?? '') != normalized ||
          existingCommand.commandType != 'local_send_message_v2' ||
          existingCommand.aggregateId != conversationId ||
          existingCommand.clientRequestId != clientMessageId ||
          existingCommand.payloadJson != command.encode()) {
        throw ArgumentError('Conflicting local message aggregate');
      }
      return command;
    }
    final now = _clock();
    await _database.outboxDao.enqueueMessage(
      LocalMessagesCompanion.insert(
        localId: clientMessageId,
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        senderKind: 'user',
        bodyText: Value(normalized.trim().isEmpty ? null : normalized),
        messageKind: normalized.trim().isEmpty ? 'attachment' : 'mixed',
        clientCreatedAt: now,
        deliveryState: const Value('uploading'),
      ),
      OutboxCommandsCompanion.insert(
        id: clientMessageId,
        commandType: 'local_send_message_v2',
        aggregateId: conversationId,
        clientRequestId: clientMessageId,
        payloadJson: command.encode(),
        nextAttemptAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return command;
  });

  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) => _session.write(_database, () async {
    final normalized = normalizeLocalTextBody(bodyText);
    if (conversationId.isEmpty ||
        normalized.trim().isEmpty ||
        normalizedLocalTextLength(bodyText) > 12000) {
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
