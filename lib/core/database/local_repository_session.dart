import 'dart:async';

import 'app_database.dart';

enum LocalRepositoryFailure { readFailed, sessionClosed }

final class LocalRepositoryException implements Exception {
  const LocalRepositoryException(this.kind);
  final LocalRepositoryFailure kind;
}

/// One instance per authenticated DB namespace. Dispose before switching users;
/// this scope never owns or closes the shared database connection.
final class LocalRepositorySession {
  static final _databaseScopes = Expando<LocalRepositorySession>();

  /// Default shared scope for all local handles on one DB namespace. A closed
  /// scope is never silently replaced; a new user must get a fresh namespace
  /// or an explicitly injected session after the old scope drained and purged.
  static LocalRepositorySession forDatabase(AppDatabase database) =>
      _databaseScopes[database] ??= LocalRepositorySession();

  bool _closed = false;
  final _stops = <Future<void> Function()>{};
  final _writes = <Future<void>>{};

  void _checkOpen() {
    if (_closed)
      throw const LocalRepositoryException(
        LocalRepositoryFailure.sessionClosed,
      );
  }

  Future<T> write<T>(
    AppDatabase database,
    Future<T> Function() operation,
  ) async {
    _checkOpen();
    final drained = Completer<void>();
    _writes.add(drained.future);
    try {
      return await database.transaction(() async {
        _checkOpen();
        final result = await operation();
        // This check is inside the transaction: disposal during any awaited
        // insert/update causes rollback rather than a post-commit exception.
        _checkOpen();
        return result;
      });
    } finally {
      drained.complete();
      _writes.remove(drained.future);
    }
  }

  Future<T> read<T>(Future<T> Function() query) async {
    if (_closed)
      throw const LocalRepositoryException(
        LocalRepositoryFailure.sessionClosed,
      );
    try {
      final result = await query();
      if (_closed)
        throw const LocalRepositoryException(
          LocalRepositoryFailure.sessionClosed,
        );
      return result;
    } on LocalRepositoryException {
      rethrow;
    } on Object {
      throw LocalRepositoryException(
        _closed
            ? LocalRepositoryFailure.sessionClosed
            : LocalRepositoryFailure.readFailed,
      );
    }
  }

  Stream<T> watch<T>(Stream<T> Function() query) {
    if (_closed)
      return Stream.error(
        const LocalRepositoryException(LocalRepositoryFailure.sessionClosed),
      );
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Future<void> stop() async {
      await subscription?.cancel();
      if (!controller.isClosed) unawaited(controller.close());
      _stops.remove(stop);
    }

    controller = StreamController<T>(
      onListen: () {
        if (_closed) {
          unawaited(stop());
          return;
        }
        _stops.add(stop);
        try {
          subscription = query().listen(
            (value) {
              if (!_closed) controller.add(value);
            },
            onError: (Object error, StackTrace stack) {
              if (!_closed)
                controller.addError(
                  const LocalRepositoryException(
                    LocalRepositoryFailure.readFailed,
                  ),
                );
            },
            onDone: () {
              unawaited(stop());
            },
          );
        } on Object {
          controller.addError(
            const LocalRepositoryException(LocalRepositoryFailure.readFailed),
          );
          unawaited(stop());
        }
      },
      onCancel: stop,
    );
    // A paused listener can retain events already queued by the controller.
    // Transform at delivery time as well as checking when enqueueing: after
    // disposal neither buffered values nor buffered errors cross the session.
    return controller.stream.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleData: (value, sink) {
          if (!_closed) sink.add(value);
        },
        handleError: (Object error, StackTrace stack, EventSink<T> sink) {
          if (!_closed) sink.addError(error, stack);
        },
      ),
    );
  }

  Future<void> dispose() async {
    _closed = true;
    await Future.wait([
      ..._stops.toList().map((stop) => stop()),
      ..._writes.toList(),
    ]);
    // Callers may purge only after this future completes. Writes already
    // committing have drained; writes interrupted in the callback rolled back.
  }
}
