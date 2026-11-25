import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

final class ProductionChatFailure implements Exception {
  const ProductionChatFailure(this.code, {this.commandSent = false});
  final String code;
  final bool commandSent;
}

final class ProductionChatScope {
  ProductionChatScope({required this.tenantId, required this.conversationId}) {
    requireChatUuid(tenantId);
    requireChatUuid(conversationId);
  }

  final String tenantId;
  final String conversationId;
}

void requireChatUuid(String value) {
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(value)) {
    throw const FormatException('Invalid chat identity');
  }
}

String productionBodyDigest(String body) =>
    sha256.convert(utf8.encode(body.trim())).toString();

final class ProductionChatTurn {
  const ProductionChatTurn({
    required this.sequence,
    required this.requestId,
    required this.assistantId,
    required this.bodySha256,
    required this.state,
    this.answer,
  });

  final int sequence;
  final String requestId;
  final String assistantId;
  final String bodySha256;
  final String state;
  final String? answer;

  static ProductionChatTurn decode(Object? raw, String requestId) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid chat turn');
    }
    final complete = raw['state'] == 'complete';
    final expected = <String>{
      'sequence',
      'clientMessageId',
      'clientRequestId',
      'assistantMessageId',
      'bodySha256',
      'state',
      if (complete) 'answer',
    };
    final sequence = raw['sequence'];
    final assistantId = raw['assistantMessageId'];
    final digest = raw['bodySha256'];
    final answer = raw['answer'];
    if (raw.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(raw.keys.toSet()).isNotEmpty ||
        sequence is! int ||
        sequence < 1 ||
        sequence > 8 ||
        raw['clientMessageId'] != requestId ||
        raw['clientRequestId'] != requestId ||
        assistantId is! String ||
        assistantId == requestId ||
        digest is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
        !<String>{
          'pending',
          'complete',
          'dispatch_unknown',
        }.contains(raw['state']) ||
        (complete &&
            (answer is! String ||
                answer.isEmpty ||
                utf8.encode(answer).length > 6000))) {
      throw const FormatException('Invalid chat turn');
    }
    requireChatUuid(assistantId);
    return ProductionChatTurn(
      sequence: sequence,
      requestId: requestId,
      assistantId: assistantId,
      bodySha256: digest,
      state: raw['state']! as String,
      answer: complete ? answer! as String : null,
    );
  }
}

abstract interface class ProductionChatApi {
  Future<ProductionChatTurn?> lookup(
    ProductionChatScope scope,
    String requestId,
  );
  Future<ProductionChatTurn> send(
    ProductionChatScope scope,
    String requestId,
    String body,
  );
}

