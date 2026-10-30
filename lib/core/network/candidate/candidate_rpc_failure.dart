import 'candidate_decode_budget.dart';
import 'candidate_validation.dart';

enum CandidateStableRpcCode {
  /// Local fail-closed result. This is not an approved backend wire code.
  contractViolation('candidate_contract_violation'),
  authenticationRequired('authentication_required'),
  conversationNotFound('conversation_not_found'),
  messageEmpty('message_empty'),
  messageBodyTooLong('message_body_too_long'),
  attachmentLimitExceeded('attachment_limit_exceeded'),
  attachmentNotReady('attachment_not_ready'),
  attachmentAlreadyBound('attachment_already_bound'),
  attachmentMetadataMismatch('attachment_metadata_mismatch'),
  idempotencyPayloadMismatch('idempotency_payload_mismatch'),
  unsupportedSchemaVersion('unsupported_schema_version'),
  rateLimited('rate_limited'),
  internalError('internal_error');

  const CandidateStableRpcCode(this.wireName);

  final String wireName;

  static CandidateStableRpcCode? fromWireName(String value) {
    for (final code in values) {
      if (code == CandidateStableRpcCode.contractViolation) continue;
      if (code.wireName == value) return code;
    }
    return null;
  }
}

final class CandidateRpcFailure {
  const CandidateRpcFailure({
    required this.code,
    this.retryAfter,
    this.requestId,
  });

  final CandidateStableRpcCode code;
  final Duration? retryAfter;
  final String? requestId;

  bool get retryable => switch (code) {
    CandidateStableRpcCode.attachmentNotReady => true,
    CandidateStableRpcCode.rateLimited => retryAfter != null,
    CandidateStableRpcCode.internalError => true,
    _ => false,
  };

  @override
  String toString() => 'CandidateRpcFailure(${code.wireName})';
}

/// Sanitizes a candidate error envelope without retaining raw server text.
///
/// This mapper is deliberately isolated from production network code. Unknown
/// and malformed envelopes become a non-retryable local contract violation;
/// only an explicit `internal_error` wire code is considered retryable.
final class CandidateRpcFailureDecoder {
  const CandidateRpcFailureDecoder({
    this.budget = const CandidateDecodeBudget(),
  });

  final CandidateDecodeBudget budget;

  /// Backward-compatible parsed-value entry point.
  ///
  /// A String passed here is an already parsed scalar. Raw JSON text must use
  /// [decodeJsonText], so input origin is never inferred from runtime type.
  CandidateRpcFailure decode(Object? parsedValue) => decodeParsed(parsedValue);

  CandidateRpcFailure _decode(CandidateDecodeInput input) {
    final bounded = decodeCandidateJsonWithinBudget(input, budget: budget);
    if (bounded is! CandidateBoundedValue) return _contractViolation();
    final map = candidateStringKeyedMap(bounded.value);
    if (map == null) return _contractViolation();

    final rawCode = map['code'];
    final code = rawCode is String
        ? CandidateStableRpcCode.fromWireName(rawCode)
        : null;
    if (code == null) {
      return _contractViolation(requestId: _requestId(map['requestId']));
    }

    final retryAfter = code == CandidateStableRpcCode.rateLimited
        ? _retryAfter(map['retryAfter'])
        : null;
    if (code == CandidateStableRpcCode.rateLimited && retryAfter == null) {
      return _contractViolation(requestId: _requestId(map['requestId']));
    }
    return CandidateRpcFailure(
      code: code,
      retryAfter: retryAfter,
      requestId: _requestId(map['requestId']),
    );
  }

  CandidateRpcFailure decodeJsonText(String source) =>
      _decode(CandidateDecodeInput.jsonText(source));

  CandidateRpcFailure decodeParsed(Object? value) =>
      _decode(CandidateDecodeInput.parsed(value));

  static Duration? _retryAfter(Object? value) {
    if (value == null) return null;
    if (value is! int || value < 0 || !isCandidateJsonSafeInteger(value)) {
      return null;
    }
    return Duration(seconds: value);
  }

  static String? _requestId(Object? value) {
    if (value is! String || value.length > 128) return null;
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value)) return null;
    return value;
  }

  static CandidateRpcFailure _contractViolation({String? requestId}) =>
      CandidateRpcFailure(
        code: CandidateStableRpcCode.contractViolation,
        requestId: requestId,
      );
}
