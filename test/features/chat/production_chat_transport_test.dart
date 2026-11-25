import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/chat/infrastructure/production_chat_transport.dart';

void main() {
  test('origin must be HTTPS and match the explicitly approved authority', () {
    for (final uri in <String>[
      'http://chat.example.invalid',
      'https://other.example.invalid',
      'https://chat.example.invalid/path',
      'https://secret@chat.example.invalid',
      'https://chat.example.invalid?token=x',
      'https://chat.example.invalid#x',
    ]) {
      expect(
        () => ProductionChatTransport(
          origin: Uri.parse(uri),
          allowedHosts: {'chat.example.invalid'},
          accessToken: () async => null,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'production JSON rejects duplicate keys, excessive depth and nonfinite numbers',
    () {
      for (final raw in <String>[
        '{"payload":{"state":"pending","state":"complete"}}',
        '{"state":"pending","st\\u0061te":"complete"}',
        '{"value":1e999}',
        '{"value":9007199254740992}',
        '${'{"a":' * 17}0${'}' * 17}',
        jsonEncode({'text': '가' * 3000}),
      ]) {
        expect(() => decodeProductionJson(raw), throwsFormatException);
      }
      expect(decodeProductionJson('{"a":[{"x":1},{"x":2}]}'), contains('a'));
    },
  );

  test(
    'turn must keep the request, distinct assistant ID and committed state',
    () {
      const id = '11111111-1111-4111-8111-111111111111';
      final value = <String, dynamic>{
        'sequence': 1,
        'clientMessageId': id,
        'clientRequestId': id,
        'assistantMessageId': '22222222-2222-4222-8222-222222222222',
        'bodySha256': productionBodyDigest('질문'),
        'state': 'complete',
        'answer': '답변',
      };
      expect(ProductionChatTurn.decode(value, id).answer, '답변');
      for (final change in <Map<String, Object?>>[
        {'assistantMessageId': id},
        {'sequence': 9},
        {'answer': ''},
        {'clientRequestId': 'wrong'},
        {'state': 'pending'},
        {'extra': 'not allowed'},
      ]) {
        expect(
          () => ProductionChatTurn.decode({...value, ...change}, id),
          throwsFormatException,
        );
      }
    },
  );
}
