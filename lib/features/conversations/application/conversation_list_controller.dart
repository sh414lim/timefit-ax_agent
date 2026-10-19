import '../domain/conversation_repository.dart';
import '../domain/conversation_summary.dart';

enum ConversationListPhase { loading, empty, ready, stale, error }

class ConversationListState {
  const ConversationListState({
    required this.phase,
    this.conversations = const <ConversationSummary>[],
    this.isRefreshing = false,
    this.isOffline = false,
    this.lastRefreshFailed = false,
  });

  const ConversationListState.loading()
    : this(phase: ConversationListPhase.loading, isRefreshing: true);

  final ConversationListPhase phase;
  final List<ConversationSummary> conversations;
  final bool isRefreshing;
  final bool isOffline;
  final bool lastRefreshFailed;
}

typedef ConversationListListener = void Function(ConversationListState state);

class ConversationListController {
  ConversationListController({required ConversationRepository repository})
    : _repository = repository;

  final ConversationRepository _repository;
  final Set<ConversationListListener> _listeners = <ConversationListListener>{};

  ConversationListState _state = const ConversationListState.loading();
  bool _isDisposed = false;

  ConversationListState get state => _state;

  void addListener(ConversationListListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ConversationListListener listener) {
    _listeners.remove(listener);
  }

  Future<void> load() => _synchronize(showInitialLoading: true);

  Future<void> refresh() => _synchronize(showInitialLoading: false);

  Future<void> _synchronize({required bool showInitialLoading}) async {
    if (showInitialLoading) {
      _emit(const ConversationListState.loading());
    }

    List<ConversationSummary> cached = _state.conversations;
    try {
      cached = _sorted(await _repository.readCachedConversations());
    } on Object {
      // A cache read failure must not prevent a remote recovery attempt.
    }

    if (cached.isNotEmpty) {
      _emit(
        ConversationListState(
          phase: ConversationListPhase.stale,
          conversations: cached,
          isRefreshing: true,
        ),
      );
    } else if (!showInitialLoading) {
      _emit(const ConversationListState.loading());
    }

    try {
      final List<ConversationSummary> refreshed = _sorted(
        await _repository.refreshConversations(),
      );
      _emit(
        refreshed.isEmpty
            ? const ConversationListState(phase: ConversationListPhase.empty)
            : ConversationListState(
                phase: ConversationListPhase.ready,
                conversations: refreshed,
              ),
      );
    } on ConversationRepositoryException catch (error) {
      _emitRefreshFailure(
        cached,
        isOffline: error.kind == ConversationRepositoryFailureKind.offline,
      );
    } on Object {
      _emitRefreshFailure(cached, isOffline: false);
    }
  }

  void _emitRefreshFailure(
    List<ConversationSummary> cached, {
    required bool isOffline,
  }) {
    _emit(
      ConversationListState(
        phase: cached.isEmpty
            ? ConversationListPhase.error
            : ConversationListPhase.stale,
        conversations: cached,
        isOffline: isOffline,
        lastRefreshFailed: true,
      ),
    );
  }

  List<ConversationSummary> _sorted(List<ConversationSummary> source) {
    final List<ConversationSummary> result = List<ConversationSummary>.of(
      source,
    );
    result.sort(
      (ConversationSummary a, ConversationSummary b) =>
          b.updatedAt.compareTo(a.updatedAt),
    );
    return List<ConversationSummary>.unmodifiable(result);
  }

  void _emit(ConversationListState nextState) {
    if (_isDisposed) {
      return;
    }
    _state = nextState;
    for (final ConversationListListener listener in _listeners.toList()) {
      listener(nextState);
    }
  }

  void dispose() {
    _isDisposed = true;
    _listeners.clear();
  }
}
