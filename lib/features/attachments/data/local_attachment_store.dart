import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../domain/attachment_policy.dart';

final class AttachmentCleanupException implements Exception {
  const AttachmentCleanupException(this.cause, this.residualUris);
  final Object cause;
  final List<Uri> residualUris;
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}

final class LocalAttachmentStore implements AttachmentStore {
  LocalAttachmentStore({required this.privateRoot, String Function()? uuid})
    : _uuid = uuid ?? (() => const Uuid().v4());
  final Directory privateRoot;
  final String Function() _uuid;
  final _owned = <String>{};

  Future<String> _root() async {
    if (await FileSystemEntity.type(privateRoot.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const AttachmentException(AttachmentFailure.unsafePath);
    }
    return privateRoot.resolveSymbolicLinks();
  }

  @override
  Future<PrivateAttachment> copy(
    AttachmentInput input,
    AttachmentCancellation cancellation,
  ) async {
    cancellation.check();
    final root = await _root();
    final id = _uuid();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const AttachmentException(AttachmentFailure.unsafePath);
    }
    final file = File(path.join(root, id));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        !_owned.add(file.path)) {
      throw const AttachmentException(AttachmentFailure.unsafePath);
    }
    RandomAccessFile? output;
    StreamIterator<List<int>>? inputStream;
    var created = false;
    try {
      await file.create(exclusive: true);
      created = true;
      output = await file.open(mode: FileMode.writeOnly);
      final result = _DigestSink();
      final hash = sha256.startChunkedConversion(result);
      final header = <int>[];
      var count = 0;
      cancellation.check();
      inputStream = StreamIterator(input.openRead());
      while (await _nextChunk(inputStream, cancellation)) {
        final chunk = inputStream.current;
        cancellation.check();
        count += chunk.length;
        if (count > AttachmentPolicy.maximumBytes)
          throw const AttachmentException(AttachmentFailure.invalidSize);
        if (header.length < 16) header.addAll(chunk.take(16 - header.length));
        hash.add(chunk);
        await output.writeFrom(chunk);
      }
      cancellation.check();
      final mime = AttachmentPolicy.validate(input, header, count);
      hash.close();
      await output.flush();
      await output.close();
      output = null;
      cancellation.check();
      return PrivateAttachment(
        uri: file.uri,
        displayName: input.name,
        contentType: mime,
        bytesTotal: count,
        sha256: result.digest.toString(),
      );
    } on Object catch (error) {
      if (!created) {
        _owned.remove(file.path);
        rethrow;
      }
      try {
        await output?.close();
        await _deletePath(file.uri);
      } on Object {
        throw AttachmentCleanupException(error, [file.uri]);
      }
      rethrow;
    } finally {
      // Request upstream cancellation immediately. A stalled source may itself
      // return a non-terminating cancel future; it must not hold our output
      // handle or private-file cleanup hostage. Consume cancellation errors.
      if (inputStream != null) {
        unawaited(inputStream.cancel().catchError((Object _) {}));
      }
    }
  }

  Future<bool> _nextChunk(
    StreamIterator<List<int>> stream,
    AttachmentCancellation cancellation,
  ) async {
    cancellation.check();
    final result = Completer<bool>();
    final remove = cancellation.onCancel(() {
      if (!result.isCompleted)
        result.completeError(
          const AttachmentException(AttachmentFailure.cancelled),
        );
      unawaited(stream.cancel().catchError((Object _) {}));
    });
    try {
      if (!result.isCompleted) {
        unawaited(
          stream.moveNext().then(
            (value) {
              if (!result.isCompleted) result.complete(value);
            },
            onError: (Object error, StackTrace stack) {
              if (!result.isCompleted) result.completeError(error, stack);
            },
          ),
        );
      }
      return await result.future;
    } finally {
      remove();
    }
  }

  Future<void> _deletePath(Uri uri) async {
    final root = await _root();
    if (uri.scheme != 'file')
      throw const AttachmentException(AttachmentFailure.unsafePath);
    final target = path.normalize(File.fromUri(uri).absolute.path);
    if (!path.isWithin(root, target) || !_owned.contains(target))
      throw const AttachmentException(AttachmentFailure.unsafePath);
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.notFound)
      throw const AttachmentException(AttachmentFailure.unsafePath);
    if (type == FileSystemEntityType.file) {
      final resolved = await File(target).resolveSymbolicLinks();
      if (!path.isWithin(root, resolved))
        throw const AttachmentException(AttachmentFailure.unsafePath);
      await File(target).delete();
    }
    _owned.remove(target);
  }

  @override
  Future<void> delete(PrivateAttachment attachment) =>
      _deletePath(attachment.uri);

  /// Deletes a private copy recovered from the local database after restart.
  /// Only direct-child UUID v4 files are eligible; arbitrary persisted paths
  /// never become deletion authority.
  Future<void> deletePersisted(Uri uri) async {
    final String root = await _root();
    if (uri.scheme != 'file') {
      throw const AttachmentException(AttachmentFailure.unsafePath);
    }
    final String target = path.normalize(File.fromUri(uri).absolute.path);
    final String id = path.basename(target);
    if (path.dirname(target) != root ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
        ).hasMatch(id)) {
      throw const AttachmentException(AttachmentFailure.unsafePath);
    }
    final FileSystemEntityType type = await FileSystemEntity.type(
      target,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw const AttachmentException(AttachmentFailure.unsafePath);
    }
    final String resolved = await File(target).resolveSymbolicLinks();
    if (path.dirname(resolved) != root) {
      throw const AttachmentException(AttachmentFailure.unsafePath);
    }
    await File(target).delete();
    _owned.remove(target);
  }
}
