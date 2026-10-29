import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_private_chat_filesystem.dart';

void main() {
  const namespaceA = FakePrivateNamespaceId(1);
  const namespaceB = FakePrivateNamespaceId(2);
  final fileA = FakePrivateRelativePath.parse('draft/a.bin');
  final fileB = FakePrivateRelativePath.parse('draft/b.bin');
  final fileC = FakePrivateRelativePath.parse('draft/c.bin');

  test('scripted delete failure retains the retry locator', () async {
    final filesystem = FakePrivateChatFilesystem();
    filesystem.seedFile(namespaceA, fileA);
    filesystem.scriptNext(
      FakePrivateFileOperation.delete,
      FakePrivateFileOutcome.fail,
    );

    await expectLater(
      filesystem.delete(namespaceA, fileA),
      throwsA(isA<FakePrivateFileException>()),
    );
    expect(filesystem.exists(namespaceA, fileA), isTrue);
    await filesystem.delete(namespaceA, fileA);
    expect(filesystem.exists(namespaceA, fileA), isFalse);
    await filesystem.delete(namespaceA, fileA);
  });

  test(
    'file success followed by a later stage failure retries absent',
    () async {
      final filesystem = FakePrivateChatFilesystem();
      filesystem.seedFile(namespaceA, fileA);

      await filesystem.delete(namespaceA, fileA);
      final laterStage = Future<void>.error(
        StateError('stable_fixture_failure'),
      );
      await expectLater(laterStage, throwsStateError);

      await filesystem.delete(namespaceA, fileA);
      expect(filesystem.listNamespace(namespaceA), isEmpty);
    },
  );

  test('quarantine rename and final unlink fail independently', () async {
    final filesystem = FakePrivateChatFilesystem();
    filesystem.seedFile(namespaceA, fileA);

    await filesystem.renameToQuarantine(namespaceA, fileA);
    expect(filesystem.exists(namespaceA, fileA), isFalse);
    expect(filesystem.quarantinedExists(namespaceA, fileA), isTrue);
    filesystem.scriptNext(
      FakePrivateFileOperation.unlinkQuarantined,
      FakePrivateFileOutcome.fail,
    );
    await expectLater(
      filesystem.unlinkQuarantined(namespaceA, fileA),
      throwsA(isA<FakePrivateFileException>()),
    );
    expect(filesystem.quarantinedExists(namespaceA, fileA), isTrue);
    await filesystem.unlinkQuarantined(namespaceA, fileA);
    expect(filesystem.listNamespace(namespaceA), isEmpty);
  });

  test(
    'root purge partial failure leaves undisposed entries discoverable',
    () async {
      final filesystem = FakePrivateChatFilesystem();
      filesystem.seedFile(namespaceA, fileA);
      filesystem.seedFile(namespaceA, fileB);
      filesystem.seedFile(namespaceA, fileC);
      filesystem.scriptNext(
        FakePrivateFileOperation.delete,
        FakePrivateFileOutcome.succeed,
      );
      filesystem.scriptNext(
        FakePrivateFileOperation.delete,
        FakePrivateFileOutcome.fail,
      );

      await expectLater(
        filesystem.purgeNamespace(namespaceA),
        throwsA(isA<FakePrivateFileException>()),
      );
      expect(filesystem.listNamespace(namespaceA), hasLength(2));
      await filesystem.purgeNamespace(namespaceA);
      expect(filesystem.listNamespace(namespaceA), isEmpty);
    },
  );

  test('pending operation releases explicitly as success or failure', () async {
    final filesystem = FakePrivateChatFilesystem();
    filesystem.seedFile(namespaceA, fileA);
    filesystem.scriptNext(
      FakePrivateFileOperation.delete,
      FakePrivateFileOutcome.remainPending,
    );
    final first = filesystem.delete(namespaceA, fileA);
    await _flushAsync();
    final successId = filesystem.pendingOperations.single.id;
    expect(
      filesystem.releasePending(
        successId,
        outcome: FakePrivateFileOutcome.succeed,
      ),
      isTrue,
    );
    await first;
    expect(filesystem.exists(namespaceA, fileA), isFalse);

    filesystem.seedFile(namespaceA, fileA);
    filesystem.scriptNext(
      FakePrivateFileOperation.delete,
      FakePrivateFileOutcome.remainPending,
    );
    final second = filesystem.delete(namespaceA, fileA);
    await _flushAsync();
    final failureId = filesystem.pendingOperations.single.id;
    filesystem.releasePending(failureId, outcome: FakePrivateFileOutcome.fail);
    await expectLater(second, throwsA(isA<FakePrivateFileException>()));
    expect(filesystem.exists(namespaceA, fileA), isTrue);
    filesystem.verifyNoPending();
  });

  test('open handle keeps delete pending until it is closed', () async {
    final filesystem = FakePrivateChatFilesystem();
    filesystem.seedFile(namespaceA, fileA);
    final handle = filesystem.open(namespaceA, fileA);
    var completed = false;

    final deletion = filesystem
        .delete(namespaceA, fileA)
        .then((_) => completed = true);
    await _flushAsync();
    expect(completed, isFalse);
    handle.close();
    await deletion;
    expect(completed, isTrue);
    expect(filesystem.exists(namespaceA, fileA), isFalse);
    filesystem.verifyNoPending();
  });

  test('namespace purge never changes another namespace', () async {
    final filesystem = FakePrivateChatFilesystem();
    filesystem.seedFile(namespaceA, fileA);
    filesystem.seedFile(namespaceB, fileA);

    await filesystem.purgeNamespace(namespaceA);
    await filesystem.purgeNamespace(namespaceA);

    expect(filesystem.listNamespace(namespaceA), isEmpty);
    expect(filesystem.exists(namespaceB, fileA), isTrue);
  });

  test('absolute and traversal-shaped paths are never representable', () {
    for (final value in <String>[
      '/private/a.bin',
      '../a.bin',
      'draft/../a.bin',
      r'C:\private\a.bin',
      'draft//a.bin',
    ]) {
      expect(
        () => FakePrivateRelativePath.parse(value),
        throwsA(
          isA<FakePrivateFileException>().having(
            (error) => error.code,
            'code',
            FakePrivateFileFailure.invalidPath,
          ),
        ),
      );
    }
  });
}

Future<void> _flushAsync() => Future<void>.delayed(Duration.zero);
