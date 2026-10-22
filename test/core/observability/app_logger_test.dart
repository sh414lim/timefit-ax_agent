import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';

void main() {
  late FakeAppLogSink sink;
  late AppLogger logger;

  setUp(() {
    sink = FakeAppLogSink();
    logger = AppLogger(
      context: AppLogContext(
        environment: 'test',
        app: 'timefit-native',
        build: '0.1.0+1',
      ),
      sink: sink,
    );
  });

  test('exports only typed allowlisted fields', () {
    logger.record(
      'send_failed',
      fields: {
        'clientMessageId': ClientMessageId('message-1'),
        'attachmentId': 'private-file-name.png',
        'body': 'private body',
      },
    );

    final encoded = jsonEncode(sink.records.single.export);
    expect(encoded, contains('message-1'));
    expect(encoded, contains(redactedValue));
    expect(encoded, isNot(contains('private')));
    expect(encoded, isNot(contains('body')));
  });

  test('typed local metrics have stable codes and safe values', () {
    logger
      ..metric(
        OutboxAgeMetric(
          age: const Duration(seconds: 3),
          clientMessageId: ClientMessageId('message-1'),
        ),
      )
      ..metric(
        SendLatencyMetric(
          latency: const Duration(milliseconds: 250),
          clientMessageId: ClientMessageId('message-1'),
        ),
      )
      ..metric(
        UploadStageMetric(
          stage: UploadStage.uploading,
          attachmentId: AttachmentId('attachment-1'),
        ),
      )
      ..metric(const ReconnectMetric(attempt: 2))
      ..metric(GapCountMetric(count: 4, eventId: EventId('event-1')));

    expect(sink.records.map((record) => record.export['eventCode']), [
      'outbox_age',
      'send_latency',
      'upload_stage',
      'reconnect',
      'gap_count',
    ]);
  });

  test('sink failure is swallowed without a fallback export', () {
    final failing = AppLogger(
      context: AppLogContext(environment: 'test', app: 'app', build: '1'),
      sink: _FailingSink(),
    );

    expect(
      () => failing.record('safe_event', fields: {'body': 'secret'}),
      returnsNormally,
    );
  });

  test('invalid context is rejected and invalid event is ignored', () {
    expect(
      () => AppLogContext(environment: 'preview', app: 'app', build: '1'),
      throwsArgumentError,
    );
    expect(() => logger.record('free form event'), returnsNormally);
    expect(sink.records, isEmpty);
  });
}

final class _FailingSink implements AppLogSink {
  @override
  void write(AppLogRecord record) => throw StateError('sink secret');
}
