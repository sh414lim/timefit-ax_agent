import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/local_repository_session.dart';
import '../application/select_attachments.dart';
import '../domain/attachment_policy.dart';
import 'local_attachment_store.dart';

/// Persists picker output as a local composer draft. It deliberately creates
/// no upload command, server attachment identity, or remote-ready state.
final class DevLocalAttachmentDrafts {
  DevLocalAttachmentDrafts({
    required AppDatabase database,
    required LocalRepositorySession session,
    required LocalAttachmentStore store,
    String Function()? uuid,
  }) : _database = database,
       _session = session,
       _store = store,
       _select = SelectAttachments(store),
       _uuid = uuid ?? (() => const Uuid().v4());

  final AppDatabase _database;
  final LocalRepositorySession _session;
  final LocalAttachmentStore _store;
  final SelectAttachments _select;
  final String Function() _uuid;

  Future<String?> findDraftClientMessageId(String conversationId) async {
    final List<LocalAttachment> rows =
        await (_database.select(_database.localAttachments)..where(
              (row) =>
                  row.conversationId.equals(conversationId) &
                  row.composerExcluded.equals(false),
            ))
            .get();
    final Set<String> candidates = rows
        .map((row) => row.clientMessageId)
        .toSet();
    for (final String candidate in candidates) {
      final OutboxCommand? submitted = await (_database.select(
        _database.outboxCommands,
      )..where((row) => row.id.equals(candidate))).getSingleOrNull();
      if (submitted == null) return candidate;
    }
    return null;
  }

  String newDraftClientMessageId() => _uuid();

  Future<List<PrivateAttachment>> add({
    required String conversationId,
    required String clientMessageId,
    required List<AttachmentInput>? inputs,
    AttachmentCancellation? cancellation,
  }) => _session.withAttachmentDraftMutation(
    clientMessageId,
    () => _add(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      inputs: inputs,
      cancellation: cancellation,
    ),
  );

  Future<List<PrivateAttachment>> _add({
    required String conversationId,
    required String clientMessageId,
    required List<AttachmentInput>? inputs,
    AttachmentCancellation? cancellation,
  }) async {
    await _ensureUnsubmitted(clientMessageId);
    final int existingCount = await _count(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
    );
    final List<PrivateAttachment> copied = await _select.select(
      inputs,
      existingCount: existingCount,
      cancellation: cancellation,
    );
    if (copied.isEmpty) return copied;
    try {
      await _session.write(
        _database,
        () => _database.transaction(() async {
          await _ensureUnsubmitted(clientMessageId);
          final int latestCount = await _count(
            conversationId: conversationId,
            clientMessageId: clientMessageId,
          );
          AttachmentPolicy.count(latestCount + copied.length);
          for (final PrivateAttachment attachment in copied) {
            final String localId = attachment.uri.pathSegments.last;
            await _database
                .into(_database.localAttachments)
                .insert(
                  LocalAttachmentsCompanion.insert(
                    localId: localId,
                    conversationId: conversationId,
                    clientMessageId: clientMessageId,
                    localFileUri: Value(attachment.uri.toString()),
                    displayName: Value(attachment.displayName),
                    uploadState: const Value('queued'),
                    bytesTotal: Value(attachment.bytesTotal),
                    contentType: attachment.contentType,
                    sha256: attachment.sha256,
                  ),
                );
          }
        }),
      );
      return copied;
    } on Object {
      await _cleanupCopies(copied);
      rethrow;
    }
  }

  Future<void> _ensureUnsubmitted(String clientMessageId) async {
    final OutboxCommand? submitted = await (_database.select(
      _database.outboxCommands,
    )..where((row) => row.id.equals(clientMessageId))).getSingleOrNull();
    if (submitted != null) {
      throw StateError('attachment_draft_submitted');
    }
  }

  Future<void> remove({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) => _session.withAttachmentDraftMutation(
    clientMessageId,
    () => _remove(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      localId: localId,
    ),
  );

  Future<void> _remove({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) async {
    final LocalAttachment? removed = await _session.write(_database, () async {
      final LocalAttachment? row = await (_database.select(
        _database.localAttachments,
      )..where((item) => item.localId.equals(localId))).getSingleOrNull();
      if (row == null ||
          row.conversationId != conversationId ||
          row.clientMessageId != clientMessageId ||
          row.uploadState != 'queued' ||
          row.attachmentId != null ||
          row.localFileUri == null) {
        return null;
      }
      final OutboxCommand? submitted = await (_database.select(
        _database.outboxCommands,
      )..where((item) => item.id.equals(clientMessageId))).getSingleOrNull();
      if (submitted != null) return null;
      final int changed = await (_database.delete(
        _database.localAttachments,
      )..where((item) => item.localId.equals(localId))).go();
      return changed == 1 ? row : null;
    });
    if (removed == null) return;
    try {
      await _store.deletePersisted(Uri.parse(removed.localFileUri!));
    } on Object {
      // Preserve a retryable local reference if filesystem cleanup fails.
      await _session.write(
        _database,
        () => _database
            .into(_database.localAttachments)
            .insert(
              removed.toCompanion(false),
              mode: InsertMode.insertOrIgnore,
            ),
      );
      rethrow;
    }
  }

  Future<int> _count({
    required String conversationId,
    required String clientMessageId,
  }) async {
    final Expression<int> count = _database.localAttachments.localId.count();
    final row =
        await (_database.selectOnly(_database.localAttachments)
              ..addColumns(<Expression<Object>>[count])
              ..where(
                _database.localAttachments.conversationId.equals(
                      conversationId,
                    ) &
                    _database.localAttachments.clientMessageId.equals(
                      clientMessageId,
                    ) &
                    _database.localAttachments.composerExcluded.equals(false),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _cleanupCopies(List<PrivateAttachment> copied) async {
    Object? cleanupError;
    for (final PrivateAttachment attachment in copied.reversed) {
      try {
        await _store.delete(attachment);
      } on Object catch (error) {
        cleanupError ??= error;
      }
    }
    if (cleanupError != null) throw cleanupError;
  }
}
