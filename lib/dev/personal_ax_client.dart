// Owner-only iPhone simulator ↔ Mac loopback development API.
// Never use this as production authentication or a shared model transport.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

abstract interface class PersonalAxApi {
  Future<Map<String, dynamic>> status(String pairing);
  Future<Map<String, dynamic>> greeting(String pairing, String requestId);
}

class PersonalAxFailure implements Exception {
  const PersonalAxFailure(this.code);
  final String code;

  @override
  String toString() => 'PersonalAxFailure($code)';
}

/// No remote host, TLS downgrade, proxy, model token, or runtime URL overrides.
class PersonalAxHttpClient implements PersonalAxApi {
  const PersonalAxHttpClient();

  static final RegExp _pairingPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  @override
  Future<Map<String, dynamic>> status(String pairing) =>
      _request('GET', '/personal/v1/status', pairing);

  @override
  Future<Map<String, dynamic>> greeting(String pairing, String requestId) =>
      _request(
        'POST',
        '/personal/v1/greeting',
        pairing,
        body: <String, Object>{
          'schemaVersion': 1,
          'clientRequestId': requestId,
        },
      );

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    String pairing, {
    Map<String, Object>? body,
  }) async {
    if (!_pairingPattern.hasMatch(pairing)) {
      throw const PersonalAxFailure('invalid_pairing');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..findProxy = ((_) => 'DIRECT');
    try {
      final request = await client
          .openUrl(
            method,
            Uri(
              scheme: 'http',
              host: '127.0.0.1',
              port: 8790,
              path: path,
            ),
          )
          .timeout(const Duration(seconds: 5));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $pairing');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }

      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in response.timeout(const Duration(seconds: 8))) {
        if (bytes.length + chunk.length > 65536) {
          throw const PersonalAxFailure('response_too_large');
        }
        bytes.add(chunk);
      }

      Object? decoded;
      try {
        decoded = jsonDecode(
          utf8.decode(bytes.takeBytes(), allowMalformed: false),
        );
      } on FormatException {
        throw const PersonalAxFailure('invalid_response');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const PersonalAxFailure('invalid_response');
      }

      if (response.statusCode != (body == null ? 200 : 202)) {
        final code = decoded['code'];
        if (code is String &&
            RegExp(r'^[a-z_]{1,64}$').hasMatch(code)) {
          throw PersonalAxFailure(code);
        }
        throw const PersonalAxFailure('request_rejected');
      }
      if (decoded['schemaVersion'] != 1 ||
          decoded['testOnly'] != true ||
          decoded['modelProvider'] != 'chatgpt-siwc' ||
          decoded['state'] is! String) {
        throw const PersonalAxFailure('invalid_response');
      }
      return decoded;
    } on PersonalAxFailure {
      rethrow;
    } on SocketException {
      throw const PersonalAxFailure('server_unreachable');
    } on HttpException {
      throw const PersonalAxFailure('http_failed');
    } on HandshakeException {
      throw const PersonalAxFailure('transport_failed');
    } on TimeoutException {
      throw const PersonalAxFailure('request_timeout');
    } finally {
      client.close(force: true);
    }
  }
}
