import '../../../../../core/network/candidate/candidate_contract_failure.dart';
import '../../../../../core/network/candidate/candidate_decode_budget.dart';
import '../../../../../core/network/candidate/candidate_validation.dart';
import 'candidate_chat_page.dart';

/// Decoder for a deliberately unapproved candidate JSON shape.
///
/// This type has no production export or domain mapper. Parsed values and raw
/// JSON use separate entry points and fail closed without retaining raw input.
final class CandidateChatPageDecoder {
  const CandidateChatPageDecoder({this.budget = const CandidateDecodeBudget()});

  final CandidateDecodeBudget budget;

  /// Backward-compatible parsed-value entry point.
  ///
  /// A String passed here is an already parsed scalar. Raw JSON text must use
  /// [decodeJsonText], so input origin is never inferred from runtime type.
  CandidateDecodeResult<CandidateChatPageDto> decode(
    Object? parsedValue, {
    required CandidatePageRequest request,
  }) => decodeParsed(parsedValue, request: request);

  CandidateDecodeResult<CandidateChatPageDto> _decode(
    CandidateDecodeInput input, {
    required CandidatePageRequest request,
  }) {
    try {
      final requestFailure = _validateRequest(request);
      if (requestFailure != null) return CandidateRejected(requestFailure);
      final bounded = decodeCandidateJsonWithinBudget(input, budget: budget);
      if (bounded is CandidateBudgetRejected) {
        return _reject(CandidateContractFailureCode.inputBudgetExceeded);
      }
      if (bounded is! CandidateBoundedValue) {
        return _reject(CandidateContractFailureCode.contractInvalid);
      }
      final root = candidateStringKeyedMap(bounded.value);
      if (root == null)
        return _reject(CandidateContractFailureCode.contractInvalid);

      final version = root['schemaVersion'];
      if (version is! int) {
        return _reject(CandidateContractFailureCode.contractInvalid);
      }
      if (version != 1) {
        return _reject(CandidateContractFailureCode.unsupportedSchemaVersion);
      }

      final conversationId = root['conversationId'];
      if (conversationId is! String) {
        return _reject(CandidateContractFailureCode.contractInvalid);
      }
      if (!isCandidateUuid(conversationId)) {
        return _reject(CandidateContractFailureCode.invalidUuid);
      }
      if (conversationId != request.expectedConversationId) {
        return _reject(CandidateContractFailureCode.conversationMismatch);
      }

      final rawLatestSequence = root['latestSequence'];
      if (rawLatestSequence is! int) {
        return _reject(CandidateContractFailureCode.contractInvalid);
      }
      final latestSequence = _sequence(rawLatestSequence, allowZero: true);
      if (latestSequence == null) {
        return _reject(CandidateContractFailureCode.unsafeInteger);
      }
      final hasMoreBefore = root['hasMoreBefore'];
      final hasMoreAfter = root['hasMoreAfter'];
      if (hasMoreBefore is! bool || hasMoreAfter is! bool) {
        return _reject(CandidateContractFailureCode.contractInvalid);
      }
      final nextCursorValue = root['nextCursor'];
      if (nextCursorValue != null &&
          (nextCursorValue is! String || nextCursorValue.isEmpty)) {
        return _reject(CandidateContractFailureCode.contractInvalid);
      }
      // Candidate-only defensive policy: this unapproved flat fixture uses
      // nextCursor solely to make older data reachable. The real wire contract
      // may instead use beforeSequence or an envelope and remains undecided.
      if (hasMoreBefore != (nextCursorValue != null)) {
        return _reject(CandidateContractFailureCode.cursorPolicyViolation);
      }

      final rawMessages = root['messages'];
      if (rawMessages is! List) {
        return _reject(CandidateContractFailureCode.contractInvalid);
      }
      final messages = <CandidateChatMessageDto>[];
      final ids = <String>{};
      final clientIds = <String>{};
      for (final rawMessage in rawMessages) {
        final decoded = _decodeMessage(rawMessage, conversationId);
        if (decoded case CandidateRejected<CandidateChatMessageDto>(
          :final failure,
        )) {
          return CandidateRejected(failure);
        }
        final message =
            (decoded as CandidateDecoded<CandidateChatMessageDto>).value;
        if (!ids.add(message.id) || !clientIds.add(message.clientMessageId)) {
          return _reject(CandidateContractFailureCode.contractInvalid);
        }
        messages.add(message);
      }

      final sequenceFailure = _validateSequences(
        request,
        messages,
        latestSequence,
        hasMoreAfter,
      );
      if (sequenceFailure != null) return CandidateRejected(sequenceFailure);
      return CandidateDecoded(
        CandidateChatPageDto(
          conversationId: conversationId,
          messages: messages,
          latestSequence: latestSequence,
          hasMoreBefore: hasMoreBefore,
          hasMoreAfter: hasMoreAfter,
          nextCursor: nextCursorValue as String?,
        ),
      );
    } on Object {
      return _reject(CandidateContractFailureCode.contractInvalid);
    }
  }

  CandidateDecodeResult<CandidateChatPageDto> decodeJsonText(
    String source, {
    required CandidatePageRequest request,
  }) => _decode(CandidateDecodeInput.jsonText(source), request: request);

  CandidateDecodeResult<CandidateChatPageDto> decodeParsed(
    Object? value, {
    required CandidatePageRequest request,
  }) => _decode(CandidateDecodeInput.parsed(value), request: request);

