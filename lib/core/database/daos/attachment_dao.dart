import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_attachments.dart';

part 'attachment_dao.g.dart';

final class AttachmentIdentityConflict implements Exception {
  const AttachmentIdentityConflict(this.reason);

  final String reason;

  @override
  String toString() => 'Attachment identity conflict: $reason';
}

@DriftAccessor(tables: [LocalAttachments])
class AttachmentDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentDaoMixin {
  AttachmentDao(super.attachedDatabase);

  Future<void> upsertCanonical(
    LocalAttachmentsCompanion canonical, {
    required String localId,
  }) => transaction(() async {
    final existing =
        await (select(localAttachments)
              ..where((attachment) => attachment.localId.equals(localId)))
            .getSingleOrNull();
    final incomingConversationId = canonical.conversationId.value;
    final incomingClientMessageId = canonical.clientMessageId.value;
    if (existing != null &&
        (existing.conversationId != incomingConversationId ||
            existing.clientMessageId != incomingClientMessageId)) {
      throw const AttachmentIdentityConflict(
        'local id belongs to another conversation or client message',
      );
    }
    final incomingAttachmentId = canonical.attachmentId.value;
    if (existing?.attachmentId != null &&
        existing!.attachmentId != incomingAttachmentId) {
      throw const AttachmentIdentityConflict(
        'canonical input would rewrite the server attachment identity',
      );
    }
    if (incomingAttachmentId != null) {
      final serverMatch =
          await (select(localAttachments)..where(
                (attachment) =>
                    attachment.attachmentId.equals(incomingAttachmentId),
              ))
              .getSingleOrNull();
      if (serverMatch != null && serverMatch.localId != localId) {
        throw const AttachmentIdentityConflict(
          'server attachment id belongs to another local row',
        );
      }
    }
    final merged = canonical.copyWith(
      localId: Value(localId),
      localFileUri: Value(existing?.localFileUri),
      uploadState: existing == null
          ? canonical.uploadState
          : Value(existing.uploadState),
    );
    await into(localAttachments).insertOnConflictUpdate(merged);
  });

  Future<List<String>> privateFileUris() async {
    final rows =
        await (selectOnly(localAttachments)
              ..addColumns([localAttachments.localFileUri])
              ..where(localAttachments.localFileUri.isNotNull()))
            .get();
    return rows
        .map((row) => row.read(localAttachments.localFileUri))
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }
}
