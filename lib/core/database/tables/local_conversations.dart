import 'package:drift/drift.dart';

class LocalConversations extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('active'))();

  IntColumn get lastSequence => integer().withDefault(const Constant(0))();

  IntColumn get messageCount => integer().withDefault(const Constant(0))();

  TextColumn get lastMessageId => text().nullable()();

  DateTimeColumn get serverCreatedAt => dateTime()();

  DateTimeColumn get serverUpdatedAt => dateTime()();

  DateTimeColumn get lastSyncedAt => dateTime()();

  TextColumn get syncState => text().withDefault(const Constant('synced'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('active', 'archived'))",
    'CHECK (last_sequence >= 0)',
    'CHECK (message_count >= 0)',
    "CHECK (sync_state IN ('synced', 'refreshing', 'stale', 'failed'))",
  ];
}
