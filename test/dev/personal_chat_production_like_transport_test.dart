import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/dev/personal_chat_client.dart';

const String _pairing = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _clientId = '11111111-1111-4111-8111-111111111111';
const String _assistantId = '22222222-2222-4222-8222-222222222222';
const String _ticket = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late HttpServer server;
  late Completer<Map<String, dynamic>> receivedCommand;

  setUp(() async {
    receivedCommand = Completer<Map<String, dynamic>>();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8790);
    server.listen((request) async {
      if (request.method == 'POST' &&
          request.uri.path == '/v1/test/ws-tickets') {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer $_pairing',
        );
        expect(
          jsonDecode(await utf8.decoder.bind(request).join()),
          <String, Object>{'requestedTenantId': 'personal-loopback'},
        );
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object>{
              'ticket': _ticket,
              'expiresInSeconds': 10,
              'testOnly': true,
            }),
          );
        await request.response.close();
        return;
      }
      if (request.uri.path == '/v1/chat/ws') {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer $_ticket',
        );
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add(
          jsonEncode(
            _event(1, 'connection.ready', <String, Object>{
              'authentication': 'test-ticket-local-only',
              'modelProvider': 'chatgpt-siwc',
              'persistence': 'private-sqlite',
            }),
          ),
        );
        final command = jsonDecode(await socket.first as String);
        receivedCommand.complete(command as Map<String, dynamic>);
        socket.add(
          jsonEncode(
            _event(2, 'chat.accepted', <String, Object>{
              'snapshot': _snapshot('pending', accepted: true),
            }, withIds: true),
          ),
        );
        socket.add(
          jsonEncode(
            _event(3, 'chat.completed', <String, Object>{
              'snapshot': _snapshot('complete', accepted: false),
            }, withIds: true),
          ),
        );
        await socket.close();
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test(
    'single-use ticket socket preserves IDs and returns durable answer',
    () async {
      final snapshot = await const PersonalChatHttpClient().send(
        pairing: _pairing,
        clientMessageId: _clientId,
        bodyText: '안녕하세요',
      );

      final command = await receivedCommand.future;
      expect(command, <String, Object>{
        'protocolVersion': 1,
        'type': 'chat.send',
        'requestId': _clientId,
        'sessionId': 'personal-loopback',
        'message': '안녕하세요',
      });
      final turn = snapshot.turn(_clientId)!;
      expect(turn.clientMessageId, _clientId);
      expect(turn.clientRequestId, _clientId);
      expect(turn.assistantMessageId, _assistantId);
      expect(turn.state, 'complete');
      expect(turn.answer, '합성 WebSocket 답변');
    },
  );
}

Map<String, Object> _event(
  int sequence,
  String type,
  Map<String, Object> payload, {
  bool withIds = false,
}) => <String, Object>{
  'protocolVersion': 1,
  'type': type,
  'eventId': '00000000-0000-4000-8000-00000000000$sequence',
  'eventSequence': sequence,
  'sentAt': '2026-11-24T03:00:0${sequence}Z',
  if (withIds) 'requestId': _clientId,
  if (withIds) 'sessionId': 'personal-loopback',
  'payload': payload,
};

Map<String, Object?> _snapshot(String state, {required bool accepted}) =>
    <String, Object?>{
      'schemaVersion': 1,
      'testOnly': true,
      'modelProvider': 'chatgpt-siwc',
      'model': 'synthetic',
      'turns': <Object>[
        <String, Object?>{
          'sequence': 1,
          'clientMessageId': _clientId,
          'clientRequestId': _clientId,
          'assistantMessageId': _assistantId,
          'bodyText': '안녕하세요',
          'state': state,
          'answer': state == 'complete' ? '합성 WebSocket 답변' : null,
        },
      ],
      'cleanup': null,
      if (accepted)
        'acceptance': <String, Object>{
          'durable': true,
          'sequence': 1,
          'clientMessageId': _clientId,
          'clientRequestId': _clientId,
        },
    };
