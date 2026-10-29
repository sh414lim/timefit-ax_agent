import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/core/database/logout_chat_data_purger.dart';
import 'package:timefit_native/core/network/realtime_client.dart';
import 'package:timefit_native/features/chat/application/chat_session_coordinator.dart';
import 'package:timefit_native/features/chat/data/chat_realtime_source.dart';

import '../../../support/fake_private_chat_filesystem.dart';
import '../../../support/hybrid_logout_candidate.dart';
import '../../../support/in_memory_chat_cleanup_ledger.dart';
import '../data/support/fake_realtime_port.dart';

void main() {
  test(
    'pending remote release cannot queue ahead of strict local purge',
    () async {
      final port = FakeRealtimeReadPort();
      final source = ChatRealtimeSource(port: port);
      await source.subscribe('synthetic-conversation');
      final handle = source.trustedHandle!;
      final remoteUnsubscribe = Completer<RealtimeUnsubscribeObservation>();
      port.unsubscribeGates[handle] = remoteUnsubscribe;
      final remote = _RemoteFake.pending();
      remote.responses[CandidateRemoteOperation.realtime] = () async {
        // Local source completion is not a server ACK, including when completed.
        await source.unsubscribe(handle);
        return CandidateRemoteObservation.uncertain;
      };
      final f = await _Fixture.create(
        remote: remote,
        fence: source.revokeSession,
      );
      addTearDown(() async {
        source.dispose();
        await port.close();
      });
      final hints = <int>[];
      final subscription = source.hints.listen(
        (hint) => hints.add(hint.sequence),
      );
      addTearDown(subscription.cancel);
      final callback = f.candidate.captureCallback();

      final logout = f.candidate.logout();
      expect(identical(logout, f.candidate.logout()), isTrue);
      expect(f.candidate.acceptsCallback(callback), isFalse);
      expect(source.trustedHandle, isNull);
      expect(
        port.quarantineCalls.where((entry) => identical(entry.handle, handle)),
        hasLength(1),
      );
      await expectLater(
        f.candidate.session.repository.read(() async => 'private'),
        throwsA(isA<LocalRepositoryException>()),
      );
      port.emit(
        RealtimeMessageCreatedEvent(
          handle,
          eventId: 'late',
          conversationId: 'synthetic-conversation',
          sequence: 2,
        ),
      );
      expect(hints, isEmpty);

      // The actual local coordinator settles before any remote Future does.
      await f.candidate.coordinator.logout();
      expect(await f.rowsRemaining(), 0);
      expect(f.files.listNamespace(f.fileNamespace), isEmpty);
      expect(f.candidate.snapshot!.localProtectionComplete, isTrue);
      expect(
        f.candidate.snapshot!.remote.values,
        everyElement(CandidateRemoteState.inProgress),
      );
      var observed = false;
      unawaited(logout.then((_) => observed = true));
      await _flush();
      expect(observed, isFalse);

      f.boundary.observeBoundaryReached();
      final result = await logout;
      expect(result.localProtectionComplete, isTrue);
      expect(
        result.remote.values,
        everyElement(CandidateRemoteState.uncertain),
      );
      expect(remote.calls, hasLength(3));
      expect(port.unsubscribeCalls[handle], 1);
      // Deliberately never release these remote Futures: no wall-clock timeout.
    },
  );

  for (final operation in CandidateRemoteOperation.values) {
    for (final observation in CandidateRemoteObservation.values) {
      test(
        '${operation.name} ${observation.name} is independent evidence',
        () async {
          final remote = _RemoteFake();
          remote.responses[operation] = () async => observation;
          final f = await _Fixture.create(remote: remote);
          final result = await f.candidate.logout();
          expect(result.localProtectionComplete, isTrue);
          expect(result.remote[operation], switch (observation) {
            CandidateRemoteObservation.acknowledged =>
              CandidateRemoteState.confirmed,
            CandidateRemoteObservation.uncertain =>
              CandidateRemoteState.uncertain,
            CandidateRemoteObservation.failed => CandidateRemoteState.failed,
            CandidateRemoteObservation.unsupported =>
              CandidateRemoteState.unsupported,
          });
          for (final other in CandidateRemoteOperation.values.where(
            (value) => value != operation,
          )) {
            expect(result.remote[other], CandidateRemoteState.unsupported);
          }
        },
      );
    }
  }

  test(
    'remote ACK cannot skip a local mutation drain or allow new work',
    () async {
      final f = await _Fixture.create(remote: _RemoteFake.acknowledged());
      final started = Completer<void>();
      final release = Completer<void>();
      final mutation = f.candidate.session.repository.write(
        f.database,
        () async {
          await f.database
              .into(f.database.localMessages)
              .insert(_message('in-flight'));
          started.complete();
          await release.future;
        },
      );
      await started.future;
      final mutationResult = expectLater(
        mutation,
        throwsA(isA<LocalRepositoryException>()),
      );
      final logout = f.candidate.logout();
      await _flush();
      expect(
        f.candidate.snapshot!.remote.values,
        everyElement(CandidateRemoteState.confirmed),
      );
      expect(f.candidate.snapshot!.localProtectionComplete, isFalse);
      expect(f.candidate.snapshot!.local.mutationsResolved, isFalse);
      expect(f.purgeCalls, 0);
      expect(
        () => f.candidate.coordinator.openSession(
          namespace: 'candidate-2',
          stopLifecycleAndOutbox: () async {},
          purgeLocalData: () async {},
        ),
        throwsA(isA<LocalChatSessionException>()),
      );
      var entered = false;
      await expectLater(
        f.candidate.session.repository.write(f.database, () async {
          entered = true;
        }),
        throwsA(isA<LocalRepositoryException>()),
      );
      expect(entered, isFalse);
      release.complete();
      await mutationResult;
      expect((await logout).localProtectionComplete, isTrue);
      expect(await f.rowsRemaining(), 0);
      expect(f.events, ['fence', 'stop', 'purge', 'verify']);
    },
  );

  test(
    'pending local mutation stays pending despite remote failures and boundary',
    () async {
      final f = await _Fixture.create(remote: _RemoteFake.failed());
      final started = Completer<void>();
      final release = Completer<void>();
      final mutation = f.candidate.session.repository
          .withAttachmentDraftMutation('synthetic-draft', () async {
            started.complete();
            await release.future;
          });
      await started.future;
      final logout = f.candidate.logout();
      f.boundary.observeBoundaryReached();
      await _flush();
      expect(f.candidate.snapshot!.localProtectionComplete, isFalse);
      expect(f.candidate.coordinator.state, LocalChatSessionState.loggingOut);
      expect(f.purgeCalls, 0);
      expect(
        f.candidate.snapshot!.remote.values,
        everyElement(CandidateRemoteState.failed),
      );
      release.complete();
      await mutation;
      expect((await logout).localProtectionComplete, isTrue);
    },
  );

  test(
    'partial file failure preserves DB tracking and retries only local work',
    () async {
      final remote = _RemoteFake.acknowledged();
      final f = await _Fixture.create(remote: remote);
      await f.addAttachment('second', 'second-private.pdf');
      f.files.scriptNext(
        FakePrivateFileOperation.delete,
        FakePrivateFileOutcome.succeed,
      );
      f.files.scriptNext(
        FakePrivateFileOperation.delete,
        FakePrivateFileOutcome.fail,
      );
      final failed = await f.candidate.logout();
      expect(failed.localProtectionComplete, isFalse);
      expect(failed.local.recoveryRequired, isTrue);
      expect(
        failed.remote.values,
        everyElement(CandidateRemoteState.confirmed),
      );
      expect(await f.rowsRemaining(), 5);
      expect(f.files.listNamespace(f.fileNamespace), hasLength(1));
      // DAO enumeration order is not a deletion-order contract. One of the
      // two files is gone, and both tracking rows remain for safe retry.
      expect(
        f.allowedFiles.values.where(
          (path) => !f.files.exists(f.fileNamespace, path),
        ),
        hasLength(1),
      );
      expect(
        f.candidate.coordinator.state,
        LocalChatSessionState.cleanupPending,
      );

      final retry = f.candidate.retryLocalCleanup();
      expect(identical(retry, f.candidate.retryLocalCleanup()), isTrue);
      expect(identical(retry, f.candidate.logout()), isTrue);
      final success = await retry;
      expect(success.attempt, 2);
      expect(success.localProtectionComplete, isTrue);
      expect(remote.calls, hasLength(3));
      expect(f.stopCalls, 1);
      expect(await f.rowsRemaining(), 0);
      f.files.verifyNoPending();
    },
  );

  test('DB rollback after file deletion leaves local recovery pending', () async {
    final f = await _Fixture.create(remote: _RemoteFake.acknowledged());
    await f.database.customStatement(
      "CREATE TRIGGER synthetic_delete_failure BEFORE DELETE ON local_messages BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
    );
    final failed = await f.candidate.logout();
    expect(failed.local.recoveryRequired, isTrue);
    expect(failed.local.privateDataPurged, isFalse);
    expect(failed.localProtectionComplete, isFalse);
    expect(await f.rowsRemaining(), 4);
    expect(f.files.listNamespace(f.fileNamespace), isEmpty);
    await f.database.customStatement('DROP TRIGGER synthetic_delete_failure');
    expect(
      (await f.candidate.retryLocalCleanup()).localProtectionComplete,
      isTrue,
    );
    expect(await f.rowsRemaining(), 0);
  });

  test('purge without verification is not complete', () async {
    final f = await _Fixture.create();
    f.verifyResult = false;
    final failed = await f.candidate.logout();
    expect(failed.local.privateDataPurged, isTrue);
    expect(failed.local.purgeVerified, isFalse);
    expect(failed.local.recoveryRequired, isTrue);
    expect(failed.localProtectionComplete, isFalse);
    f.verifyResult = true;
    expect(
      (await f.candidate.retryLocalCleanup()).localProtectionComplete,
      isTrue,
    );
  });

  test(
    'pending verification cannot be bypassed by remote ACK or boundary',
    () async {
      final f = await _Fixture.create(remote: _RemoteFake.acknowledged());
      f.verifyGate = Completer<void>();
      final logout = f.candidate.logout();
      await f.verificationStarted.future;
      f.boundary.observeBoundaryReached();
      await _flush();
      expect(await f.rowsRemaining(), 0);
      expect(f.candidate.snapshot!.local.privateDataPurged, isTrue);
      expect(f.candidate.snapshot!.localProtectionComplete, isFalse);
      expect(f.candidate.coordinator.state, LocalChatSessionState.loggingOut);
      f.verifyGate!.complete();
      expect((await logout).localProtectionComplete, isTrue);
    },
  );

  test('local stop failure is strict even when all remote calls ACK', () async {
    final f = await _Fixture.create(remote: _RemoteFake.acknowledged());
    f.stopError = const _PrivateError();
    final failed = await f.candidate.logout();
    expect(failed.local.failure, CandidateLocalFailure.localStop);
    expect(failed.localProtectionComplete, isFalse);
    expect(f.purgeCalls, 0);
    expect(await f.rowsRemaining(), 4);
    f.stopError = null;
    expect(
      (await f.candidate.retryLocalCleanup()).localProtectionComplete,
      isTrue,
    );
    expect(f.stopCalls, 2);
    expect(f.purgeCalls, 1);
  });

  test(
    'external generation fence failure blocks purge and is retryable',
    () async {
      var failFence = true;
      final f = await _Fixture.create(
        fence: () {
          if (failFence) throw const _PrivateError();
        },
      );
      final oldCallback = f.candidate.captureCallback();
      final failed = await f.candidate.logout();
      expect(f.candidate.acceptsCallback(oldCallback), isFalse);
      expect(failed.local.oldGenerationFenced, isFalse);
      expect(failed.local.failure, CandidateLocalFailure.generationFence);
      expect(failed.localProtectionComplete, isFalse);
      expect(f.purgeCalls, 0);
      failFence = false;
      expect(
        (await f.candidate.retryLocalCleanup()).localProtectionComplete,
        isTrue,
      );
    },
  );

  test(
    'late ACK after boundary updates only the current remote result',
    () async {
      final remote = _RemoteFake.pending();
      final f = await _Fixture.create(remote: remote);
      final logout = f.candidate.logout();
      f.boundary.observeBoundaryReached();
      final bounded = await logout;
      final localBefore = bounded.local.toDiagnosticMap();
      remote.gates[CandidateRemoteOperation.deviceRevoke]!.complete(
        CandidateRemoteObservation.acknowledged,
      );
      await _flush();
      expect(
        f.candidate.snapshot!.remote[CandidateRemoteOperation.deviceRevoke],
        CandidateRemoteState.confirmed,
      );
      expect(
        f.candidate.snapshot!.remote[CandidateRemoteOperation.realtime],
        CandidateRemoteState.uncertain,
      );
      expect(f.candidate.snapshot!.local.toDiagnosticMap(), localBefore);
      expect(
        bounded.remote.values,
        everyElement(CandidateRemoteState.uncertain),
      );
    },
  );

  test(
    'local retry retires old waiters and fences old remote completion',
    () async {
      final remote = _RemoteFake.pending();
      final f = await _Fixture.create(remote: remote);
      f.stopError = const _PrivateError();
      final oldLogout = f.candidate.logout();
      await expectLater(
        f.candidate.coordinator.logout(),
        throwsA(isA<_PrivateError>()),
      );
      f.stopError = null;
      final retry = f.candidate.retryLocalCleanup();
      final oldResult = await oldLogout;
      expect(oldResult.local.recoveryRequired, isTrue);
      expect(
        oldResult.remote.values,
        everyElement(CandidateRemoteState.uncertain),
      );
      final result = await retry;
      final before = jsonEncode(result.toDiagnosticMap());
      for (final gate in remote.gates.values) {
        gate.complete(CandidateRemoteObservation.acknowledged);
      }
      await _flush();
      expect(jsonEncode(f.candidate.snapshot!.toDiagnosticMap()), before);
      expect(f.candidate.ledger, hasLength(2));
      expect(remote.calls, hasLength(3));
    },
  );

  test(
    'dispose joins cleanup and late errors cannot revive a new namespace',
    () async {
      final sharedFiles = FakePrivateChatFilesystem();
      final remote = _RemoteFake.pending();
      final old = await _Fixture.create(remote: remote, files: sharedFiles);
      final oldToken = old.candidate.captureCallback();
      old.stopGate = Completer<void>();
      final logout = old.candidate.logout();
      final disposal = old.candidate.dispose();
      expect(identical(logout, disposal), isTrue);
      expect(identical(disposal, old.candidate.dispose()), isTrue);
      old.stopGate!.complete();
      final result = await disposal;
      expect(result.disposed, isTrue);
      expect(result.localProtectionComplete, isTrue);
      expect(old.candidate.coordinator.state, LocalChatSessionState.disposed);
      // Replacement starts only after local protection is complete. The
      // eventual product owner must enforce this ordering across instances.
      final next = await _Fixture.create(namespace: 2, files: sharedFiles);
      expect(next.files.listNamespace(next.fileNamespace), hasLength(1));
      expect(await next.rowsRemaining(), 4);
      final newCallback = next.candidate.captureCallback();
      expect(next.candidate.acceptsCallback(oldToken), isFalse);
      expect(next.candidate.acceptsCallback(newCallback), isTrue);
      final before = jsonEncode(old.candidate.snapshot!.toDiagnosticMap());
      for (final gate in remote.gates.values) {
        gate.completeError(const _PrivateError());
      }
      await _flush();
      expect(jsonEncode(old.candidate.snapshot!.toDiagnosticMap()), before);
      expect(await next.rowsRemaining(), 4);
    },
  );

  test(
    'dispose after completed logout returns a fresh disposed result',
    () async {
      final remote = _RemoteFake.acknowledged();
      final f = await _Fixture.create(remote: remote);
      final logout = f.candidate.logout();
      final loggedOut = await logout;
      expect(loggedOut.disposed, isFalse);
      expect(identical(logout, f.candidate.logout()), isTrue);

      final disposal = f.candidate.dispose();
      expect(identical(disposal, logout), isFalse);
      expect(identical(disposal, f.candidate.dispose()), isTrue);
      expect(identical(disposal, f.candidate.logout()), isTrue);
      final result = await disposal;
      expect(result.disposed, isTrue);
      expect(result.toDiagnosticMap(), f.candidate.snapshot!.toDiagnosticMap());
      expect(f.candidate.coordinator.state, LocalChatSessionState.disposed);
      expect(loggedOut.disposed, isFalse); // Historical immutable result.
      expect(f.purgeCalls, 1);
      expect(remote.calls, hasLength(3));
    },
  );

  for (final failStop in [false, true]) {
    test(
      'completed local failure then dispose/retry shares current result (stop: $failStop)',
      () async {
        final remote = _RemoteFake.acknowledged();
        final f = await _Fixture.create(remote: remote);
        if (failStop) {
          f.stopError = const _PrivateError();
        } else {
          f.files.scriptNext(
            FakePrivateFileOperation.delete,
            FakePrivateFileOutcome.fail,
          );
        }
        final logout = f.candidate.logout();
        final failed = await logout;
        expect(failed.local.recoveryRequired, isTrue);
        final disposal = f.candidate.dispose();
        final disposed = await disposal;
        expect(disposed.disposed, isTrue);
        expect(disposed.localProtectionComplete, isFalse);
        expect(disposed.local.recoveryRequired, isTrue);
        expect(
          disposed.toDiagnosticMap(),
          f.candidate.snapshot!.toDiagnosticMap(),
        );
        expect(identical(disposal, f.candidate.dispose()), isTrue);
        expect(identical(disposal, f.candidate.logout()), isTrue);
        expect(
          f.candidate.coordinator.state,
          LocalChatSessionState.cleanupPending,
        );

        f.stopError = null;
        final retry = f.candidate.retryLocalCleanup();
        expect(identical(retry, disposal), isFalse);
        final recovered = await retry;
        expect(recovered.attempt, 2);
        expect(recovered.disposed, isTrue);
        expect(recovered.localProtectionComplete, isTrue);
        expect(
          recovered.toDiagnosticMap(),
          f.candidate.snapshot!.toDiagnosticMap(),
        );
        expect(identical(retry, f.candidate.dispose()), isTrue);
        expect(identical(retry, f.candidate.logout()), isTrue);
        expect(failed.disposed, isFalse);
        expect(disposed.local.recoveryRequired, isTrue);
        expect(remote.calls, hasLength(3));
      },
    );
  }

  test(
    'dispose during local retry joins that attempt rather than old failure',
    () async {
      final f = await _Fixture.create();
      f.files.scriptNext(
        FakePrivateFileOperation.delete,
        FakePrivateFileOutcome.fail,
      );
      final failed = await f.candidate.logout();
      f.verifyGate = Completer<void>();
      final retry = f.candidate.retryLocalCleanup();
      await f.verificationStarted.future;
      final disposal = f.candidate.dispose();
      expect(identical(disposal, retry), isTrue);
      expect(identical(disposal, f.candidate.dispose()), isTrue);
      expect(identical(disposal, f.candidate.retryLocalCleanup()), isTrue);
      expect(identical(disposal, f.candidate.logout()), isTrue);
      expect(f.candidate.snapshot!.localProtectionComplete, isFalse);
      f.verifyGate!.complete();
      final result = await disposal;
      expect(result.attempt, 2);
      expect(result.disposed, isTrue);
      expect(result.localProtectionComplete, isTrue);
      expect(result.toDiagnosticMap(), f.candidate.snapshot!.toDiagnosticMap());
      expect(failed.local.recoveryRequired, isTrue);
      expect(f.candidate.coordinator.state, LocalChatSessionState.disposed);
    },
  );

  test(
    'dispose joins a pending remote observation after local completion',
    () async {
      final f = await _Fixture.create(remote: _RemoteFake.pending());
      final logout = f.candidate.logout();
      await f.candidate.coordinator.logout();
      expect(f.candidate.snapshot!.localProtectionComplete, isTrue);
      final disposal = f.candidate.dispose();
      expect(identical(disposal, logout), isTrue);
      final result = await disposal;
      expect(result.disposed, isTrue);
      expect(
        result.remote.values,
        everyElement(CandidateRemoteState.uncertain),
      );
      expect(result.toDiagnosticMap(), f.candidate.snapshot!.toDiagnosticMap());
      expect(identical(disposal, f.candidate.dispose()), isTrue);
    },
  );

  test(
    'post-logout dispose preserves latest remote evidence and fences late errors',
    () async {
      final remote = _RemoteFake.pending();
      final f = await _Fixture.create(remote: remote);
      final logout = f.candidate.logout();
      f.boundary.observeBoundaryReached();
      final original = await logout;
      remote.gates[CandidateRemoteOperation.realtime]!.complete(
        CandidateRemoteObservation.acknowledged,
      );
      await _flush();
      final disposal = f.candidate.dispose();
      final result = await disposal;
      expect(result.disposed, isTrue);
      expect(
        result.remote[CandidateRemoteOperation.realtime],
        CandidateRemoteState.confirmed,
      );
      expect(result.toDiagnosticMap(), f.candidate.snapshot!.toDiagnosticMap());
      remote.gates[CandidateRemoteOperation.deviceRevoke]!.completeError(
        const _PrivateError(),
      );
      remote.gates[CandidateRemoteOperation.remoteAuth]!.completeError(
        const _PrivateError(),
      );
      await _flush();
      expect(result.toDiagnosticMap(), f.candidate.snapshot!.toDiagnosticMap());
      expect(identical(disposal, f.candidate.logout()), isTrue);
      expect(original.disposed, isFalse);
      expect(
        original.remote.values,
        everyElement(CandidateRemoteState.uncertain),
      );
    },
  );

  test(
    'dispose during a failed purge still requires explicit local retry',
    () async {
      final f = await _Fixture.create(remote: _RemoteFake.pending());
      f.stopGate = Completer<void>();
      f.files.scriptNext(
        FakePrivateFileOperation.delete,
        FakePrivateFileOutcome.fail,
      );
      final logout = f.candidate.logout();
      final disposal = f.candidate.dispose();
      f.stopGate!.complete();
      final failed = await disposal;
      expect(identical(logout, disposal), isTrue);
      expect(failed.local.recoveryRequired, isTrue);
      expect(
        f.candidate.coordinator.state,
        LocalChatSessionState.cleanupPending,
      );
      final complete = await f.candidate.retryLocalCleanup();
      expect(complete.localProtectionComplete, isTrue);
      expect(complete.disposed, isTrue);
      expect(f.candidate.coordinator.state, LocalChatSessionState.disposed);
      expect(f.candidate.captureCallback(), isNull);
    },
  );

  test(
    'same-frame and late repository streams cannot expose old data',
    () async {
      final f = await _Fixture.create();
      final controller = StreamController<String>(sync: true);
      final received = <String>[];
      final listener = f.candidate.session.repository
          .watch(() => controller.stream)
          .listen(received.add);
      listener.pause();
      controller.add('canary-private-body');
      final old = f.candidate.captureCallback();
      final logout = f.candidate.logout();
      expect(f.candidate.acceptsCallback(old), isFalse);
      expect(f.candidate.captureCallback(), isNull);
      listener.resume();
      controller.add('late-canary-private-body');
      await logout;
      await _flush();
      expect(received, isEmpty);
      await controller.close();
      await listener.cancel();
    },
  );

  test(
    'raw cleanup errors and stored private values never enter the ledger',
    () async {
      final remote = _RemoteFake();
      remote.responses[CandidateRemoteOperation.realtime] = () =>
          throw const _PrivateError();
      remote.responses[CandidateRemoteOperation.deviceRevoke] = () =>
          Future.error(const _PrivateError());
      final f = await _Fixture.create(remote: remote);
      f.stopError = const _PrivateError();
      final result = await f.candidate.logout();
      final encoded = jsonEncode(
        f.candidate.ledger.map((value) => value.toDiagnosticMap()).toList(),
      );
      expect(result.localProtectionComplete, isFalse);
      expect(
        result.remote[CandidateRemoteOperation.realtime],
        CandidateRemoteState.failed,
      );
      for (final raw in [
        'canary',
        'synthetic-conversation',
        'private/',
        '.pdf',
        'token=',
        'https:',
        'file:',
      ]) {
        expect(encoded, isNot(contains(raw)));
      }
      f.stopError = null;
      await f.candidate.retryLocalCleanup();
    },
  );

  test(
    'synchronous remote reentry cannot duplicate logout or call after dispose',
    () async {
      final remote = _RemoteFake();
      final f = await _Fixture.create(remote: remote);
      Future<CandidateLogoutSnapshot>? reentry;
      remote.onCall = (_) {
        reentry = f.candidate.dispose();
      };
      final logout = f.candidate.logout();
      expect(identical(logout, reentry), isTrue);
      final result = await logout;
      expect(result.disposed, isTrue);
      expect(result.localProtectionComplete, isTrue);
      expect(remote.calls, [CandidateRemoteOperation.realtime]);
      expect(
        result.remote[CandidateRemoteOperation.realtime],
        CandidateRemoteState.uncertain,
      );
      expect(
        result.remote[CandidateRemoteOperation.remoteAuth],
        CandidateRemoteState.notAttempted,
      );
    },
  );
}

