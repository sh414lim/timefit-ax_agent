import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_chat_cleanup_ledger.dart';

void main() {
  const namespaceA = TestCleanupNamespaceId(1);
  const namespaceB = TestCleanupNamespaceId(2);

  test('same namespace begin reuses one pending attempt', () {
    final ledger = InMemoryChatCleanupLedger();

    final first = ledger.begin(namespaceA);
    final second = ledger.begin(namespaceA);

    expect(second.attemptId, first.attemptId);
    expect(ledger.pendingSnapshot(), hasLength(1));
  });

  test('different namespaces keep independent current attempts', () {
    final ledger = InMemoryChatCleanupLedger();

    final attemptA = ledger.begin(namespaceA);
    final attemptB = ledger.begin(namespaceB);

    expect(attemptA.attemptId, isNot(attemptB.attemptId));
    expect(ledger.pendingSnapshot(), hasLength(2));
    expect(
      ledger.advance(
        attemptA.attemptId,
        TestCleanupStage.stopLifecycleAndOutbox,
      ),
      TestCleanupLedgerResult.applied,
    );
    expect(
      ledger
          .pendingSnapshot()
          .singleWhere((entry) => entry.namespaceId == namespaceB)
          .stage,
      TestCleanupStage.drainLocalWrites,
    );
  });

  test('failure retries the same stage and cannot move backwards', () {
    final ledger = InMemoryChatCleanupLedger();
    final attempt = ledger.begin(namespaceA);
    expect(
      ledger.advance(
        attempt.attemptId,
        TestCleanupStage.stopLifecycleAndOutbox,
      ),
      TestCleanupLedgerResult.applied,
    );

    expect(
      ledger.recordFailure(
        attempt.attemptId,
        TestCleanupFailureCode.stageFailure,
      ),
      TestCleanupLedgerResult.applied,
    );
    expect(
      ledger.advance(attempt.attemptId, TestCleanupStage.purgeLocalData),
      TestCleanupLedgerResult.invalidTransition,
    );
    expect(ledger.retry(attempt.attemptId), TestCleanupLedgerResult.applied);
    expect(
      ledger.advance(
        attempt.attemptId,
        TestCleanupStage.stopLifecycleAndOutbox,
      ),
      TestCleanupLedgerResult.applied,
    );
    expect(
      ledger.advance(attempt.attemptId, TestCleanupStage.drainLocalWrites),
      TestCleanupLedgerResult.invalidTransition,
    );
  });

  test('old attempt late completion cannot clear a new attempt', () {
    final ledger = InMemoryChatCleanupLedger();
    final old = ledger.begin(namespaceA);
    ledger.advance(old.attemptId, TestCleanupStage.stopLifecycleAndOutbox);
    ledger.advance(old.attemptId, TestCleanupStage.purgeLocalData);
    expect(ledger.complete(old.attemptId), TestCleanupLedgerResult.applied);
    final current = ledger.begin(namespaceA);

    expect(
      ledger.complete(old.attemptId),
      TestCleanupLedgerResult.staleAttempt,
    );
    expect(ledger.pendingSnapshot().single.attemptId, current.attemptId);
  });

  test('simulated clear failure retains the pending locator', () {
    final ledger = InMemoryChatCleanupLedger();
    final attempt = ledger.begin(namespaceA);
    ledger.advance(attempt.attemptId, TestCleanupStage.stopLifecycleAndOutbox);
    ledger.advance(attempt.attemptId, TestCleanupStage.purgeLocalData);
    ledger.scriptNextCompleteFailure();

    expect(
      ledger.complete(attempt.attemptId),
      TestCleanupLedgerResult.simulatedFailure,
    );
    expect(ledger.pendingSnapshot().single.attemptId, attempt.attemptId);
    expect(ledger.complete(attempt.attemptId), TestCleanupLedgerResult.applied);
    expect(ledger.pendingSnapshot(), isEmpty);
  });

  test('unknown startup-shaped state is retained fail-closed', () {
    final ledger = InMemoryChatCleanupLedger();

    final seeded = ledger.seedPendingForStartupSimulation(
      namespaceId: namespaceA,
      stageIndex: 999,
      statusIndex: -1,
      failureCodeIndex: 999,
    );

    expect(seeded.status, TestCleanupAttemptStatus.blocked);
    expect(seeded.failureCode, TestCleanupFailureCode.corruptSeed);
    expect(ledger.pendingSnapshot(), hasLength(1));
    expect(
      ledger.complete(seeded.attemptId),
      TestCleanupLedgerResult.invalidTransition,
    );
  });

  test('snapshot diagnostics contain opaque identities only', () {
    final ledger = InMemoryChatCleanupLedger();
    final attempt = ledger.begin(namespaceA);
    ledger.markBlocked(
      attempt.attemptId,
      TestCleanupFailureCode.timeoutObserved,
    );

    final text = ledger.pendingSnapshot().single.toString();
    expect(text, contains('timeoutObserved'));
    expect(text, isNot(contains('account')));
    expect(text, isNot(contains('/')));
    expect(text, isNot(contains('token')));
  });
}
