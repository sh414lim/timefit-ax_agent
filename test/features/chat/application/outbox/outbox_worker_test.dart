import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/chat/application/outbox/command_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';

final class FakeExecutor implements CommandExecutor {
  FakeExecutor(this.run);
  final Future<CommandExecutionResult> Function(OutboxExecutionCommand) run;
  final calls = <OutboxExecutionCommand>[];
  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) {
    calls.add(command);
    return run(command);
  }
}

void main() {
  late AppDatabase db;
  late DateTime now;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 19);
  });
  tearDown(() => db.close());
  Future<void> enqueue([String id = 'command']) async {
    await db
        .into(db.outboxCommands)
        .insert(
          OutboxCommandsCompanion.insert(
            id: id,
            commandType: 'send_message',
            aggregateId: 'conversation',
            clientRequestId: 'same-client',
            payloadJson: '{"localMessageId":"same-message"}',
            nextAttemptAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  OutboxWorker worker(FakeExecutor executor, {String scope = 'db'}) =>
      OutboxWorker(
        dao: db.outboxDao,
        executor: executor,
        clock: () => now,
        retryPolicy: RetryPolicy(() => 0.5),
        scope: scope,
      );
  Future<OutboxCommand> row() async => (await db.outboxDao.getAll()).single;

  test('two workers share one process drain and execute once', () async {
    await enqueue();
    final started = Completer<void>();
    final result = Completer<CommandExecutionResult>();
    final executor = FakeExecutor((_) {
      started.complete();
      return result.future;
    });
    final first = worker(executor).wake();
    await started.future;
    await worker(executor).wake();
    expect(executor.calls, hasLength(1));
    result.complete(
      const CommandExecutionResult(ExecutionDisposition.completed),
    );
    await first;
    expect((await row()).state, 'completed');
  });

  test(
    'lease competition and expired results are fenced by acquisition token',
    () async {
      await enqueue();
      final leases = await Future.wait([
        db.outboxDao.claim(now, 'first'),
        db.outboxDao.claim(now, 'second'),
      ]);
      final old = leases.whereType<OutboxCommand>().single;
      expect(
        await db.outboxDao.claim(now.add(const Duration(seconds: 59)), 'early'),
        equals(null),
      );
      now = now.add(const Duration(seconds: 60));
      expect(
        await db.outboxDao.finish(old, now, state: 'completed', failures: 0),
        isFalse,
      );
      final fresh = (await db.outboxDao.claim(now, 'recovered'))!;
      expect(fresh.id, old.id);
      expect(
        await db.outboxDao.finish(old, now, state: 'completed', failures: 0),
        isFalse,
      );
      expect(
        await db.outboxDao.finish(fresh, now, state: 'completed', failures: 0),
        isTrue,
      );
    },
  );

  test(
    'retry clock schedule preserves command and client IDs and stops at eight',
    () async {
      await enqueue();
      final executor = FakeExecutor(
        (_) async => const CommandExecutionResult(
          ExecutionDisposition.retryable,
          errorCode: 'timeout',
        ),
      );
      final subject = worker(executor);
      const delays = [1, 2, 4, 8, 16, 30, 30];
      for (var failure = 1; failure <= 8; failure++) {
        await subject.wake();
        final current = await row();
        expect(current.attemptCount, failure);
        if (failure < 8) {
          expect(
            current.nextAttemptAt.toUtc(),
            now.toUtc().add(Duration(seconds: delays[failure - 1])),
          );
          await subject.wake();
          expect(executor.calls, hasLength(failure));
          now = current.nextAttemptAt;
        }
      }
      expect((await row()).state, 'failed_permanent');
      now = now.add(const Duration(days: 1));
      await subject.wake();
      expect(executor.calls, hasLength(8));
      expect(executor.calls.map((c) => c.id).toSet(), {'command'});
      expect(executor.calls.map((c) => c.clientRequestId).toSet(), {
        'same-client',
      });
      expect(executor.calls.map((c) => c.payloadJson).toSet(), hasLength(1));
      expect(await db.outboxDao.retryFailed('command', now), isTrue);
      expect((await row()).attemptCount, 0);
    },
  );

  test('late worker result cannot replace recovered worker failure', () async {
    await enqueue();
    final started = Completer<void>();
    final lateResult = Completer<CommandExecutionResult>();
    final oldExecutor = FakeExecutor((_) {
      started.complete();
      return lateResult.future;
    });
    final oldRun = worker(oldExecutor, scope: 'old-process').wake();
    await started.future;
    now = now.add(const Duration(seconds: 60));
    final freshExecutor = FakeExecutor(
      (_) async => const CommandExecutionResult(
        ExecutionDisposition.permanent,
        errorCode: 'forbidden',
      ),
    );
    await worker(freshExecutor, scope: 'restarted-process').wake();
    lateResult.complete(
      const CommandExecutionResult(ExecutionDisposition.completed),
    );
    await oldRun;
    expect((await row()).state, 'failed_permanent');
    expect((await row()).lastErrorCode, 'forbidden');
  });

  test(
    'unexpected executor failure persists retry without exposing raw error',
    () async {
      await enqueue();
      final executor = FakeExecutor(
        (_) async => throw StateError('private raw response'),
      );
      await worker(executor).wake();
      expect((await row()).state, 'retry_wait');
      expect((await row()).lastErrorCode, 'executor_exception');
    },
  );

  test('jitter endpoints cover each bounded delay', () {
    const base = [1, 2, 4, 8, 16, 30, 30];
    for (var i = 0; i < base.length; i++) {
      expect(
        RetryPolicy(() => 0).delay(i + 1).inSeconds,
        (base[i] * 0.8).ceil(),
      );
      expect(
        RetryPolicy(() => 1).delay(i + 1).inSeconds,
        (base[i] * 1.2).floor(),
      );
    }
  });

  test(
    'permanent validation result never retries; cancellation rejects late completion',
    () async {
      await enqueue();
      final executor = FakeExecutor(
        (_) async => const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'validation_failed',
        ),
      );
      await worker(executor).wake();
      expect((await row()).state, 'failed_permanent');
      await worker(executor).wake();
      expect(executor.calls, hasLength(1));
      await db.outboxDao.retryFailed('command', now);
      final lease = (await db.outboxDao.claim(now, 'cancelled-lease'))!;
      expect(await db.outboxDao.cancel('command', now), isTrue);
      expect(
        await db.outboxDao.finish(lease, now, state: 'completed', failures: 0),
        isFalse,
      );
      expect((await row()).state, 'cancelled');
    },
  );

  test(
    'auth pauses without consuming retry count and wake requires explicit resume',
    () async {
      await enqueue();
      final executor = FakeExecutor(
        (_) async =>
            const CommandExecutionResult(ExecutionDisposition.authRequired),
      );
      final subject = worker(executor);
      await subject.wake();
      await subject.wake();
      expect(executor.calls, hasLength(1));
      expect((await row()).attemptCount, 0);
      subject.resumeAfterAuthentication();
      await subject.wake();
      expect(executor.calls, hasLength(2));
    },
  );

  test(
    'stopped worker leaves persisted lease and does not apply result',
    () async {
      await enqueue();
      final started = Completer<void>();
      final result = Completer<CommandExecutionResult>();
      final executor = FakeExecutor((_) {
        started.complete();
        return result.future;
      });
      final subject = worker(executor);
      final running = subject.wake();
      await started.future;
      subject.stop();
      result.complete(
        const CommandExecutionResult(ExecutionDisposition.completed),
      );
      await running;
      expect((await row()).state, 'running');
      now = now.add(const Duration(seconds: 60));
      expect(await db.outboxDao.claim(now, 'replacement'), isNotNull);
    },
  );

  test(
    'file database survives process close and reclaims once at 60 seconds',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'timefit-outbox-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await db.close();
      final file = File('${directory.path}/local.sqlite');
      db = AppDatabase(NativeDatabase(file));
      await enqueue();
      await db.outboxDao.claim(now, 'dead-process');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect(
        await db.outboxDao.claim(now.add(const Duration(seconds: 59)), 'early'),
        equals(null),
      );
      now = now.add(const Duration(seconds: 60));
      expect(await db.outboxDao.claim(now, 'new-process'), isNotNull);
      expect(await db.outboxDao.claim(now, 'duplicate'), equals(null));
    },
  );
}
