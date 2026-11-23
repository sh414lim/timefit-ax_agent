// Owner-only iPhone simulator ↔ Mac loopback personal chat contract.
// This file never accepts a configurable host and never carries provider keys.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final class PersonalChatFailure implements Exception {
  const PersonalChatFailure(this.code, {this.postOutcomeUnknown = false});

  final String code;
  final bool postOutcomeUnknown;
}

final class PersonalChatTurn {
  const PersonalChatTurn({
    required this.sequence,
    required this.clientMessageId,
    required this.clientRequestId,
    required this.assistantMessageId,
    required this.bodyText,
    required this.state,
    required this.answer,
  });

  final int sequence;
  final String clientMessageId;
  final String clientRequestId;
  final String assistantMessageId;
  final String bodyText;
  final String state;
  final String? answer;
}

final class PersonalChatSnapshot {
  PersonalChatSnapshot({
    required List<PersonalChatTurn> turns,
    required this.acceptedClientMessageId,
  }) : turns = List.unmodifiable(turns);

  final List<PersonalChatTurn> turns;
  final String? acceptedClientMessageId;

  PersonalChatTurn? turn(String clientMessageId) {
    for (final turn in turns) {
      if (turn.clientMessageId == clientMessageId) return turn;
    }
    return null;
  }
}

abstract interface class PersonalChatApi {
  Future<PersonalChatSnapshot> history(String pairing);

  Future<PersonalChatSnapshot> send({
    required String pairing,
    required String clientMessageId,
    required String bodyText,
  });
}

final class PersonalChatHttpClient implements PersonalChatApi {
  const PersonalChatHttpClient();

  static final RegExp _pairingPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  @override
  Future<PersonalChatSnapshot> history(String pairing) =>
      _request('GET', '/personal/v1/history', pairing);

  @override
  Future<PersonalChatSnapshot> send({
    required String pairing,
    required String clientMessageId,
    required String bodyText,
  }) => _request(
    'POST',
    '/personal/v1/messages',
    pairing,
    body: <String, Object>{
      'schemaVersion': 1,
      'clientRequestId': clientMessageId,
      'bodyText': bodyText,
    },
  );

  Future<PersonalChatSnapshot> _request(
    String method,
    String path,
    String pairing, {
    Map<String, Object>? body,
  }) async {
    if (!_pairingPattern.hasMatch(pairing)) {
      throw const PersonalChatFailure('invalid_pairing');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..findProxy = ((_) => 'DIRECT');
    try {
      final request = await client
          .openUrl(
            method,
            Uri(scheme: 'http', host: '127.0.0.1', port: 8790, path: path),
          )
          .timeout(const Duration(seconds: 5));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $pairing');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        if (bytes.length + chunk.length > 65536) {
          throw const PersonalChatFailure('response_too_large');
        }
        bytes.add(chunk);
      }
      final raw = bytes.takeBytes();
      if (response.statusCode != (body == null ? 200 : 202)) {
        throw PersonalChatFailure(_decodeErrorCode(raw));
      }
      final snapshot = decodePersonalChatSnapshot(raw);
      if (body != null &&
          snapshot.acceptedClientMessageId != body['clientRequestId']) {
        throw const PersonalChatFailure('acceptance_mismatch');
      }
      return snapshot;
    } on PersonalChatFailure {
      rethrow;
    } on SocketException {
      throw PersonalChatFailure(
        'server_unreachable',
        postOutcomeUnknown: body != null,
      );
    } on HttpException {
      throw PersonalChatFailure(
        'http_failed',
        postOutcomeUnknown: body != null,
      );
    } on TimeoutException {
      throw PersonalChatFailure(
        'request_timeout',
        postOutcomeUnknown: body != null,
      );
    } on FormatException {
      throw PersonalChatFailure(
        'invalid_response',
        postOutcomeUnknown: body != null,
      );
    } finally {
      client.close(force: true);
    }
  }
}

String _decodeErrorCode(Uint8List raw) {
  try {
    final value = jsonDecode(utf8.decode(raw, allowMalformed: false));
    if (value is Map<String, dynamic>) {
      final code = value['code'];
      if (code is String && RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(code)) {
        return code;
      }
    }
  } on FormatException {
    // Collapse all untrusted server text to one local code.
  }
  return 'request_rejected';
}

PersonalChatSnapshot decodePersonalChatSnapshot(List<int> bytes) {
  final value = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  if (value is! Map<String, dynamic> ||
      value['schemaVersion'] != 1 ||
      value['testOnly'] != true ||
      value['modelProvider'] != 'chatgpt-siwc' ||
      value['model'] is! String ||
      value['turns'] is! List<dynamic>) {
    throw const FormatException('Invalid personal chat response');
  }
  final rawTurns = value['turns']! as List<dynamic>;
  if (rawTurns.length > 8) {
    throw const FormatException('Invalid personal chat turn count');
  }
  final turns = <PersonalChatTurn>[];
  final clientIds = <String>{};
  final assistantIds = <String>{};
  for (var index = 0; index < rawTurns.length; index++) {
    final raw = rawTurns[index];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid personal chat turn');
    }
    final sequence = raw['sequence'];
    final clientMessageId = raw['clientMessageId'];
    final clientRequestId = raw['clientRequestId'];
    final assistantMessageId = raw['assistantMessageId'];
    final bodyText = raw['bodyText'];
    final state = raw['state'];
    final answer = raw['answer'];
    if (sequence is! int ||
        sequence != index + 1 ||
        clientMessageId is! String ||
        clientRequestId != clientMessageId ||
        !_isUuid(clientMessageId) ||
        assistantMessageId is! String ||
        !_isUuid(assistantMessageId) ||
        assistantMessageId == clientMessageId ||
        bodyText is! String ||
        bodyText.isEmpty ||
        !const {'pending', 'complete', 'dispatch_unknown'}.contains(state) ||
        (state == 'complete' && (answer is! String || answer.isEmpty)) ||
        (state != 'complete' && answer != null) ||
        !clientIds.add(clientMessageId) ||
        !assistantIds.add(assistantMessageId)) {
      throw const FormatException('Invalid personal chat turn');
    }
    turns.add(
      PersonalChatTurn(
        sequence: sequence,
        clientMessageId: clientMessageId,
        clientRequestId: clientRequestId as String,
        assistantMessageId: assistantMessageId,
        bodyText: bodyText,
        state: state! as String,
        answer: answer as String?,
      ),
    );
  }

  String? acceptedClientMessageId;
  final acceptance = value['acceptance'];
  if (acceptance != null) {
    if (acceptance is! Map<String, dynamic> ||
        acceptance['durable'] != true ||
        acceptance['sequence'] is! int ||
        acceptance['clientMessageId'] is! String ||
        acceptance['clientRequestId'] != acceptance['clientMessageId']) {
      throw const FormatException('Invalid durable acceptance');
    }
    acceptedClientMessageId = acceptance['clientMessageId']! as String;
    final acceptedTurn = turns
        .where(
          (turn) =>
              turn.sequence == acceptance['sequence'] &&
              turn.clientMessageId == acceptedClientMessageId,
        )
        .toList(growable: false);
    if (acceptedTurn.length != 1) {
      throw const FormatException('Acceptance has no committed turn');
    }
  }
  return PersonalChatSnapshot(
    turns: turns,
    acceptedClientMessageId: acceptedClientMessageId,
  );
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
).hasMatch(value);
