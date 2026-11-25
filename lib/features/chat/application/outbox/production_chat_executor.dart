import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/message_dao.dart';
import '../../../../core/database/local_repository_session.dart';
import '../../infrastructure/production_chat_transport.dart';
import '../send_message.dart';
import 'command_executor.dart';

/// Explicit composition only. UI startup never constructs this executor.
/// The composition must provide an authenticated, grant-scoped database/session
/// and dispose that session before changing the authenticated user or grant.
final class ProductionChatExecutor implements CommandExecutor {
  ProductionChatExecutor({
    required AppDatabase database,
    required LocalRepositorySession session,
    required this.api,
    required this.scope,
    required this.isCurrentSession,
    required this.clock,
  }) : _database = database,
       _session = session;

  final AppDatabase _database;
  final LocalRepositorySession _session;
  final ProductionChatApi api;
  final ProductionChatScope scope;
  final bool Function() isCurrentSession;
  final DateTime Function() clock;

  static const _dispatchMarker = 'production_dispatch_started';
  static const _unknown = 'production_outcome_unknown';
  static const _pending = 'production_response_pending';
  static const _blockedMarkers = <String>{_dispatchMarker, _unknown, _pending};

  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) async {
    var attempted = false;
    try {
      if (command.commandType != 'local_send_text_v1' ||
          command.id != command.clientRequestId ||
          command.leaseToken == null ||
          command.aggregateId != scope.conversationId) {
        return const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'production_message_invalid',
        );
      }
      requireChatUuid(command.id);
      final payload = LocalTextCommand.decode(command.payloadJson);
      if (payload.id != command.id ||
          payload.conversationId != scope.conversationId ||
          payload.bodyText.trim().isEmpty ||
          payload.bodyText.trim().length > 4096) {
        return const CommandExecutionResult(
          ExecutionDisposition.permanent,
          errorCode: 'production_message_invalid',
        );
      }
      final stored = await _session.read(() => _lease(command));
      if (stored == null) return _deferred('production_lease_inactive');
      attempted = _blockedMarkers.contains(stored.lastErrorCode);
      if (!isCurrentSession()) return _auth(attempted);

      // Every wake, including after process death, resolves the original ID
      // before considering a send. An absent row is never permission to resend
      // a request for which a durable dispatch marker already exists locally.
      var turn = await api.lookup(scope, command.id);
      if (!isCurrentSession()) return _auth(attempted);
      if (turn == null) {
        if (attempted) return _deferred(_unknown);
        await _session.write(_database, () async {
          if (!isCurrentSession() || await _lease(command) == null) {
            throw const LocalRepositoryException(
              LocalRepositoryFailure.sessionClosed,
            );
          }
          await (_database.update(
            _database.outboxCommands,
          )..where((row) => row.id.equals(command.id))).write(
            const OutboxCommandsCompanion(
              lastErrorCode: Value(_dispatchMarker),
            ),
          );
        });
        attempted = true;
        try {
          turn = await api.send(scope, command.id, payload.bodyText);
        } on ProductionChatFailure catch (failure) {
          if (!failure.commandSent) {
            // The transport proved the chat command was never sent. Releasing
            // this marker is safe; a crash before this commit remains closed.
            await _session.write(_database, () async {
              if (await _lease(command) == null) return;
              await (_database.update(
                _database.outboxCommands,
              )..where((row) => row.id.equals(command.id))).write(
                const OutboxCommandsCompanion(lastErrorCode: Value(null)),
              );
            });
            attempted = false;
          }
          rethrow;
        }
      }
      if (turn.requestId != command.id ||
          turn.bodySha256 != productionBodyDigest(payload.bodyText)) {
        return _deferred(_unknown);
      }
      if (!isCurrentSession()) return _auth(true);

      await _session.write(_database, () async {
        if (!isCurrentSession() || await _lease(command) == null) {
          throw const LocalRepositoryException(
            LocalRepositoryFailure.sessionClosed,
          );
        }
        final message = await (_database.select(
          _database.localMessages,
        )..where((row) => row.localId.equals(command.id))).getSingle();
        if (message.clientMessageId != payload.id ||
            message.bodyText != payload.bodyText ||
            message.conversationId != scope.conversationId) {
          throw const CanonicalIdentityConflict('Local command changed');
        }
        final receipt = turn!;
        await _database.messageDao.upsertCanonical(
          CanonicalLocalMessage(
            serverId: command.id,
            conversationId: scope.conversationId,
            clientMessageId: command.id,
            sequence: receipt.sequence * 2 - 1,
            senderKind: 'user',
            bodyText: payload.bodyText,
            messageKind: 'text',
            serverCreatedAt: clock(),
          ),
          fallbackLocalId: command.id,
          fallbackClientCreatedAt: message.clientCreatedAt,
        );
        await (_database.update(_database.localMessages)
              ..where((row) => row.localId.equals(command.id)))
            .write(const LocalMessagesCompanion(deliveryState: Value('sent')));
        if (receipt.state == 'complete') {
          final existing =
              await (_database.select(_database.localMessages)
                    ..where((row) => row.serverId.equals(receipt.assistantId)))
                  .getSingleOrNull();
          if (existing != null && existing.bodyText != receipt.answer) {
            throw const CanonicalIdentityConflict('Assistant body changed');
          }
          await _database.messageDao.upsertCanonical(
            CanonicalLocalMessage(
              serverId: receipt.assistantId,
              conversationId: scope.conversationId,
              clientMessageId: receipt.assistantId,
              sequence: receipt.sequence * 2,
              // Local schema v1 calls every non-user bubble "system". This
              // rendering value grants no provider/system instruction authority.
              senderKind: 'system',
              bodyText: receipt.answer,
              messageKind: 'text',
              serverCreatedAt: clock(),
            ),
            fallbackLocalId: 'production-assistant:${receipt.assistantId}',
            fallbackClientCreatedAt: clock(),
          );
        }
        if (!isCurrentSession() || await _lease(command) == null) {
          throw const LocalRepositoryException(
            LocalRepositoryFailure.sessionClosed,
          );
        }
      });
      return turn.state == 'pending'
          ? _deferred(_pending)
          : CommandExecutionResult(
              ExecutionDisposition.completed,
              errorCode: turn.state == 'dispatch_unknown'
                  ? 'production_dispatch_unknown'
                  : null,
            );
    } on ProductionChatFailure catch (failure) {
      if (failure.code == 'production_auth_required') return _auth(attempted);
      return attempted
          ? _deferred(_unknown)
          : const CommandExecutionResult(
              ExecutionDisposition.retryable,
              errorCode: 'production_transport_unavailable',
            );
    } on Object {
      return attempted
          ? _deferred(_unknown)
          : const CommandExecutionResult(
              ExecutionDisposition.authRequired,
              errorCode: 'production_local_scope_unavailable',
            );
    }
  }

  Future<OutboxCommand?> _lease(OutboxExecutionCommand command) async {
    final row = await (_database.select(
      _database.outboxCommands,
    )..where((row) => row.id.equals(command.id))).getSingleOrNull();
    if (row?.state != 'running' ||
        row?.leaseOwner != command.leaseToken ||
        row?.leaseUntil?.isAfter(clock()) != true ||
        row?.payloadJson != command.payloadJson ||
        row?.clientRequestId != command.id) {
      return null;
    }
    final payload = LocalTextCommand.decode(command.payloadJson);
    final message = await (_database.select(
      _database.localMessages,
    )..where((row) => row.localId.equals(command.id))).getSingleOrNull();
    if (message?.clientMessageId != command.id ||
        message?.conversationId != scope.conversationId ||
        message?.bodyText != payload.bodyText ||
        message?.senderKind != 'user') {
      return null;
    }
    return row;
  }

  CommandExecutionResult _deferred(String code) =>
      CommandExecutionResult(ExecutionDisposition.deferred, errorCode: code);
  CommandExecutionResult _auth(bool attempted) => CommandExecutionResult(
    ExecutionDisposition.authRequired,
    errorCode: attempted ? _unknown : 'production_auth_required',
  );
}
