import 'dart:async';

import 'package:timefit_native/features/chat/application/chat_session_coordinator.dart';

import 'in_memory_chat_cleanup_ledger.dart';

// Test-support candidate for CHAT-047's 2026-10-29 decision. This file must
// never be imported by lib/, app entrypoints, or a production adapter.
enum CandidateRemoteOperation { realtime, deviceRevoke, remoteAuth }

enum CandidateRemoteObservation { acknowledged, uncertain, failed, unsupported }

enum CandidateRemoteState {
  notAttempted,
  inProgress,
  confirmed,
  uncertain,
  failed,
  unsupported,
}

enum CandidateLocalFailure {
  generationFence,
  mutationDrain,
  localStop,
  purgeOrVerification,
}

abstract interface class CandidateRemoteReleasePort {
  /// Only an explicit scripted acknowledgement may become confirmed. A local
  /// coordinator idle state or SDK unsubscribe completion is not such an ACK.
  Future<CandidateRemoteObservation> release(
    CandidateRemoteOperation operation,
  );
}

/// A manually injected observation boundary, with no clock or numeric timeout.
/// Reaching it abandons waiting; it does not cancel an underlying operation.
final class CandidateRemoteBoundary {
  final _reached = Completer<void>();

  Future<void> get reached => _reached.future;

  void observeBoundaryReached() {
    if (!_reached.isCompleted) _reached.complete();
  }
}

final class CandidateLocalProtection {
  const CandidateLocalProtection({
    required this.admissionClosed,
    required this.oldGenerationFenced,
    required this.mutationsResolved,
    required this.localWorkStopped,
    required this.privateDataPurged,
    required this.purgeVerified,
    required this.recoveryRequired,
    required this.failure,
  });

  final bool admissionClosed;
  final bool oldGenerationFenced;
  final bool mutationsResolved;
  final bool localWorkStopped;
  final bool privateDataPurged;
  final bool purgeVerified;
  final bool recoveryRequired;
  final CandidateLocalFailure? failure;

  bool get complete =>
      admissionClosed &&
      oldGenerationFenced &&
      mutationsResolved &&
      localWorkStopped &&
      privateDataPurged &&
      purgeVerified &&
      !recoveryRequired;

  Map<String, Object?> toDiagnosticMap() => {
    'admissionClosed': admissionClosed,
    'oldGenerationFenced': oldGenerationFenced,
    'mutationsResolved': mutationsResolved,
    'localWorkStopped': localWorkStopped,
    'privateDataPurged': privateDataPurged,
    'purgeVerified': purgeVerified,
    'recoveryRequired': recoveryRequired,
    'failure': failure?.name,
  };
}

final class CandidateLogoutSnapshot {
  CandidateLogoutSnapshot({
    required this.attempt,
    required this.namespace,
    required this.local,
    required Map<CandidateRemoteOperation, CandidateRemoteState> remote,
    required this.disposed,
  }) : remote = Map.unmodifiable(remote);

  final int attempt;
  final TestCleanupNamespaceId namespace;
  final CandidateLocalProtection local;
  final Map<CandidateRemoteOperation, CandidateRemoteState> remote;
  final bool disposed;

  // This intentionally says nothing about Auth credentials or actual routes.
  bool get localProtectionComplete => local.complete;

  Map<String, Object?> toDiagnosticMap() => {
    'attempt': attempt,
    'namespace': namespace.value,
    'local': local.toDiagnosticMap(),
    'remote': remote.map((key, value) => MapEntry(key.name, value.name)),
    'disposed': disposed,
  };
}

final class _Attempt {
  _Attempt(this.id, Map<CandidateRemoteOperation, CandidateRemoteState> remote)
    : remote = Map.of(remote);

  final int id;
  final Map<CandidateRemoteOperation, CandidateRemoteState> remote;
  final done = Completer<CandidateLogoutSnapshot>();
  bool admissionClosed = false;
  bool generationFenced = false;
  bool mutationsResolved = false;
  bool localWorkStopped = false;
  bool privateDataPurged = false;
  bool purgeVerified = false;
  bool recoveryRequired = false;
  bool localSettled = false;
  bool remoteObserved = false;
  CandidateLocalFailure stage = CandidateLocalFailure.mutationDrain;
  CandidateLocalFailure? failure;
}

