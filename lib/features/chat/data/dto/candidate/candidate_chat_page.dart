enum CandidatePageMode { after, latest, cursor }

final class CandidatePageRequest {
  const CandidatePageRequest.after({
    required this.expectedConversationId,
    required int this.afterSequence,
  }) : mode = CandidatePageMode.after,
       cursor = null;

  const CandidatePageRequest.latest({required this.expectedConversationId})
    : mode = CandidatePageMode.latest,
      afterSequence = null,
      cursor = null;

  const CandidatePageRequest.cursor({
    required this.expectedConversationId,
    required String this.cursor,
  }) : mode = CandidatePageMode.cursor,
       afterSequence = null;

  final CandidatePageMode mode;
  final String expectedConversationId;
  final int? afterSequence;
  final String? cursor;
}

enum CandidateSenderKind { user, system }

enum CandidateMessageKind { text, system }

final class CandidateChatMessageDto {
  const CandidateChatMessageDto({
    required this.id,
    required this.conversationId,
    required this.clientMessageId,
    required this.sequence,
    required this.senderKind,
    required this.messageKind,
    required this.bodyText,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String clientMessageId;
  final int sequence;
  final CandidateSenderKind senderKind;
  final CandidateMessageKind messageKind;
  final String? bodyText;
  final DateTime createdAt;
}

/// Candidate DTO only. It is not an approved v1 response model.
final class CandidateChatPageDto {
  CandidateChatPageDto({
    required this.conversationId,
    required List<CandidateChatMessageDto> messages,
    required this.latestSequence,
    required this.hasMoreBefore,
    required this.hasMoreAfter,
    required this.nextCursor,
  }) : messages = List.unmodifiable(messages);

  final String conversationId;
  final List<CandidateChatMessageDto> messages;
  final int latestSequence;
  final bool hasMoreBefore;
  final bool hasMoreAfter;
  final String? nextCursor;
}
