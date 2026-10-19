import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/logout_chat_data_purger.dart';

void main() {
  late Directory sandbox;
  late Directory root;
  late AppDatabase database;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp(
      'timefit-purge-regression-',
    );
    root = await Directory('${sandbox.path}/private').create();
    database = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await database.close();
    await sandbox.delete(recursive: true);
  });

  Future<void> track(String id, Uri uri) => database
      .into(database.localAttachments)
      .insert(
        LocalAttachmentsCompanion.insert(
          localId: id,
          conversationId: 'conversation',
          clientMessageId: id,
          localFileUri: Value(uri.toString()),
          contentType: 'image/png',
          sha256: 'fixture',
        ),
      );

  LogoutChatDataPurger purger() => LogoutChatDataPurger(
    database: database,
    fileStore: IoPrivateAttachmentFileStore(root),
  );

  for (final outside in [false, true]) {
    test(
      'rejects symlink to ${outside ? 'outside' : 'inside'} root and preserves URI',
      () async {
        final target = File('${outside ? sandbox.path : root.path}/target');
        await target.writeAsString('private fixture');
        final link = await Link('${root.path}/link').create(target.path);
        await track('link', link.uri);
        await expectLater(
          purger().purge(),
          throwsA(isA<PrivateFilePurgeException>()),
        );
        expect(await target.exists(), isTrue);
        expect(
          await FileSystemEntity.type(link.path, followLinks: false),
          FileSystemEntityType.link,
        );
        expect(
          await database.select(database.localAttachments).get(),
          hasLength(1),
        );
      },
    );
  }

  test('rejects directory and preserves URI', () async {
    final directory = await Directory('${root.path}/directory').create();
    await track('directory', directory.uri);
    await expectLater(
      purger().purge(),
      throwsA(isA<PrivateFilePurgeException>()),
    );
    expect(await directory.exists(), isTrue);
    expect(
      await database.select(database.localAttachments).get(),
      hasLength(1),
    );
  });

  test(
    'partial deletion failure retains URIs and retries missing file',
    () async {
      final first = await File('${root.path}/first').writeAsString('first');
      final second = await Directory('${root.path}/second').create();
      await track('first', first.uri);
      await track('second', second.uri);
      await expectLater(
        purger().purge(),
        throwsA(isA<PrivateFilePurgeException>()),
      );
      expect(await first.exists(), isFalse);
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(2),
      );
      await second.delete();
      await File(second.path).writeAsString('replacement regular file');
      await purger().purge();
      expect(await File(second.path).exists(), isFalse);
      expect(await database.select(database.localAttachments).get(), isEmpty);
    },
  );

  test('DB failure after file deletion retains URI for retry', () async {
    final file = await File('${root.path}/file').writeAsString('fixture');
    await track('file', file.uri);
    await database.customStatement(
      "CREATE TRIGGER purge_fault BEFORE DELETE ON local_attachments BEGIN SELECT RAISE(ABORT, 'fixture fault'); END",
    );
    await expectLater(purger().purge(), throwsA(isA<SqliteException>()));
    expect(await file.exists(), isFalse);
    expect(
      await database.select(database.localAttachments).get(),
      hasLength(1),
    );
    await database.customStatement('DROP TRIGGER purge_fault');
    await purger().purge();
    expect(await database.select(database.localAttachments).get(), isEmpty);
  });

  test('missing paths resolve existing symlink ancestor', () async {
    final alias = await Link('${sandbox.path}/alias').create(root.path);
    final store = IoPrivateAttachmentFileStore(root);
    final file = await File('${alias.path}/file').writeAsString('fixture');
    await store.deleteIfInsidePrivateRoot(file.uri);
    await store.deleteIfInsidePrivateRoot(file.uri);
    await store.deleteIfInsidePrivateRoot(
      Uri.file('${alias.path}/missing/child'),
    );
    final outside = await Directory('${sandbox.path}/outside').create();
    final escape = await Link('${root.path}/escape').create(outside.path);
    await expectLater(
      store.deleteIfInsidePrivateRoot(Uri.file('${escape.path}/missing')),
      throwsA(isA<FileOutsidePrivateRootException>()),
    );
  });
}
