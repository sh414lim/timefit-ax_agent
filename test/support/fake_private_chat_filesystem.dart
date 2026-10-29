import 'dart:async';
import 'dart:collection';

enum FakePrivateFileOperation {
  delete,
  renameToQuarantine,
  unlinkQuarantined,
  purgeNamespace,
}

enum FakePrivateFileOutcome { succeed, fail, remainPending }

enum FakePrivateFileFailure { scriptedFailure, invalidPath }

final class FakePrivateFileException implements Exception {
  const FakePrivateFileException(this.code);

  final FakePrivateFileFailure code;

  @override
  String toString() => 'FakePrivateFileException(${code.name})';
}

final class FakePrivateNamespaceId {
  const FakePrivateNamespaceId(this.value) : assert(value >= 0);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is FakePrivateNamespaceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FakePrivateNamespaceId($value)';
}

/// Validated relative fake path. Diagnostics never expose its original text.
final class FakePrivateRelativePath {
  const FakePrivateRelativePath._(this._value);

  factory FakePrivateRelativePath.parse(String value) {
    final segments = value.split('/');
    final valid =
        value.isNotEmpty &&
        !value.startsWith('/') &&
        !value.contains(r'\') &&
        !value.contains(':') &&
        segments.every(
          (String segment) =>
              segment.isNotEmpty &&
              segment != '.' &&
              segment != '..' &&
              RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(segment),
        );
    if (!valid) {
      throw const FakePrivateFileException(FakePrivateFileFailure.invalidPath);
    }
    return FakePrivateRelativePath._(value);
  }

  final String _value;

  @override
  bool operator ==(Object other) =>
      other is FakePrivateRelativePath && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'FakePrivateRelativePath(redacted)';
}

final class FakePrivateFileSnapshot {
  const FakePrivateFileSnapshot({
    required this.path,
    required this.quarantined,
  });

  final FakePrivateRelativePath path;
  final bool quarantined;
}

final class FakePendingFileOperation {
  FakePendingFileOperation._({
    required this.id,
    required this.operation,
    required this.namespaceId,
    required this.path,
  });

  final int id;
  final FakePrivateFileOperation operation;
  final FakePrivateNamespaceId namespaceId;
  final FakePrivateRelativePath? path;
  final Completer<FakePrivateFileOutcome> _release =
      Completer<FakePrivateFileOutcome>();

  @override
  String toString() =>
      'FakePendingFileOperation($id, ${operation.name}, $namespaceId)';
}

final class _EntryKey {
  const _EntryKey(this.namespaceId, this.path);

  final FakePrivateNamespaceId namespaceId;
  final FakePrivateRelativePath path;

  @override
  bool operator ==(Object other) =>
      other is _EntryKey &&
      other.namespaceId == namespaceId &&
      other.path == path;

  @override
  int get hashCode => Object.hash(namespaceId, path);
}

final class FakePrivateOpenHandle {
  FakePrivateOpenHandle._(this._filesystem, this._key);

  final FakePrivateChatFilesystem _filesystem;
  final _EntryKey _key;
  var _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    _filesystem._closeHandle(_key);
  }
}

/// Deterministic test-only private-file model. It never touches disk.
final class FakePrivateChatFilesystem {
  final Map<FakePrivateNamespaceId, Map<FakePrivateRelativePath, bool>>
  _entries = <FakePrivateNamespaceId, Map<FakePrivateRelativePath, bool>>{};
  final Map<FakePrivateFileOperation, Queue<FakePrivateFileOutcome>> _scripts =
      <FakePrivateFileOperation, Queue<FakePrivateFileOutcome>>{};
  final List<FakePendingFileOperation> _pending = <FakePendingFileOperation>[];
  final Map<_EntryKey, int> _openCounts = <_EntryKey, int>{};
  final Map<_EntryKey, List<Completer<void>>> _openDrainWaiters =
      <_EntryKey, List<Completer<void>>>{};
  var _nextPendingId = 0;

  List<FakePendingFileOperation> get pendingOperations =>
      List<FakePendingFileOperation>.unmodifiable(_pending);

  void seedFile(
    FakePrivateNamespaceId namespaceId,
    FakePrivateRelativePath path,
  ) {
    _namespace(namespaceId)[path] = false;
  }

  bool exists(
    FakePrivateNamespaceId namespaceId,
    FakePrivateRelativePath path,
  ) => _entries[namespaceId]?[path] == false;

  bool quarantinedExists(
    FakePrivateNamespaceId namespaceId,
    FakePrivateRelativePath path,
  ) => _entries[namespaceId]?[path] == true;

  List<FakePrivateFileSnapshot> listNamespace(
    FakePrivateNamespaceId namespaceId,
  ) => (_entries[namespaceId] ?? const <FakePrivateRelativePath, bool>{})
      .entries
      .map(
        (entry) =>
            FakePrivateFileSnapshot(path: entry.key, quarantined: entry.value),
      )
      .toList(growable: false);

  void scriptNext(
    FakePrivateFileOperation operation,
    FakePrivateFileOutcome outcome,
  ) {
    _scripts
        .putIfAbsent(operation, Queue<FakePrivateFileOutcome>.new)
        .add(outcome);
  }

