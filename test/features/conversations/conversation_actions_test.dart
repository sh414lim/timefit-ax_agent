import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/conversations/application/conversation_actions.dart';

void main() {
  test('title trims, maps blank to null, and rejects 121 graphemes', () {
    expect(ConversationTitle.normalize('  직접 입력  '), '직접 입력');
    expect(ConversationTitle.normalize('   \n '), isNull);
    expect(
      () => ConversationTitle.normalize(List<String>.filled(121, '가').join()),
      throwsA(
        isA<ConversationTitleException>().having(
          (error) => error.failure,
          'failure',
          ConversationTitleFailure.tooLong,
        ),
      ),
    );
  });

  test('title counts composed characters and ZWJ emoji as graphemes', () {
    const String combiningCharacter = 'e\u0301';
    const String familyEmoji = '👩‍👩‍👧‍👦';

    final String combining120 = List<String>.filled(
      120,
      combiningCharacter,
    ).join();
    final String emoji120 = List<String>.filled(120, familyEmoji).join();
    expect(ConversationTitle.normalize(combining120), combining120);
    expect(ConversationTitle.normalize(emoji120), emoji120);

    for (final String value in <String>[
      combining120 + combiningCharacter,
      emoji120 + familyEmoji,
    ]) {
      expect(
        () => ConversationTitle.normalize(value),
        throwsA(
          isA<ConversationTitleException>().having(
            (ConversationTitleException error) => error.failure,
            'failure',
            ConversationTitleFailure.tooLong,
          ),
        ),
      );
    }
  });

  testWidgets('UI and domain share the visible character boundary', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextFormField(
            controller: controller,
            maxLength: ConversationTitle.maximumCharacters,
          ),
        ),
      ),
    );

    for (final String grapheme in <String>['e\u0301', '👩‍👩‍👧‍👦']) {
      final String atLimit = List<String>.filled(120, grapheme).join();
      await tester.enterText(find.byType(TextFormField), atLimit);
      await tester.pump();
      expect(controller.text, atLimit);
      expect(ConversationTitle.normalize(controller.text), atLimit);

      await tester.enterText(find.byType(TextFormField), atLimit + grapheme);
      await tester.pump();
      expect(controller.text, atLimit);
    }
  });

  test(
    'rename sends normalized values and fences duplicate submission',
    () async {
      final _FakeActionsRepository repository = _FakeActionsRepository(
        renameCompleter: Completer<void>(),
      );
      final ConversationActions actions = ConversationActions(
        repository: repository,
      );

      final Future<bool> first = actions.rename('conversation-1', '  이름  ');
      final Future<bool> duplicate = actions.rename('conversation-1', '다른 이름');
      expect(await duplicate, isFalse);
      expect(repository.renameCalls, 1);
      expect(repository.lastTitle, '이름');
      repository.renameCompleter!.complete();
      expect(await first, isTrue);

      await actions.rename('conversation-1', '   ');
      expect(repository.lastTitle, isNull);
      actions.dispose();
    },
  );

  test(
    'archive failure exposes local error and allows a later retry',
    () async {
      final _FakeActionsRepository repository = _FakeActionsRepository()
        ..archiveError = StateError('synthetic');
      final ConversationActions actions = ConversationActions(
        repository: repository,
      );

      expect(await actions.archive('conversation-1'), isFalse);
      expect(actions.state.errorMessage, '대화를 보관하지 못했습니다.');
      expect(actions.state.isBusy('conversation-1'), isFalse);
      repository.archiveError = null;
      expect(await actions.archive('conversation-1'), isTrue);
      expect(repository.archiveCalls, 2);
      actions.dispose();
    },
  );

  test('dispose fences late completion notifications', () async {
    final Completer<void> operation = Completer<void>();
    final _FakeActionsRepository repository = _FakeActionsRepository(
      renameCompleter: operation,
    );
    final ConversationActions actions = ConversationActions(
      repository: repository,
    );
    var notifications = 0;
    actions.addListener((_) => notifications += 1);

    final Future<bool> rename = actions.rename('conversation-1', '이름');
    final int beforeDispose = notifications;
    actions.dispose();
    operation.complete();
    expect(await rename, isTrue);
    expect(notifications, beforeDispose);
  });
}

final class _FakeActionsRepository implements ConversationActionsRepository {
  _FakeActionsRepository({this.renameCompleter});

  final Completer<void>? renameCompleter;
  Object? archiveError;
  int renameCalls = 0;
  int archiveCalls = 0;
  String? lastTitle;

  @override
  Future<void> renameConversation(String conversationId, String? title) async {
    renameCalls += 1;
    lastTitle = title;
    await renameCompleter?.future;
  }

  @override
  Future<void> archiveConversation(String conversationId) async {
    archiveCalls += 1;
    if (archiveError case final Object error) throw error;
  }
}
