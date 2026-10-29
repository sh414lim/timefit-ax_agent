import 'dart:async';

import '../../../core/network/realtime_client.dart';
import '../application/gap_fill_controller.dart';

// Process-local, weak identity ownership. The Expando does not retain a raw
// adapter handle after every other reference is gone, but it prevents one
// live handle object from being trusted by two source instances. This is not
// a substitute for an adapter guarantee that every subscribe attempt returns
// one fresh handle object.
final Expando<Object> _rawHandleOwners = Expando<Object>(
  'ChatRealtimeSource raw handle owner',
);

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
  final Object _ownerToken = Object();
  final StreamController<GapFillHint> _hints =
      StreamController<GapFillHint>.broadcast(sync: true);
  final StreamController<RealtimeChannelStatus> _statuses =
      StreamController<RealtimeChannelStatus>.broadcast(sync: true);
  final Map<RealtimeSubscriptionHandle, RealtimeHandleDisposition>
  _dispositions = <RealtimeSubscriptionHandle, RealtimeHandleDisposition>{};
  final Map<RealtimeSubscriptionHandle, StreamSubscription<RealtimePortEvent>>
  _eventSubscriptions =
      <RealtimeSubscriptionHandle, StreamSubscription<RealtimePortEvent>>{};
  final Map<
    RealtimeSubscriptionHandle,
    Completer<StreamSubscription<RealtimePortEvent>?>
  >
  _subscriptionReady =
      <
        RealtimeSubscriptionHandle,
        Completer<StreamSubscription<RealtimePortEvent>?>
      >{};
  final Map<RealtimeSubscriptionHandle, Future<RealtimeUnsubscribeObservation>>
  _unsubscribeFutures =
      <RealtimeSubscriptionHandle, Future<RealtimeUnsubscribeObservation>>{};
  final Set<RealtimeSubscriptionHandle> _portQuarantined =
      <RealtimeSubscriptionHandle>{};
  // Attempt IDs are consumed for the full lifetime of this source instance,
  // across conversation and session generations. They are never reset or
  // reused. A production-wide namespace remains an adapter-contract concern.
  final Map<RealtimeAttemptId, RealtimeSubscriptionHandle> _consumedAttempts =
      <RealtimeAttemptId, RealtimeSubscriptionHandle>{};

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

    // Every attempt ID returned by this port is consumed for this source's
    // lifetime, including handles rejected by ownership or later validation.
    // Otherwise a rejected adapter response could replay its attempt ID on a
    // fresh raw object and become trusted.
    final attemptWasConsumed = _consumedAttempts.containsKey(handle.attemptId);
    if (!attemptWasConsumed) {
      _consumedAttempts[handle.attemptId] = handle;
    }

    // Claim raw identity only after consuming the attempt. A raw object
    // already owned by another source is ambiguous, so this source must not
    // quarantine or unsubscribe it through its port.
    if (!_claimRawHandle(handle)) {
      if (_isCurrentRequest(requestSerial, generation, conversationId)) {
        _emitStatus(RealtimeChannelStatus.channelError);
      }
      return ChatRealtimeSubscribeResult.invalidHandle;
    }

    // Both the opaque handle object and its attempt ID are single-use for the
    // full lifetime of this source. Conversation/session generations do not
    // reset this registry.
    if (_dispositions.containsKey(handle)) {
      // A late result may repeat the exact raw object already accepted by a
      // newer request in this source. It owns no cleanup authority over that
      // newer request, so do not quarantine or unsubscribe the shared object.
      if (!_isCurrentRequest(requestSerial, generation, conversationId)) {
        return ChatRealtimeSubscribeResult.stale;
      }
      _quarantine(handle, RealtimeQuarantineReason.invalidHandle);
      if (_isCurrentRequest(requestSerial, generation, conversationId)) {
        _emitStatus(RealtimeChannelStatus.channelError);
      }
      return ChatRealtimeSubscribeResult.invalidHandle;
    }
    _dispositions[handle] = RealtimeHandleDisposition.pending;
    if (attemptWasConsumed) {
      _quarantine(handle, RealtimeQuarantineReason.invalidHandle);
      if (_isCurrentRequest(requestSerial, generation, conversationId)) {
        _emitStatus(RealtimeChannelStatus.channelError);
      }
      return ChatRealtimeSubscribeResult.invalidHandle;
    }
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
    final subscriptionReady =
        Completer<StreamSubscription<RealtimePortEvent>?>();
    _subscriptionReady[handle] = subscriptionReady;
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
      subscriptionReady.complete(subscription);
      if (_trustedHandle != handle ||
          _dispositions[handle] != RealtimeHandleDisposition.trusted) {
        return _disposed
            ? ChatRealtimeSubscribeResult.disposed
            : ChatRealtimeSubscribeResult.stale;
      }
    } on Object {
      if (!subscriptionReady.isCompleted) subscriptionReady.complete(null);
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
    // Never forward an arbitrary or another source's handle to the port.
    if (!_dispositions.containsKey(handle)) {
      return Future<RealtimeUnsubscribeObservation>.value(
        RealtimeUnsubscribeObservation.uncertain,
      );
    }
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

  bool _claimRawHandle(RealtimeSubscriptionHandle handle) {
    final currentOwner = _rawHandleOwners[handle];
    if (currentOwner != null) return identical(currentOwner, _ownerToken);
    _rawHandleOwners[handle] = _ownerToken;
    return true;
  }

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
      final subscription =
          await (_subscriptionReady[handle]?.future ??
              Future<StreamSubscription<RealtimePortEvent>?>.value(
                _eventSubscriptions[handle],
              ));
      try {
        await subscription?.cancel();
      } on Object {
        observation = RealtimeUnsubscribeObservation.uncertain;
      }
      if (observation == RealtimeUnsubscribeObservation.completed) {
        _eventSubscriptions.remove(handle);
        _subscriptionReady.remove(handle);
        _dispositions[handle] = RealtimeHandleDisposition.closed;
      }
    }
    if (observation != RealtimeUnsubscribeObservation.completed) {
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
