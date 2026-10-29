import 'dart:async';

import '../../../core/network/realtime_client.dart';
import '../application/gap_fill_controller.dart';

enum ChatRealtimeSubscribeResult {
  trusted,
  stale,
  failed,
  invalidHandle,
  disposed,
}

/// Redacted local registry state. It contains no topic or conversation ID.
final class ChatRealtimeDiagnostics {
  const ChatRealtimeDiagnostics({
    required this.generation,
    required this.hasConversation,
    required this.trustedAttemptId,
    required this.knownHandleCount,
    required this.quarantinedHandleCount,
    required this.ignoredCallbackCount,
    required this.emittedHintCount,
    required this.disposed,
  });

  final RealtimeConversationGeneration generation;
  final bool hasConversation;
  final RealtimeAttemptId? trustedAttemptId;
  final int knownHandleCount;
  final int quarantinedHandleCount;
  final int ignoredCallbackCount;
  final int emittedHintCount;
  final bool disposed;
}

/// Local-only trusted-handle registry and fake-event fence for CHAT-036.
///
/// It does not build a topic, decode a wire envelope, talk to Supabase, write
/// persistence, or claim that a `subscribed` observation is a connected app.
final class ChatRealtimeSource {
  ChatRealtimeSource({required RealtimeReadPort port}) : _port = port;

  final RealtimeReadPort _port;
  final StreamController<GapFillHint> _hints =
      StreamController<GapFillHint>.broadcast(sync: true);
  final StreamController<RealtimeChannelStatus> _statuses =
      StreamController<RealtimeChannelStatus>.broadcast(sync: true);
  final Map<RealtimeSubscriptionHandle, RealtimeHandleDisposition>
  _dispositions = <RealtimeSubscriptionHandle, RealtimeHandleDisposition>{};
  final Map<RealtimeSubscriptionHandle, StreamSubscription<RealtimePortEvent>>
  _eventSubscriptions =
      <RealtimeSubscriptionHandle, StreamSubscription<RealtimePortEvent>>{};
  final Map<RealtimeSubscriptionHandle, Future<RealtimeUnsubscribeObservation>>
  _unsubscribeFutures =
      <RealtimeSubscriptionHandle, Future<RealtimeUnsubscribeObservation>>{};
  final Set<RealtimeSubscriptionHandle> _portQuarantined =
      <RealtimeSubscriptionHandle>{};

  String? _conversationId;
  RealtimeSubscriptionHandle? _trustedHandle;
  int _generationValue = 0;
  int _requestSerial = 0;
  int _ignoredCallbackCount = 0;
  int _emittedHintCount = 0;
  bool _disposed = false;

  Stream<GapFillHint> get hints => _hints.stream;
  Stream<RealtimeChannelStatus> get statuses => _statuses.stream;
  RealtimeSubscriptionHandle? get trustedHandle => _trustedHandle;

  ChatRealtimeDiagnostics get diagnostics => ChatRealtimeDiagnostics(
    generation: RealtimeConversationGeneration(_generationValue),
    hasConversation: _conversationId != null,
    trustedAttemptId: _trustedHandle?.attemptId,
    knownHandleCount: _dispositions.length,
    quarantinedHandleCount: _dispositions.values
        .where(
          (RealtimeHandleDisposition disposition) =>
              disposition == RealtimeHandleDisposition.quarantined ||
              disposition == RealtimeHandleDisposition.closing,
        )
        .length,
    ignoredCallbackCount: _ignoredCallbackCount,
    emittedHintCount: _emittedHintCount,
    disposed: _disposed,
  );

