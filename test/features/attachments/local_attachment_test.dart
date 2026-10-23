import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/attachments/application/select_attachments.dart';
import 'package:timefit_native/features/attachments/data/local_attachment_store.dart';
import 'package:timefit_native/features/attachments/domain/attachment_policy.dart';

const signatures = <String, List<int>>{
  'jpg': [255, 216, 255, 224, 1],
  'png': [137, 80, 78, 71, 13, 10, 26, 10, 1],
  'webp': [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80, 1],
  'pdf': [37, 80, 68, 70, 45, 49, 46, 55],
};

class CleanupFailureStore implements AttachmentStore {
  CleanupFailureStore(this.delegate);
  final AttachmentStore delegate;
  @override
  Future<PrivateAttachment> copy(
    AttachmentInput input,
    AttachmentCancellation cancellation,
  ) => delegate.copy(input, cancellation);
  @override
  Future<void> delete(PrivateAttachment attachment) async {
    throw const FileSystemException('cleanup fixture');
  }
}

AttachmentInput input(String extension, {List<int>? bytes, String? mime}) =>
    AttachmentInput(
      name: 'original.$extension',
      declaredMime: mime,
      openRead: () => Stream.value(bytes ?? signatures[extension]!),
    );

void main() {
  late Directory sandbox;
  late Directory root;
  late LocalAttachmentStore store;
  late SelectAttachments select;
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('timefit-attachment-');
    root = await Directory('${sandbox.path}/private').create();
    store = LocalAttachmentStore(privateRoot: root);
    select = SelectAttachments(store);
  });
  tearDown(() => sandbox.delete(recursive: true));

  for (final extension in signatures.keys) {
    test(
      'accepts $extension with matching header and streaming digest',
      () async {
        final result = (await select.select([input(extension)])).single;
        expect(
          result.sha256,
          sha256.convert(signatures[extension]!).toString(),
        );
        expect(result.bytesTotal, signatures[extension]!.length);
        expect(
          File.fromUri(result.uri).parent.path,
          await root.resolveSymbolicLinks(),
        );
        expect(
          result.uri.pathSegments.last,
          matches(RegExp(r'^[0-9a-f-]{36}$')),
        );
        expect(result.uri.toString(), isNot(contains('original')));
      },
    );
  }
  test(
    'rejects renamed HTML SVG ZIP and mismatched extension or declared MIME',
    () async {
      for (final bad in [
        input('jpg', bytes: '<html>malware</html>'.codeUnits),
        input('svg', bytes: '<svg/>'.codeUnits),
        input('zip', bytes: [80, 75, 3, 4]),
        input('jpg', bytes: signatures['pdf']),
        input('pdf', mime: 'image/png'),
      ]) {
        await expectLater(
          select.select([bad]),
          throwsA(isA<AttachmentException>()),
        );
        expect(await root.list().toList(), isEmpty);
      }
    },
  );
  Stream<List<int>> sized(int count) async* {
    final header = signatures['pdf']!;
    yield header;
    var remaining = count - header.length;
    final block = List<int>.filled(65536, 0);
    while (remaining > 0) {
      final length = remaining < block.length ? remaining : block.length;
      yield length == block.length ? block : block.sublist(0, length);
      remaining -= length;
    }
  }

  test(
    'exact 20 MiB accepted while zero and 20 MiB plus one are rejected',
    () async {
      for (final size in [
        0,
        AttachmentPolicy.maximumBytes,
        AttachmentPolicy.maximumBytes + 1,
      ]) {
        final picked = AttachmentInput(
          name: 'size.pdf',
          openRead: () => size == 0 ? const Stream.empty() : sized(size),
        );
        if (size == AttachmentPolicy.maximumBytes) {
          final result = (await select.select([picked])).single;
          expect(result.bytesTotal, size);
          await store.delete(result);
        } else {
          await expectLater(
            select.select([picked]),
            throwsA(isA<AttachmentException>()),
          );
        }
        expect(await root.list().toList(), isEmpty);
      }
    },
  );
  test(
    'five allowed six rejected before opening and existing count is enforced',
    () async {
      final five = await select.select(List.generate(5, (_) => input('pdf')));
      expect(five, hasLength(5));
      for (final item in five) {
        await store.delete(item);
      }
      var opened = 0;
      final picked = AttachmentInput(
        name: 'x.pdf',
        openRead: () {
          opened++;
          return Stream.value(signatures['pdf']!);
        },
      );
      await expectLater(
        select.select(List.filled(6, picked)),
        throwsA(isA<AttachmentException>()),
      );
      await expectLater(
        select.select([picked], existingCount: 5),
        throwsA(isA<AttachmentException>()),
      );
      expect(opened, 0);
    },
  );
  test('picker cancel returns no selection and creates no files', () async {
    expect(await select.select(null), isEmpty);
    expect(await select.select([]), isEmpty);
    expect(await root.list().toList(), isEmpty);
  });

  test('split headers and streaming chunks produce the same SHA-256', () async {
    final bytes = signatures['png']!;
    final picked = AttachmentInput(
      name: 'split.png',
      openRead: () => Stream.fromIterable(bytes.map((byte) => [byte])),
    );
    final result = (await select.select([picked])).single;
    expect(result.sha256, sha256.convert(bytes).toString());
  });

  test('pre-cancelled selection opens no input and creates no copy', () async {
    final token = AttachmentCancellation()..cancel();
    var opened = false;
    await expectLater(
      select.select([
        AttachmentInput(
          name: 'x.pdf',
          openRead: () {
            opened = true;
            return Stream.value(signatures['pdf']!);
          },
        ),
      ], cancellation: token),
      throwsA(isA<AttachmentException>()),
    );
    expect(opened, isFalse);
    expect(await root.list().toList(), isEmpty);
  });

  test(
    'cleanup failure exposes remaining private copies for explicit retry',
    () async {
      final selection = SelectAttachments(CleanupFailureStore(store));
      try {
        await selection.select([
          input('pdf'),
          input('jpg', bytes: [1]),
        ]);
        fail('expected cleanup failure');
      } on AttachmentSelectionException catch (error) {
        expect(error.residualAttachments, hasLength(1));
        final remaining = error.residualAttachments.single;
        expect(await File.fromUri(remaining.uri).exists(), isTrue);
        await store.delete(remaining);
      }
      expect(await root.list().toList(), isEmpty);
    },
  );
  test('private copy can be reopened after original source deletion', () async {
    final source = await File(
      '${sandbox.path}/source.pdf',
    ).writeAsBytes(signatures['pdf']!);
    final result = (await select.select([
      AttachmentInput(name: 'source.pdf', openRead: source.openRead),
    ])).single;
    await source.delete();
    expect(
      await File.fromUri(
        result.uri,
      ).openRead().fold<int>(0, (sum, chunk) => sum + chunk.length),
      result.bytesTotal,
    );
    expect(
      sha256.convert(await File.fromUri(result.uri).readAsBytes()).toString(),
      result.sha256,
    );
  });
  test(
    'stream failure rolls back completed files and partial destination',
    () async {
      Stream<List<int>> broken() async* {
        yield signatures['pdf']!;
        throw const FileSystemException('fixture');
      }

      await expectLater(
        select.select([
          input('pdf'),
          AttachmentInput(name: 'bad.pdf', openRead: broken),
        ]),
        throwsA(isA<FileSystemException>()),
      );
      expect(await root.list().toList(), isEmpty);
    },
  );
  test(
    'cancel stalled source without next chunk or source close cleans partial copy',
    () async {
      final token = AttachmentCancellation();
      final source = StreamController<List<int>>();
      final delivered = Completer<void>();
      var cancelled = false;
      source.onCancel = () {
        cancelled = true;
      };
      final running = select.select([
        AttachmentInput(
          name: 'stalled.pdf',
          openRead: () {
            scheduleMicrotask(() {
              source.add(signatures['pdf']!);
              delivered.complete();
            });
            return source.stream;
          },
        ),
      ], cancellation: token);
      final rejected = expectLater(
        running,
        throwsA(
          isA<AttachmentException>().having(
            (e) => e.failure,
            'failure',
            AttachmentFailure.cancelled,
          ),
        ),
      );
      await delivered.future;
      // Give the header write time to finish, then leave the source open forever.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();
      await rejected.timeout(const Duration(seconds: 2));
      expect(cancelled, isTrue);
      expect(await root.list().toList(), isEmpty);
      await source.close();
    },
  );

  test('mid-stream cancellation cleans the entire batch', () async {
    final token = AttachmentCancellation();
    Stream<List<int>> cancelled() async* {
      yield signatures['pdf']!;
      token.cancel();
      yield [1];
    }

    await expectLater(
      select.select([
        input('pdf'),
        AttachmentInput(name: 'cancel.pdf', openRead: cancelled),
      ], cancellation: token),
      throwsA(
        isA<AttachmentException>().having(
          (e) => e.failure,
          'failure',
          AttachmentFailure.cancelled,
        ),
      ),
    );
    expect(await root.list().toList(), isEmpty);
  });
  test(
    'path traversal input and unsafe UUID never become destination paths',
    () async {
      await expectLater(
        select.select([
          AttachmentInput(
            name: '../file.pdf',
            openRead: () => Stream.value(signatures['pdf']!),
          ),
        ]),
        throwsA(isA<AttachmentException>()),
      );
      final unsafe = LocalAttachmentStore(
        privateRoot: root,
        uuid: () => '../outside',
      );
      await expectLater(
        unsafe.copy(input('pdf'), AttachmentCancellation()),
        throwsA(isA<AttachmentException>()),
      );
      expect(await root.list().toList(), isEmpty);
    },
  );
  test(
    'existing UUID and symlink roots are rejected without overwriting data',
    () async {
      const id = '00000000-0000-4000-8000-000000000000';
      final existing = await File('${root.path}/$id').writeAsString('keep');
      final collision = LocalAttachmentStore(privateRoot: root, uuid: () => id);
      await expectLater(
        collision.copy(input('pdf'), AttachmentCancellation()),
        throwsA(isA<AttachmentException>()),
      );
      expect(await existing.readAsString(), 'keep');
      final link = await Link('${sandbox.path}/alias').create(root.path);
      await expectLater(
        LocalAttachmentStore(
          privateRoot: Directory(link.path),
        ).copy(input('pdf'), AttachmentCancellation()),
        throwsA(isA<AttachmentException>()),
      );
    },
  );
  test('delete refuses foreign paths and symlink substitution', () async {
    final copied = (await select.select([input('pdf')])).single;
    final outside = await File('${sandbox.path}/outside').writeAsString('keep');
    await File.fromUri(copied.uri).delete();
    await Link.fromUri(copied.uri).create(outside.path);
    await expectLater(
      store.delete(copied),
      throwsA(isA<AttachmentException>()),
    );
    expect(await outside.readAsString(), 'keep');
    await expectLater(
      store.delete(
        PrivateAttachment(
          uri: outside.uri,
          displayName: 'fixture.pdf',
          contentType: 'application/pdf',
          bytesTotal: 4,
          sha256: 'unused',
        ),
      ),
      throwsA(isA<AttachmentException>()),
    );
  });
}
