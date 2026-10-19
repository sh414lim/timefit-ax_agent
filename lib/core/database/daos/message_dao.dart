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

@DriftAccessor(tables: [LocalMessages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.attachedDatabase);

  Future<LocalMessage> upsertCanonical(
    CanonicalLocalMessage canonical, {
    required String fallbackLocalId,
    required DateTime fallbackClientCreatedAt,
  }) => transaction(() async {
    final query = select(localMessages)
      ..where(
        (message) =>
            message.serverId.equals(canonical.serverId) |
            (message.conversationId.equals(canonical.conversationId) &
                message.clientMessageId.equals(canonical.clientMessageId)) |
            (message.conversationId.equals(canonical.conversationId) &
                message.sequence.equals(canonical.sequence)),
      );
    final existing = await query.getSingleOrNull();
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
}
