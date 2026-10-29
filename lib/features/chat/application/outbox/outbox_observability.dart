import '../../../../core/observability/app_logger.dart';
import '../../../../core/observability/redaction.dart';

/// Local-only observation seam for persisted Outbox work.
///
/// Implementations must not receive command payloads, conversation IDs, file
/// names, or exception objects. The worker also treats every callback as
/// best-effort so observation can never change delivery state.
abstract interface class OutboxObservability {
  Future<void> recordClaimAge({
    required String clientMessageId,
    required Duration age,
  });

  Future<void> recordCompletedSend({
    required String clientMessageId,
    required Duration latency,
  });
}

final class NoOpOutboxObservability implements OutboxObservability {
  const NoOpOutboxObservability();

  @override
  Future<void> recordClaimAge({
    required String clientMessageId,
    required Duration age,
  }) async {}

  @override
  Future<void> recordCompletedSend({
    required String clientMessageId,
    required Duration latency,
  }) async {}
}

/// Adapts the Outbox seam to CHAT-071's typed, allowlisted local logger.
///
/// Correlation IDs that do not satisfy the approved local UUID/test-fixture
/// shape are dropped by this adapter rather than being exported or affecting
/// Outbox execution.
final class AppLoggerOutboxObservability implements OutboxObservability {
  const AppLoggerOutboxObservability(this._logger);

  final AppLogger _logger;

  @override
  Future<void> recordClaimAge({
    required String clientMessageId,
    required Duration age,
  }) async {
    try {
      final id = ClientMessageId.tryForExport(clientMessageId);
      if (id == null) return;
      await _logger.metric(OutboxAgeMetric(age: age, clientMessageId: id));
    } on Object {
      // Invalid correlation IDs and sink failures have no product fallback.
    }
  }

  @override
  Future<void> recordCompletedSend({
    required String clientMessageId,
    required Duration latency,
  }) async {
    try {
      final id = ClientMessageId.tryForExport(clientMessageId);
      if (id == null) return;
      await _logger.metric(
        SendLatencyMetric(latency: latency, clientMessageId: id),
      );
    } on Object {
      // Invalid correlation IDs and sink failures have no product fallback.
    }
  }
}
