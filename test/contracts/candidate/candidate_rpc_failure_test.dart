import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/network/candidate/candidate_rpc_failure.dart';

void main() {
  const decoder = CandidateRpcFailureDecoder();

  test('maps every recommended stable code without raw text', () {
    for (final code in CandidateStableRpcCode.values) {
      final failure = decoder.decode(<String, Object?>{
        'code': code.wireName,
        'requestId': 'req_${code.index}',
        'message': '<html>canary-secret.pdf</html>',
        'details': 'postgres canary-token',
        'sql': 'select canary-secret',
        'url': 'https://example.invalid/?access_token=canary-token',
      });

      expect(failure.code, code);
      expect(failure.requestId, 'req_${code.index}');
      expect(failure.toString(), isNot(contains('canary')));
      expect(failure.toString(), isNot(contains('postgres')));
      expect(failure.toString(), isNot(contains('html')));
    }
  });

  test('rate limited exposes only validated retryAfter and requestId', () {
    final failure = decoder.decode(
      '{"code":"rate_limited","retryAfter":30,'
      '"requestId":"req_abc-123","message":"canary-secret"}',
    );

    expect(failure.code, CandidateStableRpcCode.rateLimited);
    expect(failure.retryAfter, const Duration(seconds: 30));
    expect(failure.requestId, 'req_abc-123');
    expect(failure.retryable, isTrue);
  });

  test('unknown errors collapse to internal without raw payload leakage', () {
    final failure = decoder.decode(<String, Object?>{
      'code': 'database exploded: canary-secret',
      'requestId': 'https://example.invalid/?token=canary-token',
      'retryAfter': 'DROP TABLE',
      'message': '<script>canary-secret</script>',
    });

    expect(failure.code, CandidateStableRpcCode.internalError);
    expect(failure.requestId, isNull);
    expect(failure.retryAfter, isNull);
    expect(failure.toString(), 'CandidateRpcFailure(internal_error)');
  });

  test('malformed JSON and invalid retryAfter fail closed', () {
    expect(
      decoder.decode('{not json').code,
      CandidateStableRpcCode.internalError,
    );
    final malformedRetry = decoder.decode(<String, Object?>{
      'code': 'rate_limited',
      'retryAfter': 9007199254740992,
      'requestId': 'req_1',
    });
    expect(malformedRetry.code, CandidateStableRpcCode.internalError);
    expect(malformedRetry.retryAfter, isNull);
    expect(malformedRetry.requestId, 'req_1');
  });

  test('retryability is derived from stable code rather than server text', () {
    expect(
      decoder.decode(<String, Object?>{
        'code': 'attachment_not_ready',
      }).retryable,
      isTrue,
    );
    expect(
      decoder.decode(<String, Object?>{
        'code': 'idempotency_payload_mismatch',
      }).retryable,
      isFalse,
    );
    expect(
      decoder.decode(<String, Object?>{'code': 'rate_limited'}).retryable,
      isFalse,
    );
    final irrelevantRetry = decoder.decode(<String, Object?>{
      'code': 'message_empty',
      'retryAfter': 30,
    });
    expect(irrelevantRetry.retryAfter, isNull);
  });
}