  /// Starts a new local attempt. The most recently started attempt wins.
  ///
  /// A conversation change increments the generation. A retry for the same
  /// conversation keeps that generation but still supersedes the old attempt.
  Future<ChatRealtimeSubscribeResult> subscribe(String conversationId) async {
    if (_disposed) return ChatRealtimeSubscribeResult.disposed;
    if (conversationId.isEmpty)
      return ChatRealtimeSubscribeResult.invalidHandle;

    final previousConversation = _conversationId;
    final changedConversation = previousConversation != conversationId;
    if (changedConversation) {
      _generationValue += 1;
      _conversationId = conversationId;
    }
    final generation = RealtimeConversationGeneration(_generationValue);
    final requestSerial = ++_requestSerial;
    final previousTrusted = _trustedHandle;
    if (previousTrusted != null) {
      _quarantine(
        previousTrusted,
        changedConversation
            ? RealtimeQuarantineReason.conversationChanged
            : RealtimeQuarantineReason.superseded,
      );
    }

    late final RealtimeSubscriptionHandle handle;
    try {
      handle = await _port.subscribe(conversationId, generation);
    } on Object {
      if (_isCurrentRequest(requestSerial, generation, conversationId)) {
        _emitStatus(RealtimeChannelStatus.channelError);
        return ChatRealtimeSubscribeResult.failed;
      }
      return ChatRealtimeSubscribeResult.stale;
    }

    // A handle identity belongs to exactly one subscribe attempt. If an
    // adapter reuses it, callbacks and cleanup can no longer be attributed to
    // one generation safely, so every matching observation is quarantined.
    if (_dispositions.containsKey(handle)) {
      _quarantine(handle, RealtimeQuarantineReason.invalidHandle);
      _emitStatus(RealtimeChannelStatus.channelError);
      return ChatRealtimeSubscribeResult.invalidHandle;
    }
    _dispositions[handle] = RealtimeHandleDisposition.pending;
    if (!_isCurrentRequest(requestSerial, generation, conversationId)) {
      _quarantine(handle, RealtimeQuarantineReason.staleSubscribeCompletion);
      return ChatRealtimeSubscribeResult.stale;
    }
    if (handle.generation != generation ||
        handle.conversationId != conversationId) {
      _quarantine(handle, RealtimeQuarantineReason.invalidHandle);
      _emitStatus(RealtimeChannelStatus.channelError);
      return ChatRealtimeSubscribeResult.invalidHandle;
    }

    _trustedHandle = handle;
    _dispositions[handle] = RealtimeHandleDisposition.trusted;
    try {
      final subscription = _port
          .events(handle)
          .listen(
            (RealtimePortEvent event) => _handleEvent(handle, event),
            onError: (Object _, StackTrace __) {
              _handleEvent(
                handle,
                RealtimeStatusEvent(handle, RealtimeChannelStatus.channelError),
              );
            },
            onDone: () {
              _handleEvent(
                handle,
                RealtimeStatusEvent(handle, RealtimeChannelStatus.closed),
              );
            },
          );
      _eventSubscriptions[handle] = subscription;
      if (_trustedHandle != handle ||
          _dispositions[handle] != RealtimeHandleDisposition.trusted) {
        unawaited(subscription.cancel());
        _eventSubscriptions.remove(handle);
        return _disposed
            ? ChatRealtimeSubscribeResult.disposed
            : ChatRealtimeSubscribeResult.stale;
      }
    } on Object {
      _quarantine(handle, RealtimeQuarantineReason.invalidHandle);
      _emitStatus(RealtimeChannelStatus.channelError);
      return ChatRealtimeSubscribeResult.invalidHandle;
    }
    return ChatRealtimeSubscribeResult.trusted;
  }

  /// Immediately fences the current session. Physical cleanup remains a
  /// best-effort observation and is deliberately not assigned a timeout here.
  void revokeSession() {
    if (_disposed) return;
    _generationValue += 1;
    _requestSerial += 1;
    _conversationId = null;
    final trusted = _trustedHandle;
    if (trusted != null) {
      _quarantine(trusted, RealtimeQuarantineReason.sessionRevoked);
    }
  }

  Future<RealtimeUnsubscribeObservation> unsubscribeCurrent() {
    final handle = _trustedHandle;
    if (handle == null) {
      return Future<RealtimeUnsubscribeObservation>.value(
        RealtimeUnsubscribeObservation.completed,
      );
    }
    return unsubscribe(handle);
  }

