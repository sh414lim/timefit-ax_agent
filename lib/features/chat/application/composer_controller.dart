import 'dart:async';

import 'package:flutter/foundation.dart';

import 'send_message.dart';

final class ComposerController extends ChangeNotifier {
  ComposerController({
    required this.conversationId,
    required TextMessageSubmitter submitter,
  }) : _submitter = submitter;

  static const int counterThreshold = 10000;
  static const int maximumLength = 12000;

  final String conversationId;
  final TextMessageSubmitter _submitter;

  String _draft = '';
  int _draftVersion = 0;
  Future<void>? _activeSubmit;
  Object? _lastError;
  bool _disposed = false;

  String get draft => _draft;
  int get characterCount => _draft.runes.length;
  bool get showCounter => characterCount >= counterThreshold;
  bool get isSubmitting => _activeSubmit != null;
  Object? get lastError => _lastError;
  bool get canSubmit =>
      conversationId.isNotEmpty &&
      _draft.trim().isNotEmpty &&
      characterCount <= maximumLength;

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
    _lastError = null;

    late final Future<void> operation;
    operation =
        Future<LocalTextCommand>.sync(
              () => _submitter.submit(
                conversationId: conversationId,
                bodyText: submittedDraft,
              ),
            )
            .then<void>(
              (_) {
                if (_draftVersion == submittedVersion &&
                    _draft == submittedDraft) {
                  _draft = '';
                  _draftVersion += 1;
                }
              },
              onError: (Object error, StackTrace stack) {
                _lastError = error;
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

  Future<bool> retry(String clientMessageId) =>
      _submitter.retry(clientMessageId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
