import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/attachments/application/select_attachments.dart';
import 'package:timefit_native/features/attachments/data/local_attachment_store.dart';
import 'package:timefit_native/features/attachments/domain/attachment_policy.dart';

const _pdf = <int>[37, 80, 68, 70, 45, 49, 46, 55];

void main() {
  late Directory sandbox;
  late Directory privateRoot;
  late SelectAttachments selection;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('timefit-security-');
    privateRoot = await Directory('${sandbox.path}/private').create();
    selection = SelectAttachments(
      LocalAttachmentStore(privateRoot: privateRoot),
    );
  });

  tearDown(() => sandbox.delete(recursive: true));

  test(
    'path-like and control-character filenames fail before persistence',
    () async {
      for (final name in <String>[
        '',
        '.',
        '..',
        '../private.pdf',
        r'..\private.pdf',
        'folder\u2215private.pdf',
        'folder\u2044private.pdf',
        'private\u0001.pdf',
        'private\u007f.pdf',
      ]) {
        await expectLater(
          selection.select([
            AttachmentInput(name: name, openRead: () => Stream.value(_pdf)),
          ]),
          throwsA(
            isA<AttachmentException>().having(
              (error) => error.failure,
              'failure',
              AttachmentFailure.unsafeName,
            ),
          ),
        );
        expect(await privateRoot.list().toList(), isEmpty);
      }
    },
  );

  test('filename cannot override the verified content signature', () async {
    for (final entry in <(String, List<int>, String?)>[
      ('report.pdf.png', _pdf, null),
      ('image.png', '<svg><script/></svg>'.codeUnits, 'image/png'),
      ('archive.pdf', <int>[80, 75, 3, 4], 'application/pdf'),
    ]) {
      await expectLater(
        selection.select([
          AttachmentInput(
            name: entry.$1,
            declaredMime: entry.$3,
            openRead: () => Stream.value(entry.$2),
          ),
        ]),
        throwsA(isA<AttachmentException>()),
      );
      expect(await privateRoot.list().toList(), isEmpty);
    }
  });
}
