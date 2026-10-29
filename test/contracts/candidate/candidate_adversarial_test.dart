import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/network/candidate/candidate_contract_failure.dart';
import 'package:timefit_native/core/network/candidate/candidate_decode_budget.dart';
import 'package:timefit_native/core/network/candidate/candidate_rpc_failure.dart';
import 'package:timefit_native/features/chat/data/dto/candidate/candidate_chat_page.dart';
import 'package:timefit_native/features/chat/data/dto/candidate/candidate_chat_page_decoder.dart';

const _conversationId = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> _emptyPage() => <String, Object?>{
  'schemaVersion': 1,
  'conversationId': _conversationId,
  'messages': <Object?>[],
  'latestSequence': 0,
  'hasMoreBefore': false,
  'hasMoreAfter': false,
  'nextCursor': null,
};

Map<String, Object?> _message(int sequence) => <String, Object?>{
  'id': '00000000-0000-4000-8000-${sequence.toString().padLeft(12, '0')}',
  'conversationId': _conversationId,
  'clientMessageId':
      '10000000-0000-4000-8000-${sequence.toString().padLeft(12, '0')}',
  'sequence': sequence,
  'senderKind': 'user',
  'messageKind': 'text',
  'bodyText': 'body-$sequence',
  'createdAt': '2026-10-16T00:00:01Z',
  'attachments': <Object?>[],
};

CandidateContractFailureCode _failureCode(
  CandidateDecodeResult<CandidateChatPageDto> result,
) => (result as CandidateRejected<CandidateChatPageDto>).failure.code;

