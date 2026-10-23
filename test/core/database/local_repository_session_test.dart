import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';

void main() {
  for (final bufferError in [false, true]) {
    test(
      'paused ${bufferError ? 'error' : 'data'} is discarded after dispose and resume',
      () async {
        final session = LocalRepositorySession();
        final upstream = StreamController<int>(sync: true);
        addTearDown(upstream.close);
        final values = <int>[];
        final errors = <Object>[];
        final done = Completer<void>();
        final subscription = session
            .watch(() => upstream.stream)
            .listen(
              values.add,
              onError: (Object error) => errors.add(error),
              onDone: done.complete,
            );
        subscription.pause();
        if (bufferError) {
          upstream.addError(StateError('buffered private error'));
        } else {
          upstream.add(42);
        }
        // Let the upstream event reach the paused output controller's buffer.
        await Future<void>.delayed(Duration.zero);
        await session.dispose();
        subscription.resume();
        await done.future;
        expect(values, isEmpty);
        expect(errors, isEmpty);
        await subscription.cancel();
      },
    );
  }

  test(
    'pause and resume in an active session preserves data and typed error',
    () async {
      final session = LocalRepositorySession();
      addTearDown(session.dispose);
      final upstream = StreamController<int>(sync: true);
      addTearDown(upstream.close);
      final values = <int>[];
      final errors = <Object>[];
      final delivered = Completer<void>();
      final subscription = session
          .watch(() => upstream.stream)
          .listen(
            values.add,
            onError: (Object error) {
              errors.add(error);
              delivered.complete();
            },
          );
      subscription.pause();
      upstream.add(42);
      upstream.addError(StateError('private'));
      await Future<void>.delayed(Duration.zero);
      subscription.resume();
      await delivered.future;
      expect(values, [42]);
      expect(errors.single, isA<LocalRepositoryException>());
      await subscription.cancel();
    },
  );

  test(
    'attachment mutation boundary releases after success and failure',
    () async {
      final LocalRepositorySession session = LocalRepositorySession();
      addTearDown(session.dispose);

      await session.withAttachmentDraftMutation('draft', () async {});
      expect(session.isAttachmentDraftMutating('draft'), isFalse);

      await expectLater(
        session.withAttachmentDraftMutation<void>(
          'draft',
          () => Future<void>.error(StateError('copy_failed')),
        ),
        throwsStateError,
      );
      expect(session.isAttachmentDraftMutating('draft'), isFalse);
    },
  );

  test(
    'dispose waits for attachment mutation and leaves no active lock',
    () async {
      final LocalRepositorySession session = LocalRepositorySession();
      final Completer<void> started = Completer<void>();
      final Completer<void> release = Completer<void>();
      final Future<void> mutation = session.withAttachmentDraftMutation(
        'draft',
        () {
          started.complete();
          return release.future;
        },
      );
      await started.future;
      expect(session.isAttachmentDraftMutating('draft'), isTrue);

      var disposed = false;
      final Future<void> disposal = session.dispose().then(
        (_) => disposed = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(disposed, isFalse);
      release.complete();
      await mutation;
      await disposal;
      expect(session.isAttachmentDraftMutating('draft'), isFalse);
    },
  );
}
