import 'package:drift/drift.dart';

final class UnsupportedSchemaMigration implements Exception {
  const UnsupportedSchemaMigration(this.from, this.to);

  final int from;
  final int to;

  @override
  String toString() =>
      'Unsupported non-destructive schema migration: $from -> $to';
}

MigrationStrategy schemaV1MigrationStrategy() => MigrationStrategy(
  onCreate: (migrator) => migrator.createAll(),
  onUpgrade: (migrator, from, to) async {
    throw UnsupportedSchemaMigration(from, to);
  },
);