  /// Handle-scoped and idempotent. Repeated calls share the same Future.
  Future<RealtimeUnsubscribeObservation> unsubscribe(
    RealtimeSubscriptionHandle handle,
  ) {
    _quarantine(handle, RealtimeQuarantineReason.superseded);
    return _unsubscribeFutures[handle]!;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generationValue += 1;
    _requestSerial += 1;
    _conversationId = null;
    final handles = _dispositions.keys.toList(growable: false);
    for (final handle in handles) {
      if (_dispositions[handle] != RealtimeHandleDisposition.closed) {
        _quarantine(handle, RealtimeQuarantineReason.disposed);
      }
    }
    _trustedHandle = null;
    unawaited(_hints.close());
    unawaited(_statuses.close());
  }

  bool _isCurrentRequest(
    int requestSerial,
    RealtimeConversationGeneration generation,
    String conversationId,
  ) =>
      !_disposed &&
      requestSerial == _requestSerial &&
      generation.value == _generationValue &&
      conversationId == _conversationId;

  void _handleEvent(
    RealtimeSubscriptionHandle expectedHandle,
    RealtimePortEvent event,
  ) {
    if (_disposed ||
        event.handle != expectedHandle ||
        expectedHandle != _trustedHandle ||
        _dispositions[expectedHandle] != RealtimeHandleDisposition.trusted ||
        expectedHandle.generation.value != _generationValue ||
        expectedHandle.conversationId != _conversationId) {
      _ignoredCallbackCount += 1;
      return;
    }

    switch (event) {
      case RealtimeStatusEvent(:final status):
        _emitStatus(status);
        if (status == RealtimeChannelStatus.timedOut ||
            status == RealtimeChannelStatus.channelError ||
            status == RealtimeChannelStatus.closed) {
          _quarantine(
            expectedHandle,
            RealtimeQuarantineReason.channelTerminated,
          );
        }
      case RealtimeMessageCreatedEvent(
        :final eventId,
        :final conversationId,
        :final sequence,
      ):
        if (eventId.isEmpty ||
            conversationId != _conversationId ||
            sequence <= 0) {
          _ignoredCallbackCount += 1;
          return;
        }
        _emittedHintCount += 1;
        _hints.add(
          GapFillHint(conversationId: conversationId, sequence: sequence),
        );
      case RealtimeInvalidEvent():
        _ignoredCallbackCount += 1;
    }
  }

  void _emitStatus(RealtimeChannelStatus status) {
    if (!_disposed) _statuses.add(status);
  }

  void _quarantine(
    RealtimeSubscriptionHandle handle,
    RealtimeQuarantineReason reason,
  ) {
    if (_trustedHandle == handle) _trustedHandle = null;
    final disposition = _dispositions[handle];
    if (disposition != RealtimeHandleDisposition.closed) {
      _dispositions[handle] = RealtimeHandleDisposition.quarantined;
    }
    if (_portQuarantined.add(handle)) {
      try {
        _port.quarantine(handle, reason);
      } on Object {
        // Quarantine is already enforced locally; raw adapter errors are not
        // retained or rethrown.
      }
    }
    _unsubscribeFutures.putIfAbsent(handle, () => _unsubscribe(handle));
  }

  Future<RealtimeUnsubscribeObservation> _unsubscribe(
    RealtimeSubscriptionHandle handle,
  ) async {
    if (_dispositions[handle] != RealtimeHandleDisposition.closed) {
      _dispositions[handle] = RealtimeHandleDisposition.closing;
    }
    RealtimeUnsubscribeObservation observation;
    try {
      observation = await _port.unsubscribe(handle);
    } on Object {
      observation = RealtimeUnsubscribeObservation.uncertain;
    }
    if (observation == RealtimeUnsubscribeObservation.completed) {
      _dispositions[handle] = RealtimeHandleDisposition.closed;
      await _eventSubscriptions.remove(handle)?.cancel();
    } else {
      _dispositions[handle] = RealtimeHandleDisposition.quarantined;
      if (_portQuarantined.add(handle)) {
        try {
          _port.quarantine(
            handle,
            RealtimeQuarantineReason.unsubscribeUncertain,
          );
        } on Object {
          // The local fence remains authoritative for this fake seam.
        }
      }
    }
    return observation;
  }
}
