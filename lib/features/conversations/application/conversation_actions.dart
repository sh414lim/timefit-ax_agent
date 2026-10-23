import 'dart:async';

abstract interface class ConversationActionsRepository {
  Future<void> renameConversation(String conversationId, String? title);

  Future<void> archiveConversation(String conversationId);
}

enum ConversationTitleFailure { tooLong }

final class ConversationTitleException implements Exception {
  const ConversationTitleException(this.failure);

  final ConversationTitleFailure failure;
}

abstract final class ConversationTitle {
  static const int maximumCharacters = 120;

  static String? normalize(String value) {
    final String trimmed = value.trim();
    if (trimmed.runes.length > maximumCharacters) {
      throw const ConversationTitleException(ConversationTitleFailure.tooLong);
    }
    return trimmed.isEmpty ? null : trimmed;
  }
}

class ConversationActionsState {
  const ConversationActionsState({
    this.busyConversationIds = const <String>{},
    this.errorMessage,
  });

  final Set<String> busyConversationIds;
  final String? errorMessage;

  bool isBusy(String conversationId) =>
      busyConversationIds.contains(conversationId);
}

typedef ConversationActionsListener =
    void Function(ConversationActionsState state);

/// Serializes mutations per conversation without treating local completion as
/// a remote or server acknowledgement.
final class ConversationActions {
  ConversationActions({required ConversationActionsRepository repository})
    : _repository = repository;

  final ConversationActionsRepository _repository;
  final Set<ConversationActionsListener> _listeners =
      <ConversationActionsListener>{};
  final Set<String> _busyConversationIds = <String>{};
  ConversationActionsState _state = const ConversationActionsState();
  bool _disposed = false;

  ConversationActionsState get state => _state;

  void addListener(ConversationActionsListener listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(ConversationActionsListener listener) {
    _listeners.remove(listener);
  }

  Future<bool> rename(String conversationId, String rawTitle) async {
    String? title;
    try {
      title = ConversationTitle.normalize(rawTitle);
    } on ConversationTitleException {
      _emit(errorMessage: '제목은 120자 이하로 입력해 주세요.');
      return false;
    }
    return _run(
      conversationId,
      () => _repository.renameConversation(conversationId, title),
      failureMessage: '대화 이름을 변경하지 못했습니다.',
    );
  }

  Future<bool> archive(String conversationId) => _run(
    conversationId,
    () => _repository.archiveConversation(conversationId),
    failureMessage: '대화를 보관하지 못했습니다.',
  );

  Future<bool> _run(
    String conversationId,
    Future<void> Function() operation, {
    required String failureMessage,
  }) async {
    if (_disposed || !_busyConversationIds.add(conversationId)) return false;
    _emit();
    try {
      await operation();
      if (!_disposed) _emit();
      return true;
    } on Object {
      if (!_disposed) _emit(errorMessage: failureMessage);
      return false;
    } finally {
      _busyConversationIds.remove(conversationId);
      if (!_disposed) _emit(keepError: true);
    }
  }

  void clearError() {
    if (_state.errorMessage != null) _emit();
  }

  void _emit({String? errorMessage, bool keepError = false}) {
    if (_disposed) return;
    _state = ConversationActionsState(
      busyConversationIds: Set<String>.unmodifiable(_busyConversationIds),
      errorMessage: keepError ? _state.errorMessage : errorMessage,
    );
    for (final ConversationActionsListener listener in _listeners.toList()) {
      listener(_state);
    }
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}