/// Fake-only composition. The existing coordinator remains the authority for
/// repository closure, writer drain, strict local stop/purge, and local retry.
/// Remote observation never enters that coordinator's serial cleanup queue.
///
/// Results are process-memory only. There is no Auth, persistent marker,
/// startup recovery, timeout policy, or product/router wiring here.
final class HybridLogoutCandidate {
  HybridLogoutCandidate({
    required this.namespace,
    required CandidateRemoteReleasePort remote,
    required CandidateRemoteBoundary remoteBoundary,
    required void Function() fenceOldGeneration,
    required Future<void> Function() stopLocalWork,
    required Future<void> Function() purgePrivateData,
    required Future<bool> Function() verifyLocalPurge,
  }) : _remote = remote,
       _remoteBoundary = remoteBoundary,
       _fenceOldGeneration = fenceOldGeneration {
    session = coordinator.openSession(
      namespace: 'candidate-${namespace.value}',
      stopLifecycleAndOutbox: () async {
        final attempt = _current!;
        attempt.mutationsResolved = true;
        _publish(attempt);
        if (!attempt.generationFenced) throw const _CandidateStageFailure();
        attempt.stage = CandidateLocalFailure.localStop;
        await stopLocalWork();
        attempt.localWorkStopped = true;
        attempt.failure = null;
        _publish(attempt);
      },
      purgeLocalData: () async {
        final attempt = _current!;
        attempt.stage = CandidateLocalFailure.purgeOrVerification;
        await purgePrivateData();
        attempt.privateDataPurged = true;
        _publish(attempt);
        if (!await verifyLocalPurge()) throw const _CandidateStageFailure();
        attempt.purgeVerified = true;
        attempt.failure = null;
        _publish(attempt);
      },
    );
  }

  final TestCleanupNamespaceId namespace;
  final CandidateRemoteReleasePort _remote;
  final CandidateRemoteBoundary _remoteBoundary;
  final void Function() _fenceOldGeneration;
  final coordinator = LocalChatSessionCoordinator();
  late final LocalChatSession session;
  final _callbackToken = Object();
  final _ledger = <int, CandidateLogoutSnapshot>{};
  _Attempt? _current;
  int _nextAttempt = 0;
  bool _fenced = false;
  bool _disposed = false;

  CandidateLogoutSnapshot? get snapshot =>
      _current == null ? null : _ledger[_current!.id];

  List<CandidateLogoutSnapshot> get ledger => List.unmodifiable(_ledger.values);

  Object? captureCallback() =>
      !_fenced &&
          !_disposed &&
          coordinator.state == LocalChatSessionState.active
      ? _callbackToken
      : null;

  bool acceptsCallback(Object? token) =>
      token != null && identical(token, captureCallback());

  Future<CandidateLogoutSnapshot> logout() {
    final existing = _current;
    if (existing != null) return existing.done.future;
    return _begin(retry: false);
  }

  Future<CandidateLogoutSnapshot> retryLocalCleanup() {
    final attempt = _current;
    if (attempt != null && !attempt.localSettled) return attempt.done.future;
    if (coordinator.state != LocalChatSessionState.cleanupPending) {
      throw StateError('candidate_no_local_cleanup_pending');
    }
    // Retire observation of the old attempt before installing its retry. Its
    // callers must settle even if its remote operation never returns.
    if (attempt != null) _boundRemote(attempt);
    return _begin(retry: true);
  }