void main() {
  test('unknown or malformed error envelopes fail closed without retry', () {
    const decoder = CandidateRpcFailureDecoder();
    final unknown = decoder.decode(<String, Object?>{
      'code': 'future_unknown_code',
      'message': 'canary-private-body',
    });
    final malformedRateLimit = decoder.decode(<String, Object?>{
      'code': 'rate_limited',
      'retryAfter': 'not-an-integer',
      'message': 'canary-private-body',
    });

    expect(unknown.code, CandidateStableRpcCode.contractViolation);
    expect(malformedRateLimit.code, CandidateStableRpcCode.contractViolation);
    expect(unknown.retryable, isFalse);
    expect(malformedRateLimit.retryable, isFalse);
    expect(unknown.toString(), isNot(contains('canary')));
    expect(malformedRateLimit.toString(), isNot(contains('canary')));
  });

  test('oversized JSON input is rejected before retaining unknown data', () {
    const decoder = CandidateChatPageDecoder();
    final page = _emptyPage()
      ..['unknownOptional'] = List<String>.filled(200000, 'canary').join();
    final encoded = jsonEncode(page);
    expect(encoded.length, greaterThan(1000000));

    final result = decoder.decode(
      encoded,
      request: const CandidatePageRequest.latest(
        expectedConversationId: _conversationId,
      ),
    );

    expect(
      _failureCode(result),
      CandidateContractFailureCode.inputBudgetExceeded,
    );
    expect(result.toString(), isNot(contains('canary')));
  });

  test('deeply nested unknown JSON is rejected by a bounded decoder', () {
    const decoder = CandidateChatPageDecoder();
    Object nested = 'canary';
    for (var index = 0; index < 512; index += 1) {
      nested = <String, Object?>{'next': nested};
    }
    final page = _emptyPage()..['unknownOptional'] = nested;

    final result = decoder.decode(
      jsonEncode(page),
      request: const CandidatePageRequest.latest(
        expectedConversationId: _conversationId,
      ),
    );

    expect(
      _failureCode(result),
      CandidateContractFailureCode.inputBudgetExceeded,
    );
  });

  test('parsed cycles and throwing maps fail without exception leakage', () {
    const decoder = CandidateChatPageDecoder();
    final cyclic = _emptyPage();
    cyclic['unknownOptional'] = cyclic;
    for (final (input, expectedCode)
        in <(Object?, CandidateContractFailureCode)>[
          (cyclic, CandidateContractFailureCode.inputBudgetExceeded),
          (_ThrowingMap(), CandidateContractFailureCode.contractInvalid),
        ]) {
      final result = decoder.decode(
        input,
        request: const CandidatePageRequest.latest(
          expectedConversationId: _conversationId,
        ),
      );
      expect(_failureCode(result), expectedCode);
      expect(result.toString(), isNot(contains('canary')));
      expect(result.toString(), isNot(contains('StateError')));
    }
  });

  test('container and total-node budgets are injectable local defenses', () {
    const containerDecoder = CandidateChatPageDecoder(
      budget: CandidateDecodeBudget(maxContainerEntries: 4),
    );
    const nodeDecoder = CandidateChatPageDecoder(
      budget: CandidateDecodeBudget(maxTotalNodes: 10),
    );
    final containerResult = containerDecoder.decode(
      _emptyPage(),
      request: const CandidatePageRequest.latest(
        expectedConversationId: _conversationId,
      ),
    );
    final nodeResult = nodeDecoder.decode(
      _emptyPage(),
      request: const CandidatePageRequest.latest(
        expectedConversationId: _conversationId,
      ),
    );

    expect(
      _failureCode(containerResult),
      CandidateContractFailureCode.inputBudgetExceeded,
    );
    expect(
      _failureCode(nodeResult),
      CandidateContractFailureCode.inputBudgetExceeded,
    );
    expect(
      const CandidateChatPageDecoder().decode(
        _emptyPage(),
        request: const CandidatePageRequest.latest(
          expectedConversationId: _conversationId,
        ),
      ),
      isA<CandidateDecoded<CandidateChatPageDto>>(),
    );
  });

  test('bounded decoder accepts valid input at configured limits', () {
    const budget = CandidateDecodeBudget(
      maxUtf8Bytes: 2,
      maxDepth: 1,
      maxContainerEntries: 1,
      maxTotalNodes: 1,
    );

    expect(
      decodeCandidateJsonWithinBudget('[]', budget: budget),
      isA<CandidateBoundedValue>(),
    );
    expect(
      decodeCandidateJsonWithinBudget(<Object?>[], budget: budget),
      isA<CandidateBoundedValue>(),
    );
  });

  test('strict UTC parser rejects normalized and over-precision dates', () {
    const decoder = CandidateChatPageDecoder();
    for (final timestamp in <String>[
      '2026-10-16T24:00:00Z',
      '2026-10-16T00:00:60Z',
      '2026-10-16T00:00:00.1234567Z',
      '2026-10-16T00:00:00z',
    ]) {
      final message = _message(1)..['createdAt'] = timestamp;
      final page = _emptyPage()
        ..['messages'] = <Object?>[message]
        ..['latestSequence'] = 1;
      final result = decoder.decode(
        page,
        request: const CandidatePageRequest.latest(
          expectedConversationId: _conversationId,
        ),
      );
      expect(
        _failureCode(result),
        CandidateContractFailureCode.invalidUtcTimestamp,
      );
    }
  });

  test('cursor page cannot advertise inaccessible previous data', () {
    const decoder = CandidateChatPageDecoder();
    final page = _emptyPage()
      ..['messages'] = <Object?>[_message(3), _message(4)]
      ..['latestSequence'] = 6
      ..['hasMoreBefore'] = true
      ..['hasMoreAfter'] = true
      ..['nextCursor'] = null;

    final result = decoder.decode(
      page,
      request: const CandidatePageRequest.cursor(
        expectedConversationId: _conversationId,
        cursor: 'current-cursor',
      ),
    );

    expect(
      _failureCode(result),
      CandidateContractFailureCode.cursorPolicyViolation,
    );
  });
}

final class _ThrowingMap extends MapBase<String, Object?> {
  @override
  Iterable<String> get keys => throw StateError('canary-private-stack');

  @override
  Object? operator [](Object? key) => null;

  @override
  void operator []=(String key, Object? value) {}

  @override
  void clear() {}

  @override
  Object? remove(Object? key) => null;
}