final class _RemoteFake implements CandidateRemoteReleasePort {
  _RemoteFake();
  factory _RemoteFake.pending() {
    final port = _RemoteFake();
    for (final operation in CandidateRemoteOperation.values) {
      final gate = Completer<CandidateRemoteObservation>();
      port.gates[operation] = gate;
      port.responses[operation] = () => gate.future;
    }
    return port;
  }
  factory _RemoteFake.acknowledged() =>
      _RemoteFake().._all(CandidateRemoteObservation.acknowledged);
  factory _RemoteFake.failed() =>
      _RemoteFake().._all(CandidateRemoteObservation.failed);
  final calls = <CandidateRemoteOperation>[];
  final gates =
      <CandidateRemoteOperation, Completer<CandidateRemoteObservation>>{};
  final responses =
      <
        CandidateRemoteOperation,
        Future<CandidateRemoteObservation> Function()
      >{};
  void Function(CandidateRemoteOperation)? onCall;
  void _all(CandidateRemoteObservation observation) {
    for (final operation in CandidateRemoteOperation.values) {
      responses[operation] = () async => observation;
    }
  }

  @override
  Future<CandidateRemoteObservation> release(
    CandidateRemoteOperation operation,
  ) {
    calls.add(operation);
    onCall?.call(operation);
    return responses[operation]?.call() ??
        Future.value(CandidateRemoteObservation.unsupported);
  }
}

