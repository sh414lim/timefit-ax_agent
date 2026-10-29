import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
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
  }) => OutboxWorker(
    dao: database.outboxDao,
    executor: executor,
    clock: () => now,
    retryPolicy: RetryPolicy(() => 0.5),
    scope: scope,
    observability: observability,
  );

  test(
    'records persisted age and applied successful execution latency',
    () async {
      const clientMessageId = '4d7ac0aa-3b8d-4f9f-8b48-77d9c12b2740';
      await enqueue(clientMessageId: clientMessageId);
      now = now.add(const Duration(seconds: 5));
      final observer = _RecordingOutboxObservability();

      await worker(
        executor: _Executor((_) async {
          now = now.add(const Duration(milliseconds: 250));
          return const CommandExecutionResult(ExecutionDisposition.completed);
        }),
        observability: observer,
      ).wake();

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
    },
  );

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
}

final class _Executor implements CommandExecutor {
  const _Executor(this._execute);

  final Future<CommandExecutionResult> Function(OutboxExecutionCommand)
  _execute;

  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) =>
      _execute(command);
}

final class _RecordingOutboxObservability implements OutboxObservability {
  final ages = <({String clientMessageId, Duration value})>[];
  final latencies = <({String clientMessageId, Duration value})>[];

  @override
  void recordClaimAge({
    required String clientMessageId,
    required Duration age,
  }) => ages.add((clientMessageId: clientMessageId, value: age));

  @override
  void recordCompletedSend({
    required String clientMessageId,
    required Duration latency,
  }) => latencies.add((clientMessageId: clientMessageId, value: latency));
}

final class _ThrowingOutboxObservability implements OutboxObservability {
  @override
  void recordClaimAge({
    required String clientMessageId,
    required Duration age,
  }) => throw StateError('canary observer failure');

  @override
  void recordCompletedSend({
    required String clientMessageId,
    required Duration latency,
  }) => throw StateError('canary observer failure');
}