  FakePrivateOpenHandle open(
    FakePrivateNamespaceId namespaceId,
    FakePrivateRelativePath path,
  ) {
    final key = _EntryKey(namespaceId, path);
    if (!exists(namespaceId, path)) {
      throw const FakePrivateFileException(
        FakePrivateFileFailure.scriptedFailure,
      );
    }
    _openCounts.update(key, (int count) => count + 1, ifAbsent: () => 1);
    return FakePrivateOpenHandle._(this, key);
  }

  Future<void> delete(
    FakePrivateNamespaceId namespaceId,
    FakePrivateRelativePath path,
  ) async {
    await _applyScript(FakePrivateFileOperation.delete, namespaceId, path);
    await _waitForOpenHandles(_EntryKey(namespaceId, path));
    if (_entries[namespaceId]?[path] == false) {
      _entries[namespaceId]!.remove(path);
    }
  }

  Future<void> renameToQuarantine(
    FakePrivateNamespaceId namespaceId,
    FakePrivateRelativePath path,
  ) async {
    await _applyScript(
      FakePrivateFileOperation.renameToQuarantine,
      namespaceId,
      path,
    );
    await _waitForOpenHandles(_EntryKey(namespaceId, path));
    if (_entries[namespaceId]?[path] == false) {
      _entries[namespaceId]![path] = true;
    }
  }

  Future<void> unlinkQuarantined(
    FakePrivateNamespaceId namespaceId,
    FakePrivateRelativePath path,
  ) async {
    await _applyScript(
      FakePrivateFileOperation.unlinkQuarantined,
      namespaceId,
      path,
    );
    await _waitForOpenHandles(_EntryKey(namespaceId, path));
    if (_entries[namespaceId]?[path] == true) {
      _entries[namespaceId]!.remove(path);
    }
  }

  Future<void> purgeNamespace(FakePrivateNamespaceId namespaceId) async {
    await _applyScript(
      FakePrivateFileOperation.purgeNamespace,
      namespaceId,
      null,
    );
    final snapshot = List<FakePrivateFileSnapshot>.of(
      listNamespace(namespaceId),
    );
    for (final entry in snapshot) {
      if (entry.quarantined) {
        await unlinkQuarantined(namespaceId, entry.path);
      } else {
        await delete(namespaceId, entry.path);
      }
    }
  }

  bool releasePending(int id, {required FakePrivateFileOutcome outcome}) {
    if (outcome == FakePrivateFileOutcome.remainPending) return false;
    final operation = _pending.where((entry) => entry.id == id).firstOrNull;
    if (operation == null || operation._release.isCompleted) return false;
    operation._release.complete(outcome);
    return true;
  }

  void verifyNoPending() {
    final hasPending = _pending.any((entry) => !entry._release.isCompleted);
    final hasOpenHandles = _openCounts.values.any((int count) => count > 0);
    if (hasPending || hasOpenHandles) {
      throw StateError('fake_private_filesystem_not_drained');
    }
  }

  Map<FakePrivateRelativePath, bool> _namespace(
    FakePrivateNamespaceId namespaceId,
  ) => _entries.putIfAbsent(
    namespaceId,
    () => <FakePrivateRelativePath, bool>{},
  );

  Future<void> _applyScript(
    FakePrivateFileOperation operation,
    FakePrivateNamespaceId namespaceId,
    FakePrivateRelativePath? path,
  ) async {
    final queue = _scripts[operation];
    final outcome = queue == null || queue.isEmpty
        ? FakePrivateFileOutcome.succeed
        : queue.removeFirst();
    switch (outcome) {
      case FakePrivateFileOutcome.succeed:
        return;
      case FakePrivateFileOutcome.fail:
        throw const FakePrivateFileException(
          FakePrivateFileFailure.scriptedFailure,
        );
      case FakePrivateFileOutcome.remainPending:
        final pending = FakePendingFileOperation._(
          id: ++_nextPendingId,
          operation: operation,
          namespaceId: namespaceId,
          path: path,
        );
        _pending.add(pending);
        final released = await pending._release.future;
        _pending.remove(pending);
        if (released == FakePrivateFileOutcome.fail) {
          throw const FakePrivateFileException(
            FakePrivateFileFailure.scriptedFailure,
          );
        }
    }
  }

  Future<void> _waitForOpenHandles(_EntryKey key) {
    if ((_openCounts[key] ?? 0) == 0) return Future<void>.value();
    final waiter = Completer<void>();
    _openDrainWaiters.putIfAbsent(key, () => <Completer<void>>[]).add(waiter);
    return waiter.future;
  }

  void _closeHandle(_EntryKey key) {
    final count = _openCounts[key] ?? 0;
    if (count <= 1) {
      _openCounts.remove(key);
      for (final waiter
          in _openDrainWaiters.remove(key) ?? const <Completer<void>>[]) {
        if (!waiter.isCompleted) waiter.complete();
      }
    } else {
      _openCounts[key] = count - 1;
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
