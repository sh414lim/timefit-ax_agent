import 'package:drift/drift.dart';

class LocalMessages extends Table {
  TextColumn get localId => text()();

  TextColumn get serverId => text().nullable().unique()();

  TextColumn get conversationId => text()();

  TextColumn get clientMessageId => text()();

  IntColumn get sequence => integer().nullable()();

  TextColumn get senderKind => text()();

  TextColumn get bodyText => text().nullable()();

  TextColumn get messageKind => text()();

  DateTimeColumn get clientCreatedAt => dateTime()();

  DateTimeColumn get serverCreatedAt => dateTime().nullable()();

  TextColumn get deliveryState =>
      text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {localId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, clientMessageId},
    {conversationId, sequence},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (delivery_state IN ('pending', 'uploading', 'sending', 'sent', 'failed'))",
    'CHECK (sequence IS NULL OR sequence > 0)',
    "CHECK (sender_kind IN ('user', 'system'))",
    "CHECK (message_kind IN ('text', 'attachment', 'mixed', 'system'))",
  ];
}