  static CandidateContractFailure? _validateRequest(
    CandidatePageRequest request,
  ) {
    if (!isCandidateUuid(request.expectedConversationId)) {
      return const CandidateContractFailure(
        CandidateContractFailureCode.invalidUuid,
      );
    }
    switch (request.mode) {
      case CandidatePageMode.after:
        final sequence = request.afterSequence;
        if (sequence == null ||
            sequence < 0 ||
            !isCandidateJsonSafeInteger(sequence)) {
          return const CandidateContractFailure(
            CandidateContractFailureCode.unsafeInteger,
          );
        }
      case CandidatePageMode.latest:
        break;
      case CandidatePageMode.cursor:
        if (request.cursor == null || request.cursor!.isEmpty) {
          return const CandidateContractFailure(
            CandidateContractFailureCode.contractInvalid,
          );
        }
    }
    return null;
  }

  static CandidateDecodeResult<CandidateChatMessageDto> _decodeMessage(
    Object? input,
    String pageConversationId,
  ) {
    final map = candidateStringKeyedMap(input);
    if (map == null)
      return _reject(CandidateContractFailureCode.contractInvalid);
    final id = map['id'];
    final conversationId = map['conversationId'];
    final clientMessageId = map['clientMessageId'];
    if (id is! String ||
        conversationId is! String ||
        clientMessageId is! String) {
      return _reject(CandidateContractFailureCode.contractInvalid);
    }
    if (!isCandidateUuid(id) ||
        !isCandidateUuid(conversationId) ||
        !isCandidateUuid(clientMessageId)) {
      return _reject(CandidateContractFailureCode.invalidUuid);
    }
    if (conversationId != pageConversationId) {
      return _reject(CandidateContractFailureCode.conversationMismatch);
    }

    final rawSequence = map['sequence'];
    if (rawSequence is! int) {
      return _reject(CandidateContractFailureCode.contractInvalid);
    }
    final sequence = _sequence(rawSequence);
    if (sequence == null) {
      return _reject(CandidateContractFailureCode.unsafeInteger);
    }
    final rawSenderKind = map['senderKind'];
    final rawMessageKind = map['messageKind'];
    if (rawSenderKind is! String || rawMessageKind is! String) {
      return _reject(CandidateContractFailureCode.contractInvalid);
    }
    final senderKind = switch (rawSenderKind) {
      'user' => CandidateSenderKind.user,
      'system' => CandidateSenderKind.system,
      _ => null,
    };
    final messageKind = switch (rawMessageKind) {
      'text' => CandidateMessageKind.text,
      'system' => CandidateMessageKind.system,
      _ => null,
    };
    if (senderKind == null || messageKind == null) {
      return _reject(CandidateContractFailureCode.unknownEnum);
    }
    final bodyText = map['bodyText'];
    if (bodyText != null && bodyText is! String) {
      return _reject(CandidateContractFailureCode.contractInvalid);
    }
    final createdAtValue = map['createdAt'];
    if (createdAtValue is! String) {
      return _reject(CandidateContractFailureCode.contractInvalid);
    }
    final createdAt = parseCandidateUtcTimestamp(createdAtValue);
    if (createdAt == null) {
      return _reject(CandidateContractFailureCode.invalidUtcTimestamp);
    }
    final attachments = map['attachments'];
    if (attachments != null) {
      if (attachments is! List) {
        return _reject(CandidateContractFailureCode.contractInvalid);
      }
      if (attachments.isNotEmpty) {
        return _reject(CandidateContractFailureCode.unapprovedAttachmentSchema);
      }
    }
    return CandidateDecoded(
      CandidateChatMessageDto(
        id: id,
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        sequence: sequence,
        senderKind: senderKind,
        messageKind: messageKind,
        bodyText: bodyText as String?,
        createdAt: createdAt,
      ),
    );
  }

  static CandidateContractFailure? _validateSequences(
    CandidatePageRequest request,
    List<CandidateChatMessageDto> messages,
    int latestSequence,
    bool hasMoreAfter,
  ) {
    for (var index = 1; index < messages.length; index++) {
      if (messages[index].sequence != messages[index - 1].sequence + 1) {
        return const CandidateContractFailure(
          CandidateContractFailureCode.nonContiguousSequence,
        );
      }
    }
    if (messages.isNotEmpty && messages.last.sequence > latestSequence) {
      return const CandidateContractFailure(
        CandidateContractFailureCode.nonContiguousSequence,
      );
    }
    switch (request.mode) {
      case CandidatePageMode.after:
        final after = request.afterSequence!;
        if (after > latestSequence ||
            (messages.isNotEmpty && messages.first.sequence != after + 1) ||
            (messages.isEmpty && latestSequence > after) ||
            (messages.isNotEmpty &&
                hasMoreAfter != (messages.last.sequence < latestSequence)) ||
            (messages.isEmpty && hasMoreAfter)) {
          return const CandidateContractFailure(
            CandidateContractFailureCode.nonContiguousSequence,
          );
        }
      case CandidatePageMode.latest:
        if (hasMoreAfter ||
            (messages.isNotEmpty && messages.last.sequence != latestSequence) ||
            (messages.isEmpty && latestSequence != 0)) {
          return const CandidateContractFailure(
            CandidateContractFailureCode.nonContiguousSequence,
          );
        }
      case CandidatePageMode.cursor:
        if (messages.isEmpty && hasMoreAfter) {
          return const CandidateContractFailure(
            CandidateContractFailureCode.nonContiguousSequence,
          );
        }
    }
    return null;
  }

  static int? _sequence(Object? value, {bool allowZero = false}) {
    if (value is! int || !isCandidateJsonSafeInteger(value)) return null;
    if (allowZero ? value < 0 : value <= 0) return null;
    return value;
  }

  static CandidateRejected<T> _reject<T>(CandidateContractFailureCode code) =>
      CandidateRejected(CandidateContractFailure(code));
}
