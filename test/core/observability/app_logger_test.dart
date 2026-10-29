import 'dart:async';
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

  test(
    'delayed sink failure completes safely without fallback export',
    () async {
      final failing = AppLogger(
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        sink: _DelayedFailingSink(),
      );

      await expectLater(
        failing.record('safe_event', fields: {'body': 'secret'}),
        completes,
      );
    },
  );

  test('synchronous sink throw also completes without an error', () async {
    final failing = AppLogger(
      context: AppLogContext(environment: 'test', app: 'app', build: '1'),
      sink: _SynchronouslyFailingSink(),
    );

    await expectLater(failing.record('safe_event'), completes);
  });

  test(
    'ignored record and metric Futures contain delayed sink errors',
    () async {
      final release = Completer<void>();
      final failingSink = _ControlledFailingSink(release.future);
      final failing = AppLogger(
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        sink: failingSink,
      );
      final uncaught = <Object>[];

      await runZonedGuarded(() async {
        // Existing preview/crash callers may intentionally ignore these Futures.
        unawaited(
          failing.record('safe_event', fields: {'body': 'private body'}),
        );
        unawaited(
          failing.metric(
            OutboxAgeMetric(
              age: const Duration(seconds: 1),
              clientMessageId: ClientMessageId('message-1'),
            ),
          ),
        );
        expect(failingSink.records, hasLength(2));
        release.complete();
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => uncaught.add(error));

      expect(uncaught, isEmpty);
      final export = jsonEncode(
        failingSink.records.map((record) => record.export).toList(),
      );
      expect(export, contains('message-1'));
      expect(export, isNot(contains('private body')));
      expect(export, isNot(contains('sink secret')));
    },
  );

  test('invalid context is rejected and invalid event is ignored', () {
    expect(
      () => AppLogContext(environment: 'preview', app: 'app', build: '1'),
      throwsArgumentError,
    );
    expect(() => logger.record('free form event'), returnsNormally);
    expect(sink.records, isEmpty);
  });
}

final class _DelayedFailingSink implements AppLogSink {
  @override
  Future<void> write(AppLogRecord record) async {
    await Future<void>.delayed(Duration.zero);
    throw StateError('sink secret');
  }
}

final class _SynchronouslyFailingSink implements AppLogSink {
  @override
  Future<void> write(AppLogRecord record) => throw StateError('sink secret');
}

final class _ControlledFailingSink implements AppLogSink {
  _ControlledFailingSink(this.release);

  final Future<void> release;
  final records = <AppLogRecord>[];

  @override
  Future<void> write(AppLogRecord record) async {
    records.add(record);
    await release;
    throw StateError('sink secret');
  }
}
