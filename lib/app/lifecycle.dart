import 'dart:async';

import 'package:flutter/widgets.dart';

import '../features/chat/application/chat_connection_coordinator.dart';

/// Thin Flutter observer for an explicitly injected local coordinator.
///
/// The normal app bootstrap does not construct this observer yet. Actual Auth,
/// Realtime, and RPC adapters remain blocked by CHAT-035 and CHAT-036.
class TimeFitLifecycleObserver with WidgetsBindingObserver {
  TimeFitLifecycleObserver({required this.coordinator});

  final ChatConnectionCoordinator coordinator;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(coordinator.handleLifecycleState(state));
  }

  Future<void> logout() => coordinator.logout();

  void dispose() => coordinator.dispose();
}
