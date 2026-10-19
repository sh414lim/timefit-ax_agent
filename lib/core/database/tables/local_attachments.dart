import 'package:drift/drift.dart';

class LocalAttachments extends Table {
  TextColumn get localId => text()();

  TextColumn get attachmentId => text().nullable().unique()();

  TextColumn get conversationId => text()();

  TextColumn get clientMessageId => text()();

  TextColumn get localFileUri => text().nullable()();

  TextColumn get uploadState => text().withDefault(const Constant('queued'))();

  IntColumn get bytesTotal => integer().withDefault(const Constant(0))();

  IntColumn get bytesSent => integer().withDefault(const Constant(0))();

  TextColumn get contentType => text()();

  TextColumn get sha256 => text()();

  TextColumn get failureCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {localId};

  @override
  List<String> get customConstraints => [
    "CHECK (upload_state IN ('queued', 'preparing', 'uploading', 'finalizing', 'ready', 'bound', 'failed'))",
    'CHECK (bytes_total >= 0)',
    'CHECK (bytes_sent >= 0 AND bytes_sent <= bytes_total)',
  ];
}
