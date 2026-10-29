import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/network/candidate/candidate_contract_failure.dart';
import 'package:timefit_native/features/chat/data/dto/candidate/candidate_chat_page.dart';
import 'package:timefit_native/features/chat/data/dto/candidate/candidate_chat_page_decoder.dart';

const _conversationId = '11111111-1111-4111-8111-111111111111';
const _otherConversationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

String _fixture(String name) =>
    File('test/fixtures/chat/candidate-v1/$name').readAsStringSync();

Map<String, Object?> _message(
  int sequence, {
  String conversationId = _conversationId,
}) => <String, Object?>{
  'id': '00000000-0000-4000-8000-${sequence.toString().padLeft(12, '0')}',
  'conversationId': conversationId,
  'clientMessageId':
      '10000000-0000-4000-8000-${sequence.toString().padLeft(12, '0')}',
  'sequence': sequence,
  'senderKind': 'user',
  'messageKind': 'text',
  'bodyText': 'body-$sequence',
  'createdAt': '2026-10-16T00:00:${sequence.toString().padLeft(2, '0')}Z',
  'attachments': <Object?>[],
};

Map<String, Object?> _page({
  List<Object?>? messages,
  int latestSequence = 0,
  bool hasMoreBefore = false,
  bool hasMoreAfter = false,
}) => <String, Object?>{
  'schemaVersion': 1,
  'conversationId': _conversationId,
  'messages': messages ?? <Object?>[],
  'latestSequence': latestSequence,
  'hasMoreBefore': hasMoreBefore,
  'hasMoreAfter': hasMoreAfter,
  'nextCursor': null,
};

CandidateContractFailureCode _failureCode(
  CandidateDecodeResult<CandidateChatPageDto> result,
) => (result as CandidateRejected<CandidateChatPageDto>).failure.code;

CandidateChatPageDto _decodedPage(
  CandidateDecodeResult<CandidateChatPageDto> result,
) {
  if (result case CandidateDecoded<CandidateChatPageDto>(:final value)) {
    return value;
  }
  final failure = (result as CandidateRejected<CandidateChatPageDto>).failure;
  fail('Expected decoded candidate page, got ${failure.code.stableCode}');
}

