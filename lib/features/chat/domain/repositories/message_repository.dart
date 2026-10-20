import '../chat_message.dart';

abstract interface class MessageRepository {
  Future<List<ChatMessage>> readCachedMessages(String conversationId);
  Stream<List<ChatMessage>> watchCachedMessages(String conversationId);
  Future<void> dispose();
}
