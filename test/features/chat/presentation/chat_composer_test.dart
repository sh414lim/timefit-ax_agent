import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/domain/chat_message.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';
import 'package:timefit_native/features/chat/presentation/widgets/chat_composer.dart';

void main() {
  testWidgets('blank is disabled and counter starts at 10000', (
    WidgetTester tester,
  ) async {
    final _FakeSubmitter submitter = _FakeSubmitter();
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: submitter,
    );
    addTearDown(controller.dispose);
    await _pumpComposer(tester, controller);

    expect(_sendButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'a' * 9999);
    await tester.pump();
    expect(find.text('9999/12000'), findsNothing);
    await tester.enterText(find.byType(TextField), 'a' * 10000);
    await tester.pump();
    expect(find.text('10000/12000'), findsOneWidget);
    expect(_sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('input is enforced at 12000 characters', (
    WidgetTester tester,
  ) async {
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: _FakeSubmitter(),
    );
    addTearDown(controller.dispose);
    await _pumpComposer(tester, controller);

    await tester.enterText(find.byType(TextField), 'a' * 12001);
    await tester.pump();

    expect(controller.characterCount, 12000);
    expect(find.text('12000/12000'), findsOneWidget);
    expect(_sendButton(tester).onPressed, isNotNull);
  });

  test('controller rejects a 12001 character draft', () async {
    final _FakeSubmitter submitter = _FakeSubmitter();
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: submitter,
    );
    addTearDown(controller.dispose);
    controller.updateDraft('a' * 12001);

    expect(controller.canSubmit, isFalse);
    await controller.submit();
    expect(submitter.submitCalls, 0);
  });

  test('double submit shares one future and creates one command', () async {
    final Completer<LocalTextCommand> pending = Completer<LocalTextCommand>();
    final _FakeSubmitter submitter = _FakeSubmitter(pending: pending);
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: submitter,
    );
    addTearDown(controller.dispose);
    controller.updateDraft('message');

    final Future<void> first = controller.submit();
    final Future<void> second = controller.submit();

    expect(identical(first, second), isTrue);
    expect(submitter.submitCalls, 1);
    pending.complete(_command(body: 'message'));
    await first;
    expect(controller.draft, isEmpty);
  });

  test('late success never clears text typed after submission', () async {
    final Completer<LocalTextCommand> pending = Completer<LocalTextCommand>();
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: _FakeSubmitter(pending: pending),
    );
    addTearDown(controller.dispose);
    controller.updateDraft('submitted');

    final Future<void> submission = controller.submit();
    controller.updateDraft('new draft');
    pending.complete(_command(body: 'submitted'));
    await submission;

    expect(controller.draft, 'new draft');
  });

  test('late failure never attaches an error to a newer draft', () async {
    final Completer<LocalTextCommand> pending = Completer<LocalTextCommand>();
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: _FakeSubmitter(pending: pending),
    );
    addTearDown(controller.dispose);
    controller.updateDraft('submitted');

    final Future<void> submission = controller.submit();
    controller.updateDraft('new draft');
    pending.completeError(StateError('old failure'));
    await expectLater(submission, throwsStateError);

    expect(controller.draft, 'new draft');
    expect(controller.lastError, isNull);
  });

  test('local transaction success clears the unchanged draft', () async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: SendMessage(
        database: database,
        clock: () => DateTime.utc(2026, 10, 20),
        clientMessageId: () => 'client-1',
      ),
    );
    addTearDown(controller.dispose);
    controller.updateDraft('persist me');

    await controller.submit();

    expect(controller.draft, isEmpty);
    expect(await database.messageDao.getAll(), hasLength(1));
    expect(await database.outboxDao.getAll(), hasLength(1));
  });

  test('local transaction failure preserves input and creates no rows', () async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customStatement(
      "CREATE TRIGGER reject_outbox BEFORE INSERT ON outbox_commands BEGIN SELECT RAISE(ABORT, 'fixture'); END",
    );
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: SendMessage(
        database: database,
        clock: () => DateTime.utc(2026, 10, 20),
        clientMessageId: () => 'client-1',
      ),
    );
    addTearDown(controller.dispose);
    controller.updateDraft('keep me');

    await expectLater(controller.submit(), throwsA(isA<SqliteException>()));

    expect(controller.draft, 'keep me');
    expect(controller.lastError, isA<SqliteException>());
    expect(await database.messageDao.getAll(), isEmpty);
    expect(await database.outboxDao.getAll(), isEmpty);
  });

  testWidgets('multiline composer remains visible with keyboard inset', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: _FakeSubmitter(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatComposer(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      List<String>.filled(8, 'multiline').join('\n'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatComposer), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ChatComposer)).height, lessThan(200));
  });

  test('retry delegates the same client message identity', () async {
    final _FakeSubmitter submitter = _FakeSubmitter();
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: submitter,
    );
    addTearDown(controller.dispose);

    expect(await controller.retry('stable-client-id'), isTrue);
    expect(submitter.retriedIds, <String>['stable-client-id']);
  });

  testWidgets('failed bubble retries its existing client identity', (
    WidgetTester tester,
  ) async {
    final _FakeSubmitter submitter = _FakeSubmitter();
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: submitter,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          title: 'retry',
          messages: Stream<List<ChatMessage>>.value(<ChatMessage>[
            ChatMessage(
              clientMessageId: 'failed-client-id',
              sequence: null,
              body: 'retry me',
              displayedAt: DateTime.utc(2026, 10, 20),
              isMine: true,
              deliveryState: MessageDeliveryState.failed,
            ),
          ]),
          composerController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('재시도'));
    await tester.pump();

    expect(submitter.retriedIds, <String>['failed-client-id']);
  });

  testWidgets('received failed message never exposes retry', (
    WidgetTester tester,
  ) async {
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: _FakeSubmitter(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          title: 'retry',
          messages: Stream<List<ChatMessage>>.value(<ChatMessage>[
            ChatMessage(
              clientMessageId: 'received-id',
              sequence: null,
              body: 'system failure',
              displayedAt: DateTime.utc(2026, 10, 20),
              isMine: false,
              deliveryState: MessageDeliveryState.failed,
            ),
          ]),
          composerController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('재시도'), findsNothing);
  });

  testWidgets('rapid send button taps create one submission', (
    WidgetTester tester,
  ) async {
    final Completer<LocalTextCommand> pending = Completer<LocalTextCommand>();
    final _FakeSubmitter submitter = _FakeSubmitter(pending: pending);
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: submitter,
    );
    addTearDown(controller.dispose);
    await _pumpComposer(tester, controller);
    await tester.enterText(find.byType(TextField), 'one command');
    await tester.pump();

    await tester.tap(find.byType(IconButton));
    await tester.tap(find.byType(IconButton));
    expect(submitter.submitCalls, 1);

    pending.complete(_command(body: 'one command'));
    await tester.pumpAndSettle();
    expect(controller.draft, isEmpty);
  });

  test('composer retry requeues the existing outbox identity', () async {
    final DateTime now = DateTime.utc(2026, 10, 20);
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final ComposerController controller = ComposerController(
      conversationId: 'conversation',
      submitter: SendMessage(
        database: database,
        clock: () => now,
        clientMessageId: () => 'stable-client-id',
      ),
    );
    addTearDown(controller.dispose);
    controller.updateDraft('retry me');
    await controller.submit();
    final lease = (await database.outboxDao.claim(now, 'lease'))!;
    await database.outboxDao.finish(
      lease,
      now,
      state: 'failed_permanent',
      failures: 8,
      errorCode: 'retry_exhausted',
    );

    expect(await controller.retry('stable-client-id'), isTrue);
    final stored = (await database.outboxDao.getAll()).single;
    expect(stored.id, 'stable-client-id');
    expect(stored.clientRequestId, 'stable-client-id');
    expect(stored.state, 'queued');
  });
}

IconButton _sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

Future<void> _pumpComposer(
  WidgetTester tester,
  ComposerController controller,
) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ChatComposer(controller: controller),
      ),
    ),
  ),
);

LocalTextCommand _command({required String body}) => LocalTextCommand(
  id: 'client-1',
  conversationId: 'conversation',
  bodyText: body,
);

final class _FakeSubmitter implements TextMessageSubmitter {
  _FakeSubmitter({this.pending});

  final Completer<LocalTextCommand>? pending;
  int submitCalls = 0;
  final List<String> retriedIds = <String>[];

  @override
  Future<bool> retry(String commandId) async {
    retriedIds.add(commandId);
    return true;
  }

  @override
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) {
    submitCalls += 1;
    return pending?.future ??
        Future<LocalTextCommand>.value(_command(body: bodyText));
  }
}
