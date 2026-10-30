import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';

void main() {
  for (final attachmentFails in [true, false]) {
    for (final synchronous in [true, false]) {
      test(
        '${attachmentFails ? 'attachment' : 'mutation'} cancel failure is isolated (sync: $synchronous)',
        () async {
          await _observeErrors(() async {
            final source = _CancelSource();
            addTearDown(source.close);
            final failed = attachmentFails
                ? source.attachments
                : source.mutations;
            failed.synchronousFailure = synchronous;
            failed.pending = !synchronous;
            final controller = _composer(source);
            controller.updateDraft('private draft');
            var notifications = 0;
            controller.addListener(() => notifications += 1);
            source.attachments.emit(const []);
            final before = notifications;

            controller.dispose();
            expect(source.attachments.cancelCalls, 1);
            expect(source.mutations.cancelCalls, 1);
            if (!synchronous) failed.fail();
            source.attachments.emit(const [
              ComposerAttachment(
                localId: 'late',
                contentType: 'application/pdf',
                state: ComposerAttachmentState.failed,
                bytesSent: 0,
                bytesTotal: 1,
              ),
            ]);
            source.mutations.emit(true);
            await _flush();

            expect(notifications, before);
            expect(controller.attachments, isEmpty);
            expect(controller.lastError, isNull);
            expect(controller.draft, 'private draft');
            expect(controller.canSubmit, isFalse);
            expect(failed.error.stringifications, 0);
          });
        },
      );
    }
  }

  for (final firstSync in [true, false]) {
    test(
      'both cleanup failures are consumed (first sync: $firstSync)',
      () async {
        await _observeErrors(() async {
          final source = _CancelSource();
          addTearDown(source.close);
          source.attachments
            ..synchronousFailure = firstSync
            ..pending = !firstSync;
          source.mutations
            ..synchronousFailure = !firstSync
            ..pending = firstSync;
          final controller = _composer(source);

          controller.dispose();
          if (firstSync) {
            source.mutations.fail();
          } else {
            source.attachments.fail();
          }
          await _flush();

          expect(source.attachments.cancelCalls, 1);
          expect(source.mutations.cancelCalls, 1);
          expect(source.attachments.error.stringifications, 0);
          expect(source.mutations.error.stringifications, 0);
          expect(controller.lastError, isNull);
        });
      },
    );
  }

  test(
    'reentrant and overlapping dispose cancel each subscription once',
    () async {
      await _observeErrors(() async {
        final source = _CancelSource();
        addTearDown(source.close);
        source.attachments.pending = true;
        source.mutations.pending = true;
        final controller = _composer(source);
        var reentered = false;
        source.attachments.onCancel = () {
          if (reentered) return;
          reentered = true;
          controller.dispose();
        };

        await Future.wait([
          Future<void>.sync(controller.dispose),
          Future<void>.sync(controller.dispose),
        ]);
        source.attachments.fail();
        source.mutations.fail();
        await _flush();
        controller.dispose();

        expect(reentered, isTrue);
        expect(source.attachments.cancelCalls, 1);
        expect(source.mutations.cancelCalls, 1);
      });
    },
  );

  test('never-completing cancel does not block editor disposal', () async {
    await _observeErrors(() async {
      final source = _CancelSource();
      addTearDown(source.close);
      source.attachments.pending = true;
      source.mutations.pending = true;
      final controller = _composer(source);
      controller.updateDraft('unchanged');

      controller.dispose();
      controller.dispose();
      source.attachments.emit(const []);
      source.mutations.emit(true);
      await _flush();

      expect(controller.canSubmit, isFalse);
      expect(controller.draft, 'unchanged');
      expect(source.attachments.cancelCalls, 1);
      expect(source.mutations.cancelCalls, 1);
      // No production timeout or physical-cancellation success is inferred.
    });
  });

  for (final retry in [false, true]) {
    test(
      'cancel errors preserve admitted ${retry ? 'retry' : 'submit'} and new DB session use',
      () async {
        await _observeErrors(() async {
          final database = AppDatabase(NativeDatabase.memory());
          addTearDown(() async {
            await LocalRepositorySession.forDatabase(database).dispose();
            await database.close();
          });
          final now = DateTime.utc(2026, 10, 30);
          final oldSend = SendMessage(
            database: database,
            clock: () => now,
            clientMessageId: () => 'old-message',
          );
          if (retry) {
            await oldSend.submit(conversationId: 'old', bodyText: 'old draft');
            final lease = (await database.outboxDao.claim(now, 'lease'))!;
            await database.outboxDao.finish(
              lease,
              now,
              state: 'failed_permanent',
              failures: 8,
              errorCode: 'retry_exhausted',
            );
          }
          final source = _CancelSource();
          addTearDown(source.close);
          source.attachments.pending = true;
          source.mutations.pending = true;
          final submitter = _DelayedSend(oldSend);
          final old = _composer(source, submitter: submitter);
          old.updateDraft('old draft');
          source.attachments.emit(const []);
          final Future<Object?> active = retry
              ? old.retry('old-message')
              : old.submit();

          old.dispose();
          final Future<Object?> repeated = retry
              ? old.retry('old-message')
              : old.submit();
          expect(identical(active, repeated), isTrue);
          final current = ComposerController(
            conversationId: 'current',
            submitter: SendMessage(
              database: database,
              clock: () => now,
              clientMessageId: () => 'current-message',
            ),
          );
          addTearDown(current.dispose);
          current.updateDraft('current draft');
          await current.submit();
          current.updateDraft('current unsent draft');
          var currentNotifications = 0;
          current.addListener(() => currentNotifications += 1);

          source.attachments.fail();
          source.mutations.fail();
          source.attachments.emit(const []);
          source.mutations.emit(true);
          submitter.release.complete();
          await active;
          await _flush();
          await old.submit();
          expect(await old.retry('old-message'), isFalse);

          final messages = await database.messageDao.getAll();
          final commands = await database.outboxDao.getAll();
          expect(messages, hasLength(2));
          expect(messages.map((row) => row.clientMessageId).toSet(), {
            'old-message',
            'current-message',
          });
          expect(
            messages.every(
              (row) => row.serverId == null && row.sequence == null,
            ),
            isTrue,
          );
          expect(commands, hasLength(2));
          expect(
            commands.every(
              (row) => row.state == 'queued' && row.attemptCount == 0,
            ),
            isTrue,
          );
          expect(submitter.calls, 1);
          expect(current.draft, 'current unsent draft');
          expect(currentNotifications, 0);
          expect(current.lastError, isNull);
          expect(old.lastError, isNull);
          expect(source.attachments.error.stringifications, 0);
          expect(source.mutations.error.stringifications, 0);
        });
      },
    );
  }
}

