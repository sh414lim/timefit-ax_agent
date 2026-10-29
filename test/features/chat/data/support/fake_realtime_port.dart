import 'dart:async';

import 'package:timefit_native/core/network/realtime_client.dart';

final class PendingRealtimeSubscribe {
  PendingRealtimeSubscribe({required this.handle});

  final RealtimeSubscriptionHandle handle;
  final Completer<RealtimeSubscriptionHandle> completer =
      Completer<RealtimeSubscriptionHandle>();
}

final class FakeRealtimeReadPort implements RealtimeReadPort {
  bool autoCompleteSubscribe = true;
  Object? subscribeError;
  Object? eventsError;
  Object? unsubscribeError;
  RealtimeSubscriptionHandle? nextHandleOverride;
  final List<PendingRealtimeSubscribe> pendingSubscribes =
      <PendingRealtimeSubscribe>[];
  final List<RealtimeSubscriptionHandle> subscribeCalls =
      <RealtimeSubscriptionHandle>[];
  final Map<RealtimeSubscriptionHandle, int> unsubscribeCalls =
      <RealtimeSubscriptionHandle, int>{};
  final List<
    ({RealtimeSubscriptionHandle handle, RealtimeQuarantineReason reason})
  >
  quarantineCalls =
      <
        ({RealtimeSubscriptionHandle handle, RealtimeQuarantineReason reason})
      >[];
  final Map<RealtimeSubscriptionHandle, StreamController<RealtimePortEvent>>
  _controllers =
      <RealtimeSubscriptionHandle, StreamController<RealtimePortEvent>>{};
  final Map<
    RealtimeSubscriptionHandle,
    Completer<RealtimeUnsubscribeObservation>
  >
  unsubscribeGates =
      <RealtimeSubscriptionHandle, Completer<RealtimeUnsubscribeObservation>>{};
  var _attempt = 0;

  @override
  Future<RealtimeSubscriptionHandle> subscribe(
    String conversationId,
    RealtimeConversationGeneration generation,
  ) {
    if (subscribeError case final error?) {
      subscribeError = null;
      return Future<RealtimeSubscriptionHandle>.error(error);
    }
    final generated = RealtimeSubscriptionHandle(
      attemptId: RealtimeAttemptId(++_attempt),
      generation: generation,
      conversationId: conversationId,
    );
    final handle = nextHandleOverride ?? generated;
    nextHandleOverride = null;
    subscribeCalls.add(handle);
    _controllers.putIfAbsent(
      handle,
      () => StreamController<RealtimePortEvent>.broadcast(sync: true),
    );
    if (autoCompleteSubscribe) {
      return Future<RealtimeSubscriptionHandle>.value(handle);
    }
    final pending = PendingRealtimeSubscribe(handle: handle);
    pendingSubscribes.add(pending);
    return pending.completer.future;
  }

  @override
  Stream<RealtimePortEvent> events(RealtimeSubscriptionHandle handle) {
    if (eventsError case final error?) {
      eventsError = null;
      throw error;
    }
    return _controllers[handle]!.stream;
  }

  @override
  Future<RealtimeUnsubscribeObservation> unsubscribe(
    RealtimeSubscriptionHandle handle,
  ) {
    unsubscribeCalls.update(
      handle,
      (int count) => count + 1,
      ifAbsent: () => 1,
    );
    if (unsubscribeError case final error?) {
      unsubscribeError = null;
      return Future<RealtimeUnsubscribeObservation>.error(error);
    }
    final gate = unsubscribeGates[handle];
    return gate?.future ??
        Future<RealtimeUnsubscribeObservation>.value(
          RealtimeUnsubscribeObservation.completed,
        );
  }

  @override
  void quarantine(
    RealtimeSubscriptionHandle handle,
    RealtimeQuarantineReason reason,
  ) {
    quarantineCalls.add((handle: handle, reason: reason));
  }

  void completeSubscribe(int index) {
    final pending = pendingSubscribes[index];
    if (!pending.completer.isCompleted) {
      pending.completer.complete(pending.handle);
    }
  }

  void failSubscribe(int index, Object error) {
    final pending = pendingSubscribes[index];
    if (!pending.completer.isCompleted) pending.completer.completeError(error);
  }

  void emit(RealtimePortEvent event) {
    _controllers[event.handle]!.add(event);
  }

  void emitOn(
    RealtimeSubscriptionHandle streamHandle,
    RealtimePortEvent event,
  ) {
    _controllers[streamHandle]!.add(event);
  }

  void emitStreamError(RealtimeSubscriptionHandle handle, Object error) {
    _controllers[handle]!.addError(error);
  }

  Future<void> closeEvents(RealtimeSubscriptionHandle handle) =>
      _controllers[handle]!.close();

  Future<void> close() async {
    for (final controller in _controllers.values) {
      if (!controller.isClosed) await controller.close();
    }
  }
}
