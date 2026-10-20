import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/outbox_dao.dart';
import 'package:timefit_native/features/chat/application/outbox/command_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';

final class BoundaryExecutor implements CommandExecutor {
  int calls = 0;
  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) async {
    calls++;
    return const CommandExecutionResult(ExecutionDisposition.retryable);
  }
}

void main() {
  late AppDatabase first;
  late AppDatabase second;
  late Directory directory;
  final now = DateTime.utc(2026, 10, 19, 0, 0, 0, 900);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('outbox-boundary-');
    final file = File('${directory.path}/db.sqlite');
    final previous = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      first = AppDatabase(NativeDatabase(file));
      second = AppDatabase(NativeDatabase(file));
    } finally {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = previous;
    }
    await first
        .into(first.outboxCommands)
        .insert(
          OutboxCommandsCompanion.insert(
            id: 'command',
            commandType: 'send',
            aggregateId: 'conversation',
            clientRequestId: 'same-client',
            payloadJson: '{}',
            nextAttemptAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await second.outboxDao.getAll();
  });
  tearDown(() async {
    await first.close();
    await second.close();
    await directory.delete(recursive: true);
  });

  test(
    'fractional acquisition and retry deadlines never shorten waits',
    () async {
      final lease = (await first.outboxDao.claim(now, 'token'))!;
      expect(lease.leaseUntil!.toUtc(), DateTime.utc(2026, 10, 19, 0, 1, 1));
      expect(
        await second.outboxDao.claim(
          now.add(const Duration(seconds: 60)),
          'early',
        ),
        equals(null),
      );
      expect(
        await first.outboxDao.finish(
          lease,
          now.add(const Duration(seconds: 60)),
          state: 'retry_wait',
          failures: 1,
          nextAttemptAt: now.add(const Duration(seconds: 61)),
        ),
        isTrue,
      );
      expect(
        await second.outboxDao.claim(
          now.add(const Duration(seconds: 61)),
          'retry-early',
        ),
        equals(null),
      );
      final retry = (await second.outboxDao.claim(
        DateTime.utc(2026, 10, 19, 0, 1, 2),
        'retry',
      ))!;
      expect(
        await second.outboxDao.finish(
          retry,
          retry.leaseUntil!.toUtc(),
          state: 'completed',
          failures: 1,
        ),
        isFalse,
      );
    },
  );

  test('independent connections race without leaking SQLITE_BUSY', () async {
    final claims = await Future.wait([
      first.outboxDao.claim(now, 'first'),
      second.outboxDao.claim(now, 'second'),
    ]);
    expect(claims.whereType<OutboxCommand>(), hasLength(1));
  });

  test(
    'held write lock returns contention and worker wake exits safely',
    () async {
      await first.customStatement('BEGIN IMMEDIATE');
      try {
        await expectLater(
          second.outboxDao.claim(now, 'blocked'),
          throwsA(isA<OutboxContention>()),
        );
        final executor = BoundaryExecutor();
        final worker = OutboxWorker(
          dao: second.outboxDao,
          executor: executor,
          clock: () => now,
          retryPolicy: RetryPolicy(() => 0.5),
          scope: 'blocked',
        );
        await worker.wake();
        expect(executor.calls, 0);
      } finally {
        await first.customStatement('ROLLBACK');
      }
      expect((await second.outboxDao.getAll()).single.state, 'queued');
    },
  );
}
