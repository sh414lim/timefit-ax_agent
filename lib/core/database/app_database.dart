import 'package:drift/drift.dart';

import 'daos/attachment_dao.dart';
import 'daos/conversation_dao.dart';
import 'daos/message_dao.dart';
import 'daos/outbox_dao.dart';
import 'migrations.dart';
import 'tables/local_attachments.dart';
import 'tables/local_conversations.dart';
import 'tables/local_messages.dart';
import 'tables/outbox_commands.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [LocalConversations, LocalMessages, LocalAttachments, OutboxCommands],
  daos: [ConversationDao, MessageDao, AttachmentDao, OutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => schemaV4MigrationStrategy(
    upgradeV1ToV2: (migrator) async {
      await migrator.addColumn(
        localAttachments,
        localAttachments.uploadObjectPath,
      );
      await migrator.addColumn(
        localAttachments,
        localAttachments.verificationFailures,
      );
    },
    upgradeV2ToV3: (migrator) =>
        migrator.addColumn(localAttachments, localAttachments.composerExcluded),
    upgradeV3ToV4: (migrator) =>
        migrator.addColumn(localAttachments, localAttachments.displayName),
  );

  Future<void> purgeChatData() => transaction(() async {
    await delete(localAttachments).go();
    await delete(outboxCommands).go();
    await delete(localMessages).go();
    await delete(localConversations).go();
  });
}

abstract interface class CorruptDatabaseRecreator {
  /// Explicit recovery seam. Callers must confirm corruption before invoking it;
  /// [AppDatabase] never performs destructive recovery automatically.
  Future<AppDatabase> recreateAfterConfirmedCorruption();
}

final class ConfirmedCorruptionRecovery implements CorruptDatabaseRecreator {
  const ConfirmedCorruptionRecovery({
    required Future<void> Function() deleteCorruptedStore,
    required QueryExecutor Function() openFreshExecutor,
  }) : _deleteCorruptedStore = deleteCorruptedStore,
       _openFreshExecutor = openFreshExecutor;

  final Future<void> Function() _deleteCorruptedStore;
  final QueryExecutor Function() _openFreshExecutor;

  @override
  Future<AppDatabase> recreateAfterConfirmedCorruption() async {
    await _deleteCorruptedStore();
    return AppDatabase(_openFreshExecutor());
  }
}
