/// Local command envelope; payload is opaque until the remote contract is ready.
final class OutboxExecutionCommand {
  const OutboxExecutionCommand({
    required this.id,
    required this.clientRequestId,
    required this.commandType,
    required this.aggregateId,
    required this.payloadJson,
  });
  final String id;
  final String clientRequestId;
  final String commandType;
  final String aggregateId;
  final String payloadJson;
}

enum ExecutionDisposition { completed, retryable, permanent, authRequired }

final class CommandExecutionResult {
  const CommandExecutionResult(this.disposition, {this.errorCode});
  final ExecutionDisposition disposition;

  /// Stable, redacted code only. Never include a raw server response.
  final String? errorCode;
}

abstract interface class CommandExecutor {
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command);
}
