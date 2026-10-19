enum MessageDeliveryState { pending, uploading, sending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.clientMessageId,
    required this.sequence,
    required this.body,
    required this.displayedAt,
    required this.isMine,
    required this.deliveryState,
  });

  final String clientMessageId;
  final int? sequence;
  final String body;
  final DateTime displayedAt;
  final bool isMine;
  final MessageDeliveryState deliveryState;
}
