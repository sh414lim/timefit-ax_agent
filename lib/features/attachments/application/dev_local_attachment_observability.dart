import '../../../core/observability/observability_boundary.dart';

enum DevLocalPreviewFailure { missing, readFailed, unsupportedType }

/// Typed, local-only observability adapter for the dev attachment flow.
///
/// Callers provide correlation identifiers and stable codes only. File names,
/// paths, URIs, picker payloads, exception text, and stack traces never cross
/// this boundary.
final class DevLocalAttachmentObservability {
  const DevLocalAttachmentObservability({
    required AppLogger logger,
    required CrashReporter crashReporter,
  }) : _logger = logger,
       _crashReporter = crashReporter;

  final AppLogger _logger;
  final CrashReporter _crashReporter;

  void pickerCancelled(String clientMessageId) =>
      _event('attachment_picker_cancelled', clientMessageId: clientMessageId);

  void draftRestored(String clientMessageId) =>
      _event('attachment_draft_restored', clientMessageId: clientMessageId);

  void privateCopyReady({
    required String clientMessageId,
    required String attachmentId,
  }) => _event(
    'attachment_private_copy_ready',
    clientMessageId: clientMessageId,
    attachmentId: attachmentId,
  );

  void privateCopyFailed({
    required Object exception,
    required String clientMessageId,
    required bool persistFailure,
  }) => _failure(
    'attachment_private_copy_failed',
    stableErrorCode: persistFailure
        ? 'private_copy_persist_failed'
        : 'private_copy_failed',
    exception: exception,
    clientMessageId: clientMessageId,
  );

  void cleanupFailed({
    required Object exception,
    required String clientMessageId,
    String? attachmentId,
  }) => _failure(
    'attachment_cleanup_failed',
    stableErrorCode: 'private_copy_cleanup_failed',
    exception: exception,
    clientMessageId: clientMessageId,
    attachmentId: attachmentId,
  );

  void previewReady(String attachmentId) =>
      _event('attachment_local_preview_ready', attachmentId: attachmentId);

  void previewFailed({
    required Object exception,
    required String attachmentId,
    required DevLocalPreviewFailure failure,
  }) => _failure(
    'attachment_local_preview_failed',
    stableErrorCode: switch (failure) {
      DevLocalPreviewFailure.missing => 'local_preview_missing',
      DevLocalPreviewFailure.readFailed => 'local_preview_read_failed',
      DevLocalPreviewFailure.unsupportedType => 'local_preview_unsupported',
    },
    exception: exception,
    attachmentId: attachmentId,
  );

  void _event(
    String eventCode, {
    String? clientMessageId,
    String? attachmentId,
  }) {
    try {
      _logger.record(
        eventCode,
        fields: _fields(
          clientMessageId: clientMessageId,
          attachmentId: attachmentId,
        ),
      );
    } on Object {
      // Observability is non-blocking and has no raw fallback output.
    }
  }

  void _failure(
    String eventCode, {
    required String stableErrorCode,
    required Object exception,
    String? clientMessageId,
    String? attachmentId,
  }) {
    try {
      final Map<String, Object?> fields = _fields(
        clientMessageId: clientMessageId,
        attachmentId: attachmentId,
      );
      _logger.record(
        eventCode,
        level: AppLogLevel.error,
        fields: fields,
        errorCode: ErrorCode(stableErrorCode),
      );
      _crashReporter.record(
        stableErrorCode: stableErrorCode,
        exception: exception,
        fields: fields,
      );
    } on Object {
      // Invalid identifiers and sink/reporter failures must not escape.
    }
  }

  Map<String, Object?> _fields({
    String? clientMessageId,
    String? attachmentId,
  }) => <String, Object?>{
    if (clientMessageId != null)
      'clientMessageId': ClientMessageId(clientMessageId),
    if (attachmentId != null) 'attachmentId': AttachmentId(attachmentId),
  };
}