void main() {
  const decoder = CandidateChatPageDecoder();

  group('candidate fixtures', () {
    test('decodes an empty latest page from JSON text', () {
      final result = decoder.decode(
        _fixture('empty-latest.json'),
        request: const CandidatePageRequest.latest(
          expectedConversationId: _conversationId,
        ),
      );

      final page = _decodedPage(result);
      expect(page.messages, isEmpty);
      expect(page.latestSequence, 0);
      expect(page.hasMoreBefore, isFalse);
      expect(page.hasMoreAfter, isFalse);
    });

    test('decodes one after message and ignores unknown optional fields', () {
      final result = decoder.decode(
        jsonDecode(_fixture('one-after.json')),
        request: const CandidatePageRequest.after(
          expectedConversationId: _conversationId,
          afterSequence: 0,
        ),
      );

      final page = _decodedPage(result);
      expect(page.messages, hasLength(1));
      expect(page.messages.single.sequence, 1);
      expect(page.messages.single.bodyText, 'candidate only');
      expect(page.messages.single.createdAt.isUtc, isTrue);
    });

    test('decodes a contiguous multi-message cursor page', () {
      final result = decoder.decode(
        _fixture('multi-cursor.json'),
        request: const CandidatePageRequest.cursor(
          expectedConversationId: _conversationId,
          cursor: 'local-cursor-input',
        ),
      );

      final page = _decodedPage(result);
      expect(page.messages.map((message) => message.sequence), <int>[3, 4]);
      expect(page.latestSequence, 6);
      expect(page.hasMoreAfter, isTrue);
      expect(page.nextCursor, 'candidate_cursor_2');
    });

    test('decodes a complete multi-message after page', () {
      final result = decoder.decode(
        _page(messages: <Object?>[_message(5), _message(6)], latestSequence: 6),
        request: const CandidatePageRequest.after(
          expectedConversationId: _conversationId,
          afterSequence: 4,
        ),
      );

      expect(result, isA<CandidateDecoded<CandidateChatPageDto>>());
    });
  });

  group('candidate contract failures', () {
    test('rejects malformed JSON, missing fields, and wrong field types', () {
      expect(
        _failureCode(
          decoder.decode(
            '{not json',
            request: const CandidatePageRequest.latest(
              expectedConversationId: _conversationId,
            ),
          ),
        ),
        CandidateContractFailureCode.contractInvalid,
      );
      expect(
        _failureCode(
          decoder.decode(
            _page()..['latestSequence'] = '0',
            request: const CandidatePageRequest.latest(
              expectedConversationId: _conversationId,
            ),
          ),
        ),
        CandidateContractFailureCode.contractInvalid,
      );
      final missing = _page()..remove('messages');
      expect(
        _failureCode(
          decoder.decode(
            missing,
            request: const CandidatePageRequest.latest(
              expectedConversationId: _conversationId,
            ),
          ),
        ),
        CandidateContractFailureCode.contractInvalid,
      );
      expect(
        _failureCode(
          decoder.decode(
            _page()..['hasMoreAfter'] = 'false',
            request: const CandidatePageRequest.latest(
              expectedConversationId: _conversationId,
            ),
          ),
        ),
        CandidateContractFailureCode.contractInvalid,
      );
    });

    test('rejects unsupported candidate versions', () {
      final result = decoder.decode(
        _page()..['schemaVersion'] = 2,
        request: const CandidatePageRequest.latest(
          expectedConversationId: _conversationId,
        ),
      );

      expect(
        _failureCode(result),
        CandidateContractFailureCode.unsupportedSchemaVersion,
      );
    });

    test('rejects invalid UUIDs and conversation mismatches', () {
      expect(
        _failureCode(
          decoder.decode(
            _page()..['conversationId'] = 'not-a-uuid',
            request: const CandidatePageRequest.latest(
              expectedConversationId: _conversationId,
            ),
          ),
        ),
        CandidateContractFailureCode.invalidUuid,
      );
      expect(
        _failureCode(
          decoder.decode(
            _page(),
            request: const CandidatePageRequest.latest(
              expectedConversationId: _otherConversationId,
            ),
          ),
        ),
        CandidateContractFailureCode.conversationMismatch,
      );
      expect(
        _failureCode(
          decoder.decode(
            _page(
              messages: <Object?>[
                _message(1, conversationId: _otherConversationId),
              ],
              latestSequence: 1,
            ),
            request: const CandidatePageRequest.latest(
              expectedConversationId: _conversationId,
            ),
          ),
        ),
        CandidateContractFailureCode.conversationMismatch,
      );
    });

    test('rejects non-UTC and invalid calendar timestamps', () {
      for (final timestamp in <String>[
        '2026-10-16T00:00:01+09:00',
        '2026-02-30T00:00:01Z',
      ]) {
        final message = _message(1)..['createdAt'] = timestamp;
        final result = decoder.decode(
          _page(messages: <Object?>[message], latestSequence: 1),
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

    test('rejects unsafe and non-positive sequences', () {
      for (final sequence in <int>[0, 9007199254740992]) {
        final result = decoder.decode(
          _page(
            messages: <Object?>[_message(sequence)],
            latestSequence: sequence,
          ),
          request: const CandidatePageRequest.cursor(
            expectedConversationId: _conversationId,
            cursor: 'cursor',
          ),
        );
        expect(
          _failureCode(result),
          CandidateContractFailureCode.unsafeInteger,
        );
      }
    });

    test('rejects unknown sender and message enums', () {
      final sender = _message(1)..['senderKind'] = 'robot';
      final messageKind = _message(1)..['messageKind'] = 'attachment';
      for (final message in <Map<String, Object?>>[sender, messageKind]) {
        expect(
          _failureCode(
            decoder.decode(
              _page(messages: <Object?>[message], latestSequence: 1),
              request: const CandidatePageRequest.latest(
                expectedConversationId: _conversationId,
              ),
            ),
          ),
          CandidateContractFailureCode.unknownEnum,
        );
      }
    });

    test('treats missing required enums as contract invalid', () {
      final message = _message(1)..remove('senderKind');
      expect(
        _failureCode(
          decoder.decode(
            _page(messages: <Object?>[message], latestSequence: 1),
            request: const CandidatePageRequest.latest(
              expectedConversationId: _conversationId,
            ),
          ),
        ),
        CandidateContractFailureCode.contractInvalid,
      );
    });

    test('rejects holes, wrong after boundaries, and latest mismatches', () {
      final cases = <(CandidatePageRequest, Map<String, Object?>)>[
        (
          const CandidatePageRequest.cursor(
            expectedConversationId: _conversationId,
            cursor: 'cursor',
          ),
          _page(
            messages: <Object?>[_message(1), _message(3)],
            latestSequence: 3,
          ),
        ),
        (
          const CandidatePageRequest.after(
            expectedConversationId: _conversationId,
            afterSequence: 4,
          ),
          _page(messages: <Object?>[_message(6)], latestSequence: 6),
        ),
        (
          const CandidatePageRequest.latest(
            expectedConversationId: _conversationId,
          ),
          _page(
            messages: <Object?>[_message(1)],
            latestSequence: 2,
            hasMoreAfter: true,
          ),
        ),
      ];
      for (final (request, page) in cases) {
        expect(
          _failureCode(decoder.decode(page, request: request)),
          CandidateContractFailureCode.nonContiguousSequence,
        );
      }
    });

    test('fails closed when any unapproved attachment is present', () {
      final message = _message(1)
        ..['attachments'] = <Object?>[
          <String, Object?>{
            'url': 'https://example.invalid/private?token=canary-secret',
            'fileName': 'canary-secret.pdf',
          },
        ];
      final result = decoder.decode(
        _page(messages: <Object?>[message], latestSequence: 1),
        request: const CandidatePageRequest.latest(
          expectedConversationId: _conversationId,
        ),
      );

      expect(
        _failureCode(result),
        CandidateContractFailureCode.unapprovedAttachmentSchema,
      );
      expect(result.toString(), isNot(contains('canary-secret')));
    });

    test('failure objects never retain raw payload text', () {
      final result = decoder.decode(
        <String, Object?>{'raw': 'canary-secret.pdf?token=canary-token'},
        request: const CandidatePageRequest.latest(
          expectedConversationId: _conversationId,
        ),
      );

      final rejected = result as CandidateRejected<CandidateChatPageDto>;
      expect(
        rejected.failure.toString(),
        'CandidateContractFailure(candidate_contract_invalid)',
      );
      expect(rejected.failure.toString(), isNot(contains('canary')));
    });
  });
}
