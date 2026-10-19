import 'dart:io';

import 'package:path/path.dart' as path;

import 'app_database.dart';

abstract interface class PrivateAttachmentFileStore {
  Future<void> deleteIfInsidePrivateRoot(Uri fileUri);
}

final class PrivateFilePurgeException implements Exception {
  const PrivateFilePurgeException({required this.fileUri, required this.cause});

  final Uri fileUri;
  final Object cause;

  @override
  String toString() => 'Private file purge failed for $fileUri: $cause';
}

final class FileOutsidePrivateRootException implements Exception {
  const FileOutsidePrivateRootException(this.fileUri);

  final Uri fileUri;

  @override
  String toString() => 'Refusing to delete outside the private root: $fileUri';
}

final class IoPrivateAttachmentFileStore implements PrivateAttachmentFileStore {
  const IoPrivateAttachmentFileStore(this.privateRoot);

  final Directory privateRoot;

  @override
  Future<void> deleteIfInsidePrivateRoot(Uri fileUri) async {
    if (fileUri.scheme != 'file') {
      throw FileOutsidePrivateRootException(fileUri);
    }

    final rootPath = await privateRoot.resolveSymbolicLinks();
    final file = File.fromUri(fileUri);
    final filePath = await file.exists()
        ? await file.resolveSymbolicLinks()
        : path.normalize(file.absolute.path);
    if (!path.equals(rootPath, filePath) &&
        !path.isWithin(rootPath, filePath)) {
      throw FileOutsidePrivateRootException(fileUri);
    }
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Logout ordering is deliberately file-first and database-last.
/// The caller must first stop workers, subscriptions, and other chat DB writers,
/// and keep the database inaccessible to the next session until purge succeeds.
///
/// If any file cannot be deleted, database rows remain intact so their URIs
/// continue to track residual personal files. Retrying is safe because a
/// missing in-root file is treated as already deleted. Only after every file
/// succeeds are the four chat tables purged in one database transaction.
final class LogoutChatDataPurger {
  const LogoutChatDataPurger({
    required AppDatabase database,
    required PrivateAttachmentFileStore fileStore,
  }) : _database = database,
       _fileStore = fileStore;

  final AppDatabase _database;
  final PrivateAttachmentFileStore _fileStore;

  Future<void> purge() async {
    final fileUris = await _database.attachmentDao.privateFileUris();
    for (final value in fileUris) {
      final fileUri = Uri.tryParse(value);
      if (fileUri == null) {
        throw PrivateFilePurgeException(
          fileUri: Uri(),
          cause: FormatException('Invalid private file URI: $value'),
        );
      }
      try {
        await _fileStore.deleteIfInsidePrivateRoot(fileUri);
      } on Object catch (error) {
        throw PrivateFilePurgeException(fileUri: fileUri, cause: error);
      }
    }
    await _database.purgeChatData();
  }
}
