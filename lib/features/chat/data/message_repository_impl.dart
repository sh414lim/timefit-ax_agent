import '../../../core/database/app_database.dart';
import '../../../core/database/local_repository_session.dart';
import '../domain/chat_message.dart';
import '../domain/repositories/message_repository.dart';

export '../../../core/database/local_repository_session.dart'
    show LocalRepositoryException, LocalRepositoryFailure;

final class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl({
    required AppDatabase database,
    LocalRepositorySession? session,
  }) : _database = database,
       _session = session ?? LocalRepositorySession.forDatabase(database);
  final AppDatabase _database;
  final LocalRepositorySession _session;

  List<ChatMessage> _map(List<LocalMessage> rows) => List.unmodifiable(
    rows.map(
      (row) => ChatMessage(
        clientMessageId: row.clientMessageId,
        sequence: row.sequence,
        body: row.bodyText ?? '',
        displayedAt: (row.serverCreatedAt ?? row.clientCreatedAt).toUtc(),
        isMine: row.senderKind == 'user',
        deliveryState: MessageDeliveryState.values.byName(row.deliveryState),
      ),
    ),
  );
  @override
  Future<List<ChatMessage>> readCachedMessages(String conversationId) =>
      _session.read(
        () async =>
            _map(await _database.messageDao.readTimeline(conversationId)),
      );
  @override
  Stream<List<ChatMessage>> watchCachedMessages(String conversationId) =>
      _session.watch(
        () => _database.messageDao.watchTimeline(conversationId).map(_map),
      );
  @override
  Future<void> dispose() => _session.dispose();
}
