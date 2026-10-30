import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/network/candidate/candidate_decode_budget.dart';
import 'package:timefit_native/core/network/candidate/candidate_rpc_failure.dart';

void main() {
  const decoder = CandidateRpcFailureDecoder();

  test('maps every recommended stable code without raw text', () {
    for (final code in CandidateStableRpcCode.values.where(
      (code) => code != CandidateStableRpcCode.contractViolation,
    )) {
      final envelope = <String, Object?>{
        'code': code.wireName,
        'requestId': 'req_${code.index}',
        'message': '<html>canary-secret.pdf</html>',
        'details': 'postgres canary-token',
        'sql': 'select canary-secret',
        'url': 'https://example.invalid/?access_token=canary-token',
      };
      if (code == CandidateStableRpcCode.rateLimited) {
        envelope['retryAfter'] = 30;
      }
      final failure = decoder.decode(envelope);

      expect(failure.code, code);
      expect(failure.requestId, 'req_${code.index}');
      expect(failure.toString(), isNot(contains('canary')));
      expect(failure.toString(), isNot(contains('postgres')));
      expect(failure.toString(), isNot(contains('html')));
    }
  });

  test('rate limited exposes only validated retryAfter and requestId', () {
    final failure = decoder.decodeJsonText(
      '{"code":"rate_limited","retryAfter":30,'
      '"requestId":"req_abc-123","message":"canary-secret"}',
    );

    expect(failure.code, CandidateStableRpcCode.rateLimited);
    expect(failure.retryAfter, const Duration(seconds: 30));
    expect(failure.requestId, 'req_abc-123');
    expect(failure.retryable, isTrue);
  });

  test('unknown errors become non-retryable contract violations', () {
    final failure = decoder.decode(<String, Object?>{
      'code': 'database exploded: canary-secret',
      'requestId': 'https://example.invalid/?token=canary-token',
      'retryAfter': 'DROP TABLE',
      'message': '<script>canary-secret</script>',
    });

    expect(failure.code, CandidateStableRpcCode.contractViolation);
    expect(failure.retryable, isFalse);
    expect(failure.requestId, isNull);
    expect(failure.retryAfter, isNull);
    expect(
      failure.toString(),
      'CandidateRpcFailure(candidate_contract_violation)',
    );
  });

  test('malformed JSON and invalid retryAfter fail closed', () {
    expect(
      decoder.decodeJsonText('{not json').code,
      CandidateStableRpcCode.contractViolation,
    );
    final malformedRetry = decoder.decode(<String, Object?>{
      'code': 'rate_limited',
      'retryAfter': 9007199254740992,
      'requestId': 'req_1',
    });
    expect(malformedRetry.code, CandidateStableRpcCode.contractViolation);
    expect(malformedRetry.retryable, isFalse);
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
    final missingRetry = decoder.decode(<String, Object?>{
      'code': 'rate_limited',
    });
    expect(missingRetry.code, CandidateStableRpcCode.contractViolation);
    expect(missingRetry.retryable, isFalse);
    final irrelevantRetry = decoder.decode(<String, Object?>{
      'code': 'message_empty',
      'retryAfter': 30,
    });
    expect(irrelevantRetry.retryAfter, isNull);
  });

  test('applies injected structural budgets to string and object input', () {
    const bounded = CandidateRpcFailureDecoder(
      budget: CandidateDecodeBudget(
        maxUtf8Bytes: 128,
        maxDepth: 3,
        maxContainerEntries: 4,
        maxTotalNodes: 10,
      ),
    );
    final oversized = bounded.decode(<String, Object?>{
      'code': 'internal_error',
      'message': 'canary-${List<String>.filled(256, 'x').join()}',
    });
    final tooDeep = bounded.decode(
      '{"code":"internal_error","nested":{"a":{"b":{"c":1}}}}',
    );

    expect(oversized.code, CandidateStableRpcCode.contractViolation);
    expect(tooDeep.code, CandidateStableRpcCode.contractViolation);
    expect(oversized.retryable, isFalse);
    expect(tooDeep.retryable, isFalse);
    expect(oversized.toString(), isNot(contains('canary')));
  });
}
