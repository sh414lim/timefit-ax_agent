import 'dart:async';

import '../domain/chat_message.dart';

/// Local injection port, not an RPC DTO. Fetch must have no persistence side
/// effects: only an accepted result may later be committed through a guarded
/// repository transaction. UI continues to render the repository's Drift stream.
abstract interface class HistoryPageSource {
  Future<HistoryPage> loadBefore(HistoryRequest request);
}

final class HistoryRequest {
  HistoryRequest._(this.conversationId, this.beforeSequence);
  final String conversationId;
  final int beforeSequence;
  int get limit => 50;
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
}

final class HistoryPage {
  HistoryPage({
    required this.conversationId,
    required List<ChatMessage> messages,
    required this.hasMoreBefore,
  }) : messages = List.unmodifiable(messages);
  final String conversationId;
  final List<ChatMessage> messages;
  final bool hasMoreBefore;
}

enum HistoryFailure { sourceUnavailable, invalidPage }

final class HistoryState {
  const HistoryState({
    required this.conversationId,
    required this.beforeSequence,
    this.isLoading = false,
    this.hasMoreBefore = true,
    this.failure,
  });
  final String conversationId;
  final int? beforeSequence;
  final bool isLoading;
  final bool hasMoreBefore;
  final HistoryFailure? failure;
}

final class HistoryController {
  HistoryController({
    required HistoryPageSource source,
    required String conversationId,
    required int? earliestSequence,
  }) : _source = source,
       _state = HistoryState(
         conversationId: conversationId,
         beforeSequence: earliestSequence,
       ) {
    _validateCursor(earliestSequence);
  }
  final HistoryPageSource _source;
  HistoryState _state;
  HistoryState get state => _state;
  final _listeners = <void Function(HistoryState)>{};
  final _identities = <String, int>{};
  final _sequences = <int, String>{};
  HistoryRequest? _request;
  Future<HistoryPage?>? _pending;
  Completer<HistoryPage?>? _completion;
  bool _disposed = false;