/// Explicit HTTPS/WSS adapter. Nothing imports or enables this from app startup.
/// The composition owns login, endpoint discovery and authenticated DB isolation.
final class ProductionChatTransport implements ProductionChatApi {
  ProductionChatTransport({
    required this.origin,
    required Set<String> allowedHosts,
    required this.accessToken,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new {
    if (origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.path.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        !allowedHosts.contains(origin.authority)) {
      throw ArgumentError('Approved HTTPS chat origin required');
    }
  }

  final Uri origin;
  final Future<String?> Function() accessToken;
  final HttpClient Function() _clientFactory;

  @override
  Future<ProductionChatTurn?> lookup(
    ProductionChatScope scope,
    String requestId,
  ) => _exchange(scope, requestId);

  @override
  Future<ProductionChatTurn> send(
    ProductionChatScope scope,
    String requestId,
    String body,
  ) async {
    if (body.trim().isEmpty || utf8.encode(body.trim()).length > 4096) {
      throw const ProductionChatFailure('production_message_invalid');
    }
    final value = await _exchange(scope, requestId, body: body.trim());
    if (value == null)
      throw const ProductionChatFailure('production_response_invalid');
    return value;
  }

  Future<ProductionChatTurn?> _exchange(
    ProductionChatScope scope,
    String requestId, {
    String? body,
  }) async {
    requireChatUuid(requestId);
    final deadline = Stopwatch()..start();
    Duration remaining() {
      final value = const Duration(seconds: 22) - deadline.elapsed;
      if (value <= Duration.zero) throw TimeoutException('Chat deadline');
      return value;
    }

    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 4)
      ..findProxy = ((_) => 'DIRECT');
    WebSocket? socket;
    StreamIterator<dynamic>? frames;
    var commandSent = false;
    ProductionChatTurn? accepted;
    try {
      final token = await accessToken().timeout(remaining());
      if (token == null ||
          token.length < 8 ||
          token.length > 8192 ||
          token.codeUnits.any((value) => value < 33 || value > 126)) {
        throw const ProductionChatFailure('production_auth_required');
      }
      final request = await client
          .postUrl(origin.resolve('/v1/ws-tickets'))
          .timeout(remaining());
      request.followRedirects = false;
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..contentType = ContentType.json
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.write(
        jsonEncode(<String, String>{
          'tenantId': scope.tenantId,
          'conversationId': scope.conversationId,
        }),
      );
      final response = await request.close().timeout(remaining());
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ProductionChatFailure('production_auth_required');
      }
      if (response.statusCode != 200 ||
          response.headers.contentType?.mimeType != 'application/json') {
        throw const ProductionChatFailure('production_ticket_unavailable');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(remaining())) {
        bytes.addAll(chunk);
        if (bytes.length > 4096)
          throw const FormatException('Ticket too large');
        remaining();
      }
      final ticket = decodeProductionJson(utf8.decode(bytes));
      final ticketValue = ticket['ticket'];
      final ttl = ticket['expiresInSeconds'];
      if (ticket.length != 3 ||
          ticketValue is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(ticketValue) ||
          ttl is! int ||
          ttl < 1 ||
          ttl > 30 ||
          ticket['websocketPath'] != '/v1/chat/ws') {
        throw const FormatException('Invalid production ticket');
      }
      socket = await WebSocket.connect(
        origin.replace(scheme: 'wss', path: '/v1/chat/ws').toString(),
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer $ticketValue',
        },
        customClient: client,
        compression: CompressionOptions.compressionOff,
      ).timeout(remaining());
      frames = StreamIterator<dynamic>(socket);
      var sequence = 1;
      Future<Map<String, dynamic>> next() async {
        if (!await frames!.moveNext().timeout(remaining()) ||
            frames.current is! String) {
          throw const FormatException('Socket ended');
        }
        final event = decodeProductionJson(frames.current as String);
        final eventId = event['eventId'];
        final sentAt = event['sentAt'];
        if (event['protocolVersion'] != 1 ||
            event['eventSequence'] != sequence++ ||
            eventId is! String ||
            sentAt is! String ||
            DateTime.tryParse(sentAt)?.isUtc != true ||
            event['payload'] is! Map<String, dynamic>) {
          throw const FormatException('Invalid production event');
        }
        requireChatUuid(eventId);
        return event;
      }

      final ready = await next();
      final readyPayload = ready['payload']! as Map<String, dynamic>;
      if (ready['type'] != 'connection.ready' ||
          readyPayload['authentication'] != 'single-use-ticket' ||
          readyPayload['modelProvider'] != 'openai-api' ||
          readyPayload['persistence'] != 'private-sqlite') {
        throw const FormatException('Invalid production ready');
      }
      remaining();
      final command = jsonEncode(<String, Object>{
        'protocolVersion': 1,
        'type': body == null ? 'chat.lookup' : 'chat.send',
        'requestId': requestId,
        'sessionId': scope.conversationId,
        if (body != null) 'message': body,
      });
      commandSent = body != null;
      socket.add(command);
      while (true) {
        final event = await next();
        if (event['type'] == 'error')
          throw const FormatException('Chat rejected');
        if (event['requestId'] != requestId ||
            event['sessionId'] != scope.conversationId) {
          throw const FormatException('Chat scope mismatch');
        }
        final payload = event['payload']! as Map<String, dynamic>;
        if (body == null) {
          if (event['type'] != 'chat.status' ||
              payload.length != 1 ||
              !payload.containsKey('turn')) {
            throw const FormatException('Invalid chat lookup');
          }
          return payload['turn'] == null
              ? null
              : ProductionChatTurn.decode(payload['turn'], requestId);
        }
        final turn = ProductionChatTurn.decode(payload['turn'], requestId);
        if (turn.bodySha256 != productionBodyDigest(body)) {
          throw const FormatException('Chat body mismatch');
        }
        if (event['type'] == 'chat.accepted' &&
            accepted == null &&
            payload['durable'] == true) {
          accepted = turn;
          continue;
        }
        if (accepted == null ||
            accepted.sequence != turn.sequence ||
            accepted.assistantId != turn.assistantId ||
            !((event['type'] == 'chat.completed' && turn.state == 'complete') ||
                (event['type'] == 'chat.dispatch_unknown' &&
                    turn.state == 'dispatch_unknown'))) {
          throw const FormatException('Chat identity changed');
        }
        return turn;
      }
    } on ProductionChatFailure {
      rethrow;
    } on Object {
      if (accepted != null) return accepted;
      throw ProductionChatFailure(
        'production_transport_unavailable',
        commandSent: commandSent,
      );
    } finally {
      client.close(force: true);
      try {
        await socket?.close().timeout(const Duration(milliseconds: 500));
      } on Object {
        // The operation is finished; no reconnect or resend is started here.
      }
      try {
        await frames?.cancel().timeout(const Duration(milliseconds: 500));
      } on Object {
        // Cleanup cannot change the durable result.
      }
    }
  }
}

/// Bound depth/bytes and reject duplicate object keys before JSON decoding.
Map<String, dynamic> decodeProductionJson(String raw) {
  if (utf8.encode(raw).length > 8192)
    throw const FormatException('Chat frame too large');
  final stack = <Set<String>?>[];
  var keyExpected = false;
  for (var index = 0; index < raw.length; index++) {
    final char = raw[index];
    if (char == '"') {
      final start = index;
      while (++index < raw.length) {
        if (raw[index] == '\\') {
          index++;
          continue;
        }
        if (raw[index] == '"') break;
      }
      if (index >= raw.length) throw const FormatException('Incomplete JSON');
      if (keyExpected && stack.isNotEmpty && stack.last != null) {
        final key = jsonDecode(raw.substring(start, index + 1)) as String;
        if (!stack.last!.add(key))
          throw const FormatException('Duplicate JSON key');
      }
      keyExpected = false;
    } else if (char == '{' || char == '[') {
      stack.add(char == '{' ? <String>{} : null);
      keyExpected = char == '{';
      if (stack.length > 16) throw const FormatException('JSON too deep');
    } else if (char == '}' || char == ']') {
      if (stack.isEmpty) throw const FormatException('Invalid JSON');
      stack.removeLast();
      keyExpected = false;
    } else if (char == ',') {
      keyExpected = stack.isNotEmpty && stack.last != null;
    } else if (char == ':') {
      keyExpected = false;
    }
  }
  final value = jsonDecode(raw);
  void check(Object? item) {
    if (item is num && (!item.isFinite || item.abs() > 9007199254740991)) {
      throw const FormatException('Unbounded number');
    }
    if (item is Map) {
      for (final child in item.values) {
        check(child);
      }
    }
    if (item is List) {
      for (final child in item) {
        check(child);
      }
    }
  }

  check(value);
  if (value is! Map<String, dynamic>)
    throw const FormatException('JSON object required');
  return value;
}
