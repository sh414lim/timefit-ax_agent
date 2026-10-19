import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_conversations.dart';

part 'conversation_dao.g.dart';

@DriftAccessor(tables: [LocalConversations])
class ConversationDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationDaoMixin {
  ConversationDao(super.attachedDatabase);

  Future<void> upsert(LocalConversationsCompanion conversation) =>
      into(localConversations).insertOnConflictUpdate(conversation);

  Future<List<LocalConversation>> getAll() => select(localConversations).get();
}
