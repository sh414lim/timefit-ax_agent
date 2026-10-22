import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';
import 'package:timefit_native/features/attachments/application/attachment_download_controller.dart';

void main() {
  test(
    'existing preview telemetry records only code and typed attachment id',
    () {
      final sink = FakeAppLogSink();
      final telemetry = AppLoggerAttachmentPreviewTelemetry(
        logger: AppLogger(
          context: AppLogContext(
            environment: 'test',
            app: 'timefit-native',
            build: '1',
          ),
          sink: sink,
        ),
        attachmentId: 'attachment-1',
      );

      telemetry.record('attachment_url_ready');

      expect(sink.records.single.export['eventCode'], 'attachment_url_ready');
      expect(jsonEncode(sink.records.single.export), contains('attachment-1'));
    },
  );

  test('sink failure never breaks preview telemetry caller', () {
    final telemetry = AppLoggerAttachmentPreviewTelemetry(
      logger: AppLogger(
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        sink: _FailingSink(),
      ),
      attachmentId: 'attachment-1',
    );

    expect(() => telemetry.record('attachment_url_ready'), returnsNormally);
  });

  test('invalid adapter inputs do not escape the observability boundary', () {
    final sink = FakeAppLogSink();
    final telemetry = AppLoggerAttachmentPreviewTelemetry(
      logger: AppLogger(
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        sink: sink,
      ),
      attachmentId: 'https://host/path?token=canary',
    );

    expect(
      () => telemetry.record('https://host/path?token=canary'),
      returnsNormally,
    );
    expect(sink.records, isEmpty);
  });
}

final class _FailingSink implements AppLogSink {
  @override
  void write(AppLogRecord record) => throw StateError('must not escape');
}
