import '../../../core/database/app_database.dart';
import '../../../core/database/daos/conversation_dao.dart';
import '../../../core/database/local_repository_session.dart';
import '../domain/conversation_summary.dart';
import '../domain/repositories/conversation_repository.dart';

export '../../../core/database/local_repository_session.dart'
    show LocalRepositoryException, LocalRepositoryFailure;

final class ConversationRepositoryImpl implements LocalConversationRepository {
  ConversationRepositoryImpl({required AppDatabase database})
    : _database = database;
  final AppDatabase _database;
  final _session = LocalRepositorySession();

  List<ConversationSummary> _map(List<CachedConversationRow> rows) =>
      List.unmodifiable(
        rows.map(
          (row) => ConversationSummary(
            id: row.conversation.id,
            title: row.conversation.title ?? '',
            preview: row.preview,
            updatedAt: row.conversation.serverUpdatedAt.toUtc(),
          ),
        ),
      );

  @override
  Future<List<ConversationSummary>> readCachedConversations() => _session.read(
    () async => _map(await _database.conversationDao.readActive()),
  );
  @override
  Stream<List<ConversationSummary>> watchCachedConversations() =>
      _session.watch(() => _database.conversationDao.watchActive().map(_map));
  @override
  Future<List<ConversationSummary>> refreshConversations() => Future.error(
    const ConversationRepositoryException(
      ConversationRepositoryFailureKind.unavailable,
    ),
  );
  @override
  Future<void> dispose() => _session.dispose();
}
