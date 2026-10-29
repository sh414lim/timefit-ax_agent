enum TestCleanupStage {
  drainLocalWrites,
  stopLifecycleAndOutbox,
  purgeLocalData,
}

enum TestCleanupAttemptStatus { pending, failed, blocked, completed }

enum TestCleanupFailureCode { stageFailure, timeoutObserved, corruptSeed }

enum TestCleanupLedgerResult {
  applied,
  staleAttempt,
  invalidTransition,
  simulatedFailure,
}

/// Opaque test-only namespace identity. It never contains an account ID.
final class TestCleanupNamespaceId {
  const TestCleanupNamespaceId(this.value) : assert(value >= 0);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is TestCleanupNamespaceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TestCleanupNamespaceId($value)';
}

/// Opaque test-only cleanup attempt identity.
final class TestCleanupAttemptId {
  const TestCleanupAttemptId(this.value) : assert(value >= 0);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is TestCleanupAttemptId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TestCleanupAttemptId($value)';
}

final class TestCleanupAttemptSnapshot {
  const TestCleanupAttemptSnapshot({
    required this.attemptId,
    required this.namespaceId,
    required this.stage,
    required this.status,
    required this.failureCode,
  });

  final TestCleanupAttemptId attemptId;
  final TestCleanupNamespaceId namespaceId;
  final TestCleanupStage stage;
  final TestCleanupAttemptStatus status;
  final TestCleanupFailureCode? failureCode;

  @override
  String toString() =>
      'TestCleanupAttemptSnapshot('
      '$attemptId, $namespaceId, ${stage.name}, ${status.name}, '
      '${failureCode?.name ?? 'none'})';
}

final class _MutableCleanupAttempt {
  _MutableCleanupAttempt({
    required this.attemptId,
    required this.namespaceId,
    required this.stage,
    required this.status,
    this.failureCode,
  });

  final TestCleanupAttemptId attemptId;
  final TestCleanupNamespaceId namespaceId;
  TestCleanupStage stage;
  TestCleanupAttemptStatus status;
  TestCleanupFailureCode? failureCode;

  TestCleanupAttemptSnapshot snapshot() => TestCleanupAttemptSnapshot(
    attemptId: attemptId,
    namespaceId: namespaceId,
    stage: stage,
    status: status,
    failureCode: failureCode,
  );
}

/// Test-support-only, process-local characterization ledger.
///
/// It deliberately has no persistence, clock, account mapping, filesystem, or
/// production interface. A PASS here is not restart-recovery evidence.
final class InMemoryChatCleanupLedger {
  final Map<TestCleanupNamespaceId, _MutableCleanupAttempt> _current =
      <TestCleanupNamespaceId, _MutableCleanupAttempt>{};
  final Map<TestCleanupAttemptId, _MutableCleanupAttempt> _attempts =
      <TestCleanupAttemptId, _MutableCleanupAttempt>{};
  var _nextAttempt = 0;
  var _failNextComplete = false;

  TestCleanupAttemptSnapshot begin(TestCleanupNamespaceId namespaceId) {
    final existing = _current[namespaceId];
    if (existing != null) return existing.snapshot();
    final attempt = _MutableCleanupAttempt(
      attemptId: TestCleanupAttemptId(++_nextAttempt),
      namespaceId: namespaceId,
      stage: TestCleanupStage.drainLocalWrites,
      status: TestCleanupAttemptStatus.pending,
    );
    _current[namespaceId] = attempt;
    _attempts[attempt.attemptId] = attempt;
    return attempt.snapshot();
  }

  TestCleanupLedgerResult advance(
    TestCleanupAttemptId attemptId,
    TestCleanupStage nextStage,
  ) {
    final attempt = _currentAttempt(attemptId);
    if (attempt == null) return TestCleanupLedgerResult.staleAttempt;
    if (attempt.status != TestCleanupAttemptStatus.pending) {
      return TestCleanupLedgerResult.invalidTransition;
    }
    final distance = nextStage.index - attempt.stage.index;
    if (distance < 0 || distance > 1) {
      return TestCleanupLedgerResult.invalidTransition;
    }
    attempt.stage = nextStage;
    return TestCleanupLedgerResult.applied;
  }

  TestCleanupLedgerResult recordFailure(
    TestCleanupAttemptId attemptId,
    TestCleanupFailureCode failureCode,
  ) => _mark(attemptId, TestCleanupAttemptStatus.failed, failureCode);

