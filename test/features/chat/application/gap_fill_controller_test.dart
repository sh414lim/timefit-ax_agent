import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/message_dao.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/gap_fill_controller.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/drift_gap_fill_persistence.dart';

final _now = DateTime.utc(2026, 10, 27);

CanonicalLocalMessage _message(
  int sequence, {
  String conversationId = 'one',
  String? clientMessageId,
  String? serverId,
  String body = 'body',
}) => CanonicalLocalMessage(
  serverId: serverId ?? 'server-$sequence',
  conversationId: conversationId,
  clientMessageId: clientMessageId ?? 'client-$sequence',
  sequence: sequence,
  senderKind: 'user',
  bodyText: body,
  messageKind: 'text',
  serverCreatedAt: _now.add(Duration(seconds: sequence)),
);

GapFillPage _page(
  List<CanonicalLocalMessage> messages, {
  String conversationId = 'one',
  int? latestSequence,
}) => GapFillPage(
  conversationId: conversationId,
  messages: messages,
  latestSequence:
      latestSequence ?? (messages.isEmpty ? 0 : messages.last.sequence),
);

final class _FakePersistence implements GapFillPersistence {
  _FakePersistence({this.latest = 0, this.advanceLatest = true});

  int latest;
  final bool advanceLatest;
  Object? readError;
  Object? persistError;
  int readCount = 0;
  int persistCount = 0;
  final stored = <int, CanonicalLocalMessage>{};

  @override
  Future<int> readLatestSequence(String conversationId) async {
    readCount += 1;
    if (readError case final error?) throw error;
    return latest;
  }

  @override
  Future<void> persist(
    GapFillRequest request,
    GapFillPage originalPage,
    List<CanonicalLocalMessage> acceptedMessages,
  ) async {
    persistCount += 1;
    if (persistError case final error?) throw error;
    if (request.isCancelled) throw StateError('cancelled');
    for (final message in acceptedMessages) {
      stored[message.sequence] = message;
      if (advanceLatest) latest = message.sequence;
    }
  }
}

final class _PausedReadPersistence implements GapFillPersistence {
  _PausedReadPersistence({required this.latest, this.advanceLatest = true});

  int latest;
  final bool advanceLatest;
  final readEntered = Completer<void>();
  final readResume = Completer<int>();
  int readCount = 0;
  int persistCount = 0;
  final stored = <int, CanonicalLocalMessage>{};

  @override
  Future<int> readLatestSequence(String conversationId) {
    readCount += 1;
    if (readCount == 1) {
      readEntered.complete();
      return readResume.future;
    }
    return Future<int>.value(latest);
  }

  @override
  Future<void> persist(
    GapFillRequest request,
    GapFillPage originalPage,
    List<CanonicalLocalMessage> acceptedMessages,
  ) async {
    persistCount += 1;
    if (request.isCancelled) throw StateError('cancelled');
    for (final message in acceptedMessages) {
      stored[message.sequence] = message;
      if (advanceLatest) latest = message.sequence;
    }
  }
}

final class _QueuedSource implements GapFillSource {
  final requests = <GapFillRequest>[];
  final _responses = <Future<GapFillPage> Function()>[];

  void enqueue(FutureOr<GapFillPage> page) {
    _responses.add(() => Future<GapFillPage>.value(page));
  }

  void enqueueError(Object error) {
    _responses.add(() => Future<GapFillPage>.error(error));
  }

  @override
  Future<GapFillPage> loadAfter(GapFillRequest request) {
    requests.add(request);
    if (_responses.isEmpty) throw StateError('missing fixture response');
    return _responses.removeAt(0)();
  }
}

final class _PauseInsert extends QueryInterceptor {
  bool enabled = false;
  final entered = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (enabled && statement.contains('local_messages')) {
      enabled = false;
      entered.complete();
      await resume.future;
    }
    return super.runInsert(executor, statement, args);
  }
}

