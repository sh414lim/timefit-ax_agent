import 'package:drift/drift.dart';

class OutboxCommands extends Table {
  TextColumn get id => text()();

  TextColumn get commandType => text()();

  TextColumn get aggregateId => text()();

  TextColumn get clientRequestId => text()();

  TextColumn get payloadJson => text()();

  TextColumn get state => text().withDefault(const Constant('queued'))();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextAttemptAt => dateTime()();

  TextColumn get leaseOwner => text().nullable()();

  DateTimeColumn get leaseUntil => dateTime().nullable()();

  TextColumn get lastErrorCode => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (state IN ('queued', 'running', 'retry_wait', 'completed', 'failed_permanent', 'cancelled'))",
    'CHECK (attempt_count >= 0)',
  ];
}
