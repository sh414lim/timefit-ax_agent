import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/local_repository_session.dart';
import '../application/conversation_actions.dart';
import '../domain/conversation_summary.dart';
import '../domain/repositories/conversation_repository.dart';

/// Development-only local conversation source. It never represents a remote
/// refresh or a server response.
final class DevLocalConversationRepository
    implements LocalConversationRepository, ConversationActionsRepository {
  DevLocalConversationRepository({
    required AppDatabase database,
    required LocalRepositorySession session,
    DateTime Function()? clock,
    String Function()? conversationId,
  }) : _database = database,
       _session = session,
       _clock = clock ?? DateTime.now,
       _conversationId = conversationId ?? (() => const Uuid().v4());

  final AppDatabase _database;
  final LocalRepositorySession _session;
  final DateTime Function() _clock;
  final String Function() _conversationId;
  Future<String>? _activeCreate;

  Selectable<ConversationSummary> _byStatus(String status) => _database
      .customSelect(
        '''
SELECT c.*,
  COALESCE((
    SELECT m.body_text
    FROM local_messages m
    WHERE m.conversation_id = c.id
    ORDER BY m.rowid DESC
    LIMIT 1
  ), '') AS local_preview,
  COALESCE((
    SELECT m.client_created_at
    FROM local_messages m
    WHERE m.conversation_id = c.id
    ORDER BY m.rowid DESC
    LIMIT 1
  ), c.server_updated_at) AS local_updated_at
FROM local_conversations c
WHERE c.status = ?
ORDER BY local_updated_at DESC, c.rowid DESC
''',
        variables: <Variable<Object>>[Variable<String>(status)],
        readsFrom: {_database.localConversations, _database.localMessages},
      )
      .map((row) {
        final conversation = _database.localConversations.map(row.data);
        return ConversationSummary(
          id: conversation.id,
          title: conversation.title ?? '새 대화',
          preview: row.read<String>('local_preview'),
          updatedAt: row.read<DateTime>('local_updated_at').toUtc(),
        );
      });

  @override
  Future<List<ConversationSummary>> readCachedConversations() =>
      _session.read(() => _byStatus('active').get());

  @override
  Stream<List<ConversationSummary>> watchCachedConversations() =>
      _session.watch(() => _byStatus('active').watch());

  Future<List<ConversationSummary>> readArchivedConversations() =>
      _session.read(() => _byStatus('archived').get());

  Stream<List<ConversationSummary>> watchArchivedConversations() =>
      _session.watch(() => _byStatus('archived').watch());

  @override
  Future<List<ConversationSummary>> refreshConversations() =>
      Future.error(StateError('remote_refresh_unavailable_in_dev_local_mode'));

  Future<String> createConversation() {
    if (_activeCreate case final active?) return active;
    late final Future<String> operation;
    operation = _createConversation().whenComplete(() {
      if (identical(_activeCreate, operation)) _activeCreate = null;
    });
    _activeCreate = operation;
    return operation;
  }

  Future<String> _createConversation() => _session.write(_database, () async {
    final id = _conversationId();
    final now = _clock().toUtc();
    await _database.conversationDao.upsert(
      LocalConversationsCompanion.insert(
        id: id,
        title: const Value(null),
        serverCreatedAt: now,
        serverUpdatedAt: now,
        lastSyncedAt: now,
        syncState: const Value('stale'),
      ),
    );
    return id;
  });

  @override
  Future<void> renameConversation(String conversationId, String? title) =>
      _session.write(_database, () async {
        final bool changed = await _database.conversationDao.renameLocal(
          id: conversationId,
          title: title,
          updatedAt: _clock().toUtc(),
        );
        if (!changed) throw StateError('local_conversation_not_found');
      });

  @override
  Future<void> archiveConversation(String conversationId) =>
      _session.write(_database, () async {
        final bool changed = await _database.conversationDao.archiveLocal(
          id: conversationId,
          updatedAt: _clock().toUtc(),
        );
        if (!changed) throw StateError('local_conversation_not_active');
      });

  /// The shell owns the shared session and database lifecycle.
  @override
  Future<void> dispose() async {}
}