void main() {
  group('GapFillController ports', () {
    late _FakePersistence persistence;
    late _QueuedSource source;
    late GapFillController controller;

    setUp(() {
      persistence = _FakePersistence(latest: 4);
      source = _QueuedSource();
      controller = GapFillController(
        source: source,
        persistence: persistence,
        conversationId: 'one',
      );
    });

    tearDown(() => controller.dispose());

    test('events 5 3 3 8 coalesce and store 5 through 8 once', () async {
      source.enqueue(
        _page([
          for (var sequence = 5; sequence <= 8; sequence++) _message(sequence),
        ]),
      );

      final results = await Future.wait([
        controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        ),
        controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 3),
        ),
        controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 3),
        ),
        controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 8),
        ),
      ]);

      expect(results, everyElement(GapFillResult.completed));
      expect(source.requests, hasLength(1));
      expect(source.requests.single.afterSequence, 4);
      expect(persistence.stored.keys, [5, 6, 7, 8]);
      expect(persistence.persistCount, 1);
    });

    test(
      'same satisfied hint three times performs no duplicate fetch',
      () async {
        source.enqueue(_page([_message(5)]));
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        );
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        );
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        );

        expect(source.requests, hasLength(1));
        expect(persistence.persistCount, 1);
        expect(persistence.stored.keys, [5]);
      },
    );

    test('new in-flight hint drains one follow-up request', () async {
      final first = Completer<GapFillPage>();
      source.enqueue(first.future);
      source.enqueue(_page([_message(6), _message(7), _message(8)]));

      final loading = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 5),
      );
      await Future<void>.delayed(Duration.zero);
      final coalesced = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 8),
      );
      first.complete(_page([_message(5)]));

      expect(await loading, GapFillResult.completed);
      expect(await coalesced, GapFillResult.completed);
      expect(source.requests.map((request) => request.afterSequence), [4, 5]);
      expect(persistence.stored.keys, [5, 6, 7, 8]);
    });

    test('higher hint joining a satisfied DB read is drained', () async {
      controller.dispose();
      final paused = _PausedReadPersistence(latest: 5);
      source = _QueuedSource()
        ..enqueue(_page([_message(6), _message(7), _message(8)]));
      controller = GapFillController(
        source: source,
        persistence: paused,
        conversationId: 'one',
      );

      final lower = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 5),
      );
      await paused.readEntered.future;
      final higher = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 8),
      );
      paused.readResume.complete(5);

      expect(await lower, GapFillResult.completed);
      expect(await higher, GapFillResult.completed);
      expect(source.requests.map((request) => request.afterSequence), [5]);
      expect(paused.stored.keys, [6, 7, 8]);
      expect(paused.readCount, 2);
      expect(paused.persistCount, 1);
    });

    test('multiple hints joining a DB read coalesce to the highest', () async {
      controller.dispose();
      final paused = _PausedReadPersistence(latest: 5);
      source = _QueuedSource()
        ..enqueue(_page([_message(6), _message(7), _message(8)]));
      controller = GapFillController(
        source: source,
        persistence: paused,
        conversationId: 'one',
      );

      final results = <Future<GapFillResult>>[
        controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        ),
      ];
      await paused.readEntered.future;
      results.addAll(<Future<GapFillResult>>[
        controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 6),
        ),
        controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 7),
        ),
        controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 8),
        ),
      ]);
      paused.readResume.complete(5);

      expect(await Future.wait(results), everyElement(GapFillResult.completed));
      expect(source.requests.map((request) => request.afterSequence), [5]);
      expect(paused.stored.keys, [6, 7, 8]);
      expect(paused.persistCount, 1);
    });

    test('conversation switch cancels hints waiting on a DB read', () async {
      controller.dispose();
      final paused = _PausedReadPersistence(latest: 5);
      source = _QueuedSource();
      controller = GapFillController(
        source: source,
        persistence: paused,
        conversationId: 'one',
      );

      final lower = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 5),
      );
      await paused.readEntered.future;
      final higher = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 8),
      );
      controller.switchConversation('two');
      paused.readResume.complete(5);

      expect(await lower, GapFillResult.cancelled);
      expect(await higher, GapFillResult.cancelled);
      expect(source.requests, isEmpty);
      expect(paused.stored, isEmpty);
      expect(controller.state.conversationId, 'two');
    });

    test('joined higher hint still fails closed on no DB progress', () async {
      controller.dispose();
      final paused = _PausedReadPersistence(latest: 5, advanceLatest: false);
      source = _QueuedSource()
        ..enqueue(_page([_message(6), _message(7), _message(8)]));
      controller = GapFillController(
        source: source,
        persistence: paused,
        conversationId: 'one',
      );

      final lower = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 5),
      );
      await paused.readEntered.future;
      final higher = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 8),
      );
      paused.readResume.complete(5);

      expect(await lower, GapFillResult.failed);
      expect(await higher, GapFillResult.failed);
      expect(controller.state.failure, GapFillFailure.persistenceFailed);
      expect(source.requests.map((request) => request.afterSequence), [5]);
      expect(paused.persistCount, 1);
      expect(paused.stored.keys, [6, 7, 8]);
    });

    test('hole persists only the contiguous prefix then refetches', () async {
      source.enqueue(_page([_message(5), _message(7)], latestSequence: 8));
      source.enqueue(_page([_message(6), _message(7), _message(8)]));

      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 8),
        ),
        GapFillResult.completed,
      );
      expect(source.requests.map((request) => request.afterSequence), [4, 5]);
      expect(persistence.stored.keys, [5, 6, 7, 8]);
      expect(persistence.persistCount, 2);
    });

    test('first-sequence hole and empty no-progress never persist', () async {
      source.enqueue(_page([_message(6), _message(7)], latestSequence: 8));
      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 8),
        ),
        GapFillResult.failed,
      );
      expect(controller.state.failure, GapFillFailure.invalidPage);
      expect(persistence.stored, isEmpty);

      source.enqueue(_page([], latestSequence: 8));
      expect(await controller.retry(), GapFillResult.failed);
      expect(controller.state.failure, GapFillFailure.invalidPage);
      expect(persistence.stored, isEmpty);
      expect(persistence.persistCount, 0);
    });

    test('successful persistence must advance before another fetch', () async {
      controller.dispose();
      persistence = _FakePersistence(latest: 4, advanceLatest: false);
      source = _QueuedSource()..enqueue(_page([_message(5)]));
      controller = GapFillController(
        source: source,
        persistence: persistence,
        conversationId: 'one',
      );

      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        ),
        GapFillResult.failed,
      );
      expect(controller.state.failure, GapFillFailure.persistenceFailed);
      expect(source.requests, hasLength(1));
      expect(persistence.persistCount, 1);
    });

    test('canonical duplicates collapse but conflicts fail closed', () async {
      final five = _message(5);
      source.enqueue(_page([five, five]));
      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        ),
        GapFillResult.completed,
      );
      expect(persistence.stored.keys, [5]);

      source.enqueue(
        _page([_message(6, body: 'first'), _message(6, body: 'conflict')]),
      );
      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 6),
        ),
        GapFillResult.failed,
      );
      expect(controller.state.failure, GapFillFailure.invalidPage);
      expect(persistence.stored.keys, [5]);
      expect(persistence.persistCount, 1);
    });

    test(
      'source and persistence errors are retryable without partial state',
      () async {
        source.enqueueError(StateError('offline'));
        expect(
          await controller.onHint(
            const GapFillHint(conversationId: 'one', sequence: 5),
          ),
          GapFillResult.failed,
        );
        expect(controller.state.failure, GapFillFailure.sourceUnavailable);

        persistence.persistError = StateError('db');
        source.enqueue(_page([_message(5)]));
        expect(await controller.retry(), GapFillResult.failed);
        expect(controller.state.failure, GapFillFailure.persistenceFailed);
        expect(persistence.stored, isEmpty);

        persistence.persistError = null;
        source.enqueue(_page([_message(5)]));
        expect(await controller.retry(), GapFillResult.completed);
        expect(persistence.stored.keys, [5]);
      },
    );

    test(
      'invalid hint is ignored without source or persistence access',
      () async {
        expect(
          await controller.onHint(
            const GapFillHint(conversationId: '', sequence: 8),
          ),
          GapFillResult.ignored,
        );
        expect(
          await controller.onHint(
            const GapFillHint(conversationId: 'other', sequence: 8),
          ),
          GapFillResult.ignored,
        );
        expect(
          await controller.onHint(
            const GapFillHint(conversationId: 'one', sequence: 0),
          ),
          GapFillResult.ignored,
        );
        expect(source.requests, isEmpty);
        expect(persistence.readCount, 0);
        expect(persistence.persistCount, 0);
      },
    );

    test('latest-sequence read failure never calls source', () async {
      persistence.readError = StateError('db read');

      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        ),
        GapFillResult.failed,
      );
      expect(controller.state.failure, GapFillFailure.persistenceFailed);
      expect(source.requests, isEmpty);
      expect(persistence.persistCount, 0);
    });

    test(
      'conversation switch fences a late response and starts fresh',
      () async {
        final late = Completer<GapFillPage>();
        source.enqueue(late.future);
        final old = controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        );
        await Future<void>.delayed(Duration.zero);
        controller.switchConversation('two');
        late.complete(_page([_message(5)]));

        expect(await old, GapFillResult.cancelled);
        expect(persistence.stored, isEmpty);
        expect(controller.state.conversationId, 'two');
      },
    );
  });

  group('DriftGapFillPersistence', () {
    late AppDatabase database;
    late LocalRepositorySession session;
    late DriftGapFillPersistence persistence;
    late _QueuedSource source;
    late GapFillController controller;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      session = LocalRepositorySession.forDatabase(database);
      persistence = DriftGapFillPersistence(
        database: database,
        session: session,
      );
      source = _QueuedSource();
      controller = GapFillController(
        source: source,
        persistence: persistence,
        conversationId: 'one',
      );
    });

    tearDown(() async {
      controller.dispose();
      await session.dispose();
      await database.close();
    });

    Future<void> seedThrough(int latest) async {
      for (var sequence = 1; sequence <= latest; sequence++) {
        await database.messageDao.upsertCanonical(
          _message(sequence),
          fallbackLocalId: 'seed-$sequence',
          fallbackClientCreatedAt: _now,
        );
      }
    }

    test('local sequence 4 signal 8 atomically stores 5 through 8', () async {
      await seedThrough(4);
      source.enqueue(
        _page([
          for (var sequence = 5; sequence <= 8; sequence++) _message(sequence),
        ]),
      );

      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 8),
        ),
        GapFillResult.completed,
      );
      final rows = await database.messageDao.readTimeline('one');
      expect(rows.map((row) => row.sequence), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(source.requests.single.afterSequence, 4);
    });

    test(
      'existing local sequence hole resumes from its contiguous prefix',
      () async {
        for (final sequence in [1, 2, 4]) {
          await database.messageDao.upsertCanonical(
            _message(sequence),
            fallbackLocalId: 'seed-$sequence',
            fallbackClientCreatedAt: _now,
          );
        }
        source.enqueue(
          _page([_message(3), _message(4), _message(5)], latestSequence: 5),
        );

        expect(
          await controller.onHint(
            const GapFillHint(conversationId: 'one', sequence: 5),
          ),
          GapFillResult.completed,
        );
        expect(source.requests.single.afterSequence, 2);
        expect(
          (await database.messageDao.readTimeline(
            'one',
          )).map((row) => row.sequence),
          [1, 2, 3, 4, 5],
        );
      },
    );

    test('failed page insert rolls back every canonical row', () async {
      await seedThrough(4);
      await database.customStatement(
        "CREATE TRIGGER fail_gap BEFORE INSERT ON local_messages WHEN NEW.sequence = 6 BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      source.enqueue(
        _page([_message(5), _message(6), _message(7), _message(8)]),
      );

      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 8),
        ),
        GapFillResult.failed,
      );
      expect(controller.state.failure, GapFillFailure.persistenceFailed);
      expect(
        (await database.messageDao.readTimeline(
          'one',
        )).map((row) => row.sequence),
        [1, 2, 3, 4],
      );
    });

    test('own-send race converges pending row and outbox command', () async {
      await seedThrough(4);
      final send = SendMessage(
        database: database,
        session: session,
        clock: () => _now,
        clientMessageId: () => 'client-5',
      );
      await send.submit(conversationId: 'one', bodyText: 'own body');
      source.enqueue(_page([_message(5, body: 'own body')]));

      expect(
        await controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 5),
        ),
        GapFillResult.completed,
      );
      final rows = await database.messageDao.readTimeline('one');
      expect(rows, hasLength(5));
      final own = rows.singleWhere((row) => row.sequence == 5);
      expect(own.localId, 'client-5');
      expect(own.serverId, 'server-5');
      expect(own.deliveryState, 'sent');
      expect((await database.outboxDao.getAll()).single.state, 'completed');
    });

    test(
      'unsupported local command conflict rolls back canonical write',
      () async {
        await seedThrough(4);
        await database.outboxDao.enqueueMessage(
          LocalMessagesCompanion.insert(
            localId: 'client-5',
            conversationId: 'one',
            clientMessageId: 'client-5',
            senderKind: 'user',
            bodyText: const Value('own body'),
            messageKind: 'mixed',
            clientCreatedAt: _now,
            deliveryState: const Value('uploading'),
          ),
          OutboxCommandsCompanion.insert(
            id: 'client-5',
            commandType: 'local_send_message_v2',
            aggregateId: 'one',
            clientRequestId: 'client-5',
            payloadJson: '{}',
            nextAttemptAt: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
        source.enqueue(_page([_message(5, body: 'own body')]));

        expect(
          await controller.onHint(
            const GapFillHint(conversationId: 'one', sequence: 5),
          ),
          GapFillResult.failed,
        );
        expect(controller.state.failure, GapFillFailure.persistenceFailed);
        final local = (await database.messageDao.getAll()).singleWhere(
          (row) => row.localId == 'client-5',
        );
        expect(local.serverId, isNull);
        expect(local.sequence, isNull);
        expect(local.deliveryState, 'uploading');
        expect((await database.outboxDao.getAll()).single.state, 'queued');
      },
    );

    test(
      'conversation switch rolls back a paused old write and keeps new run',
      () async {
        controller.dispose();
        await session.dispose();
        await database.close();

        final pause = _PauseInsert()..enabled = true;
        database = AppDatabase(NativeDatabase.memory().interceptWith(pause));
        session = LocalRepositorySession.forDatabase(database);
        persistence = DriftGapFillPersistence(
          database: database,
          session: session,
        );
        source = _QueuedSource()..enqueue(_page([_message(1)]));
        controller = GapFillController(
          source: source,
          persistence: persistence,
          conversationId: 'one',
        );

        final old = controller.onHint(
          const GapFillHint(conversationId: 'one', sequence: 1),
        );
        await pause.entered.future;
        controller.switchConversation('two');
        source.enqueue(
          _page([_message(1, conversationId: 'two')], conversationId: 'two'),
        );
        final fresh = controller.onHint(
          const GapFillHint(conversationId: 'two', sequence: 1),
        );
        pause.resume.complete();

        expect(await old, GapFillResult.cancelled);
        expect(await fresh, GapFillResult.completed);
        expect(await database.messageDao.readTimeline('one'), isEmpty);
        final newRows = await database.messageDao.readTimeline('two');
        expect(newRows, hasLength(1));
        expect(newRows.single.sequence, 1);
        expect(newRows.single.conversationId, 'two');
      },
    );

    test('session disposal fences a paused canonical write', () async {
      controller.dispose();
      await session.dispose();
      await database.close();

      final pause = _PauseInsert()..enabled = true;
      database = AppDatabase(NativeDatabase.memory().interceptWith(pause));
      session = LocalRepositorySession.forDatabase(database);
      persistence = DriftGapFillPersistence(
        database: database,
        session: session,
      );
      source = _QueuedSource()..enqueue(_page([_message(1)]));
      controller = GapFillController(
        source: source,
        persistence: persistence,
        conversationId: 'one',
      );

      final filling = controller.onHint(
        const GapFillHint(conversationId: 'one', sequence: 1),
      );
      await pause.entered.future;
      final disposing = session.dispose();
      controller.dispose();
      pause.resume.complete();
      await disposing;

      expect(await filling, GapFillResult.cancelled);
      expect(await database.messageDao.getAll(), isEmpty);
    });
  });
}
