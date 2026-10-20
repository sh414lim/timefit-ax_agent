import 'dart:async';

enum LocalRepositoryFailure { readFailed, sessionClosed }

final class LocalRepositoryException implements Exception {
  const LocalRepositoryException(this.kind);
  final LocalRepositoryFailure kind;
}

/// One instance per authenticated DB namespace. Dispose before switching users;
/// this scope never owns or closes the shared database connection.
final class LocalRepositorySession {
  bool _closed = false;
  final _stops = <Future<void> Function()>{};

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
    return controller.stream;
  }

  Future<void> dispose() async {
    _closed = true;
    await Future.wait(_stops.toList().map((stop) => stop()));
  }
}
