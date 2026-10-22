import 'dart:async';

import '../domain/conversation_summary.dart';
import '../domain/repositories/conversation_repository.dart';

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
  ConversationListController({
    required ConversationRepository repository,
    this.localOnly = false,
  }) : _repository = repository;

  // Injected repositories are owned by the session/composition scope. This
  // controller only owns and cancels its subscription.
  final ConversationRepository _repository;
  final bool localOnly;
  final Set<ConversationListListener> _listeners = <ConversationListListener>{};

  ConversationListState _state = const ConversationListState.loading();
  bool _isDisposed = false;
  int _requestEpoch = 0;
  int _cacheRevision = 0;
  StreamSubscription<List<ConversationSummary>>? _cacheSubscription;

  ConversationListState get state => _state;

  void addListener(ConversationListListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ConversationListListener listener) {
    _listeners.remove(listener);
  }

  Future<void> load() async {
    _subscribeToCache();
    await _synchronize(showInitialLoading: true);
  }

  Future<void> refresh() => _synchronize(showInitialLoading: false);

  void _subscribeToCache() {
    if (_cacheSubscription != null ||
        _repository is! LocalConversationRepository) {
      return;
    }
    final LocalConversationRepository localRepository = _repository;
    _cacheSubscription = localRepository.watchCachedConversations().listen(
      (List<ConversationSummary> conversations) {
        _cacheRevision += 1;
        final List<ConversationSummary> sorted = _sorted(conversations);
        _emit(
          sorted.isEmpty
              ? const ConversationListState(phase: ConversationListPhase.empty)
              : ConversationListState(
                  phase: ConversationListPhase.ready,
                  conversations: sorted,
                ),
        );
      },
      onError: (Object _) {
        _cacheRevision += 1;
        _emitRefreshFailure(_state.conversations, isOffline: false);
      },
    );
  }

  Future<void> _synchronize({required bool showInitialLoading}) async {
    final int requestEpoch = ++_requestEpoch;
    final int cacheRevisionAtReadStart = _cacheRevision;
    List<ConversationSummary> retained = _state.conversations;
    if (showInitialLoading) {
      _emit(const ConversationListState.loading());
    }

    try {
      final List<ConversationSummary> cached = _sorted(
        await _repository.readCachedConversations(),
      );
      if (!_isCurrent(requestEpoch)) {
        return;
      }
      // Once the watch has emitted it is the authoritative cache snapshot.
      // A slower point-in-time read must never replace that newer state.
      if (_repository is LocalConversationRepository &&
          _cacheRevision != cacheRevisionAtReadStart) {
        retained = _state.conversations;
      } else if (cached.isNotEmpty) {
        // An empty cache is not proof that the server-side list is empty. Keep
        // the in-memory result until a successful refresh confirms that state.
        retained = cached;
      } else if (localOnly) {
        // With no remote source, an uncontested empty local read is also an
        // authoritative snapshot. A concurrent watch emission is protected
        // by the revision check above.
        retained = cached;
      }
    } on Object {
      // A cache read failure must not prevent a remote recovery attempt.
    }
    if (!_isCurrent(requestEpoch)) {
      return;
    }

    if (localOnly) {
      _emit(
        retained.isEmpty
            ? const ConversationListState(phase: ConversationListPhase.empty)
            : ConversationListState(
                phase: ConversationListPhase.ready,
                conversations: retained,
              ),
      );
      return;
    }

    if (retained.isNotEmpty) {
      _emit(
        ConversationListState(
          phase: ConversationListPhase.stale,
          conversations: retained,
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
      if (!_isCurrent(requestEpoch)) {
        return;
      }
      _emit(
        refreshed.isEmpty
            ? const ConversationListState(phase: ConversationListPhase.empty)
            : ConversationListState(
                phase: ConversationListPhase.ready,
                conversations: refreshed,
              ),
      );
    } on ConversationRepositoryException catch (error) {
      if (!_isCurrent(requestEpoch)) {
        return;
      }
      _emitRefreshFailure(
        retained,
        isOffline: error.kind == ConversationRepositoryFailureKind.offline,
      );
    } on Object {
      if (!_isCurrent(requestEpoch)) {
        return;
      }
      _emitRefreshFailure(retained, isOffline: false);
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
    result.sort((ConversationSummary a, ConversationSummary b) {
      final int updatedAtOrder = b.updatedAt.compareTo(a.updatedAt);
      return updatedAtOrder != 0 ? updatedAtOrder : b.id.compareTo(a.id);
    });
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

  bool _isCurrent(int requestEpoch) {
    return !_isDisposed && requestEpoch == _requestEpoch;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _requestEpoch += 1;
    _listeners.clear();
    await _cacheSubscription?.cancel();
    _cacheSubscription = null;
  }
}
