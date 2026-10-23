import 'dart:async';

import 'package:flutter/foundation.dart';

import 'send_message.dart';

final class ComposerController extends ChangeNotifier {
  ComposerController({
    required this.conversationId,
    required TextMessageSubmitter submitter,
    this.attachmentClientMessageId,
    AttachmentComposerSource? attachmentSource,
  }) : _submitter = submitter,
       _attachmentSource = attachmentSource {
    if ((attachmentClientMessageId == null) != (attachmentSource == null)) {
      throw ArgumentError(
        'attachmentClientMessageId and attachmentSource must be paired',
      );
    }
    if (attachmentSource != null) {
      _attachmentSubscription = attachmentSource
          .watch(
            conversationId: conversationId,
            clientMessageId: attachmentClientMessageId!,
          )
          .listen(
            (items) {
              if (_disposed || _aggregateSubmitted) return;
              _attachments = List.unmodifiable(items);
              _attachmentsLoaded = true;
              _lastError = null;
              _notify();
            },
            onError: (Object error) {
              if (_disposed) return;
              _attachmentsLoaded = false;
              _lastError = error;
              _notify();
            },
          );
    }
  }

  static const int counterThreshold = 10000;
  static const int maximumLength = 12000;

  final String conversationId;
  final TextMessageSubmitter _submitter;
  final String? attachmentClientMessageId;
  final AttachmentComposerSource? _attachmentSource;
  StreamSubscription<List<ComposerAttachment>>? _attachmentSubscription;

  String _draft = '';
  int _draftVersion = 0;
  Future<void>? _activeSubmit;
  final Map<String, Future<bool>> _activeRetries = <String, Future<bool>>{};
  Object? _lastError;
  bool _disposed = false;
  bool _attachmentsLoaded = false;
  bool _aggregateSubmitted = false;
  List<ComposerAttachment> _attachments = const <ComposerAttachment>[];

  String get draft => _draft;
  static int characterCountOf(String value) => normalizedLocalTextLength(value);
  static String truncateDraft(String value) =>
      truncateLocalTextBody(value, maximumLength);

  int get characterCount => characterCountOf(_draft);
  bool get showCounter => characterCount >= counterThreshold;
  bool get isSubmitting => _activeSubmit != null;
  Object? get lastError => _lastError;
  List<ComposerAttachment> get attachments => _attachments;
  bool get hasFailedAttachment => attachments.any(
    (attachment) => attachment.state == ComposerAttachmentState.failed,
  );
  bool get canSubmit =>
      conversationId.isNotEmpty &&
      characterCount <= maximumLength &&
      !_aggregateSubmitted &&
      !(_attachmentSource is AttachmentDraftMutationState &&
          (_attachmentSource as AttachmentDraftMutationState)
              .isAttachmentDraftMutating(attachmentClientMessageId!)) &&
      (attachmentClientMessageId == null || _attachmentsLoaded) &&
      !hasFailedAttachment &&
      (normalizeLocalTextBody(_draft).trim().isNotEmpty ||
          attachments.isNotEmpty);

  void updateDraft(String value) {
    if (_draft == value) return;
    _draft = value;
    _draftVersion += 1;
    _lastError = null;
    _notify();
  }

  Future<void> submit() {
    if (_activeSubmit case final Future<void> active) return active;
    if (!canSubmit) return Future<void>.value();

    final String submittedDraft = _draft;
    final int submittedVersion = _draftVersion;
    final bool submittedWithAttachments = attachments.isNotEmpty;
    _lastError = null;

    late final Future<void> operation;
    operation =
        Future<Object>.sync(() {
              if (attachments.isEmpty) {
                return _submitter.submit(
                  conversationId: conversationId,
                  bodyText: submittedDraft,
                );
              }
              final submitter = _submitter;
              if (submitter is! AttachmentMessageSubmitter) {
                throw StateError('Attachment submission is unavailable');
              }
              return (submitter as AttachmentMessageSubmitter)
                  .submitWithAttachments(
                    clientMessageId: attachmentClientMessageId!,
                    conversationId: conversationId,
                    bodyText: submittedDraft,
                    localAttachmentIds: attachments
                        .map((attachment) => attachment.localId)
                        .toList(growable: false),
                  );
            })
            .then<void>(
              (_) {
                if (_draftVersion == submittedVersion &&
                    _draft == submittedDraft) {
                  _draft = '';
                  _draftVersion += 1;
                }
                if (submittedWithAttachments) {
                  _aggregateSubmitted = true;
                }
              },
              onError: (Object error, StackTrace stack) {
                if (_draftVersion == submittedVersion &&
                    _draft == submittedDraft) {
                  _lastError = error;
                }
                Error.throwWithStackTrace(error, stack);
              },
            )
            .whenComplete(() {
              if (identical(_activeSubmit, operation)) _activeSubmit = null;
              _notify();
            });
    _activeSubmit = operation;
    _notify();
    return operation;
  }

  Future<void> removeFailedAttachment(String localId) async {
    if (_disposed) return;
    final attachment = attachments
        .where((item) => item.localId == localId)
        .firstOrNull;
    if (attachment?.state != ComposerAttachmentState.failed) return;
    await _attachmentSource!.removeFailed(
      conversationId: conversationId,
      clientMessageId: attachmentClientMessageId!,
      localId: localId,
    );
  }

  Future<bool> retry(String clientMessageId) {
    if (_activeRetries[clientMessageId] case final Future<bool> active) {
      return active;
    }
    late final Future<bool> operation;
    operation = Future<bool>.sync(() => _submitter.retry(clientMessageId))
        .whenComplete(() {
          if (identical(_activeRetries[clientMessageId], operation)) {
            _activeRetries.remove(clientMessageId);
          }
        });
    _activeRetries[clientMessageId] = operation;
    return operation;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_attachmentSubscription?.cancel());
    super.dispose();
  }
}

enum ComposerAttachmentState { queued, uploading, failed, ready }

final class ComposerAttachment {
  const ComposerAttachment({
    required this.localId,
    required this.contentType,
    required this.state,
    required this.bytesSent,
    required this.bytesTotal,
  });

  final String localId;
  final String contentType;
  final ComposerAttachmentState state;
  final int bytesSent;
  final int bytesTotal;
}

abstract interface class AttachmentComposerSource {
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  });

  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  });
}

abstract interface class AttachmentDraftMutationState {
  bool isAttachmentDraftMutating(String clientMessageId);
}
