import 'package:flutter/widgets.dart';

/// Lifecycle seam for later session, realtime, and outbox coordination.
///
/// CHAT-006 intentionally performs no provider or data-layer work here.
class TimeFitLifecycleObserver with WidgetsBindingObserver {
  const TimeFitLifecycleObserver();
}
