import '../domain/attachment_policy.dart';

/// Local port shapes only. CHAT-016 owns future RPC/Storage wire adapters.
final class AttachmentUploadInput {
  const AttachmentUploadInput({
    required this.localId,
    required this.conversationId,
    required this.clientMessageId,
    required this.file,
  });
  final String localId;
  final String conversationId;
  final String clientMessageId;
  final PrivateAttachment file;
}

final class PreparedAttachment {
  const PreparedAttachment({
    required this.attachmentId,
    required this.objectPath,
  });
  final String attachmentId;
  final String objectPath;
}

enum AttachmentUploadOutcome { uploaded, alreadyExists }

enum AttachmentVerification { ready, metadataMismatch }

enum AttachmentRemoteFailure { retryable, authRequired, permanent }

final class AttachmentRemoteException implements Exception {
  const AttachmentRemoteException(this.failure);
  final AttachmentRemoteFailure failure;
}

abstract interface class AttachmentRemoteSource {
  Future<PreparedAttachment> prepare(
    AttachmentUploadInput input,
    AttachmentCancellation cancellation,
  );
  Future<AttachmentUploadOutcome> upload(
    AttachmentUploadInput input,
    PreparedAttachment target, {
    required bool replace,
    required AttachmentCancellation cancellation,
    required Future<void> Function(int bytesSent) onProgress,
  });
  Future<AttachmentVerification> finalize(
    AttachmentUploadInput input,
    PreparedAttachment target,
    AttachmentCancellation cancellation,
  );
}
