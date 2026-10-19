import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/message_dao.dart';
import 'package:timefit_native/core/database/migrations.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('schema v1 creates all local chat tables', () async {
    final tables = await database
        .customSelect(
          "select name from sqlite_master where type = 'table' order by name",
        )
        .map((row) => row.read<String>('name'))
        .get();

    expect(database.schemaVersion, 1);
    expect(
      tables,
      containsAll(<String>[
        'local_conversations',
        'local_messages',
        'local_attachments',
        'outbox_commands',
      ]),
    );
  });

  test('migration strategy rejects unplanned upgrades', () async {
    final onUpgrade = schemaV1MigrationStrategy().onUpgrade;

    expect(
      () => onUpgrade(database.createMigrator(), 1, 2),
      throwsA(isA<UnsupportedSchemaMigration>()),
    );
  });

  test('canonical RPC and Broadcast inputs converge to one row', () async {
    final now = DateTime.utc(2026, 10, 19);
    await database
        .into(database.localMessages)
        .insert(
          LocalMessagesCompanion.insert(
            localId: 'local-1',
            conversationId: 'conversation-1',
            clientMessageId: 'client-message-1',
            senderKind: 'user',
            bodyText: const Value('local draft'),
            messageKind: 'text',
            clientCreatedAt: now,
            deliveryState: const Value('sending'),
          ),
        );
    final canonical = CanonicalLocalMessage(
      serverId: 'server-1',
      conversationId: 'conversation-1',
      clientMessageId: 'client-message-1',
      sequence: 7,
      senderKind: 'user',
      bodyText: 'canonical body',
      messageKind: 'text',
      serverCreatedAt: now.add(const Duration(seconds: 1)),
    );

    await database.messageDao.upsertCanonical(
      canonical,
      fallbackLocalId: 'rpc-fallback',
      fallbackClientCreatedAt: now,
    );
    await database.messageDao.upsertCanonical(
      canonical,
      fallbackLocalId: 'broadcast-fallback',
      fallbackClientCreatedAt: now,
    );

    final rows = await database.messageDao.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.localId, 'local-1');
    expect(rows.single.serverId, 'server-1');
    expect(rows.single.sequence, 7);
    expect(rows.single.bodyText, 'canonical body');
    expect(rows.single.deliveryState, 'sending');
  });

  test('duplicate server id and sequence are rejected', () async {
    final now = DateTime.utc(2026, 10, 19);
    Future<void> insert({
      required String localId,
      required String serverId,
      required String clientId,
      required int sequence,
    }) => database
        .into(database.localMessages)
        .insert(
          LocalMessagesCompanion.insert(
            localId: localId,
            serverId: Value(serverId),
            conversationId: 'conversation-1',
            clientMessageId: clientId,
            sequence: Value(sequence),
            senderKind: 'user',
            bodyText: const Value('body'),
            messageKind: 'text',
            clientCreatedAt: now,
          ),
        );

    await insert(
      localId: 'local-1',
      serverId: 'server-1',
      clientId: 'client-1',
      sequence: 1,
    );

    expect(
      () => insert(
        localId: 'local-2',
        serverId: 'server-1',
        clientId: 'client-2',
        sequence: 2,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => insert(
        localId: 'local-3',
        serverId: 'server-3',
        clientId: 'client-3',
        sequence: 1,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => insert(
        localId: 'local-4',
        serverId: 'server-4',
        clientId: 'client-1',
        sequence: 4,
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('invalid local state is rejected by schema constraints', () async {
    final now = DateTime.utc(2026, 10, 19);

    expect(
      () => database
          .into(database.localMessages)
          .insert(
            LocalMessagesCompanion.insert(
              localId: 'invalid-state',
              conversationId: 'conversation-1',
              clientMessageId: 'client-invalid-state',
              senderKind: 'user',
              messageKind: 'text',
              clientCreatedAt: now,
              deliveryState: const Value('not-a-state'),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('message and outbox insert roll back together on error', () async {
    final now = DateTime.utc(2026, 10, 19);
    final existingCommand = _command('outbox-1', now);
    await database.into(database.outboxCommands).insert(existingCommand);

    final message = LocalMessagesCompanion.insert(
      localId: 'local-rollback',
      conversationId: 'conversation-1',
      clientMessageId: 'client-rollback',
      senderKind: 'user',
      bodyText: const Value('body'),
      messageKind: 'text',
      clientCreatedAt: now,
    );

    await expectLater(
      database.outboxDao.enqueueMessage(message, _command('outbox-1', now)),
      throwsA(isA<SqliteException>()),
    );

    expect(await database.messageDao.getAll(), isEmpty);
    expect(await database.outboxDao.getAll(), hasLength(1));
  });

  test('canonical attachment merge preserves private local file URI', () async {
    await database
        .into(database.localAttachments)
        .insert(
          LocalAttachmentsCompanion.insert(
            localId: 'local-attachment-1',
            conversationId: 'conversation-1',
            clientMessageId: 'client-message-1',
            localFileUri: const Value('file:///private/copied-image.png'),
            uploadState: const Value('uploading'),
            contentType: 'image/png',
            sha256: 'local-sha',
          ),
        );

    await database.attachmentDao.upsertCanonical(
      LocalAttachmentsCompanion.insert(
        localId: 'ignored-by-merge',
        attachmentId: const Value('server-attachment-1'),
        conversationId: 'conversation-1',
        clientMessageId: 'client-message-1',
        contentType: 'image/png',
        sha256: 'canonical-sha',
      ),
      localId: 'local-attachment-1',
    );

    final row = await database.select(database.localAttachments).getSingle();
    expect(row.attachmentId, 'server-attachment-1');
    expect(row.sha256, 'canonical-sha');
    expect(row.localFileUri, 'file:///private/copied-image.png');
    expect(row.uploadState, 'uploading');
  });

  test('logout purge removes chat data without invoking recovery', () async {
    final now = DateTime.utc(2026, 10, 19);
    await database
        .into(database.localConversations)
        .insert(
          LocalConversationsCompanion.insert(
            id: 'conversation-1',
            serverCreatedAt: now,
            serverUpdatedAt: now,
            lastSyncedAt: now,
          ),
        );
    await database
        .into(database.outboxCommands)
        .insert(_command('outbox-1', now));

    await database.purgeChatData();

    expect(await database.select(database.localConversations).get(), isEmpty);
    expect(await database.select(database.localMessages).get(), isEmpty);
    expect(await database.select(database.localAttachments).get(), isEmpty);
    expect(await database.select(database.outboxCommands).get(), isEmpty);
  });

  test(
    'corruption recreation only runs through the explicit recovery seam',
    () async {
      var deletionCount = 0;
      final recovery = ConfirmedCorruptionRecovery(
        deleteCorruptedStore: () async {
          deletionCount += 1;
        },
        openFreshExecutor: NativeDatabase.memory,
      );

      await database.purgeChatData();
      expect(deletionCount, 0);

      await database.close();
      final recreated = await recovery.recreateAfterConfirmedCorruption();
      addTearDown(recreated.close);
      expect(deletionCount, 1);
      expect(recreated.schemaVersion, 1);
    },
  );
}

OutboxCommandsCompanion _command(String id, DateTime now) =>
    OutboxCommandsCompanion.insert(
      id: id,
      commandType: 'send_message',
      aggregateId: 'conversation-1',
      clientRequestId: 'client-request-1',
      payloadJson: '{}',
      nextAttemptAt: now,
      createdAt: now,
      updatedAt: now,
    );
