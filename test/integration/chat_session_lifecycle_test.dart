import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/core/database/logout_chat_data_purger.dart';
import 'package:timefit_native/features/chat/application/chat_connection_coordinator.dart';
import 'package:timefit_native/features/chat/application/chat_session_coordinator.dart';
import 'package:timefit_native/features/chat/application/reconnect_policy.dart';

void main() {
  test(
    'logout closes admission drains writes then cleans lifecycle files and DB',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final privateRoot = await Directory.systemTemp.createTemp(
        'timefit-chat047-order-',
      );
      addTearDown(() => privateRoot.delete(recursive: true));
      final privateFile = await File(
        '${privateRoot.path}/attachment.bin',
      ).writeAsString('fixture');
      await _insertAttachment(database, 'attachment', privateFile.uri);

      final events = <String>[];
      final connectionPort = _ConnectionPort();
      final connection = ChatConnectionCoordinator(
        port: connectionPort,
        scheduler: const SystemLifecycleScheduler(),
        reconnectPolicy: ReconnectPolicy(randomUnit: () => 0.5),
      );
      addTearDown(connection.dispose);
      await connection.handleLifecycleState(AppLifecycleState.resumed);
      connectionPort.events.clear();

      final fileStore = _RecordingFileStore(
        delegate: IoPrivateAttachmentFileStore(privateRoot),
        events: events,
      );
      final purger = LogoutChatDataPurger(
        database: database,
        fileStore: fileStore,
      );
      final coordinator = LocalChatSessionCoordinator();
      final session = coordinator.openSession(
        namespace: 'account-a',
        stopLifecycleAndOutbox: () async {
          events.add('lifecycle-start');
          await connection.logout();
          events.add('lifecycle-done');
        },
        purgeLocalData: () async {
          await purger.purge();
          events.add('purge-done');
        },
      );

      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      final write = session.repository.write(database, () async {
        events.add('write-start');
        writeStarted.complete();
        await releaseWrite.future;
        events.add('write-finish');
        await database
            .into(database.localConversations)
            .insert(_conversation('rolled-back'));
      });
      final writeFailure = expectLater(
        write,
        throwsA(
          isA<LocalRepositoryException>().having(
            (error) => error.kind,
            'kind',
            LocalRepositoryFailure.sessionClosed,
          ),
        ),
      );
      await writeStarted.future;

      final mutationStarted = Completer<void>();
      final releaseMutation = Completer<void>();
      final mutation = session.repository.withAttachmentDraftMutation(
        'draft',
        () {
          mutationStarted.complete();
          return releaseMutation.future;
        },
      );
      await mutationStarted.future;

      final firstLogout = coordinator.logout();
      final secondLogout = coordinator.logout();
      expect(identical(firstLogout, secondLogout), isTrue);
      expect(coordinator.state, LocalChatSessionState.loggingOut);
      await _flushAsync();
      expect(events, isNot(contains('lifecycle-start')));
      await expectLater(
        session.repository.write<void>(database, () async {}),
        throwsA(isA<LocalRepositoryException>()),
      );

      releaseWrite.complete();
      releaseMutation.complete();
      await Future.wait<void>(<Future<void>>[
        writeFailure,
        mutation,
        firstLogout,
        secondLogout,
      ]);

      expect(
        events,
        containsAllInOrder(<String>[
          'write-start',
          'write-finish',
          'lifecycle-start',
          'lifecycle-done',
          'file-delete',
          'purge-done',
        ]),
      );
      expect(connectionPort.events, <String>[
        'outbox-pause',
        'unsubscribe',
        'logout-cleanup',
      ]);
      expect(await privateFile.exists(), isFalse);
      expect(await database.select(database.localAttachments).get(), isEmpty);
      expect(await database.select(database.localConversations).get(), isEmpty);
      expect(coordinator.state, LocalChatSessionState.idle);
    },
  );

  test(
    'file purge failure blocks a new session until retry succeeds',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final privateRoot = await Directory.systemTemp.createTemp(
        'timefit-chat047-file-retry-',
      );
      addTearDown(() => privateRoot.delete(recursive: true));
      final privateFile = await File(
        '${privateRoot.path}/attachment.bin',
      ).writeAsString('fixture');
      await _insertAttachment(database, 'attachment', privateFile.uri);

      var failDelete = true;
      var lifecycleCalls = 0;
      final fileStore = _RecordingFileStore(
        delegate: IoPrivateAttachmentFileStore(privateRoot),
        events: <String>[],
        fail: () => failDelete,
      );
      final coordinator = LocalChatSessionCoordinator();
      final session = coordinator.openSession(
        namespace: 'account-a',
        stopLifecycleAndOutbox: () async {
          lifecycleCalls += 1;
        },
        purgeLocalData: LogoutChatDataPurger(
          database: database,
          fileStore: fileStore,
        ).purge,
      );

      await expectLater(
        coordinator.logout(),
        throwsA(isA<PrivateFilePurgeException>()),
      );
      expect(coordinator.state, LocalChatSessionState.cleanupPending);
      expect(
        coordinator.lastFailedStage,
        LocalChatSessionCleanupStage.purgeLocalData,
      );
      expect(await privateFile.exists(), isTrue);
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(1),
      );
      await expectLater(
        session.repository.read(
          () => database.select(database.localAttachments).get(),
        ),
        throwsA(isA<LocalRepositoryException>()),
      );
      expect(
        () => coordinator.openSession(
          namespace: 'account-b',
          stopLifecycleAndOutbox: () async {},
          purgeLocalData: () async {},
        ),
        throwsA(
          isA<LocalChatSessionException>().having(
            (error) => error.kind,
            'kind',
            LocalChatSessionFailure.cleanupPending,
          ),
        ),
      );

      failDelete = false;
      final firstRetry = coordinator.retryCleanup();
      final secondRetry = coordinator.retryCleanup();
      expect(identical(firstRetry, secondRetry), isTrue);
      await Future.wait<void>(<Future<void>>[firstRetry, secondRetry]);

      expect(lifecycleCalls, 1);
      expect(coordinator.state, LocalChatSessionState.idle);
      expect(coordinator.cleanupPending, isFalse);
      expect(await privateFile.exists(), isFalse);
      expect(await database.select(database.localAttachments).get(), isEmpty);

      coordinator.openSession(
        namespace: 'account-b',
        stopLifecycleAndOutbox: () async {},
        purgeLocalData: () async {},
      );
      expect(coordinator.activeNamespace, 'account-b');
      await coordinator.logout();
    },
  );

  test(
    'DB purge failure retains a closed session and retries missing file',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final privateRoot = await Directory.systemTemp.createTemp(
        'timefit-chat047-db-retry-',
      );
      addTearDown(() => privateRoot.delete(recursive: true));
      final privateFile = await File(
        '${privateRoot.path}/attachment.bin',
      ).writeAsString('fixture');
      await _insertAttachment(database, 'attachment', privateFile.uri);
      await database.customStatement(
        "CREATE TRIGGER purge_fault BEFORE DELETE ON local_attachments BEGIN SELECT RAISE(ABORT, 'fixture fault'); END",
      );

      final coordinator = LocalChatSessionCoordinator();
      final session = coordinator.openSession(
        namespace: 'account-a',
        stopLifecycleAndOutbox: () async {},
        purgeLocalData: LogoutChatDataPurger(
          database: database,
          fileStore: IoPrivateAttachmentFileStore(privateRoot),
        ).purge,
      );
      await expectLater(coordinator.logout(), throwsA(isA<SqliteException>()));

      expect(coordinator.cleanupPending, isTrue);
      expect(await privateFile.exists(), isFalse);
      expect(
        await database.select(database.localAttachments).get(),
        hasLength(1),
      );
      await expectLater(
        session.repository.write<void>(database, () async {}),
        throwsA(isA<LocalRepositoryException>()),
      );

      await database.customStatement('DROP TRIGGER purge_fault');
      await coordinator.retryCleanup();
      expect(coordinator.state, LocalChatSessionState.idle);
      expect(await database.select(database.localAttachments).get(), isEmpty);
    },
  );

  test(
    'disposed old streams cannot deliver buffered or later events',
    () async {
      final upstream = StreamController<int>(sync: true);
      addTearDown(upstream.close);
      final values = <int>[];
      final errors = <Object>[];
      final coordinator = LocalChatSessionCoordinator();
      final session = coordinator.openSession(
        namespace: 'account-a',
        stopLifecycleAndOutbox: () async {},
        purgeLocalData: () async {},
      );
      final subscription = session.repository
          .watch(() => upstream.stream)
          .listen(values.add, onError: errors.add);
      addTearDown(subscription.cancel);
      subscription.pause();
      upstream.add(1);
      await _flushAsync();

      await coordinator.logout();
      upstream.add(2);
      subscription.resume();
      await _flushAsync();

      expect(values, isEmpty);
      expect(errors, isEmpty);
      await expectLater(
        session.repository.read(() async => 3),
        throwsA(isA<LocalRepositoryException>()),
      );
    },
  );

  test('different namespace opens only after the previous purge', () async {
    final databaseA = AppDatabase(NativeDatabase.memory());
    var databaseAClosed = false;
    addTearDown(() async {
      if (!databaseAClosed) await databaseA.close();
    });
    final coordinator = LocalChatSessionCoordinator();
    final sessionA = coordinator.openSession(
      namespace: 'account-a',
      stopLifecycleAndOutbox: () async {},
      purgeLocalData: databaseA.purgeChatData,
    );
    await sessionA.repository.write(
      databaseA,
      () => databaseA
          .into(databaseA.localConversations)
          .insert(_conversation('account-a')),
    );
    await coordinator.logout();
    expect(await databaseA.select(databaseA.localConversations).get(), isEmpty);
    await expectLater(
      sessionA.repository.read(
        () => databaseA.select(databaseA.localConversations).get(),
      ),
      throwsA(isA<LocalRepositoryException>()),
    );
    await databaseA.close();
    databaseAClosed = true;

    final databaseB = AppDatabase(NativeDatabase.memory());
    addTearDown(databaseB.close);
    final sessionB = coordinator.openSession(
      namespace: 'account-b',
      stopLifecycleAndOutbox: () async {},
      purgeLocalData: databaseB.purgeChatData,
    );
    await sessionB.repository.write(
      databaseB,
      () => databaseB
          .into(databaseB.localConversations)
          .insert(_conversation('account-b')),
    );

    expect(
      (await databaseB.select(databaseB.localConversations).get()).single.id,
      'account-b',
    );
    await coordinator.logout();
  });

  test(
    'lifecycle cleanup failure retries before purge and blocks reentry',
    () async {
      final coordinator = LocalChatSessionCoordinator();
      var lifecycleCalls = 0;
      var purgeCalls = 0;
      var failLifecycle = true;
      final retryGate = Completer<void>();
      coordinator.openSession(
        namespace: 'account-a',
        stopLifecycleAndOutbox: () async {
          lifecycleCalls += 1;
          if (failLifecycle) throw StateError('fixture lifecycle failure');
          await retryGate.future;
        },
        purgeLocalData: () async {
          purgeCalls += 1;
        },
      );

      await expectLater(coordinator.logout(), throwsStateError);
      expect(coordinator.cleanupPending, isTrue);
      expect(
        coordinator.lastFailedStage,
        LocalChatSessionCleanupStage.stopLifecycleAndOutbox,
      );
      expect(purgeCalls, 0);

      failLifecycle = false;
      final firstRetry = coordinator.retryCleanup();
      final secondRetry = coordinator.retryCleanup();
      final repeatedLogout = coordinator.logout();
      expect(identical(firstRetry, secondRetry), isTrue);
      expect(identical(firstRetry, repeatedLogout), isTrue);
      await _flushAsync();
      expect(purgeCalls, 0);
      retryGate.complete();
      await Future.wait<void>(<Future<void>>[
        firstRetry,
        secondRetry,
        repeatedLogout,
      ]);

      expect(lifecycleCalls, 2);
      expect(purgeCalls, 1);
      expect(coordinator.state, LocalChatSessionState.idle);
    },
  );

  test(
    'dispose and logout share cleanup and finish permanently disposed',
    () async {
      final coordinator = LocalChatSessionCoordinator();
      final lifecycleStarted = Completer<void>();
      final releaseLifecycle = Completer<void>();
      var purgeCalls = 0;
      coordinator.openSession(
        namespace: 'account-a',
        stopLifecycleAndOutbox: () async {
          lifecycleStarted.complete();
          await releaseLifecycle.future;
        },
        purgeLocalData: () async {
          purgeCalls += 1;
        },
      );

      final logout = coordinator.logout();
      await lifecycleStarted.future;
      final disposal = coordinator.dispose();
      expect(identical(logout, disposal), isTrue);
      releaseLifecycle.complete();
      await Future.wait<void>(<Future<void>>[logout, disposal]);

      expect(purgeCalls, 1);
      expect(coordinator.state, LocalChatSessionState.disposed);
      expect(
        () => coordinator.openSession(
          namespace: 'account-b',
          stopLifecycleAndOutbox: () async {},
          purgeLocalData: () async {},
        ),
        throwsA(
          isA<LocalChatSessionException>().having(
            (error) => error.kind,
            'kind',
            LocalChatSessionFailure.coordinatorDisposed,
          ),
        ),
      );
    },
  );
}