  Future<CandidateLogoutSnapshot> dispose() {
    final run = logout();
    _disposed = true;
    _boundRemote(_current!);
    // Request disposal of the same local cleanup. The handled local run below
    // retains any failure; disposal must not rethrow raw cleanup exceptions.
    unawaited(
      coordinator.dispose().then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
    _publish(_current!);
    return run;
  }

  Future<CandidateLogoutSnapshot> _begin({required bool retry}) {
    final previous = _current;
    final attempt = _Attempt(++_nextAttempt, {
      for (final operation in CandidateRemoteOperation.values)
        operation: retry
            ? (previous!.remote[operation] == CandidateRemoteState.inProgress
                  ? CandidateRemoteState.uncertain
                  : previous.remote[operation]!)
            : CandidateRemoteState.notAttempted,
    });
    _current = attempt;
    _fenced = true; // Synchronous, independent of widget frames or remote I/O.
    attempt.generationFenced = previous?.generationFenced ?? false;
    attempt.mutationsResolved = previous?.mutationsResolved ?? false;
    attempt.localWorkStopped = previous?.localWorkStopped ?? false;
    if (!attempt.generationFenced) {
      try {
        _fenceOldGeneration();
        attempt.generationFenced = true;
      } on Object {
        attempt.failure = CandidateLocalFailure.generationFence;
      }
    }
    final local = retry ? coordinator.retryCleanup() : coordinator.logout();
    attempt.admissionClosed = true;
    _publish(attempt);
    unawaited(
      local.then<void>(
        (_) {
          attempt.localSettled = true;
          _publish(attempt);
        },
        onError: (Object _, StackTrace __) {
          attempt.recoveryRequired = true;
          attempt.failure ??= attempt.stage;
          attempt.localSettled = true;
          _publish(attempt);
        },
      ),
    );

    if (retry) {
      // No remote retry capability is assumed. Retry only local stages and
      // preserve previous remote evidence; old in-flight replies are fenced.
      attempt.remoteObserved = true;
      _publish(attempt);
    } else {
      _startRemote(attempt);
    }
    return attempt.done.future;
  }

  void _startRemote(_Attempt attempt) {
    if (_disposed) {
      attempt.remoteObserved = true;
      _publish(attempt);
      return;
    }
    for (final operation in CandidateRemoteOperation.values) {
      attempt.remote[operation] = CandidateRemoteState.inProgress;
    }
    _publish(attempt);
    for (final operation in CandidateRemoteOperation.values) {
      if (_disposed) {
        attempt.remote[operation] = CandidateRemoteState.notAttempted;
        continue;
      }
      unawaited(
        Future<CandidateRemoteObservation>.sync(
          () => _remote.release(operation),
        ).then<void>(
          (observation) {
            if (!_acceptsRemote(attempt)) return;
            attempt.remote[operation] = switch (observation) {
              CandidateRemoteObservation.acknowledged =>
                CandidateRemoteState.confirmed,
              CandidateRemoteObservation.uncertain =>
                CandidateRemoteState.uncertain,
              CandidateRemoteObservation.failed => CandidateRemoteState.failed,
              CandidateRemoteObservation.unsupported =>
                CandidateRemoteState.unsupported,
            };
            _updateRemoteObserved(attempt);
          },
          onError: (Object _, StackTrace __) {
            if (!_acceptsRemote(attempt)) return;
            attempt.remote[operation] = CandidateRemoteState.failed;
            _updateRemoteObserved(attempt);
          },
        ),
      );
    }
    _publish(attempt);
    unawaited(
      _remoteBoundary.reached.then((_) {
        if (identical(_current, attempt)) _boundRemote(attempt);
      }),
    );
  }

  bool _acceptsRemote(_Attempt attempt) =>
      !_disposed && identical(_current, attempt);

  void _updateRemoteObserved(_Attempt attempt) {
    attempt.remoteObserved = !attempt.remote.values.contains(
      CandidateRemoteState.inProgress,
    );
    _publish(attempt);
  }

  void _boundRemote(_Attempt attempt) {
    for (final operation in CandidateRemoteOperation.values) {
      if (attempt.remote[operation] == CandidateRemoteState.inProgress) {
        attempt.remote[operation] = CandidateRemoteState.uncertain;
      }
    }
    attempt.remoteObserved = true;
    _publish(attempt);
  }

  void _publish(_Attempt attempt) {
    final value = CandidateLogoutSnapshot(
      attempt: attempt.id,
      namespace: namespace,
      local: CandidateLocalProtection(
        admissionClosed: attempt.admissionClosed,
        oldGenerationFenced: attempt.generationFenced,
        mutationsResolved: attempt.mutationsResolved,
        localWorkStopped: attempt.localWorkStopped,
        privateDataPurged: attempt.privateDataPurged,
        purgeVerified: attempt.purgeVerified && attempt.localSettled,
        recoveryRequired: attempt.recoveryRequired,
        failure: attempt.failure,
      ),
      remote: attempt.remote,
      disposed: _disposed,
    );
    _ledger[attempt.id] = value;
    if (attempt.localSettled &&
        attempt.remoteObserved &&
        !attempt.done.isCompleted) {
      attempt.done.complete(value);
    }
  }
}

final class _CandidateStageFailure implements Exception {
  const _CandidateStageFailure();
}
