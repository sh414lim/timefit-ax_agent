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

bool _acceptedJson(String source, CandidateDecodeBudget budget) =>
    decodeCandidateJsonWithinBudget(
          CandidateDecodeInput.jsonText(source),
          budget: budget,
        )
        is CandidateBoundedValue;

bool _acceptedParsed(Object? value, CandidateDecodeBudget budget) =>
    decodeCandidateJsonWithinBudget(
          CandidateDecodeInput.parsed(value),
          budget: budget,
        )
        is CandidateBoundedValue;

void main() {
  group('shared budget depth definition', () {
    for (final testCase
        in <
          ({
            String name,
            String json,
            Object? object,
            int maxDepth,
            bool accepted,
          })
        >[
          (
            name: 'root scalar at zero',
            json: '0',
            object: 0,
            maxDepth: 0,
            accepted: true,
          ),
          (
            name: 'root list exceeds zero',
            json: '[]',
            object: <Object?>[],
            maxDepth: 0,
            accepted: false,
          ),
          (
            name: 'root list at one',
            json: '[]',
            object: <Object?>[],
            maxDepth: 1,
            accepted: true,
          ),
          (
            name: 'root map at one',
            json: '{}',
            object: <String, Object?>{},
            maxDepth: 1,
            accepted: true,
          ),
          (
            name: 'nested list exceeds one',
            json: '[[]]',
            object: <Object?>[<Object?>[]],
            maxDepth: 1,
            accepted: false,
          ),
          (
            name: 'nested list at two',
            json: '[[]]',
            object: <Object?>[<Object?>[]],
            maxDepth: 2,
            accepted: true,
          ),
          (
            name: 'nested map exceeds one',
            json: '{"a":{}}',
            object: <String, Object?>{'a': <String, Object?>{}},
            maxDepth: 1,
            accepted: false,
          ),
          (
            name: 'nested map at two',
            json: '{"a":{}}',
            object: <String, Object?>{'a': <String, Object?>{}},
            maxDepth: 2,
            accepted: true,
          ),
        ]) {
      test('${testCase.name} has string/object parity', () {
        final budget = CandidateDecodeBudget(
          maxUtf8Bytes: 512,
          maxDepth: testCase.maxDepth,
          maxContainerEntries: 16,
          maxTotalNodes: 32,
        );

        expect(_acceptedJson(testCase.json, budget), testCase.accepted);
        expect(_acceptedParsed(testCase.object, budget), testCase.accepted);
      });
    }

    test('depth 32 is accepted and depth 33 is rejected for both paths', () {
      Object? acceptedObject = null;
      var acceptedJson = 'null';
      for (var index = 0; index < 32; index += 1) {
        acceptedObject = <Object?>[acceptedObject];
        acceptedJson = '[$acceptedJson]';
      }
      final rejectedObject = <Object?>[acceptedObject];
      final rejectedJson = '[$acceptedJson]';
      const budget = CandidateDecodeBudget(
        maxUtf8Bytes: 4096,
        maxDepth: 32,
        maxContainerEntries: 4,
        maxTotalNodes: 128,
      );

      expect(_acceptedJson(acceptedJson, budget), isTrue);
      expect(_acceptedParsed(acceptedObject, budget), isTrue);
      expect(_acceptedJson(rejectedJson, budget), isFalse);
      expect(_acceptedParsed(rejectedObject, budget), isFalse);
    });
  });

  test('escaped quotes and UTF-8 text use the same logical byte guard', () {
    final object = <String, Object?>{'text': '한글 "quoted" 😀'};
    final json = jsonEncode(object);
    const acceptedBudget = CandidateDecodeBudget(
      maxUtf8Bytes: 128,
      maxDepth: 1,
      maxContainerEntries: 4,
      maxTotalNodes: 4,
    );
    const rejectedBudget = CandidateDecodeBudget(
      maxUtf8Bytes: 10,
      maxDepth: 1,
      maxContainerEntries: 4,
      maxTotalNodes: 4,
    );

    expect(_acceptedJson(json, acceptedBudget), isTrue);
    expect(_acceptedParsed(object, acceptedBudget), isTrue);
    expect(_acceptedJson(json, rejectedBudget), isFalse);
    expect(_acceptedParsed(object, rejectedBudget), isFalse);
    for (var maxBytes = 1; maxBytes <= 128; maxBytes += 1) {
      final budget = CandidateDecodeBudget(
        maxUtf8Bytes: maxBytes,
        maxDepth: 1,
        maxContainerEntries: 4,
        maxTotalNodes: 4,
      );
      expect(
        _acceptedJson(json, budget),
        _acceptedParsed(object, budget),
        reason: 'string/object byte parity at $maxBytes bytes',
      );
    }
  });

  test('shared aliases are accepted while cycles fail closed', () {
    final shared = <Object?>[];
    final alias = <String, Object?>{'a': shared, 'b': shared};
    final cycle = <Object?>[];
    cycle.add(cycle);
    const budget = CandidateDecodeBudget(
      maxUtf8Bytes: 128,
      maxDepth: 2,
      maxContainerEntries: 4,
      maxTotalNodes: 8,
    );

    expect(_acceptedParsed(alias, budget), isTrue);
    expect(_acceptedParsed(cycle, budget), isFalse);
  });

  test('node and container entry boundaries match for both paths', () {
    final object = <String, Object?>{'a': 1};
    final tooManyEntries = <String, Object?>{'a': 1, 'b': 2};
    const accepted = CandidateDecodeBudget(
      maxUtf8Bytes: 128,
      maxDepth: 1,
      maxContainerEntries: 1,
      maxTotalNodes: 3,
    );
    const tooFewNodes = CandidateDecodeBudget(
      maxUtf8Bytes: 128,
      maxDepth: 1,
      maxContainerEntries: 1,
      maxTotalNodes: 2,
    );
    expect(_acceptedJson(jsonEncode(object), accepted), isTrue);
    expect(_acceptedParsed(object, accepted), isTrue);
    expect(_acceptedJson(jsonEncode(object), tooFewNodes), isFalse);
    expect(_acceptedParsed(object, tooFewNodes), isFalse);
    expect(_acceptedJson(jsonEncode(tooManyEntries), accepted), isFalse);
    expect(_acceptedParsed(tooManyEntries, accepted), isFalse);
  });

  test('RPC decoder applies the same nested-depth policy to both inputs', () {
    final envelope = <String, Object?>{
      'code': 'internal_error',
      'unknown': <String, Object?>{'text': '한글 "quoted"'},
    };
    const rejected = CandidateRpcFailureDecoder(
      budget: CandidateDecodeBudget(maxDepth: 1),
    );
    const accepted = CandidateRpcFailureDecoder(
      budget: CandidateDecodeBudget(maxDepth: 2),
    );

    expect(
      rejected.decodeParsed(envelope).code,
      CandidateStableRpcCode.contractViolation,
    );
    expect(
      rejected.decodeJsonText(jsonEncode(envelope)).code,
      CandidateStableRpcCode.contractViolation,
    );
    expect(
      accepted.decodeParsed(envelope).code,
      CandidateStableRpcCode.internalError,
    );
    expect(
      accepted.decodeJsonText(jsonEncode(envelope)).code,
      CandidateStableRpcCode.internalError,
    );
  });

  test('page decoder applies the same root/list depth policy', () {
    final page = _emptyPage();
    const rejected = CandidateChatPageDecoder(
      budget: CandidateDecodeBudget(maxDepth: 1),
    );
    const accepted = CandidateChatPageDecoder(
      budget: CandidateDecodeBudget(maxDepth: 2),
    );
    const request = CandidatePageRequest.latest(
      expectedConversationId: _conversationId,
    );

    for (final result in <CandidateDecodeResult<CandidateChatPageDto>>[
      rejected.decodeParsed(page, request: request),
      rejected.decodeJsonText(jsonEncode(page), request: request),
    ]) {
      expect(
        (result as CandidateRejected<CandidateChatPageDto>).failure.code,
        CandidateContractFailureCode.inputBudgetExceeded,
      );
    }
    expect(
      accepted.decodeParsed(page, request: request),
      isA<CandidateDecoded<CandidateChatPageDto>>(),
    );
    expect(
      accepted.decodeJsonText(jsonEncode(page), request: request),
      isA<CandidateDecoded<CandidateChatPageDto>>(),
    );
  });

  test('both decoders reject parsed cycles without raw data', () {
    final page = _emptyPage();
    page['unknown'] = page;
    final error = <String, Object?>{'code': 'internal_error'};
    error['unknown'] = error;

    final pageResult = const CandidateChatPageDecoder().decode(
      page,
      request: const CandidatePageRequest.latest(
        expectedConversationId: _conversationId,
      ),
    );
    final rpcResult = const CandidateRpcFailureDecoder().decode(error);

    expect(pageResult, isA<CandidateRejected<CandidateChatPageDto>>());
    expect(rpcResult.code, CandidateStableRpcCode.contractViolation);
    expect(pageResult.toString(), isNot(contains('unknown')));
    expect(rpcResult.toString(), isNot(contains('unknown')));
  });
}
