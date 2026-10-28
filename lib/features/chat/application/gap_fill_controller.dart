import 'dart:async';

import '../../../core/database/daos/message_dao.dart';

/// Validated domain hint. This is deliberately not a wire decoder or a
/// Broadcast payload model.
final class GapFillHint {
  const GapFillHint({required this.conversationId, required this.sequence});

  final String conversationId;
  final int sequence;
}

abstract interface class GapFillSource {
  /// Loads canonical messages strictly after [request.afterSequence].
  /// Fetching must not mutate local persistence.
  Future<GapFillPage> loadAfter(GapFillRequest request);
}

abstract interface class GapFillPersistence {
  Future<int> readLatestSequence(String conversationId);

  /// Commits the whole accepted page atomically or commits nothing.
  Future<void> persist(
    GapFillRequest request,
    GapFillPage originalPage,
    List<CanonicalLocalMessage> acceptedMessages,
  );
}

final class GapFillRequest {
  GapFillRequest._({required this.conversationId, required this.afterSequence});

  final String conversationId;
  final int afterSequence;
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
}

final class GapFillPage {
  GapFillPage({
    required this.conversationId,
    required List<CanonicalLocalMessage> messages,
    required this.latestSequence,
  }) : messages = List.unmodifiable(messages);

  final String conversationId;
  final List<CanonicalLocalMessage> messages;
  final int latestSequence;
}

enum GapFillFailure { sourceUnavailable, invalidPage, persistenceFailed }

enum GapFillResult { completed, ignored, failed, cancelled }

final class GapFillState {
  const GapFillState({
    required this.conversationId,
    this.isLoading = false,
    this.targetSequence,
    this.latestSequence,
    this.failure,
  });

  final String conversationId;
  final bool isLoading;
  final int? targetSequence;
  final int? latestSequence;
  final GapFillFailure? failure;
}

/// Coalesces Broadcast hints into one after-sequence fetch stream for the
/// active conversation. Hints never become persistence inputs themselves.
final class GapFillController {
  GapFillController({
    required GapFillSource source,
    required GapFillPersistence persistence,
    required String conversationId,
  }) : _source = source,
       _persistence = persistence,
       _state = GapFillState(conversationId: conversationId) {
    if (conversationId.isEmpty) {
      throw ArgumentError.value(conversationId, 'conversationId');
    }
  }

  final GapFillSource _source;
  final GapFillPersistence _persistence;
  final _listeners = <void Function(GapFillState)>{};
  GapFillState _state;
  GapFillState get state => _state;

  bool _disposed = false;
  int _generation = 0;
  int? _targetSequence;
  Object? _runToken;
  GapFillRequest? _request;
  Future<GapFillResult>? _pending;

