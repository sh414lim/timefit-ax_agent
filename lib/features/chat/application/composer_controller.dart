import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'send_message.dart';

/// Synchronous, generation-bound permission to start a new local mutation.
///
/// Once a submit, retry, or removal has started, its returned future is allowed
/// to drain through the repository session. Revocation only rejects work that
/// has not crossed this boundary yet.
typedef ComposerMutationAdmission = bool Function();

final class ComposerController extends ChangeNotifier {
  ComposerController({
    required this.conversationId,
    required TextMessageSubmitter submitter,
    this.attachmentClientMessageId,
    AttachmentComposerSource? attachmentSource,
    ComposerMutationAdmission? mutationAdmission,
  }) : _submitter = submitter,
       _attachmentSource = attachmentSource,
       _mutationAdmission = mutationAdmission ?? _allowMutation {
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
      if (attachmentSource is AttachmentDraftMutationEvents) {
        _attachmentMutationSubscription =
            (attachmentSource as AttachmentDraftMutationEvents)
                .watchAttachmentDraftMutating(attachmentClientMessageId!)
                .listen((_) => _notify());
      }
    }
  }

  static const int counterThreshold = 10000;
  static const int maximumLength = 12000;

  final String conversationId;
  final TextMessageSubmitter _submitter;
  final ComposerMutationAdmission _mutationAdmission;
  final String? attachmentClientMessageId;
  final AttachmentComposerSource? _attachmentSource;
  StreamSubscription<List<ComposerAttachment>>? _attachmentSubscription;
  StreamSubscription<bool>? _attachmentMutationSubscription;
  bool _attachmentMutationFallbackScheduled = false;

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
  bool get isAttachmentDraftMutating =>
      _attachmentSource is AttachmentDraftMutationState &&
      (_attachmentSource as AttachmentDraftMutationState)
          .isAttachmentDraftMutating(attachmentClientMessageId!);
  Object? get lastError => _lastError;
  List<ComposerAttachment> get attachments => _attachments;
  bool get hasFailedAttachment => attachments.any(
    (attachment) => attachment.state == ComposerAttachmentState.failed,
  );

  bool _hasMutationAdmission() {
    if (_disposed) return false;
    final allowed = _mutationAdmission();
    // The injected predicate may synchronously dispose this editor itself.
    return allowed && !_disposed;
  }

  bool get canSubmit {
    if (_disposed) return false;
    final bool attachmentDraftMutating = isAttachmentDraftMutating;
    if (attachmentDraftMutating &&
        _attachmentSource is! AttachmentDraftMutationEvents) {
      _scheduleAttachmentMutationFallback();
    }
    return conversationId.isNotEmpty &&
        _hasMutationAdmission() &&
        characterCount <= maximumLength &&
        !_aggregateSubmitted &&
        !attachmentDraftMutating &&
        (attachmentClientMessageId == null || _attachmentsLoaded) &&
        !hasFailedAttachment &&
        (normalizeLocalTextBody(_draft).trim().isNotEmpty ||
            attachments.isNotEmpty);
  }

  void updateDraft(String value) {
    if (_disposed || _draft == value) return;
    _draft = value;
    _draftVersion += 1;
    _lastError = null;
    _notify();
  }

  Future<void> submit() {
    if (_activeSubmit case final Future<void> active) return active;
    if (!_hasMutationAdmission()) return Future<void>.value();
    if (!canSubmit) return Future<void>.value();

    final String submittedDraft = _draft;
    final int submittedVersion = _draftVersion;
    bool submittedWithAttachments = false;
    _lastError = null;

    late final Future<void> operation;
    operation =
        Future<Object>.sync(() {
              final source = _attachmentSource;
              if (source is AttachmentDraftSnapshotSource) {
                return (source as AttachmentDraftSnapshotSource)
                    .withStableAttachmentDraftSnapshot(
                      conversationId: conversationId,
                      clientMessageId: attachmentClientMessageId!,
                      operation: (snapshot) {
                        submittedWithAttachments = snapshot.isNotEmpty;
                        return _submitSnapshot(submittedDraft, snapshot);
                      },
                    );
              }
              submittedWithAttachments = attachments.isNotEmpty;
              return _submitSnapshot(submittedDraft, attachments);
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

  Future<Object> _submitSnapshot(
    String submittedDraft,
    List<ComposerAttachment> snapshot,
  ) {
    if (snapshot.isEmpty) {
      return _submitter.submit(
        conversationId: conversationId,
        bodyText: submittedDraft,
      );
    }
    final submitter = _submitter;
    if (submitter is! AttachmentMessageSubmitter) {
      throw StateError('Attachment submission is unavailable');
    }
    return (submitter as AttachmentMessageSubmitter).submitWithAttachments(
      clientMessageId: attachmentClientMessageId!,
      conversationId: conversationId,
      bodyText: submittedDraft,
      localAttachmentIds: snapshot
          .map((attachment) => attachment.localId)
          .toList(growable: false),
    );
  }

  void _scheduleAttachmentMutationFallback() {
    if (_attachmentMutationFallbackScheduled || _disposed) return;
    _attachmentMutationFallbackScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _attachmentMutationFallbackScheduled = false;
      if (_disposed) return;
      if ((_attachmentSource as AttachmentDraftMutationState)
          .isAttachmentDraftMutating(attachmentClientMessageId!)) {
        _scheduleAttachmentMutationFallback();
        return;
      }
      _notify();
    });
  }

  Future<void> removeFailedAttachment(String localId) async {
    if (!_hasMutationAdmission()) return;
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
    if (!_hasMutationAdmission()) return Future<bool>.value(false);
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

  Future<void> _cancelSubscription<T>(
    StreamSubscription<T>? subscription,
  ) async {
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } on Object {
      // Editor admission is already closed. Cancellation is best effort;
      // never retain, stringify, log or rethrow a raw cleanup error/stack.
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    // Close this editor's admission only. Already admitted operations retain
    // their shared Futures and drain through the repository/session boundary;
    // disposing a conversation editor must not close the shared DB session.
    _disposed = true;
    final attachmentSubscription = _attachmentSubscription;
    final mutationSubscription = _attachmentMutationSubscription;
    _attachmentSubscription = null;
    _attachmentMutationSubscription = null;
    unawaited(_cancelSubscription(attachmentSubscription));
    unawaited(_cancelSubscription(mutationSubscription));
    super.dispose();
  }
}

bool _allowMutation() => true;

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

abstract interface class AttachmentDraftMutationEvents {
  Stream<bool> watchAttachmentDraftMutating(String clientMessageId);
}

abstract interface class AttachmentDraftSnapshotSource {
  Future<T> withStableAttachmentDraftSnapshot<T>({
    required String conversationId,
    required String clientMessageId,
    required Future<T> Function(List<ComposerAttachment> attachments) operation,
  });
}
