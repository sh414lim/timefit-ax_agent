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

Object? _value(CandidateDecodeInput input) {
  final result = decodeCandidateJsonWithinBudget(input);
  expect(result, isA<CandidateBoundedValue>());
  return (result as CandidateBoundedValue).value;
}

void main() {
  group('explicit candidate input origin', () {
    test('raw null, quoted null, and parsed null string stay distinct', () {
      expect(_value(const CandidateDecodeInput.jsonText('null')), isNull);
      expect(_value(const CandidateDecodeInput.jsonText('"null"')), 'null');
      expect(_value(const CandidateDecodeInput.parsed('null')), 'null');
    });

    test('empty and general strings are never inferred as JSON text', () {
      expect(
        decodeCandidateJsonWithinBudget(
          const CandidateDecodeInput.jsonText(''),
        ),
        isA<CandidateInputInvalid>(),
      );
      expect(_value(const CandidateDecodeInput.jsonText('""')), '');
      expect(_value(const CandidateDecodeInput.parsed('')), '');
      expect(_value(const CandidateDecodeInput.jsonText('"hello"')), 'hello');
      expect(_value(const CandidateDecodeInput.parsed('hello')), 'hello');
      expect(
        _value(const CandidateDecodeInput.parsed('{"looks":"json"}')),
        '{"looks":"json"}',
      );
    });

    test('scalar, list, and map preserve explicit-origin parity', () {
      expect(_value(const CandidateDecodeInput.jsonText('7')), 7);
      expect(_value(const CandidateDecodeInput.parsed(7)), 7);
      expect(_value(const CandidateDecodeInput.jsonText('[1,true]')), <Object?>[
        1,
        true,
      ]);
      expect(
        _value(const CandidateDecodeInput.parsed(<Object?>[1, true])),
        <Object?>[1, true],
      );
      expect(
        _value(const CandidateDecodeInput.jsonText('{"key":"value"}')),
        <String, Object?>{'key': 'value'},
      );
      expect(
        _value(
          const CandidateDecodeInput.parsed(<String, Object?>{'key': 'value'}),
        ),
        <String, Object?>{'key': 'value'},
      );
    });

    test('explicit paths retain depth budget and cycle rejection', () {
      const budget = CandidateDecodeBudget(
        maxUtf8Bytes: 64,
        maxDepth: 1,
        maxContainerEntries: 4,
        maxTotalNodes: 8,
      );
      expect(
        decodeCandidateJsonWithinBudget(
          const CandidateDecodeInput.jsonText('[[]]'),
          budget: budget,
        ),
        isA<CandidateBudgetRejected>(),
      );
      expect(
        decodeCandidateJsonWithinBudget(
          const CandidateDecodeInput.parsed(<Object?>[<Object?>[]]),
          budget: budget,
        ),
        isA<CandidateBudgetRejected>(),
      );

      final cycle = <Object?>[];
      cycle.add(cycle);
      expect(
        decodeCandidateJsonWithinBudget(
          CandidateDecodeInput.parsed(cycle),
          budget: budget,
        ),
        isA<CandidateBudgetRejected>(),
      );
    });
  });

  group('decoder entry points', () {
    test('page decoder accepts explicit raw and parsed page inputs', () {
      const decoder = CandidateChatPageDecoder();
      const request = CandidatePageRequest.latest(
        expectedConversationId: _conversationId,
      );
      final page = _emptyPage();

      expect(
        decoder.decodeJsonText(jsonEncode(page), request: request),
        isA<CandidateDecoded<CandidateChatPageDto>>(),
      );
      expect(
        decoder.decodeParsed(page, request: request),
        isA<CandidateDecoded<CandidateChatPageDto>>(),
      );
      expect(
        decoder.decode(page, request: request),
        isA<CandidateDecoded<CandidateChatPageDto>>(),
        reason: 'the compatibility entry point remains parsed-value-only',
      );
    });

    test('parsed JSON-looking strings are not reinterpreted', () {
      const pageDecoder = CandidateChatPageDecoder();
      const request = CandidatePageRequest.latest(
        expectedConversationId: _conversationId,
      );
      final encodedPage = jsonEncode(_emptyPage());

      final parsedScalar = pageDecoder.decodeParsed(
        encodedPage,
        request: request,
      );
      expect(parsedScalar, isA<CandidateRejected<CandidateChatPageDto>>());
      expect(
        (parsedScalar as CandidateRejected<CandidateChatPageDto>).failure.code,
        CandidateContractFailureCode.contractInvalid,
      );
      expect(
        pageDecoder.decodeJsonText(encodedPage, request: request),
        isA<CandidateDecoded<CandidateChatPageDto>>(),
      );
    });

    test('RPC raw and parsed maps match without String inference', () {
      const decoder = CandidateRpcFailureDecoder();
      const envelope = <String, Object?>{'code': 'internal_error'};

      expect(
        decoder.decodeJsonText(jsonEncode(envelope)).code,
        CandidateStableRpcCode.internalError,
      );
      expect(
        decoder.decodeParsed(envelope).code,
        CandidateStableRpcCode.internalError,
      );
      expect(
        decoder.decode(jsonEncode(envelope)).code,
        CandidateStableRpcCode.contractViolation,
        reason: 'decode is parsed-only and must not infer raw JSON',
      );
      expect(
        decoder.decodeParsed('null').code,
        CandidateStableRpcCode.contractViolation,
      );
      expect(
        decoder.decodeJsonText('null').code,
        CandidateStableRpcCode.contractViolation,
      );
    });
  });
}
