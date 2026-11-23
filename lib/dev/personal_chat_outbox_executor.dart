import 'dart:async';

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/database/daos/message_dao.dart';
import '../core/database/local_repository_session.dart';
import '../features/chat/application/outbox/command_executor.dart';
import '../features/chat/application/send_message.dart';
import 'personal_chat_client.dart';

final class PersonalChatOutboxExecutor implements CommandExecutor {
  PersonalChatOutboxExecutor({
    required AppDatabase database,
    required this.api,
    required this.pairing,
    required DateTime Function() clock,
    LocalRepositorySession? session,
    Future<void> Function(Duration) delay = Future<void>.delayed,
    this.maximumPolls = 20,
  }) : _database = database,
       _session = session ?? LocalRepositorySession.forDatabase(database),
       _clock = clock,
       _delay = delay;

  final AppDatabase _database;
  final LocalRepositorySession _session;
  final PersonalChatApi api;
  final String pairing;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _delay;
  final int maximumPolls;

  @override
  Future<CommandExecutionResult> execute(OutboxExecutionCommand command) async {
    if (command.commandType != 'local_send_text_v1' ||
        command.id != command.clientRequestId ||
        command.aggregateId.isEmpty ||
        command.leaseToken == null) {
      return const CommandExecutionResult(
        ExecutionDisposition.permanent,
        errorCode: 'personal_message_invalid',
      );
    }
    LocalTextCommand payload;
    try {
      payload = LocalTextCommand.decode(command.payloadJson);
    } on FormatException {
      return const CommandExecutionResult(
        ExecutionDisposition.permanent,
        errorCode: 'personal_payload_invalid',
      );
    }
    if (payload.id != command.id ||
        payload.conversationId != command.aggregateId) {
      return const CommandExecutionResult(
        ExecutionDisposition.permanent,
        errorCode: 'personal_message_invalid',
      );
    }
    try {
      if (!await _hasCurrentLease(command, payload)) {
        return const CommandExecutionResult(
          ExecutionDisposition.retryable,
          errorCode: 'inactive_personal_lease',
        );
      }
      PersonalChatSnapshot snapshot;
      try {
        snapshot = await api.send(
          pairing: pairing,
          clientMessageId: payload.id,
          bodyText: payload.bodyText.trim(),
        );
      } on PersonalChatFailure catch (failure) {
        if (failure.code == 'pairing_required' ||
            failure.code == 'invalid_pairing') {
          return CommandExecutionResult(
            ExecutionDisposition.authRequired,
            errorCode: failure.code,
          );
        }
        if (!failure.postOutcomeUnknown) {
          return CommandExecutionResult(
            failure.code == 'message_rejected'
                ? ExecutionDisposition.permanent
                : ExecutionDisposition.retryable,
            errorCode: failure.code,
          );
        }
        snapshot = await api.history(pairing);
      }

      final initialTurn = _matchingTurn(snapshot, payload);
      if (initialTurn == null) {
        return const CommandExecutionResult(
          ExecutionDisposition.retryable,
          errorCode: 'personal_acceptance_unknown',
        );
      }
      var turn = initialTurn;
      await _acknowledgeUser(payload, turn);

      for (
        var poll = 0;
        turn.state == 'pending' && poll < maximumPolls;
        poll++
      ) {
        await _delay(const Duration(seconds: 2));
        if (!await _hasCurrentLease(command, payload)) {
          return const CommandExecutionResult(
            ExecutionDisposition.retryable,
            errorCode: 'inactive_personal_lease',
          );
        }
        final next = await api.history(pairing);
        final matched = _matchingTurn(next, payload);
        if (matched == null ||
            matched.sequence != turn.sequence ||
            matched.assistantMessageId != turn.assistantMessageId) {
          return const CommandExecutionResult(
            ExecutionDisposition.permanent,
            errorCode: 'personal_identity_conflict',
          );
        }
        turn = matched;
      }
      if (turn.state == 'pending') {
        return const CommandExecutionResult(
          ExecutionDisposition.retryable,
          errorCode: 'personal_response_pending',
        );
      }
      if (turn.state == 'dispatch_unknown') {
        return const CommandExecutionResult(
          ExecutionDisposition.completed,
          errorCode: 'personal_dispatch_unknown',
        );
      }
      await _upsertAssistant(payload, turn);
      return const CommandExecutionResult(ExecutionDisposition.completed);
    } on PersonalChatFailure catch (failure) {
      return CommandExecutionResult(
        failure.code == 'pairing_required' || failure.code == 'invalid_pairing'
            ? ExecutionDisposition.authRequired
            : ExecutionDisposition.retryable,
        errorCode: failure.code,
      );
    } on LocalRepositoryException catch (failure) {
      return CommandExecutionResult(
        failure.kind == LocalRepositoryFailure.sessionClosed
            ? ExecutionDisposition.authRequired
            : ExecutionDisposition.retryable,
        errorCode: failure.kind == LocalRepositoryFailure.sessionClosed
            ? 'personal_session_closed'
            : 'personal_local_write_failed',
      );
    } on CanonicalIdentityConflict {
      return const CommandExecutionResult(
        ExecutionDisposition.permanent,
        errorCode: 'personal_identity_conflict',
      );
    } on Object {
      return const CommandExecutionResult(
        ExecutionDisposition.retryable,
        errorCode: 'personal_transport_failed',
      );
    }
  }

