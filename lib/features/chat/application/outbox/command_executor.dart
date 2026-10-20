/// Local command envelope; payload is opaque until the remote contract is ready.
final class OutboxExecutionCommand {
  const OutboxExecutionCommand({
    required this.id,
    required this.clientRequestId,
    required this.commandType,
    required this.aggregateId,
    required this.payloadJson,
    this.leaseToken,
  });
  final String id;
  final String clientRequestId;
  final String commandType;
  final String aggregateId;
  final String payloadJson;
  final String? leaseToken;
}

enum ExecutionDisposition {
  completed,
  retryable,
  permanent,
  authRequired,

  /// A local prerequisite is incomplete. The command remains scheduled but
  /// this observation does not consume the remote failure budget.
  deferred,
}

final class CommandExecutionResult {
  const CommandExecutionResult(this.disposition, {this.errorCode});
  final ExecutionDisposition disposition;

  /// Stable, redacted code only. Never include a raw server response.
  final String? errorCode;
}

abstract interface class CommandExecutor {
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command);
}
