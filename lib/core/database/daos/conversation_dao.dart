import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_conversations.dart';

part 'conversation_dao.g.dart';

final class CachedConversationRow {
  const CachedConversationRow(this.conversation, this.preview);
  final LocalConversation conversation;
  final String preview;
}

@DriftAccessor(tables: [LocalConversations])
class ConversationDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationDaoMixin {
  ConversationDao(super.attachedDatabase);

  Future<void> upsert(LocalConversationsCompanion conversation) =>
      into(localConversations).insertOnConflictUpdate(conversation);

  Future<List<LocalConversation>> getAll() => select(localConversations).get();

  Selectable<CachedConversationRow> _active() =>
      customSelect(
        "SELECT c.*, m.body_text AS cached_preview FROM local_conversations c LEFT JOIN local_messages m ON m.server_id = c.last_message_id AND m.conversation_id = c.id WHERE c.status = 'active' ORDER BY c.server_updated_at DESC, c.id DESC",
        readsFrom: {localConversations, attachedDatabase.localMessages},
      ).map(
        (row) => CachedConversationRow(
          localConversations.map(row.data),
          row.readNullable<String>('cached_preview') ?? '',
        ),
      );

  Future<List<CachedConversationRow>> readActive() => _active().get();
  Stream<List<CachedConversationRow>> watchActive() => _active().watch();
}
