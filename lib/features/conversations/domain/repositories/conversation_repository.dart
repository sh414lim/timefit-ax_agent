import '../conversation_repository.dart';
import '../conversation_summary.dart';

export '../conversation_repository.dart';

abstract interface class LocalConversationRepository
    implements ConversationRepository {
  Stream<List<ConversationSummary>> watchCachedConversations();
  Future<void> dispose();
}
