import 'dart:convert';

import 'candidate_validation.dart';

enum CandidateStableRpcCode {
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
/// and malformed envelopes collapse to `internal_error`.
final class CandidateRpcFailureDecoder {
  const CandidateRpcFailureDecoder();

  CandidateRpcFailure decode(Object? input) {
    final decoded = _decodeJson(input);
    final map = candidateStringKeyedMap(decoded);
    if (map == null) return _internal();

    final rawCode = map['code'];
    final code = rawCode is String
        ? CandidateStableRpcCode.fromWireName(rawCode)
        : null;
    if (code == null) return _internal(requestId: _requestId(map['requestId']));

    final retryAfter = code == CandidateStableRpcCode.rateLimited
        ? _retryAfter(map['retryAfter'])
        : null;
    if (code == CandidateStableRpcCode.rateLimited &&
        map.containsKey('retryAfter') &&
        map['retryAfter'] != null &&
        retryAfter == null) {
      return _internal(requestId: _requestId(map['requestId']));
    }
    return CandidateRpcFailure(
      code: code,
      retryAfter: retryAfter,
      requestId: _requestId(map['requestId']),
    );
  }

  static Object? _decodeJson(Object? input) {
    if (input is! String) return input;
    try {
      return jsonDecode(input);
    } on Object {
      return null;
    }
  }

  static Duration? _retryAfter(Object? value) {
    if (value == null) return null;
    if (value is! int ||
        value < 0 ||
        !isCandidateJsonSafeInteger(value) ||
        value >
            Duration.microsecondsPerDay *
                365 ~/
                Duration.microsecondsPerSecond) {
      return null;
    }
    return Duration(seconds: value);
  }

  static String? _requestId(Object? value) {
    if (value is! String || value.length > 128) return null;
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value)) return null;
    return value;
  }

  static CandidateRpcFailure _internal({String? requestId}) =>
      CandidateRpcFailure(
        code: CandidateStableRpcCode.internalError,
        requestId: requestId,
      );
}