Future<void> _observeErrors(Future<void> Function() action) async {
  final zoneErrors = <Object>[];
  final actionErrors = <Object>[];
  final printed = <String>[];
  await runZonedGuarded<Future<void>>(
    () async {
      try {
        await action();
      } on Object catch (error) {
        actionErrors.add(error);
      }
      await _flush();
    },
    (error, _) => zoneErrors.add(error),
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) => printed.add(line),
    ),
  );
  expect(actionErrors, isEmpty, reason: 'no synchronous disposal/test failure');
  expect(zoneErrors, isEmpty, reason: 'no unhandled cancellation Future error');
  expect(printed, isEmpty, reason: 'no raw fallback logging');
}

ComposerController _composer(
  _CancelSource source, {
  TextMessageSubmitter? submitter,
}) => ComposerController(
  conversationId: 'old',
  attachmentClientMessageId: 'attachment-draft',
  attachmentSource: source,
  submitter: submitter ?? _NoWriteSubmitter(),
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final class _PrivateCancelError implements Exception {
  int stringifications = 0;
  @override
  String toString() {
    stringifications += 1;
    return 'synthetic-private-file.pdf?token=synthetic-canary';
  }
}

final class _CancelStream<T> extends Stream<T> {
  final controller = StreamController<T>.broadcast(sync: true);
  final gate = Completer<void>();
  final error = _PrivateCancelError();
  final subscriptions = <StreamSubscription<T>>[];
  bool synchronousFailure = false;
  bool pending = false;
  int cancelCalls = 0;
  void Function()? onCancel;

  void emit(T value) => controller.add(value);
  void fail() => gate.completeError(error);

  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final delegate = controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    subscriptions.add(delegate);
    return _CancelSubscription(delegate, this);
  }

  Future<void> close() async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await controller.close();
  }
}

final class _CancelSubscription<T> implements StreamSubscription<T> {
  _CancelSubscription(this.delegate, this.owner);
  final StreamSubscription<T> delegate;
  final _CancelStream<T> owner;

  @override
  Future<void> cancel() {
    owner.cancelCalls += 1;
    owner.onCancel?.call();
    if (owner.synchronousFailure) throw owner.error;
    if (owner.pending) return owner.gate.future.then((_) => delegate.cancel());
    return delegate.cancel();
  }

  @override
  void onData(void Function(T)? handleData) => delegate.onData(handleData);
  @override
  void onDone(void Function()? handleDone) => delegate.onDone(handleDone);
  @override
  void onError(Function? handleError) => delegate.onError(handleError);
  @override
  void pause([Future<void>? resumeSignal]) => delegate.pause(resumeSignal);
  @override
  void resume() => delegate.resume();
  @override
  bool get isPaused => delegate.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) => delegate.asFuture(futureValue);
}

final class _CancelSource
    implements AttachmentComposerSource, AttachmentDraftMutationEvents {
  final attachments = _CancelStream<List<ComposerAttachment>>();
  final mutations = _CancelStream<bool>();

  @override
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  }) => attachments;
  @override
  Stream<bool> watchAttachmentDraftMutating(String clientMessageId) =>
      mutations;
  @override
  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) async {}
  Future<void> close() async {
    await attachments.close();
    await mutations.close();
  }
}

final class _NoWriteSubmitter implements TextMessageSubmitter {
  @override
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) => throw StateError('not expected');
  @override
  Future<bool> retry(String commandId) => throw StateError('not expected');
}

final class _DelayedSend implements TextMessageSubmitter {
  _DelayedSend(this.delegate);
  final SendMessage delegate;
  final release = Completer<void>();
  int calls = 0;
  @override
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) {
    calls += 1;
    return release.future.then(
      (_) =>
          delegate.submit(conversationId: conversationId, bodyText: bodyText),
    );
  }

  @override
  Future<bool> retry(String commandId) {
    calls += 1;
    return release.future.then((_) => delegate.retry(commandId));
  }
}
