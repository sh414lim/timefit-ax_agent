import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_messages.dart';

part 'message_dao.g.dart';

final class CanonicalLocalMessage {
  const CanonicalLocalMessage({
    required this.serverId,
    required this.conversationId,
    required this.clientMessageId,
    required this.sequence,
    required this.senderKind,
    required this.bodyText,
    required this.messageKind,
    required this.serverCreatedAt,
  });

  final String serverId;
  final String conversationId;
  final String clientMessageId;
  final int sequence;
  final String senderKind;
  final String? bodyText;
  final String messageKind;
  final DateTime serverCreatedAt;
}

final class CanonicalIdentityConflict implements Exception {
  const CanonicalIdentityConflict(this.reason);

  final String reason;

  @override
  String toString() => 'Canonical identity conflict: $reason';
}

@DriftAccessor(tables: [LocalMessages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.attachedDatabase);

  Future<LocalMessage> upsertCanonical(
    CanonicalLocalMessage canonical, {
    required String fallbackLocalId,
    required DateTime fallbackClientCreatedAt,
  }) => transaction(() async {
    final serverMatch =
        await (select(localMessages)
              ..where((message) => message.serverId.equals(canonical.serverId)))
            .getSingleOrNull();
    final clientMatch =
        await (select(localMessages)..where(
              (message) =>
                  message.conversationId.equals(canonical.conversationId) &
                  message.clientMessageId.equals(canonical.clientMessageId),
            ))
            .getSingleOrNull();
    final sequenceMatch =
        await (select(localMessages)..where(
              (message) =>
                  message.conversationId.equals(canonical.conversationId) &
                  message.sequence.equals(canonical.sequence),
            ))
            .getSingleOrNull();
    final fallbackMatch =
        await (select(localMessages)
              ..where((message) => message.localId.equals(fallbackLocalId)))
            .getSingleOrNull();

    final identityMatches = <LocalMessage>{
      if (serverMatch != null) serverMatch,
      if (clientMatch != null) clientMatch,
      if (sequenceMatch != null) sequenceMatch,
    };
    final identityLocalIds = identityMatches.map((row) => row.localId).toSet();
    if (identityLocalIds.length > 1) {
      throw const CanonicalIdentityConflict(
        'server, client, and sequence keys resolve to different rows',
      );
    }

    final existing = identityMatches.isEmpty
        ? fallbackMatch
        : identityMatches.first;
    if (existing != null &&
        fallbackMatch != null &&
        existing.localId != fallbackMatch.localId) {
      throw const CanonicalIdentityConflict(
        'fallback local id belongs to a different row',
      );
    }
    if (existing != null) {
      _validateImmutableIdentity(existing, canonical);
    }
    final localId = existing?.localId ?? fallbackLocalId;
    final deliveryState = existing?.deliveryState ?? 'sent';
    final clientCreatedAt =
        existing?.clientCreatedAt ?? fallbackClientCreatedAt;

    final row = LocalMessagesCompanion.insert(
      localId: localId,
      serverId: Value(canonical.serverId),
      conversationId: canonical.conversationId,
      clientMessageId: canonical.clientMessageId,
      sequence: Value(canonical.sequence),
      senderKind: canonical.senderKind,
      bodyText: Value(canonical.bodyText),
      messageKind: canonical.messageKind,
      clientCreatedAt: clientCreatedAt,
      serverCreatedAt: Value(canonical.serverCreatedAt),
      deliveryState: Value(deliveryState),
    );
    await into(localMessages).insertOnConflictUpdate(row);
    return (select(
      localMessages,
    )..where((message) => message.localId.equals(localId))).getSingle();
  });

  Future<List<LocalMessage>> getAll() => select(localMessages).get();

  Selectable<LocalMessage> _timeline(String conversationId) => customSelect(
    'SELECT * FROM local_messages WHERE conversation_id = ? ORDER BY sequence IS NULL, sequence ASC, rowid ASC',
    variables: [Variable(conversationId)],
    readsFrom: {localMessages},
  ).map((row) => localMessages.map(row.data));

  Future<List<LocalMessage>> readTimeline(String conversationId) =>
      _timeline(conversationId).get();
  Stream<List<LocalMessage>> watchTimeline(String conversationId) =>
      _timeline(conversationId).watch();

  void _validateImmutableIdentity(
    LocalMessage existing,
    CanonicalLocalMessage canonical,
  ) {
    if (existing.conversationId != canonical.conversationId ||
        existing.clientMessageId != canonical.clientMessageId ||
        (existing.serverId != null &&
            existing.serverId != canonical.serverId) ||
        (existing.sequence != null &&
            existing.sequence != canonical.sequence)) {
      throw const CanonicalIdentityConflict(
        'canonical input would rewrite an existing identity',
      );
    }
  }
}
