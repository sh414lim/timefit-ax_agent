import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/outbox_dao.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';
import 'package:timefit_native/features/chat/application/outbox/command_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_observability.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';

void main() {
  late AppDatabase database;
  late DateTime now;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 29, 10);
  });

  tearDown(() => database.close());

  Future<void> enqueue({
    required String clientMessageId,
    String payload = '{"bodyText":"canary-private-body"}',
  }) async {
    await database
        .into(database.outboxCommands)
        .insert(
          OutboxCommandsCompanion.insert(
            id: clientMessageId,
            commandType: 'send_message',
            aggregateId: 'conversation-private',
            clientRequestId: clientMessageId,
            payloadJson: payload,
            nextAttemptAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  OutboxWorker worker({
    required CommandExecutor executor,
    required OutboxObservability observability,
    String scope = 'observability-test',
    OutboxDao? dao,
  }) => OutboxWorker(
    dao: dao ?? database.outboxDao,
    executor: executor,
    clock: () => now,
    retryPolicy: RetryPolicy(() => 0.5),
    scope: scope,
    observability: observability,
  );

  test('claim delay belongs to persisted age, not executor latency', () async {
    const clientMessageId = '4d7ac0aa-3b8d-4f9f-8b48-77d9c12b2740';
    await enqueue(clientMessageId: clientMessageId);
    final observer = _RecordingOutboxObservability();
    final claiming = Completer<void>();
    final releaseClaim = Completer<void>();

    final wake = worker(
      dao: _DelayedClaimDao(
        database,
        beforeReturn: () async {
          claiming.complete();
          await releaseClaim.future;
        },
      ),
      executor: _Executor((_) async {
        now = now.add(const Duration(milliseconds: 250));
        return const CommandExecutionResult(ExecutionDisposition.completed);
      }),
      observability: observer,
    ).wake();
    await claiming.future;
    now = now.add(const Duration(seconds: 5));
    releaseClaim.complete();
    await wake;

    expect(observer.ages, [
      (clientMessageId: clientMessageId, value: const Duration(seconds: 5)),
    ]);
    expect(observer.latencies, [
      (
        clientMessageId: clientMessageId,
        value: const Duration(milliseconds: 250),
      ),
    ]);
    expect((await database.outboxDao.getAll()).single.state, 'completed');
  });

  test('clock regression clamps both metrics without failing work', () async {
    const clientMessageId = '0c9293ee-c4d7-4117-a088-f2c90c0805f5';
    await enqueue(clientMessageId: clientMessageId);
    final observer = _RecordingOutboxObservability();

    await worker(
      dao: _DelayedClaimDao(
        database,
        beforeReturn: () async {
          now = now.subtract(const Duration(seconds: 2));
        },
      ),
      executor: _Executor((_) async {
        now = now.subtract(const Duration(seconds: 3));
        return const CommandExecutionResult(ExecutionDisposition.completed);
      }),
      observability: observer,
    ).wake();

    expect(observer.ages.single.value, Duration.zero);
    expect(observer.latencies.single.value, Duration.zero);
    expect((await database.outboxDao.getAll()).single.state, 'completed');
  });

  test('executor timing also excludes synchronous observation work', () async {
    const clientMessageId = '6f735fd0-3cbd-413a-a871-7b0d21112312';
    await enqueue(clientMessageId: clientMessageId);
    now = now.add(const Duration(seconds: 5));
    final observer = _RecordingOutboxObservability(
      onAge: () => now = now.add(const Duration(seconds: 2)),
    );

    await worker(
      executor: _Executor((_) async {
        now = now.add(const Duration(milliseconds: 250));
        return const CommandExecutionResult(ExecutionDisposition.completed);
      }),
      observability: observer,
    ).wake();

    expect(observer.ages.single.value, const Duration(seconds: 5));
    expect(observer.latencies.single.value, const Duration(milliseconds: 250));
  });

  test('retry records age per claim and latency only for success', () async {
    const clientMessageId = 'fbec32b2-1d23-4d4d-a2ba-cf0b9bc0b9ef';
    await enqueue(clientMessageId: clientMessageId);
    final observer = _RecordingOutboxObservability();
    var executions = 0;
    final outboxWorker = worker(
      executor: _Executor((_) async {
        executions += 1;
        if (executions == 1) {
          return const CommandExecutionResult(
            ExecutionDisposition.retryable,
            errorCode: 'offline',
          );
        }
        now = now.add(const Duration(milliseconds: 10));
        return const CommandExecutionResult(ExecutionDisposition.completed);
      }),
      observability: observer,
    );

    await outboxWorker.wake();
    expect(observer.ages.map((entry) => entry.value), [Duration.zero]);
    expect(observer.latencies, isEmpty);
    expect((await database.outboxDao.getAll()).single.attemptCount, 1);

    // An early wake must not record a claim or bypass the retry deadline.
    await outboxWorker.wake();
    expect(executions, 1);
    expect(observer.ages, hasLength(1));

    now = now.add(const Duration(seconds: 1));
    await outboxWorker.wake();

    expect(observer.ages.map((entry) => entry.value), [
      Duration.zero,
      const Duration(seconds: 1),
    ]);
    expect(observer.latencies.map((entry) => entry.value), [
      const Duration(milliseconds: 10),
    ]);
    expect((await database.outboxDao.getAll()).single.state, 'completed');
  });

  test('expired delayed claim cannot report successful latency', () async {
    const clientMessageId = '72bca130-4090-4be4-a49b-cf10312d9ae0';
    await enqueue(clientMessageId: clientMessageId);
    final observer = _RecordingOutboxObservability();
    await worker(
      dao: _DelayedClaimDao(
        database,
        beforeReturn: () async {
          now = now.add(const Duration(seconds: 61));
        },
      ),
      executor: _Executor(
        (_) async =>
            const CommandExecutionResult(ExecutionDisposition.completed),
      ),
      observability: observer,
    ).wake();

    expect(observer.ages.single.value, const Duration(seconds: 61));
    expect(observer.latencies, isEmpty);
    expect((await database.outboxDao.getAll()).single.state, 'running');
  });

  test('stale completion is not reported as successful send latency', () async {
    const clientMessageId = '6a8759b8-6dd5-4e60-97f0-2b69ee23216f';
    await enqueue(clientMessageId: clientMessageId);
    final observer = _RecordingOutboxObservability();

    await worker(
      executor: _Executor((command) async {
        expect(await database.outboxDao.cancel(command.id, now), isTrue);
        now = now.add(const Duration(seconds: 1));
        return const CommandExecutionResult(ExecutionDisposition.completed);
      }),
      observability: observer,
    ).wake();

    expect(observer.ages, hasLength(1));
    expect(observer.latencies, isEmpty);
    expect((await database.outboxDao.getAll()).single.state, 'cancelled');
  });

  test('logger adapter exports only typed ID and numeric timings', () async {
    const clientMessageId = '8a515cf8-0b89-4fa1-b188-64ab2f088ecc';
    await enqueue(
      clientMessageId: clientMessageId,
      payload: '{"bodyText":"canary-private-body","fileName":"canary.pdf"}',
    );
    now = now.add(const Duration(seconds: 3));
    final sink = FakeAppLogSink();
    final logger = AppLogger(
      context: AppLogContext(
        environment: 'test',
        app: 'timefit-native',
        build: '0.1.0+1',
      ),
      sink: sink,
    );

    await worker(
      executor: _Executor((_) async {
        now = now.add(const Duration(milliseconds: 40));
        return const CommandExecutionResult(ExecutionDisposition.completed);
      }),
      observability: AppLoggerOutboxObservability(logger),
    ).wake();

    expect(sink.records.map((record) => record.export['eventCode']), [
      'outbox_age',
      'send_latency',
    ]);
    final encoded = jsonEncode(
      sink.records.map((record) => record.export).toList(),
    );
    expect(encoded, contains(clientMessageId));
    expect(encoded, isNot(contains('canary-private-body')));
    expect(encoded, isNot(contains('canary.pdf')));
    expect(encoded, isNot(contains('conversation-private')));
  });

  test(
    'invalid IDs and observer failures never change Outbox behavior',
    () async {
      await enqueue(clientMessageId: 'canary-private-file.pdf');
      final sink = FakeAppLogSink();
      final logger = AppLogger(
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        sink: sink,
      );

      await worker(
        executor: _Executor(
          (_) async =>
              const CommandExecutionResult(ExecutionDisposition.completed),
        ),
        observability: AppLoggerOutboxObservability(logger),
        scope: 'invalid-id',
      ).wake();

      expect(sink.records, isEmpty);
      expect((await database.outboxDao.getAll()).single.state, 'completed');

      await database.delete(database.outboxCommands).go();
      await enqueue(clientMessageId: '9d04537a-b853-44e8-8b95-334c0a5981ef');
      await worker(
        executor: _Executor(
          (_) async =>
              const CommandExecutionResult(ExecutionDisposition.completed),
        ),
        observability: _ThrowingOutboxObservability(),
        scope: 'throwing-observer',
      ).wake();

      expect((await database.outboxDao.getAll()).single.state, 'completed');
    },
  );

  test('delayed observer failure is contained without a zone error', () async {
    const clientMessageId = '6461afce-baf3-46a0-a1b4-5506939cf75e';
    await enqueue(clientMessageId: clientMessageId);
    final uncaught = <Object>[];
    final release = Completer<void>();
    final observer = _DelayedThrowingOutboxObservability(release.future);

    await runZonedGuarded(() async {
      await worker(
        executor: _Executor(
          (_) async =>
              const CommandExecutionResult(ExecutionDisposition.completed),
        ),
        observability: observer,
      ).wake();
      // Both callbacks are still pending; they must not delay delivery.
      expect(observer.calls, 2);
      expect((await database.outboxDao.getAll()).single.state, 'completed');
      release.complete();
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => uncaught.add(error));

    expect(uncaught, isEmpty);
    expect((await database.outboxDao.getAll()).single.state, 'completed');
  });

  test(
    'worker logger contains delayed sink errors after wake returns',
    () async {
      const clientMessageId = 'f35830cd-7914-4d9c-b637-06fda68c3db1';
      await enqueue(clientMessageId: clientMessageId);
      final release = Completer<void>();
      final sink = _DelayedFailingSink(release.future);
      final logger = AppLogger(
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        sink: sink,
      );
      final uncaught = <Object>[];

      await runZonedGuarded(() async {
        await worker(
          executor: _Executor(
            (_) async =>
                const CommandExecutionResult(ExecutionDisposition.completed),
          ),
          observability: AppLoggerOutboxObservability(logger),
        ).wake();
        expect(sink.records, hasLength(2));
        expect((await database.outboxDao.getAll()).single.state, 'completed');
        release.complete();
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => uncaught.add(error));

      expect(uncaught, isEmpty);
      final export = jsonEncode(
        sink.records.map((record) => record.export).toList(),
      );
      expect(export, contains(clientMessageId));
      expect(export, isNot(contains('canary-private-body')));
      expect(export, isNot(contains('delayed sink canary')));
    },
  );
}

final class _Executor implements CommandExecutor {
  const _Executor(this._execute);

  final Future<CommandExecutionResult> Function(OutboxExecutionCommand)
  _execute;

  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) =>
      _execute(command);
}

final class _DelayedClaimDao extends OutboxDao {
  _DelayedClaimDao(super.database, {required this.beforeReturn});

  final Future<void> Function() beforeReturn;

  @override
  Future<OutboxCommand?> claim(DateTime now, String token) async {
    final lease = await super.claim(now, token);
    if (lease != null) await beforeReturn();
    return lease;
  }
}

final class _RecordingOutboxObservability implements OutboxObservability {
  _RecordingOutboxObservability({this.onAge});

  final void Function()? onAge;
  final ages = <({String clientMessageId, Duration value})>[];
  final latencies = <({String clientMessageId, Duration value})>[];

  @override
  Future<void> recordClaimAge({
    required String clientMessageId,
    required Duration age,
  }) async {
    ages.add((clientMessageId: clientMessageId, value: age));
    onAge?.call();
  }

  @override
  Future<void> recordCompletedSend({
    required String clientMessageId,
    required Duration latency,
  }) async => latencies.add((clientMessageId: clientMessageId, value: latency));
}

final class _ThrowingOutboxObservability implements OutboxObservability {
  @override
  Future<void> recordClaimAge({
    required String clientMessageId,
    required Duration age,
  }) => throw StateError('canary observer failure');

  @override
  Future<void> recordCompletedSend({
    required String clientMessageId,
    required Duration latency,
  }) => throw StateError('canary observer failure');
}

final class _DelayedFailingSink implements AppLogSink {
  _DelayedFailingSink(this.release);

  final Future<void> release;
  final records = <AppLogRecord>[];

  @override
  Future<void> write(AppLogRecord record) async {
    records.add(record);
    await release;
    throw StateError('delayed sink canary');
  }
}

final class _DelayedThrowingOutboxObservability implements OutboxObservability {
  _DelayedThrowingOutboxObservability(this.release);

  final Future<void> release;
  var calls = 0;

  @override
  Future<void> recordClaimAge({
    required String clientMessageId,
    required Duration age,
  }) async {
    calls += 1;
    await release;
    throw StateError('delayed observer canary');
  }

  @override
  Future<void> recordCompletedSend({
    required String clientMessageId,
    required Duration latency,
  }) async {
    calls += 1;
    await release;
    throw StateError('delayed observer canary');
  }
}
