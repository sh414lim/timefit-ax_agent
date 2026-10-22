import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/drift_attachment_composer_source.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';

const _conversationId = 'performance-conversation';
const _aggregateId = 'performance-attachment-aggregate';

void main() {
  test('500-message file cache survives close and reopen', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'timefit-performance-regression-',
    );
    final file = File('${sandbox.path}/chat.sqlite');
    final seed = AppDatabase(NativeDatabase(file));
    await _seedMessages(seed);
    await seed.close();

    final database = AppDatabase(NativeDatabase(file));
    final repository = MessageRepositoryImpl(database: database);
    expect(
      await repository.readCachedMessages(_conversationId),
      hasLength(500),
    );
    await repository.dispose();
    await database.close();
    await sandbox.delete(recursive: true);
  });

  test(
    'production Drift source emits all five intermediate progress values',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final session = LocalRepositorySession();
      final source = DriftAttachmentComposerSource(
        database: database,
        clock: DateTime.now,
        session: session,
      );
      await _seedAttachments(database);
      final iterator = StreamIterator<List<ComposerAttachment>>(
        source.watch(
          conversationId: _conversationId,
          clientMessageId: _aggregateId,
        ),
      );

      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, hasLength(5));
      for (var step = 1; step <= 10; step += 1) {
        await (database.update(database.localAttachments)
              ..where((row) => row.clientMessageId.equals(_aggregateId)))
            .write(LocalAttachmentsCompanion(bytesSent: Value(step * 100)));
        expect(
          await iterator.moveNext().timeout(const Duration(seconds: 2)),
          isTrue,
        );
        expect(iterator.current, hasLength(5));
        expect(
          iterator.current.map((attachment) => attachment.bytesSent),
          everyElement(step * 100),
        );
        expect(
          iterator.current.map((attachment) => attachment.state),
          everyElement(ComposerAttachmentState.uploading),
        );
      }

      await iterator.cancel();
      await session.dispose();
      await database.close();
    },
  );
}

Future<void> _seedMessages(AppDatabase database) async {
  final base = DateTime.utc(2026, 10, 22, 12);
  await database.batch((batch) {
    batch.insertAll(database.localMessages, <LocalMessagesCompanion>[
      for (var sequence = 1; sequence <= 500; sequence += 1)
        LocalMessagesCompanion.insert(
          localId: 'performance-message-$sequence',
          serverId: Value('performance-server-$sequence'),
          conversationId: _conversationId,
          clientMessageId: 'performance-client-$sequence',
          sequence: Value(sequence),
          senderKind: sequence.isEven ? 'user' : 'system',
          bodyText: Value(_body(sequence)),
          messageKind: 'text',
          clientCreatedAt: base.add(Duration(seconds: sequence)),
          serverCreatedAt: Value(base.add(Duration(seconds: sequence))),
          deliveryState: const Value('sent'),
        ),
    ]);
  });
}

Future<void> _seedAttachments(AppDatabase database) => database.batch((batch) {
  batch.insertAll(database.localAttachments, <LocalAttachmentsCompanion>[
    for (var index = 1; index <= 5; index += 1)
      LocalAttachmentsCompanion.insert(
        localId: 'performance-attachment-$index',
        conversationId: _conversationId,
        clientMessageId: _aggregateId,
        uploadState: const Value('uploading'),
        bytesTotal: const Value(1000),
        bytesSent: const Value(0),
        contentType: index.isEven ? 'image/png' : 'application/pdf',
        sha256: 'fixture-sha256-$index',
      ),
  ]);
});

String _body(int sequence) =>
    'Performance message $sequence ${'segment ' * ((sequence % 4) + 1)}';