final class _Fixture {
  _Fixture(
    this.namespace,
    this.files,
    CandidateRemoteReleasePort remote,
    this.fence,
  ) : database = AppDatabase(NativeDatabase.memory()),
      fileNamespace = FakePrivateNamespaceId(namespace) {
    candidate = HybridLogoutCandidate(
      namespace: TestCleanupNamespaceId(namespace),
      remote: remote,
      remoteBoundary: boundary,
      fenceOldGeneration: () {
        events.add('fence');
        fence?.call();
      },
      stopLocalWork: () async {
        events.add('stop');
        stopCalls += 1;
        await stopGate?.future;
        if (stopError case final error?) throw error;
      },
      purgePrivateData: () async {
        events.add('purge');
        purgeCalls += 1;
        await LogoutChatDataPurger(
          database: database,
          fileStore: _FakeFileStore(files, fileNamespace, allowedFiles),
        ).purge();
      },
      verifyLocalPurge: () async {
        events.add('verify');
        if (!verificationStarted.isCompleted) verificationStarted.complete();
        await verifyGate?.future;
        return verifyResult &&
            await rowsRemaining() == 0 &&
            files.listNamespace(fileNamespace).isEmpty;
      },
    );
  }
  final int namespace;
  final FakePrivateChatFilesystem files;
  final FakePrivateNamespaceId fileNamespace;
  final AppDatabase database;
  final void Function()? fence;
  final boundary = CandidateRemoteBoundary();
  final events = <String>[];
  late final HybridLogoutCandidate candidate;
  final relativePath = FakePrivateRelativePath.parse('canary-private-file.pdf');
  final allowedFiles = <Uri, FakePrivateRelativePath>{};
  Uri get fileUri =>
      Uri.parse('file:///synthetic/private/$namespace/canary-private-file.pdf');
  var stopCalls = 0;
  var purgeCalls = 0;
  bool verifyResult = true;
  Object? stopError;
  Completer<void>? stopGate;
  Completer<void>? verifyGate;
  final verificationStarted = Completer<void>();

