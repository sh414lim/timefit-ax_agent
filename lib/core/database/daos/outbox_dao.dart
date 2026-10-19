import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_messages.dart';
import '../tables/outbox_commands.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [LocalMessages, OutboxCommands])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  Future<void> enqueueMessage(
    LocalMessagesCompanion message,
    OutboxCommandsCompanion command,
  ) => transaction(() async {
    await into(localMessages).insert(message);
    await into(outboxCommands).insert(command);
  });

  Future<List<OutboxCommand>> getAll() => select(outboxCommands).get();

  /// The caller supplies a fresh opaque token for every acquisition, including
  /// reclamation by the same worker. It fences late results from older leases.
  Future<OutboxCommand?> claim(
    DateTime now,
    String token,
  ) => transaction(() async {
    final rows = await customWriteReturning(
      "UPDATE outbox_commands SET state = 'running', lease_owner = ?, lease_until = ?, updated_at = ? WHERE id = (SELECT id FROM outbox_commands WHERE ((state IN ('queued','retry_wait') AND next_attempt_at <= ?) OR (state = 'running' AND lease_until <= ?)) ORDER BY created_at, id LIMIT 1) RETURNING *",
      variables: [
        Variable(token),
        Variable.withDateTime(now.add(const Duration(seconds: 60))),
        Variable.withDateTime(now),
        Variable.withDateTime(now),
        Variable.withDateTime(now),
      ],
      updates: {outboxCommands},
    );
    return rows.isEmpty ? null : outboxCommands.map(rows.single.data);
  });

  Future<bool> finish(
    OutboxCommand lease,
    DateTime now, {
    required String state,
    required int failures,
    DateTime? nextAttemptAt,
    String? errorCode,
  }) async {
    final count =
        await (update(outboxCommands)..where(
              (row) =>
                  row.id.equals(lease.id) &
                  row.state.equals('running') &
                  row.leaseOwner.equals(lease.leaseOwner!) &
                  row.leaseUntil.isBiggerThanValue(now),
            ))
            .write(
              OutboxCommandsCompanion(
                state: Value(state),
                attemptCount: Value(failures),
                nextAttemptAt: Value(nextAttemptAt ?? now),
                leaseOwner: const Value(null),
                leaseUntil: const Value(null),
                lastErrorCode: Value(errorCode),
                updatedAt: Value(now),
              ),
            );
    return count == 1;
  }

  Future<bool> cancel(String id, DateTime now) async =>
      await (update(outboxCommands)..where(
            (row) =>
                row.id.equals(id) &
                row.state.isIn(['queued', 'running', 'retry_wait']),
          ))
          .write(
            OutboxCommandsCompanion(
              state: const Value('cancelled'),
              leaseOwner: const Value(null),
              leaseUntil: const Value(null),
              updatedAt: Value(now),
            ),
          ) ==
      1;

  Future<bool> retryFailed(String id, DateTime now) async =>
      await (update(outboxCommands)..where(
            (row) => row.id.equals(id) & row.state.equals('failed_permanent'),
          ))
          .write(
            OutboxCommandsCompanion(
              state: const Value('queued'),
              attemptCount: const Value(0),
              nextAttemptAt: Value(now),
              lastErrorCode: const Value(null),
              updatedAt: Value(now),
            ),
          ) ==
      1;
}