Future<void> _insertAttachment(AppDatabase database, String id, Uri fileUri) =>
    database
        .into(database.localAttachments)
        .insert(
          LocalAttachmentsCompanion.insert(
            localId: id,
            conversationId: 'conversation',
            clientMessageId: id,
            localFileUri: Value(fileUri.toString()),
            contentType: 'application/octet-stream',
            sha256: 'fixture-sha',
          ),
        );

LocalConversationsCompanion _conversation(String id) {
  final now = DateTime.utc(2026, 10, 29);
  return LocalConversationsCompanion.insert(
    id: id,
    serverCreatedAt: now,
    serverUpdatedAt: now,
    lastSyncedAt: now,
  );
}

final class _RecordingFileStore implements PrivateAttachmentFileStore {
  const _RecordingFileStore({
    required this.delegate,
    required this.events,
    this.fail,
  });

  final PrivateAttachmentFileStore delegate;
  final List<String> events;
  final bool Function()? fail;

  @override
  Future<void> deleteIfInsidePrivateRoot(Uri fileUri) async {
    events.add('file-delete');
    if (fail?.call() ?? false) {
      throw StateError('fixture file delete failure');
    }
    await delegate.deleteIfInsidePrivateRoot(fileUri);
  }
}

final class _ConnectionPort implements ChatConnectionLifecyclePort {
  final events = <String>[];

  @override
  Future<bool> refreshAuthentication(
    ChatLifecycleCancellation cancellation,
  ) async => true;

  @override
  Future<bool> subscribe(ChatLifecycleCancellation cancellation) async => true;

  @override
  Future<void> gapFill(ChatLifecycleCancellation cancellation) async {}

  @override
  Future<void> resumeOutbox(ChatLifecycleCancellation cancellation) async {}

  @override
  Future<void> pauseNewOutboxWork() async {
    events.add('outbox-pause');
  }

  @override
  Future<void> unsubscribe() async {
    events.add('unsubscribe');
  }

  @override
  Future<void> cleanupAfterDetach() async {}

  @override
  Future<void> cleanupAfterLogout() async {
    events.add('logout-cleanup');
  }
}

Future<void> _flushAsync() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
