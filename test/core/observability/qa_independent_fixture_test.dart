import 'dart:collection';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';
import 'package:timefit_native/features/attachments/application/attachment_download_controller.dart';

AppLogger logger(AppLogSink sink) => AppLogger(
  context: AppLogContext(environment: 'test', app: 'app', build: '1'),
  sink: sink,
);
void main() {
  test('QA stable field cannot accept build wrapper filename', () {
    final sink = FakeAppLogSink();
    logger(sink).record(
      'send_failed',
      fields: {
        'errorCode': SafeLogText.buildValue('canary-secret.pdf'),
        'stage': SafeLogText.buildValue('canary-token'),
      },
    );
    expect(jsonEncode(sink.records.single.export), isNot(contains('canary')));
  });
  test('QA global traversal budget bounds shared nested lists', () {
    final leaf = CountingLeaf();
    Object tree = leaf;
    for (var i = 0; i < 5; i++) {
      tree = List<Object>.filled(32, tree);
    }
    redactForExport(tree);
    expect(leaf.visits, lessThanOrEqualTo(256));
  });
  test('QA wrapper cannot export a sensitive filename as correlation', () {
    final sink = FakeAppLogSink();
    logger(sink).record(
      'send_failed',
      fields: {
        'clientMessageId': ClientMessageId('canary-secret.pdf'),
        'attachmentId': SafeLogText.buildValue('canary-token'),
      },
    );
    expect(jsonEncode(sink.records.single.export), isNot(contains('canary')));
  });
  test('QA rejected value does not escape in validation exception', () {
    Object? caught;
    try {
      logger(FakeAppLogSink()).record('https://host/path?token=canary-secret');
    } on Object catch (e) {
      caught = e;
    }
    expect(caught.toString(), isNot(contains('canary-secret')));
  });
  test('QA map traversal has a finite entry budget', () {
    final bomb = BudgetMap();
    redactForExport(bomb);
    expect(bomb.visits, lessThanOrEqualTo(64));
  });
  test('QA nonfinite metric remains JSON exportable', () {
    final sink = FakeAppLogSink();
    logger(
      sink,
    ).record('reconnect', fields: {'attempt': const SafeLogNumber(double.nan)});
    expect(() => jsonEncode(sink.records.single.export), returnsNormally);
  });
  test(
    'QA actual preview path preserves correlation and redacts canaries',
    () async {
      final sink = FakeAppLogSink();
      final c = AttachmentDownloadController(
        metadata: const AttachmentPreviewMetadata(
          attachmentId: 'attachment-1',
          displayName: 'canary-file.pdf',
          contentType: 'application/pdf',
        ),
        provider: P(),
        clock: () => DateTime.utc(2026),
        memoryCache: AttachmentUrlMemoryCache(),
        telemetry: AppLoggerAttachmentPreviewTelemetry(
          logger: logger(sink),
          attachmentId: 'attachment-1',
        ),
      );
      await c.open();
      expect(c.state, isA<AttachmentPreviewReady>());
      final export = jsonEncode(sink.records.map((r) => r.export).toList());
      expect(export, contains('attachment-1'));
      expect(export, isNot(contains('canary')));
      c.dispose();
      final failing = AttachmentDownloadController(
        metadata: const AttachmentPreviewMetadata(
          attachmentId: 'attachment-1',
          displayName: 'canary-file.pdf',
          contentType: 'application/pdf',
        ),
        provider: P(),
        clock: () => DateTime.utc(2026),
        memoryCache: AttachmentUrlMemoryCache(),
        telemetry: AppLoggerAttachmentPreviewTelemetry(
          logger: logger(Failing()),
          attachmentId: 'attachment-1',
        ),
      );
      await failing.open();
      expect(failing.state, isA<AttachmentPreviewReady>());
      failing.dispose();
    },
  );
}

class BudgetMap extends MapBase<String, Object?> {
  int visits = 0;
  @override
  Iterable<MapEntry<String, Object?>> get entries sync* {
    for (var i = 0; i < 1000; i++) {
      visits++;
      yield MapEntry('unknown$i', null);
    }
    throw StateError('bounded simulation of unending entries');
  }

  @override
  Iterable<String> get keys => throw UnimplementedError();
  @override
  Object? operator [](Object? key) => null;
  @override
  void operator []=(String key, Object? value) => throw UnimplementedError();
  @override
  void clear() => throw UnimplementedError();
  @override
  Object? remove(Object? key) => throw UnimplementedError();
}

class P implements AttachmentUrlProvider {
  Future<SignedAttachmentUrl> issue({
    required String attachmentId,
  }) async => SignedAttachmentUrl(
    url: Uri.parse(
      'https://user:canary-pass@host/canary-path?token=canary-token#canary-fragment',
    ),
    expiresAt: DateTime.utc(2026, 1, 1, 0, 5),
  );
}

class Failing implements AppLogSink {
  @override
  Future<void> write(AppLogRecord record) async =>
      throw StateError('canary-sink');
}

class CountingLeaf extends Iterable<Object?> {
  int visits = 0;
  @override
  Iterator<Object?> get iterator => values().iterator;
  Iterable<Object?> values() sync* {
    for (var i = 0; i < 32; i++) {
      visits++;
      if (visits > 10000) throw StateError('stop finite simulation');
      yield const SafeLogNumber(1);
    }
  }
}
