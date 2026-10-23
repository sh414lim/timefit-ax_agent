import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../../core/database/app_database.dart';
import '../../../core/database/local_repository_session.dart';
import 'attachment_download_controller.dart';

enum DevLocalPreviewError { missing, readFailed, unsupportedType }

final class DevLocalPreviewFileException implements Exception {
  const DevLocalPreviewFileException(this.error);
  final DevLocalPreviewError error;
}

sealed class DevLocalPreviewState {
  const DevLocalPreviewState();
}

final class DevLocalPreviewLoading extends DevLocalPreviewState {
  const DevLocalPreviewLoading();
}

final class DevLocalPreviewReady extends DevLocalPreviewState {
  const DevLocalPreviewReady({
    required this.file,
    required this.displayName,
    required this.kind,
  });

  final File file;
  final String displayName;
  final AttachmentPreviewKind kind;
}

final class DevLocalPreviewFailed extends DevLocalPreviewState {
  const DevLocalPreviewFailed(this.error);
  final DevLocalPreviewError error;
}

abstract interface class DevLocalPreviewFileReader {
  Future<File> verify({
    required Directory privateRoot,
    required Uri uri,
    required String contentType,
    required String sha256Digest,
  });
}

final class PrivateCopyPreviewFileReader implements DevLocalPreviewFileReader {
  const PrivateCopyPreviewFileReader();

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<File> verify({
    required Directory privateRoot,
    required Uri uri,
    required String contentType,
    required String sha256Digest,
  }) async {
    if (uri.scheme != 'file') {
      throw const DevLocalPreviewFileException(DevLocalPreviewError.readFailed);
    }
    final String root = await privateRoot.resolveSymbolicLinks();
    final File file = File.fromUri(uri);
    final String target = path.normalize(file.absolute.path);
    if (path.dirname(target) != root ||
        !_uuid.hasMatch(path.basename(target))) {
      throw const DevLocalPreviewFileException(DevLocalPreviewError.readFailed);
    }
    if (await FileSystemEntity.type(target, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const DevLocalPreviewFileException(DevLocalPreviewError.missing);
    }
    final String resolved = await file.resolveSymbolicLinks();
    if (path.dirname(resolved) != root) {
      throw const DevLocalPreviewFileException(DevLocalPreviewError.readFailed);
    }

    final int length = await file.length();
    final List<int> header = await file
        .openRead(0, length < 16 ? length : 16)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    if (_mimeFor(header) != contentType) {
      throw const DevLocalPreviewFileException(DevLocalPreviewError.readFailed);
    }
    final Digest digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != sha256Digest) {
      throw const DevLocalPreviewFileException(DevLocalPreviewError.readFailed);
    }
    return file;
  }
}

String? _mimeFor(List<int> header) {
  bool prefix(List<int> signature, [int offset = 0]) =>
      header.length >= signature.length + offset &&
      List<bool>.generate(
        signature.length,
        (index) => header[index + offset] == signature[index],
      ).every((matches) => matches);
  if (prefix(<int>[0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (prefix(<int>[137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (prefix(<int>[82, 73, 70, 70]) && prefix(<int>[87, 69, 66, 80], 8)) {
    return 'image/webp';
  }
  if (prefix(<int>[37, 80, 68, 70, 45])) return 'application/pdf';
  return null;
}

final class DevLocalAttachmentPreviewController extends ChangeNotifier {
  DevLocalAttachmentPreviewController({
    required AppDatabase database,
    required LocalRepositorySession session,
    required Directory privateRoot,
    required this.conversationId,
    required this.localId,
    DevLocalPreviewFileReader reader = const PrivateCopyPreviewFileReader(),
  }) : _database = database,
       _session = session,
       _privateRoot = privateRoot,
       _reader = reader;

  final AppDatabase _database;
  final LocalRepositorySession _session;
  final Directory _privateRoot;
  final DevLocalPreviewFileReader _reader;
  final String conversationId;
  final String localId;

  DevLocalPreviewState _state = const DevLocalPreviewLoading();
  int _generation = 0;
  bool _disposed = false;

  DevLocalPreviewState get state => _state;

  Future<void> load() async {
    final int generation = ++_generation;
    _setState(const DevLocalPreviewLoading());
    try {
      final LocalAttachment? row = await _session.read(
        () =>
            (_database.select(_database.localAttachments)..where(
                  (candidate) =>
                      candidate.localId.equals(localId) &
                      candidate.conversationId.equals(conversationId) &
                      candidate.composerExcluded.equals(false),
                ))
                .getSingleOrNull(),
      );
      if (!_current(generation)) return;
      if (row == null || row.localFileUri == null) {
        _setState(const DevLocalPreviewFailed(DevLocalPreviewError.missing));
        return;
      }
      final AttachmentPreviewKind? kind = switch (row.contentType) {
        'image/jpeg' ||
        'image/png' ||
        'image/webp' => AttachmentPreviewKind.image,
        'application/pdf' => AttachmentPreviewKind.pdf,
        _ => null,
      };
      if (kind == null) {
        _setState(
          const DevLocalPreviewFailed(DevLocalPreviewError.unsupportedType),
        );
        return;
      }
      final File file = await _reader.verify(
        privateRoot: _privateRoot,
        uri: Uri.parse(row.localFileUri!),
        contentType: row.contentType,
        sha256Digest: row.sha256,
      );
      if (!_current(generation)) return;
      _setState(
        DevLocalPreviewReady(
          file: file,
          displayName: row.displayName ?? '첨부 파일',
          kind: kind,
        ),
      );
    } on DevLocalPreviewFileException catch (error) {
      if (_current(generation)) {
        _setState(DevLocalPreviewFailed(error.error));
      }
    } on LocalRepositoryException {
      if (_current(generation)) {
        _setState(const DevLocalPreviewFailed(DevLocalPreviewError.readFailed));
      }
    } on Object {
      if (_current(generation)) {
        _setState(const DevLocalPreviewFailed(DevLocalPreviewError.readFailed));
      }
    }
  }

  void reportRenderFailure() {
    if (_disposed) return;
    _generation += 1;
    _setState(const DevLocalPreviewFailed(DevLocalPreviewError.readFailed));
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _setState(DevLocalPreviewState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    super.dispose();
  }
}
