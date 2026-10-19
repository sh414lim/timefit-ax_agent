import 'conversation_summary.dart';

abstract interface class ConversationRepository {
  Future<List<ConversationSummary>> readCachedConversations();

  Future<List<ConversationSummary>> refreshConversations();
}

enum ConversationRepositoryFailureKind { offline, unavailable }

class ConversationRepositoryException implements Exception {
  const ConversationRepositoryException(this.kind);

  final ConversationRepositoryFailureKind kind;
}