  TestCleanupLedgerResult markBlocked(
    TestCleanupAttemptId attemptId,
    TestCleanupFailureCode failureCode,
  ) => _mark(attemptId, TestCleanupAttemptStatus.blocked, failureCode);

  TestCleanupLedgerResult retry(TestCleanupAttemptId attemptId) {
    final attempt = _currentAttempt(attemptId);
    if (attempt == null) return TestCleanupLedgerResult.staleAttempt;
    if (attempt.status != TestCleanupAttemptStatus.failed &&
        attempt.status != TestCleanupAttemptStatus.blocked) {
      return TestCleanupLedgerResult.invalidTransition;
    }
    attempt.status = TestCleanupAttemptStatus.pending;
    attempt.failureCode = null;
    return TestCleanupLedgerResult.applied;
  }

  void scriptNextCompleteFailure() {
    _failNextComplete = true;
  }

  TestCleanupLedgerResult complete(TestCleanupAttemptId attemptId) {
    final attempt = _currentAttempt(attemptId);
    if (attempt == null) return TestCleanupLedgerResult.staleAttempt;
    if (attempt.status != TestCleanupAttemptStatus.pending ||
        attempt.stage != TestCleanupStage.purgeLocalData) {
      return TestCleanupLedgerResult.invalidTransition;
    }
    if (_failNextComplete) {
      _failNextComplete = false;
      return TestCleanupLedgerResult.simulatedFailure;
    }
    attempt.status = TestCleanupAttemptStatus.completed;
    attempt.failureCode = null;
    _current.remove(attempt.namespaceId);
    return TestCleanupLedgerResult.applied;
  }

  /// Seeds a restart-shaped record without claiming durable recovery.
  ///
  /// Unknown numeric values become a blocked fail-closed record rather than
  /// being interpreted as a successful or completed cleanup.
  TestCleanupAttemptSnapshot seedPendingForStartupSimulation({
    required TestCleanupNamespaceId namespaceId,
    required int stageIndex,
    required int statusIndex,
    int? failureCodeIndex,
  }) {
    final existing = _current[namespaceId];
    if (existing != null) return existing.snapshot();
    final validStage = _enumAt(TestCleanupStage.values, stageIndex);
    final validStatus = _enumAt(TestCleanupAttemptStatus.values, statusIndex);
    final validFailure = failureCodeIndex == null
        ? null
        : _enumAt(TestCleanupFailureCode.values, failureCodeIndex);
    final isPendingShape =
        validStage != null &&
        validStatus != null &&
        validStatus != TestCleanupAttemptStatus.completed &&
        (failureCodeIndex == null || validFailure != null);
    final attempt = _MutableCleanupAttempt(
      attemptId: TestCleanupAttemptId(++_nextAttempt),
      namespaceId: namespaceId,
      stage: validStage ?? TestCleanupStage.drainLocalWrites,
      status: isPendingShape ? validStatus : TestCleanupAttemptStatus.blocked,
      failureCode: isPendingShape
          ? validFailure
          : TestCleanupFailureCode.corruptSeed,
    );
    _current[namespaceId] = attempt;
    _attempts[attempt.attemptId] = attempt;
    return attempt.snapshot();
  }

  List<TestCleanupAttemptSnapshot> pendingSnapshot() => _current.values
      .map((_MutableCleanupAttempt attempt) => attempt.snapshot())
      .toList(growable: false);

  TestCleanupLedgerResult _mark(
    TestCleanupAttemptId attemptId,
    TestCleanupAttemptStatus status,
    TestCleanupFailureCode failureCode,
  ) {
    final attempt = _currentAttempt(attemptId);
    if (attempt == null) return TestCleanupLedgerResult.staleAttempt;
    if (attempt.status == TestCleanupAttemptStatus.completed) {
      return TestCleanupLedgerResult.invalidTransition;
    }
    attempt.status = status;
    attempt.failureCode = failureCode;
    return TestCleanupLedgerResult.applied;
  }

  _MutableCleanupAttempt? _currentAttempt(TestCleanupAttemptId attemptId) {
    final attempt = _attempts[attemptId];
    if (attempt == null || !identical(_current[attempt.namespaceId], attempt)) {
      return null;
    }
    return attempt;
  }
}

T? _enumAt<T>(List<T> values, int index) =>
    index >= 0 && index < values.length ? values[index] : null;
