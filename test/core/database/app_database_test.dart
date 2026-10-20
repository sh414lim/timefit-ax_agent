import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/attachment_dao.dart';
import 'package:timefit_native/core/database/daos/message_dao.dart';
import 'package:timefit_native/core/database/logout_chat_data_purger.dart';
import 'package:timefit_native/core/database/migrations.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('schema v2 creates all local chat tables', () async {
    final tables = await database
        .customSelect(
          "select name from sqlite_master where type = 'table' order by name",
        )
        .map((row) => row.read<String>('name'))
        .get();

    expect(database.schemaVersion, 2);
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

  test(
    'server identity cannot move to another client or conversation',
    () async {
      final now = DateTime.utc(2026, 10, 19);
      await _insertMessage(
        database,
        localId: 'local-1',
        serverId: 'server-1',
        conversationId: 'conversation-1',
        clientMessageId: 'client-1',
        sequence: 1,
        now: now,
      );

      for (final canonical in <CanonicalLocalMessage>[
        _canonical(
          serverId: 'server-1',
          conversationId: 'conversation-1',
          clientMessageId: 'client-2',
          sequence: 2,
          now: now,
        ),
        _canonical(
          serverId: 'server-1',
          conversationId: 'conversation-2',
          clientMessageId: 'client-1',
          sequence: 1,
          now: now,
        ),
      ]) {
        await expectLater(
          database.messageDao.upsertCanonical(
            canonical,
            fallbackLocalId: 'fallback',
            fallbackClientCreatedAt: now,
          ),
          throwsA(isA<CanonicalIdentityConflict>()),
        );
      }

      final rows = await database.messageDao.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.serverId, 'server-1');
      expect(rows.single.conversationId, 'conversation-1');
      expect(rows.single.clientMessageId, 'client-1');
      expect(rows.single.sequence, 1);
    },
  );

  test('partial canonical keys on different rows fail closed', () async {
    final now = DateTime.utc(2026, 10, 19);
    await _insertMessage(
      database,
      localId: 'local-1',
      serverId: 'server-1',
      conversationId: 'conversation-1',
      clientMessageId: 'client-1',
      sequence: 1,
      now: now,
    );
    await _insertMessage(
      database,
      localId: 'local-2',
      serverId: 'server-2',
      conversationId: 'conversation-1',
      clientMessageId: 'client-2',
      sequence: 2,
      now: now,
    );

    await expectLater(
      database.messageDao.upsertCanonical(
        _canonical(
          serverId: 'server-1',
          conversationId: 'conversation-1',
          clientMessageId: 'client-2',
          sequence: 3,
          now: now,
        ),
        fallbackLocalId: 'fallback',
        fallbackClientCreatedAt: now,
      ),
      throwsA(isA<CanonicalIdentityConflict>()),
    );

    final rows = await database.messageDao.getAll();
    expect(rows.map((row) => row.bodyText), everyElement('original'));
    expect(rows.map((row) => row.localId), containsAll(['local-1', 'local-2']));
  });

  test('identity rejection rolls back surrounding writes', () async {
    final now = DateTime.utc(2026, 10, 19);
    await _insertMessage(
      database,
      localId: 'original',
      serverId: 'server-original',
      conversationId: 'conversation-original',
      clientMessageId: 'client-original',
      sequence: 1,
      now: now,
    );
    await expectLater(
      database.transaction(() async {
        await database
            .into(database.outboxCommands)
            .insert(_command('rolled-back', now));
        await database.messageDao.upsertCanonical(
          _canonical(
            serverId: 'server-original',
            conversationId: 'another-conversation',
            clientMessageId: 'another-client',
            sequence: 1,
            now: now,
          ),
          fallbackLocalId: 'fallback',
          fallbackClientCreatedAt: now,
        );
      }),
      throwsA(isA<CanonicalIdentityConflict>()),
    );
    expect(await database.outboxDao.getAll(), isEmpty);
    final row = (await database.messageDao.getAll()).single;
    expect(row.conversationId, 'conversation-original');
    expect(row.bodyText, 'original');
  });

  test('fallback local id collision fails closed', () async {
    final now = DateTime.utc(2026, 10, 19);
    await database
        .into(database.localMessages)
        .insert(
          LocalMessagesCompanion.insert(
            localId: 'fallback-collision',
            conversationId: 'conversation-existing',
            clientMessageId: 'client-existing',
            senderKind: 'user',
            messageKind: 'text',
            clientCreatedAt: now,
          ),
        );

    await expectLater(
      database.messageDao.upsertCanonical(
        _canonical(
          serverId: 'server-new',
          conversationId: 'conversation-new',
          clientMessageId: 'client-new',
          sequence: 1,
          now: now,
        ),
        fallbackLocalId: 'fallback-collision',
        fallbackClientCreatedAt: now,
      ),
      throwsA(isA<CanonicalIdentityConflict>()),
    );

    final row = await database.messageDao.getAll().then((rows) => rows.single);
    expect(row.serverId, equals(null));
    expect(row.conversationId, 'conversation-existing');
    expect(row.clientMessageId, 'client-existing');
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

  test('sequence and kind constraints reject invalid values', () async {
    final now = DateTime.utc(2026, 10, 19);

    for (final invalid in <({int sequence, String sender, String kind})>[
      (sequence: 0, sender: 'user', kind: 'text'),
      (sequence: -1, sender: 'user', kind: 'text'),
      (sequence: 1, sender: 'assistant', kind: 'text'),
      (sequence: 1, sender: 'user', kind: 'unknown'),
    ]) {
      await expectLater(
        database
            .into(database.localMessages)
            .insert(
              LocalMessagesCompanion.insert(
                localId:
                    'invalid-${invalid.sequence}-${invalid.sender}-${invalid.kind}',
                serverId: Value(
                  'server-${invalid.sequence}-${invalid.sender}-${invalid.kind}',
                ),
                conversationId: 'conversation-1',
                clientMessageId:
                    'client-${invalid.sequence}-${invalid.sender}-${invalid.kind}',
                sequence: Value(invalid.sequence),
                senderKind: invalid.sender,
                messageKind: invalid.kind,
                clientCreatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    }
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

  test('attachment local id cannot reassign a private URI', () async {
    await database
        .into(database.localAttachments)
        .insert(
          LocalAttachmentsCompanion.insert(
            localId: 'local-attachment-1',
            conversationId: 'conversation-1',
            clientMessageId: 'client-message-1',
            localFileUri: const Value('file:///private/original.png'),
            contentType: 'image/png',
            sha256: 'original-sha',
          ),
        );

    await expectLater(
      database.attachmentDao.upsertCanonical(
        LocalAttachmentsCompanion.insert(
          localId: 'ignored',
          attachmentId: const Value('server-attachment-1'),
          conversationId: 'conversation-2',
          clientMessageId: 'client-message-2',
          contentType: 'image/png',
          sha256: 'new-sha',
        ),
        localId: 'local-attachment-1',
      ),
      throwsA(isA<AttachmentIdentityConflict>()),
    );

    final row = await database.select(database.localAttachments).getSingle();
    expect(row.conversationId, 'conversation-1');
    expect(row.clientMessageId, 'client-message-1');
    expect(row.localFileUri, 'file:///private/original.png');
    expect(row.attachmentId, equals(null));
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

  test('logout purge deletes private file then all four tables', () async {
    final privateRoot = await Directory.systemTemp.createTemp(
      'timefit-private-',
    );
    addTearDown(() => privateRoot.delete(recursive: true));
    final privateFile = File('${privateRoot.path}/attachment.png');
    await privateFile.writeAsBytes([1, 2, 3]);
    await _populateAllTables(database, privateFile.uri.toString());

    final purger = LogoutChatDataPurger(
      database: database,
      fileStore: IoPrivateAttachmentFileStore(privateRoot),
    );
    await purger.purge();

    expect(await privateFile.exists(), isFalse);
    expect(await database.select(database.localConversations).get(), isEmpty);
    expect(await database.select(database.localMessages).get(), isEmpty);
    expect(await database.select(database.localAttachments).get(), isEmpty);
    expect(await database.select(database.outboxCommands).get(), isEmpty);
  });

  test(
    'outside-root file is not deleted and database remains retryable',
    () async {
      final privateRoot = await Directory.systemTemp.createTemp(
        'timefit-private-',
      );
      final outsideRoot = await Directory.systemTemp.createTemp(
        'timefit-outside-',
      );
      addTearDown(() => privateRoot.delete(recursive: true));
      addTearDown(() => outsideRoot.delete(recursive: true));
      final outsideFile = File('${outsideRoot.path}/do-not-delete.png');
      await outsideFile.writeAsBytes([4, 5, 6]);
      await _populateAllTables(database, outsideFile.uri.toString());

      final purger = LogoutChatDataPurger(
        database: database,
        fileStore: IoPrivateAttachmentFileStore(privateRoot),
      );
      await expectLater(
        purger.purge(),
        throwsA(isA<PrivateFilePurgeException>()),
      );

      expect(await outsideFile.exists(), isTrue);
      expect(
        await database.select(database.localConversations).get(),
        hasLength(1),
      );
      expect(await database.select(database.localMessages).get(), hasLength(1));
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.outboxCommands).get(),
        hasLength(1),
      );
    },
  );

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
      expect(recreated.schemaVersion, 2);
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

CanonicalLocalMessage _canonical({
  required String serverId,
  required String conversationId,
  required String clientMessageId,
  required int sequence,
  required DateTime now,
}) => CanonicalLocalMessage(
  serverId: serverId,
  conversationId: conversationId,
  clientMessageId: clientMessageId,
  sequence: sequence,
  senderKind: 'user',
  bodyText: 'canonical',
  messageKind: 'text',
  serverCreatedAt: now,
);

Future<void> _insertMessage(
  AppDatabase database, {
  required String localId,
  required String serverId,
  required String conversationId,
  required String clientMessageId,
  required int sequence,
  required DateTime now,
}) => database
    .into(database.localMessages)
    .insert(
      LocalMessagesCompanion.insert(
        localId: localId,
        serverId: Value(serverId),
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        sequence: Value(sequence),
        senderKind: 'user',
        bodyText: const Value('original'),
        messageKind: 'text',
        clientCreatedAt: now,
      ),
    );

Future<void> _populateAllTables(AppDatabase database, String fileUri) async {
  final now = DateTime.utc(2026, 10, 19);
  await database
      .into(database.localConversations)
      .insert(
        LocalConversationsCompanion.insert(
          id: 'conversation-purge',
          serverCreatedAt: now,
          serverUpdatedAt: now,
          lastSyncedAt: now,
        ),
      );
  await database
      .into(database.localMessages)
      .insert(
        LocalMessagesCompanion.insert(
          localId: 'message-purge',
          conversationId: 'conversation-purge',
          clientMessageId: 'client-purge',
          senderKind: 'user',
          messageKind: 'attachment',
          clientCreatedAt: now,
        ),
      );
  await database
      .into(database.localAttachments)
      .insert(
        LocalAttachmentsCompanion.insert(
          localId: 'attachment-purge',
          conversationId: 'conversation-purge',
          clientMessageId: 'client-purge',
          localFileUri: Value(fileUri),
          contentType: 'image/png',
          sha256: 'sha',
        ),
      );
  await database
      .into(database.outboxCommands)
      .insert(_command('outbox-purge', now));
}