  static Future<_Fixture> create({
    int namespace = 1,
    CandidateRemoteReleasePort? remote,
    FakePrivateChatFilesystem? files,
    void Function()? fence,
  }) async {
    final fixture = _Fixture(
      namespace,
      files ?? FakePrivateChatFilesystem(),
      remote ?? _RemoteFake(),
      fence,
    );
    addTearDown(fixture.database.close);
    fixture.files.seedFile(fixture.fileNamespace, fixture.relativePath);
    fixture.allowedFiles[fixture.fileUri] = fixture.relativePath;
    final now = DateTime.utc(2026, 10, 29);
    await fixture.database
        .into(fixture.database.localConversations)
        .insert(
          LocalConversationsCompanion.insert(
            id: 'synthetic-conversation',
            title: const Value('canary-private-title'),
            serverCreatedAt: now,
            serverUpdatedAt: now,
            lastSyncedAt: now,
          ),
        );
    await fixture.database
        .into(fixture.database.localMessages)
        .insert(_message('seed'));
    await fixture.database
        .into(fixture.database.outboxCommands)
        .insert(
          OutboxCommandsCompanion.insert(
            id: 'synthetic-command',
            commandType: 'send_message',
            aggregateId: 'synthetic-conversation',
            clientRequestId: 'synthetic-message',
            payloadJson: '{"bodyText":"canary-private-body"}',
            nextAttemptAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await fixture.database
        .into(fixture.database.localAttachments)
        .insert(
          LocalAttachmentsCompanion.insert(
            localId: 'synthetic-attachment',
            conversationId: 'synthetic-conversation',
            clientMessageId: 'synthetic-message',
            localFileUri: Value(fixture.fileUri.toString()),
            displayName: const Value('canary-private-file.pdf'),
            contentType: 'application/pdf',
            sha256: 'synthetic-hash',
          ),
        );
    return fixture;
  }

  Future<void> addAttachment(String id, String relative) async {
    final path = FakePrivateRelativePath.parse(relative);
    final uri = Uri.parse('file:///synthetic/private/$namespace/$relative');
    allowedFiles[uri] = path;
    files.seedFile(fileNamespace, path);
    await database
        .into(database.localAttachments)
        .insert(
          LocalAttachmentsCompanion.insert(
            localId: id,
            conversationId: 'synthetic-conversation',
            clientMessageId: 'synthetic-message',
            localFileUri: Value(uri.toString()),
            contentType: 'application/pdf',
            sha256: 'synthetic-hash',
          ),
        );
  }

  Future<int> rowsRemaining() async =>
      (await database.select(database.localConversations).get()).length +
      (await database.select(database.localMessages).get()).length +
      (await database.select(database.outboxCommands).get()).length +
      (await database.select(database.localAttachments).get()).length;
}

final class _FakeFileStore implements PrivateAttachmentFileStore {
  _FakeFileStore(this.files, this.namespace, this.allowedFiles);
  final FakePrivateChatFilesystem files;
  final FakePrivateNamespaceId namespace;
  final Map<Uri, FakePrivateRelativePath> allowedFiles;
  @override
  Future<void> deleteIfInsidePrivateRoot(Uri uri) {
    final relative = allowedFiles[uri];
    if (relative == null) throw const _PrivateError();
    return files.delete(namespace, relative);
  }
}

LocalMessagesCompanion _message(String id) => LocalMessagesCompanion.insert(
  localId: id,
  conversationId: 'synthetic-conversation',
  clientMessageId: id,
  senderKind: 'user',
  bodyText: const Value('canary-private-body'),
  messageKind: 'text',
  clientCreatedAt: DateTime.utc(2026, 10, 29),
);

final class _PrivateError implements Exception {
  const _PrivateError();
  @override
  String toString() => throw StateError('must_not_stringify_private_error');
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
