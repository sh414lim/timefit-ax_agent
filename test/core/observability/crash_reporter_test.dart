import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';

void main() {
  test('exception text stack and unsafe fields never reach fake export', () {
    final sink = FakeAppLogSink();
    final reporter = LocalCrashReporter(
      AppLogger(
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        sink: sink,
      ),
    );

    reporter.record(
      stableErrorCode: 'send_timeout',
      exception: Exception(
        'body=hello filename=secret.pdf '
        'https://user:pass@host/path?access_token=x#refresh-token',
      ),
      stackTrace: StackTrace.fromString('token-stack'),
      fields: {
        'clientMessageId': ClientMessageId('message-1'),
        'attachmentId': 'secret.pdf',
      },
    );

    final encoded = jsonEncode(sink.records.single.export);
    expect(encoded, contains('send_timeout'));
    expect(encoded, contains('message-1'));
    expect(encoded, isNot(contains('hello')));
    expect(encoded, isNot(contains('secret.pdf')));
    expect(encoded, isNot(contains('host/path')));
    expect(encoded, isNot(contains('token-stack')));
  });
}