  PersonalChatTurn? _matchingTurn(
    PersonalChatSnapshot snapshot,
    LocalTextCommand payload,
  ) {
    final turn = snapshot.turn(payload.id);
    if (turn == null ||
        turn.clientRequestId != payload.id ||
        turn.bodyText != payload.bodyText.trim()) {
      return null;
    }
    return turn;
  }

  Future<bool> _hasCurrentLease(
    OutboxExecutionCommand command,
    LocalTextCommand payload,
  ) => _session.read(() async {
    final persisted = await (_database.select(
      _database.outboxCommands,
    )..where((row) => row.id.equals(command.id))).getSingleOrNull();
    final message = await (_database.select(
      _database.localMessages,
    )..where((row) => row.localId.equals(command.id))).getSingleOrNull();
    return persisted?.state == 'running' &&
        persisted?.leaseOwner == command.leaseToken &&
        persisted?.leaseUntil?.isAfter(_clock()) == true &&
        persisted?.payloadJson == command.payloadJson &&
        persisted?.clientRequestId == payload.id &&
        message?.clientMessageId == payload.id &&
        message?.conversationId == payload.conversationId &&
        message?.bodyText == payload.bodyText;
  });

  Future<void> _acknowledgeUser(
    LocalTextCommand payload,
    PersonalChatTurn turn,
  ) => _session.write(_database, () async {
    final message = await (_database.select(
      _database.localMessages,
    )..where((row) => row.localId.equals(payload.id))).getSingle();
    await _database.messageDao.upsertCanonical(
      CanonicalLocalMessage(
        serverId: payload.id,
        conversationId: payload.conversationId,
        clientMessageId: payload.id,
        sequence: turn.sequence * 2 - 1,
        senderKind: 'user',
        bodyText: payload.bodyText,
        messageKind: 'text',
        serverCreatedAt: _clock(),
      ),
      fallbackLocalId: payload.id,
      fallbackClientCreatedAt: message.clientCreatedAt,
    );
    await (_database.update(_database.localMessages)..where(
          (row) =>
              row.localId.equals(payload.id) &
              row.clientMessageId.equals(payload.id),
        ))
        .write(const LocalMessagesCompanion(deliveryState: Value('sent')));
  });

  Future<void> _upsertAssistant(
    LocalTextCommand payload,
    PersonalChatTurn turn,
  ) => _session.write(_database, () async {
    final answer = turn.answer;
    if (answer == null || answer.isEmpty) {
      throw const FormatException('Missing completed answer');
    }
    await _database.messageDao.upsertCanonical(
      CanonicalLocalMessage(
        serverId: turn.assistantMessageId,
        conversationId: payload.conversationId,
        clientMessageId: turn.assistantMessageId,
        sequence: turn.sequence * 2,
        senderKind: 'system',
        bodyText: answer,
        messageKind: 'text',
        serverCreatedAt: _clock(),
      ),
      fallbackLocalId: 'personal-assistant:${turn.assistantMessageId}',
      fallbackClientCreatedAt: _clock(),
    );
  });
}
