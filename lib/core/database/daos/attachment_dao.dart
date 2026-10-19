import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_attachments.dart';

part 'attachment_dao.g.dart';

@DriftAccessor(tables: [LocalAttachments])
class AttachmentDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentDaoMixin {
  AttachmentDao(super.attachedDatabase);

  Future<void> upsertCanonical(
    LocalAttachmentsCompanion canonical, {
    required String localId,
  }) async {
    final existing =
        await (select(localAttachments)
              ..where((attachment) => attachment.localId.equals(localId)))
            .getSingleOrNull();
    final merged = canonical.copyWith(
      localId: Value(localId),
      localFileUri: Value(existing?.localFileUri),
      uploadState: existing == null
          ? canonical.uploadState
          : Value(existing.uploadState),
    );
    await into(localAttachments).insertOnConflictUpdate(merged);
  }
}
