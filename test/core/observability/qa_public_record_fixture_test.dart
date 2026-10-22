import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';

void main() {
  test('QA public record rejects build wrapper as event code', () {
    String result = '';
    try {
      final record = AppLogRecord(
        level: AppLogLevel.info,
        eventCode: SafeLogText.buildValue('canary-secret.pdf'),
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        fields: {},
      );
      final sink = FakeAppLogSink();
      sink.write(record);
      result = jsonEncode(sink.records.single.export);
    } on Object catch (e) {
      result = e.toString();
    }
    expect(result, isNot(contains('canary-secret.pdf')));
  });
}
