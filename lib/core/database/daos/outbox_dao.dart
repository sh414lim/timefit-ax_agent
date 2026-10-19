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
}
