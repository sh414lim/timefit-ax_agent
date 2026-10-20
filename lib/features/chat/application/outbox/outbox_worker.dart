import 'package:uuid/uuid.dart';

import '../../../../core/database/daos/outbox_dao.dart';
import 'command_executor.dart';
import 'retry_policy.dart';

/// One active drain per database scope within this process. Separate processes
/// additionally coordinate through the persisted, atomically acquired lease.
final class OutboxWorker {
  OutboxWorker({
    required this.dao,
    required this.executor,
    required this.clock,
    required this.retryPolicy,
    required this.scope,
    String Function()? leaseToken,
  }) : _leaseToken = leaseToken ?? (() => const Uuid().v4());

  final OutboxDao dao;
  final CommandExecutor executor;
  final DateTime Function() clock;
  final RetryPolicy retryPolicy;

  /// Composition must share this value for every worker on the same DB file.
  final String scope;
  final String Function() _leaseToken;
  static final Set<String> _activeScopes = {};
  bool _stopped = false;
  bool _authPaused = false;

  void stop() => _stopped = true;
  void resumeAfterAuthentication() => _authPaused = false;

  /// Connectivity and lifecycle may call this only as a wake signal. Scheduling
  /// the next wake belongs to the lifecycle integration; no background timer is
  /// installed by this local core.
  Future<void> wake() async {
    if (_stopped || _authPaused || !_activeScopes.add(scope)) return;
    try {
      while (!_stopped && !_authPaused) {
        final lease = await dao.claim(clock(), _leaseToken());
        if (lease == null || _stopped) return;
        CommandExecutionResult result;
        try {
          result = await executor.execute(
            OutboxExecutionCommand(
              id: lease.id,
              clientRequestId: lease.clientRequestId,
              commandType: lease.commandType,
              aggregateId: lease.aggregateId,
              payloadJson: lease.payloadJson,
              leaseToken: lease.leaseOwner,
            ),
          );
        } on Object {
          result = const CommandExecutionResult(
            ExecutionDisposition.retryable,
            errorCode: 'executor_exception',
          );
        }
        if (_stopped) return; // Preserve the lease for recovery after expiry.
        final now = clock();
        var failures = lease.attemptCount;
        var state = 'completed';
        DateTime? next;
        switch (result.disposition) {
          case ExecutionDisposition.completed:
            break;
          case ExecutionDisposition.authRequired:
            _authPaused = true;
            state = 'retry_wait';
            next = now;
          case ExecutionDisposition.permanent:
            failures += 1;
            state = 'failed_permanent';
          case ExecutionDisposition.retryable:
            failures += 1;
            state = failures >= RetryPolicy.maximumFailures
                ? 'failed_permanent'
                : 'retry_wait';
            if (state == 'retry_wait')
              next = now.add(retryPolicy.delay(failures));
          case ExecutionDisposition.deferred:
            state = 'retry_wait';
            next = now.add(retryPolicy.delay(1));
        }
        final applied = await dao.finish(
          lease,
          now,
          state: state,
          failures: failures,
          nextAttemptAt: next,
          errorCode: result.errorCode,
        );
        if (!applied)
          return; // Expired/cancelled/reclaimed: ignore stale result.
      }
    } on OutboxContention {
      // Another connection still owns SQLite's write lock. Keep persisted
      // commands/leases unchanged and retry on the next lifecycle/timer wake.
      return;
    } finally {
      _activeScopes.remove(scope);
    }
  }
}
