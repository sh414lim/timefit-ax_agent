import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';

void main() {
  test('raw strings and unknown nested keys never reach export', () {
    final nested = <Object?, Object?>{
      'attachmentId': <Object?>[
        'private-name.png',
        Uri.parse('https://user:pass@example.test/private/path?q=token#frag'),
        {'token': 'refresh-secret'},
      ],
      'body': 'private body',
      'filename': 'private-name.png',
    };

    final encoded = jsonEncode(redactForExport(nested));

    expect(encoded, isNot(contains('private')));
    expect(encoded, isNot(contains('example.test')));
    expect(encoded, isNot(contains('token')));
    expect(encoded, contains(redactedValue));
  });

  test('raw text in an allowlisted id field cannot bypass typed values', () {
    expect(redactForExport({'clientMessageId': 'access-token-value'}), {
      'clientMessageId': redactedValue,
    });
    expect(redactForExport({'clientMessageId': ClientMessageId('message-1')}), {
      'clientMessageId': 'message-1',
    });
  });

  test('cycles, deep data, and arbitrary objects fail closed', () {
    final cyclic = <Object?>[];
    cyclic.add(cyclic);
    Object? deep = const SafeLogNumber(1);
    for (var index = 0; index < 10; index += 1) {
      deep = <Object?>[deep];
    }

    expect(redactForExport(cyclic), [redactedValue]);
    expect(jsonEncode(redactForExport(deep)), contains(redactedValue));
    expect(
      redactForExport(const FormatException('access-token')),
      redactedValue,
    );
    expect(redactForExport(_ThrowingIterable()), redactedValue);
  });

  test('typed values reject URL-shaped and whitespace correlation ids', () {
    expect(
      () => AttachmentId('https://host/path?token=secret'),
      throwsArgumentError,
    );
    expect(() => EventId('event id'), throwsArgumentError);
  });

  test(
    'client message export factory accepts only UUID or test fixture IDs',
    () {
      expect(ClientMessageId.tryForExport('message-7'), isNotNull);
      expect(
        ClientMessageId.tryForExport('8a515cf8-0b89-4fa1-b188-64ab2f088ecc'),
        isNotNull,
      );
      expect(ClientMessageId.tryForExport('canary-private-file.pdf'), isNull);
      expect(
        ClientMessageId.tryForExport('https://host/?token=canary'),
        isNull,
      );
    },
  );
}

final class _ThrowingIterable extends Iterable<Object?> {
  @override
  Iterator<Object?> get iterator => throw StateError('access-token');
}
