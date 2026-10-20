import '../domain/attachment_policy.dart';

final class AttachmentSelectionException implements Exception {
  const AttachmentSelectionException(this.cause, this.residualAttachments);
  final Object cause;
  final List<PrivateAttachment> residualAttachments;
}

final class SelectAttachments {
  const SelectAttachments(this.store);
  final AttachmentStore store;

  /// null means picker cancellation. Existing composer attachments count toward
  /// the five-file limit. No source is read before the batch count is checked.
  Future<List<PrivateAttachment>> select(
    List<AttachmentInput>? inputs, {
    int existingCount = 0,
    AttachmentCancellation? cancellation,
  }) async {
    if (inputs == null || inputs.isEmpty) return const [];
    if (existingCount < 0)
      throw const AttachmentException(AttachmentFailure.invalidCount);
    AttachmentPolicy.count(existingCount + inputs.length);
    final token = cancellation ?? AttachmentCancellation();
    final copied = <PrivateAttachment>[];
    try {
      for (final input in inputs) {
        token.check();
        copied.add(await store.copy(input, token));
      }
      token.check();
      return List.unmodifiable(copied);
    } on Object catch (error) {
      final residual = <PrivateAttachment>[];
      for (final attachment in copied.reversed) {
        try {
          await store.delete(attachment);
        } on Object {
          residual.add(attachment);
        }
      }
      if (residual.isNotEmpty)
        throw AttachmentSelectionException(error, List.unmodifiable(residual));
      rethrow;
    }
  }
}