  void addListener(void Function(HistoryState) listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(void Function(HistoryState) listener) =>
      _listeners.remove(listener);

  Future<HistoryPage?> onTopDistance(double distance) {
    if (!distance.isFinite || distance > 300 || distance < 0)
      return Future.value();
    return loadMore();
  }

  Future<HistoryPage?> retry() => loadMore();

  /// Concurrent callers get the identical future. Returned pages are data for
  /// the future guarded repository integration, never a direct rendering source.
  Future<HistoryPage?> loadMore() {
    if (_disposed || !_state.hasMoreBefore || _state.beforeSequence == null)
      return Future.value();
    if (_pending != null) return _pending!;
    final request = HistoryRequest._(
      _state.conversationId,
      _state.beforeSequence!,
    );
    _request = request;
    final completer = Completer<HistoryPage?>();
    _completion = completer;
    _pending = completer.future;
    _emit(
      HistoryState(
        conversationId: _state.conversationId,
        beforeSequence: _state.beforeSequence,
        isLoading: true,
        hasMoreBefore: _state.hasMoreBefore,
      ),
    );
    unawaited(_load(request, completer));
    return completer.future;
  }

  Future<void> _load(
    HistoryRequest request,
    Completer<HistoryPage?> completer,
  ) async {
    HistoryPage? accepted;
    try {
      if (!_current(request)) return;
      final page = await _source.loadBefore(request);
      if (!_current(request)) return;
      if (page.conversationId != request.conversationId ||
          page.messages.length > request.limit) {
        throw const FormatException('Invalid local page');
      }
      final ids = Map<String, int>.of(_identities);
      final sequences = Map<int, String>.of(_sequences);
      final unique = <int, ChatMessage>{};
      for (final message in page.messages) {
        final sequence = message.sequence;
        if (sequence == null ||
            sequence <= 0 ||
            sequence > request.beforeSequence ||
            message.clientMessageId.isEmpty ||
            (ids.containsKey(message.clientMessageId) &&
                ids[message.clientMessageId] != sequence) ||
            (sequences.containsKey(sequence) &&
                sequences[sequence] != message.clientMessageId)) {
          throw const FormatException('Invalid page identity or sequence');
        }
        ids[message.clientMessageId] = sequence;
        sequences[sequence] = message.clientMessageId;
        // Tolerate a repeated cursor boundary without exposing it as a prepend.
        if (sequence < request.beforeSequence &&
            !_sequences.containsKey(sequence))
          unique[sequence] = message;
      }
      final messages = unique.values.toList()
        ..sort((a, b) => a.sequence!.compareTo(b.sequence!));
      if (messages.isEmpty && page.hasMoreBefore)
        throw const FormatException('Page makes no progress');
      final next = messages.isEmpty
          ? request.beforeSequence
          : messages.first.sequence!;
      _identities
        ..clear()
        ..addAll(ids);
      _sequences
        ..clear()
        ..addAll(sequences);
      accepted = HistoryPage(
        conversationId: page.conversationId,
        messages: messages,
        hasMoreBefore: page.hasMoreBefore,
      );
      _emit(
        HistoryState(
          conversationId: request.conversationId,
          beforeSequence: next,
          hasMoreBefore: page.hasMoreBefore,
        ),
      );
    } on FormatException {
      if (_current(request)) _error(HistoryFailure.invalidPage);
    } on Object {
      if (_current(request)) _error(HistoryFailure.sourceUnavailable);
    } finally {
      if (identical(_request, request)) {
        _pending = null;
        _request = null;
        _completion = null;
      }
      if (!completer.isCompleted)
        completer.complete(_disposed || request.isCancelled ? null : accepted);
    }
  }

  bool _current(HistoryRequest request) =>
      !_disposed && !request.isCancelled && identical(_request, request);
  void _error(HistoryFailure failure) => _emit(
    HistoryState(
      conversationId: _state.conversationId,
      beforeSequence: _state.beforeSequence,
      hasMoreBefore: _state.hasMoreBefore,
      failure: failure,
    ),
  );
  void _emit(HistoryState state) {
    _state = state;
    for (final listener in _listeners.toList()) {
      if (!_disposed) listener(state);
    }
  }

  void switchConversation({
    required String conversationId,
    required int? earliestSequence,
  }) {
    if (_disposed) return;
    _validateCursor(earliestSequence);
    _request?._cancelled = true;
    if (_completion != null && !_completion!.isCompleted)
      _completion!.complete(null);
    _completion = null;
    _request = null;
    _pending = null;
    _identities.clear();
    _sequences.clear();
    _emit(
      HistoryState(
        conversationId: conversationId,
        beforeSequence: earliestSequence,
      ),
    );
  }

  void dispose() {
    _disposed = true;
    _request?._cancelled = true;
    if (_completion != null && !_completion!.isCompleted)
      _completion!.complete(null);
    _completion = null;
    _request = null;
    _pending = null;
    _listeners.clear();
  }

  static void _validateCursor(int? cursor) {
    if (cursor != null && cursor <= 0)
      throw ArgumentError.value(cursor, 'earliestSequence');
  }

  /// UI may measure these extents around the guarded Drift prepend/layout.
  /// The controller owns no ScrollController or rendering dependencies.
  static double prependAnchorOffset({
    required double previousPixels,
    required double previousMaxExtent,
    required double currentMaxExtent,
  }) {
    if (![
          previousPixels,
          previousMaxExtent,
          currentMaxExtent,
        ].every((v) => v.isFinite) ||
        previousMaxExtent < 0 ||
        currentMaxExtent < 0)
      throw ArgumentError('Invalid scroll geometry');
    return (previousPixels + currentMaxExtent - previousMaxExtent)
        .clamp(0, currentMaxExtent)
        .toDouble();
  }
}
