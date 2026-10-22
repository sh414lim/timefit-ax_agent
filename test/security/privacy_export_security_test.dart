import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';

void main() {
  test('security export keeps correlation and removes private payloads', () {
    final sink = FakeAppLogSink();
    final logger = AppLogger(
      context: AppLogContext(
        environment: 'test',
        app: 'timefit-native',
        build: '1.0.0+1',
      ),
      sink: sink,
    );

    logger.record(
      'attachment_security_boundary',
      fields: {
        'attachmentId': AttachmentId('attachment-72'),
        'body': 'canary-private-body',
        'filename': 'canary-private.pdf',
        'url': Uri.parse(
          'https://user:password@example.invalid/private?token=canary#fragment',
        ),
        'nested': <Object?>[
          const FormatException('canary-exception'),
          {'refreshToken': 'canary-refresh'},
        ],
      },
    );

    final encoded = jsonEncode(sink.records.single.export);
    expect(encoded, contains('attachment-72'));
    for (final forbidden in <String>[
      'canary-private-body',
      'canary-private.pdf',
      'user:password',
      'example.invalid',
      'canary-exception',
      'canary-refresh',
    ]) {
      expect(encoded, isNot(contains(forbidden)));
    }
  });

  test('rejected event data never reaches or breaks the sink boundary', () {
    final sink = FakeAppLogSink();
    final logger = AppLogger(
      context: AppLogContext(
        environment: 'test',
        app: 'timefit-native',
        build: '1.0.0+1',
      ),
      sink: sink,
    );

    expect(
      () => logger.record(
        'https://example.invalid/?token=canary',
        fields: {'attachmentId': 'canary-private.pdf'},
      ),
      returnsNormally,
    );
    expect(sink.records, isEmpty);
  });
}