  void addListener(void Function(GapFillState) listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(void Function(GapFillState) listener) =>
      _listeners.remove(listener);

  Future<GapFillResult> onHint(GapFillHint hint) {
    if (_disposed ||
        hint.conversationId.isEmpty ||
        hint.conversationId != _state.conversationId ||
        hint.sequence <= 0) {
      return Future.value(
        _disposed ? GapFillResult.cancelled : GapFillResult.ignored,
      );
    }
    final previous = _targetSequence;
    if (previous == null || hint.sequence > previous) {
      _targetSequence = hint.sequence;
    }
    return _pending ?? _start();
  }

  Future<GapFillResult> retry() {
    if (_disposed) return Future.value(GapFillResult.cancelled);
    if (_targetSequence == null) return Future.value(GapFillResult.ignored);
    return _pending ?? _start();
  }

  Future<GapFillResult> _start() {
    final token = Object();
    final generation = _generation;
    _runToken = token;
    final future = _drain(token, generation);
    _pending = future;
    return future;
  }

  Future<GapFillResult> _drain(Object token, int generation) async {
    int? requiredProgressBeyond;
    try {
      while (_currentRun(token, generation)) {
        final targetAtReadStart = _targetSequence;
        if (targetAtReadStart == null) return GapFillResult.ignored;

        int afterSequence;
        try {
          afterSequence = await _persistence.readLatestSequence(
            _state.conversationId,
          );
        } on Object {
          if (_currentRun(token, generation)) {
            _error(
              GapFillFailure.persistenceFailed,
              _targetSequence ?? targetAtReadStart,
            );
            return GapFillResult.failed;
          }
          return GapFillResult.cancelled;
        }
        if (!_currentRun(token, generation)) return GapFillResult.cancelled;
        // A higher hint can join while persistence is reading. The read may
        // satisfy the target captured before the await but not the coalesced
        // target. Refresh it before deciding that this drain is complete.
        final target = _targetSequence;
        if (target == null) return GapFillResult.ignored;
        if (afterSequence < 0) {
          _error(GapFillFailure.persistenceFailed, target);
          return GapFillResult.failed;
        }
        if (requiredProgressBeyond case final previousAfter?
            when afterSequence <= previousAfter) {
          _error(
            GapFillFailure.persistenceFailed,
            target,
            latestSequence: afterSequence,
          );
          return GapFillResult.failed;
        }
        requiredProgressBeyond = null;
        if (afterSequence >= target) {
          _emit(
            GapFillState(
              conversationId: _state.conversationId,
              targetSequence: target,
              latestSequence: afterSequence,
            ),
          );
          return GapFillResult.completed;
        }

        final request = GapFillRequest._(
          conversationId: _state.conversationId,
          afterSequence: afterSequence,
        );
        _request = request;
        _emit(
          GapFillState(
            conversationId: request.conversationId,
            isLoading: true,
            targetSequence: target,
            latestSequence: afterSequence,
          ),
        );

        GapFillPage page;
        try {
          page = await _source.loadAfter(request);
        } on Object {
          if (_current(request, token, generation)) {
            _error(
              GapFillFailure.sourceUnavailable,
              target,
              latestSequence: afterSequence,
            );
            return GapFillResult.failed;
          }
          return GapFillResult.cancelled;
        }
        if (!_current(request, token, generation)) {
          return GapFillResult.cancelled;
        }

        late final List<CanonicalLocalMessage> accepted;
        try {
          accepted = _validatePage(request, page);
        } on FormatException {
          _error(
            GapFillFailure.invalidPage,
            target,
            latestSequence: afterSequence,
          );
          return GapFillResult.failed;
        }

        try {
          await _persistence.persist(request, page, accepted);
        } on Object {
          if (_current(request, token, generation)) {
            _error(
              GapFillFailure.persistenceFailed,
              target,
              latestSequence: afterSequence,
            );
            return GapFillResult.failed;
          }
          return GapFillResult.cancelled;
        }
        if (!_current(request, token, generation)) {
          return GapFillResult.cancelled;
        }
        requiredProgressBeyond = request.afterSequence;
        _request = null;
        // Re-read persistence on the next iteration. This incorporates an
        // own-send/RPC race and any larger hint received while this page was
        // in flight instead of trusting either event payload.
      }
      return GapFillResult.cancelled;
    } finally {
      if (identical(_runToken, token)) {
        _request?._cancelled = true;
        _request = null;
        _runToken = null;
        _pending = null;
      }
    }
  }

  List<CanonicalLocalMessage> _validatePage(
    GapFillRequest request,
    GapFillPage page,
  ) {
    if (page.conversationId != request.conversationId ||
        page.latestSequence < request.afterSequence) {
      throw const FormatException('Invalid gap-fill page metadata');
    }
    final bySequence = <int, CanonicalLocalMessage>{};
    final clientSequences = <String, int>{};
    final serverSequences = <String, int>{};
    for (final message in page.messages) {
      if (message.conversationId != request.conversationId ||
          message.serverId.isEmpty ||
          message.clientMessageId.isEmpty ||
          message.sequence <= request.afterSequence ||
          message.sequence > page.latestSequence) {
        throw const FormatException('Invalid canonical gap-fill message');
      }
      final previous = bySequence[message.sequence];
      if (previous != null && !_sameCanonical(previous, message)) {
        throw const FormatException('Conflicting sequence duplicate');
      }
      final clientSequence = clientSequences[message.clientMessageId];
      final serverSequence = serverSequences[message.serverId];
      if ((clientSequence != null && clientSequence != message.sequence) ||
          (serverSequence != null && serverSequence != message.sequence)) {
        throw const FormatException('Conflicting canonical identity');
      }
      bySequence[message.sequence] = message;
      clientSequences[message.clientMessageId] = message.sequence;
      serverSequences[message.serverId] = message.sequence;
    }
    final sorted = bySequence.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final accepted = <CanonicalLocalMessage>[];
    var expected = request.afterSequence + 1;
    for (final message in sorted) {
      if (message.sequence != expected) break;
      accepted.add(message);
      expected += 1;
    }
    if (accepted.isEmpty) {
      throw const FormatException('Gap-fill page made no progress');
    }
    return List.unmodifiable(accepted);
  }

  bool _sameCanonical(
    CanonicalLocalMessage left,
    CanonicalLocalMessage right,
  ) =>
      left.serverId == right.serverId &&
      left.conversationId == right.conversationId &&
      left.clientMessageId == right.clientMessageId &&
      left.sequence == right.sequence &&
      left.senderKind == right.senderKind &&
      left.bodyText == right.bodyText &&
      left.messageKind == right.messageKind &&
      left.serverCreatedAt == right.serverCreatedAt;

  bool _currentRun(Object token, int generation) =>
      !_disposed && generation == _generation && identical(_runToken, token);

  bool _current(GapFillRequest request, Object token, int generation) =>
      _currentRun(token, generation) &&
      !request.isCancelled &&
      identical(_request, request);

  void _error(GapFillFailure failure, int target, {int? latestSequence}) =>
      _emit(
        GapFillState(
          conversationId: _state.conversationId,
          targetSequence: target,
          latestSequence: latestSequence,
          failure: failure,
        ),
      );

  void _emit(GapFillState state) {
    _state = state;
    for (final listener in _listeners.toList()) {
      if (!_disposed) listener(state);
    }
  }

  void switchConversation(String conversationId) {
    if (_disposed) return;
    if (conversationId.isEmpty) {
      throw ArgumentError.value(conversationId, 'conversationId');
    }
    _generation += 1;
    _request?._cancelled = true;
    _request = null;
    _runToken = null;
    _pending = null;
    _targetSequence = null;
    _emit(GapFillState(conversationId: conversationId));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _request?._cancelled = true;
    _request = null;
    _runToken = null;
    _pending = null;
    _targetSequence = null;
    _listeners.clear();
  }
}
