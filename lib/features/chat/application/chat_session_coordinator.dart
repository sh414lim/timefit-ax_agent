import '../../../core/database/local_repository_session.dart';

enum LocalChatSessionState {
  idle,
  active,
  loggingOut,
  cleanupPending,
  disposed,
}

enum LocalChatSessionCleanupStage {
  drainLocalWrites,
  stopLifecycleAndOutbox,
  purgeLocalData,
}

enum LocalChatSessionFailure {
  sessionAlreadyActive,
  cleanupPending,
  coordinatorDisposed,
  noActiveSession,
  noCleanupPending,
}

final class LocalChatSessionException implements Exception {
  const LocalChatSessionException(this.kind);

  final LocalChatSessionFailure kind;
}

/// One local repository scope and the injected cleanup operations for its
/// account namespace. The namespace is opaque to this local core; no server or
/// authentication contract is inferred from it.
final class LocalChatSession {
  const LocalChatSession._({
    required this.namespace,
    required this.repository,
    required Future<void> Function() stopLifecycleAndOutbox,
    required Future<void> Function() purgeLocalData,
  }) : _stopLifecycleAndOutbox = stopLifecycleAndOutbox,
       _purgeLocalData = purgeLocalData;

  final String namespace;
  final LocalRepositorySession repository;
  final Future<void> Function() _stopLifecycleAndOutbox;
  final Future<void> Function() _purgeLocalData;
}

/// Fail-closed local session boundary for CHAT-047.
///
/// This coordinator intentionally does not choose Auth, Realtime, device
/// revoke, routing, or timeout contracts. Composition injects one lifecycle /
/// Outbox cleanup operation and one local purge operation. A failed stage is
/// retained for an explicit retry; until it succeeds no new local repository
/// session can be admitted.
final class LocalChatSessionCoordinator {
  LocalChatSessionState _state = LocalChatSessionState.idle;
  LocalChatSessionCleanupStage? _cleanupStage;
  LocalChatSessionCleanupStage? _lastFailedStage;
  LocalChatSession? _activeSession;
  Future<void>? _cleanupRun;
  bool _disposeRequested = false;

  LocalChatSessionState get state => _state;
  LocalChatSessionCleanupStage? get lastFailedStage => _lastFailedStage;
  bool get cleanupPending => _state == LocalChatSessionState.cleanupPending;
  String? get activeNamespace => _activeSession?.namespace;

  LocalChatSession openSession({
    required String namespace,
    required Future<void> Function() stopLifecycleAndOutbox,
    required Future<void> Function() purgeLocalData,
  }) {
    switch (_state) {
      case LocalChatSessionState.idle:
        break;
      case LocalChatSessionState.cleanupPending:
        throw const LocalChatSessionException(
          LocalChatSessionFailure.cleanupPending,
        );
      case LocalChatSessionState.disposed:
        throw const LocalChatSessionException(
          LocalChatSessionFailure.coordinatorDisposed,
        );
      case LocalChatSessionState.active:
      case LocalChatSessionState.loggingOut:
        throw const LocalChatSessionException(
          LocalChatSessionFailure.sessionAlreadyActive,
        );
    }

    final session = LocalChatSession._(
      namespace: namespace,
      repository: LocalRepositorySession(),
      stopLifecycleAndOutbox: stopLifecycleAndOutbox,
      purgeLocalData: purgeLocalData,
    );
    _activeSession = session;
    _state = LocalChatSessionState.active;
    return session;
  }

  Future<void> logout() {
    final running = _cleanupRun;
    if (running != null) return running;
    switch (_state) {
      case LocalChatSessionState.idle:
      case LocalChatSessionState.disposed:
        return Future<void>.value();
      case LocalChatSessionState.cleanupPending:
        return Future<void>.error(
          const LocalChatSessionException(
            LocalChatSessionFailure.cleanupPending,
          ),
        );
      case LocalChatSessionState.active:
        _cleanupStage = LocalChatSessionCleanupStage.drainLocalWrites;
        break;
      case LocalChatSessionState.loggingOut:
        break;
    }
    return _startCleanup();
  }

  Future<void> retryCleanup() {
    final running = _cleanupRun;
    if (running != null) return running;
    if (_state != LocalChatSessionState.cleanupPending) {
      return Future<void>.error(
        const LocalChatSessionException(
          LocalChatSessionFailure.noCleanupPending,
        ),
      );
    }
    return _startCleanup();
  }

  Future<void> dispose() {
    _disposeRequested = true;
    final running = _cleanupRun;
    if (running != null) return running;
    if (_state == LocalChatSessionState.idle) {
      _state = LocalChatSessionState.disposed;
      return Future<void>.value();
    }
    if (_state == LocalChatSessionState.disposed) return Future<void>.value();
    if (_state == LocalChatSessionState.cleanupPending) {
      return Future<void>.error(
        const LocalChatSessionException(LocalChatSessionFailure.cleanupPending),
      );
    }
    return logout();
  }

  Future<void> _startCleanup() {
    final active = _activeSession;
    if (active == null) {
      return Future<void>.error(
        const LocalChatSessionException(
          LocalChatSessionFailure.noActiveSession,
        ),
      );
    }
    _state = LocalChatSessionState.loggingOut;
    late final Future<void> run;
    run = _runCleanup(active).whenComplete(() {
      if (identical(_cleanupRun, run)) _cleanupRun = null;
    });
    _cleanupRun = run;
    return run;
  }

  Future<void> _runCleanup(LocalChatSession active) async {
    try {
      while (true) {
        switch (_cleanupStage) {
          case LocalChatSessionCleanupStage.drainLocalWrites:
            await active.repository.dispose();
            _cleanupStage = LocalChatSessionCleanupStage.stopLifecycleAndOutbox;
            continue;
          case LocalChatSessionCleanupStage.stopLifecycleAndOutbox:
            await active._stopLifecycleAndOutbox();
            _cleanupStage = LocalChatSessionCleanupStage.purgeLocalData;
            continue;
          case LocalChatSessionCleanupStage.purgeLocalData:
            await active._purgeLocalData();
            _cleanupStage = null;
            _lastFailedStage = null;
            _activeSession = null;
            _state = _disposeRequested
                ? LocalChatSessionState.disposed
                : LocalChatSessionState.idle;
            return;
          case null:
            throw const LocalChatSessionException(
              LocalChatSessionFailure.noCleanupPending,
            );
        }
      }
    } on Object {
      _lastFailedStage = _cleanupStage;
      _state = LocalChatSessionState.cleanupPending;
      rethrow;
    }
  }
}
