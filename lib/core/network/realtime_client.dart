/// Opaque local identity for one Realtime subscription attempt.
///
/// This value is not a server request ID and must not encode a user, topic, or
/// conversation identifier.
final class RealtimeAttemptId {
  const RealtimeAttemptId(this.value) : assert(value >= 0);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is RealtimeAttemptId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'RealtimeAttemptId($value)';
}

/// Local conversation/session generation used only for stale callback fences.
final class RealtimeConversationGeneration {
  const RealtimeConversationGeneration(this.value) : assert(value >= 0);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is RealtimeConversationGeneration && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'RealtimeConversationGeneration($value)';
}

/// Immutable local handle returned by a future Realtime adapter.
///
/// Handle equality is deliberately object identity. A structurally identical
/// handle created by another source/port is not owned by this source.
///
/// [conversationId] remains an internal routing value. [toString] deliberately
/// omits it so diagnostics cannot accidentally expose a raw conversation ID.
final class RealtimeSubscriptionHandle {
  RealtimeSubscriptionHandle({
    required this.attemptId,
    required this.generation,
    required this.conversationId,
  });

  final RealtimeAttemptId attemptId;
  final RealtimeConversationGeneration generation;
  final String conversationId;

  @override
  String toString() => 'RealtimeSubscriptionHandle($attemptId, $generation)';
}

/// Typed local channel observations. These are not a Supabase SDK contract.
enum RealtimeChannelStatus {
  joining,
  subscribed,
  timedOut,
  channelError,
  closed,
}

enum RealtimeHandleDisposition {
  pending,
  trusted,
  closing,
  closed,
  quarantined,
}

enum RealtimeQuarantineReason {
  superseded,
  conversationChanged,
  sessionRevoked,
  disposed,
  staleSubscribeCompletion,
  invalidHandle,
  channelTerminated,
  unsubscribeUncertain,
}

/// Observation of a local unsubscribe call.
///
/// Even [completed] is not a claim that an unapproved SDK physically removed a
/// server channel. [uncertain] is fail-closed and remains quarantined.
enum RealtimeUnsubscribeObservation { completed, uncertain }

sealed class RealtimePortEvent {
  const RealtimePortEvent(this.handle);

  final RealtimeSubscriptionHandle handle;
}

final class RealtimeStatusEvent extends RealtimePortEvent {
  const RealtimeStatusEvent(super.handle, this.status);

  final RealtimeChannelStatus status;
}

/// Already-typed fake event. This is deliberately not a wire envelope.
final class RealtimeMessageCreatedEvent extends RealtimePortEvent {
  const RealtimeMessageCreatedEvent(
    super.handle, {
    required this.eventId,
    required this.conversationId,
    required this.sequence,
  });

  final String eventId;
  final String conversationId;
  final int sequence;
}

/// Stable local invalid-event marker without raw callback payload or error.
final class RealtimeInvalidEvent extends RealtimePortEvent {
  const RealtimeInvalidEvent(super.handle, {required this.code});

  final String code;
}

/// Read-only seam for a future Realtime adapter.
///
/// It intentionally has no Broadcast send/write method, topic builder, SDK
/// type, timeout, retry, Auth, or wire decoder. Those remain unapproved.
abstract interface class RealtimeReadPort {
  Future<RealtimeSubscriptionHandle> subscribe(
    String conversationId,
    RealtimeConversationGeneration generation,
  );

  Stream<RealtimePortEvent> events(RealtimeSubscriptionHandle handle);

  Future<RealtimeUnsubscribeObservation> unsubscribe(
    RealtimeSubscriptionHandle handle,
  );

  void quarantine(
    RealtimeSubscriptionHandle handle,
    RealtimeQuarantineReason reason,
  );
}
