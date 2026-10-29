import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/chat/application/chat_connection_controller.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/domain/chat_message.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';
import 'package:timefit_native/features/chat/presentation/widgets/connection_banner.dart';

final class _FakeDelay implements ChatConnectionDelay {
  _FakeDelay(this.callback);

  final void Function() callback;
  bool cancelled = false;

  void fire() {
    if (!cancelled) callback();
  }

  @override
  void cancel() => cancelled = true;
}

final class _FakeClock {
  final delays = <_FakeDelay>[];

  ChatConnectionDelay schedule(Duration duration, void Function() callback) {
    expect(duration, const Duration(seconds: 3));
    final delay = _FakeDelay(callback);
    delays.add(delay);
    return delay;
  }
}

final class _Submitter implements TextMessageSubmitter {
  int calls = 0;

  @override
  Future<bool> retry(String commandId) async => true;

  @override
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) async {
    calls += 1;
    return LocalTextCommand(
      id: 'local-$calls',
      conversationId: conversationId,
      bodyText: bodyText,
    );
  }
}

final class _FailedAttachmentSource implements AttachmentComposerSource {
  @override
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  }) => Stream<List<ComposerAttachment>>.value(
    List<ComposerAttachment>.generate(
      5,
      (index) => ComposerAttachment(
        localId: 'synthetic-$index',
        contentType: 'image/png',
        state: ComposerAttachmentState.failed,
        bytesSent: 0,
        bytesTotal: 100,
      ),
    ),
  );

  @override
  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) async {}
}

void main() {
  group('ChatConnectionController', () {
    late _FakeClock clock;
    late ChatConnectionController controller;
    var retryCalls = 0;

    setUp(() {
      retryCalls = 0;
      clock = _FakeClock();
      controller = ChatConnectionController(
        onRetry: () async => retryCalls += 1,
        delayFactory: clock.schedule,
      );
    });

    tearDown(() => controller.dispose());

    test('quick joining reconnect stays hidden and cancels grace timer', () {
      controller.update(phase: ChatConnectionPhase.joining, rpcAvailable: true);
      expect(controller.state.showBanner, isFalse);
      expect(clock.delays, hasLength(1));

      controller.update(
        phase: ChatConnectionPhase.connected,
        rpcAvailable: true,
      );
      clock.delays.single.fire();

      expect(clock.delays.single.cancelled, isTrue);
      expect(controller.state.phase, ChatConnectionPhase.connected);
      expect(controller.state.showBanner, isFalse);
    });

    test('joining longer than grace shows a nonblocking banner state', () {
      controller.update(phase: ChatConnectionPhase.joining, rpcAvailable: true);
      clock.delays.single.fire();

      expect(controller.state.phase, ChatConnectionPhase.joining);
      expect(controller.state.rpcAvailable, isTrue);
      expect(controller.state.showBanner, isTrue);
    });

    test('disconnected and polling show immediately; background hides', () {
      controller.update(
        phase: ChatConnectionPhase.disconnected,
        rpcAvailable: true,
      );
      expect(controller.state.showBanner, isTrue);
      controller.update(phase: ChatConnectionPhase.polling, rpcAvailable: true);
      expect(controller.state.showBanner, isTrue);
      controller.update(
        phase: ChatConnectionPhase.background,
        rpcAvailable: true,
      );
      expect(controller.state.showBanner, isFalse);
    });

    test(
      'rapid retries share one operation and do not assume success',
      () async {
        final pending = Completer<void>();
        controller.dispose();
        controller = ChatConnectionController(
          onRetry: () {
            retryCalls += 1;
            return pending.future;
          },
          delayFactory: clock.schedule,
          initialPhase: ChatConnectionPhase.disconnected,
        );

        final first = controller.retry();
        final second = controller.retry();
        expect(identical(first, second), isTrue);
        expect(retryCalls, 1);
        expect(controller.state.isRetrying, isTrue);

        pending.complete();
        await first;
        expect(controller.state.phase, ChatConnectionPhase.disconnected);
        expect(controller.state.showBanner, isTrue);
        expect(controller.state.isRetrying, isFalse);
      },
    );

    test('phase updates during retry do not leave retry locked', () async {
      final pending = Completer<void>();
      controller.dispose();
      controller = ChatConnectionController(
        onRetry: () => pending.future,
        initialPhase: ChatConnectionPhase.disconnected,
      );

      final retry = controller.retry();
      controller.update(phase: ChatConnectionPhase.polling, rpcAvailable: true);
      pending.complete();
      await retry;

      expect(controller.state.phase, ChatConnectionPhase.polling);
      expect(controller.state.showBanner, isTrue);
      expect(controller.state.isRetrying, isFalse);
    });

    test('a synchronous retry failure can be retried', () async {
      controller.dispose();
      controller = ChatConnectionController(
        onRetry: () {
          retryCalls += 1;
          throw StateError('synthetic');
        },
        initialPhase: ChatConnectionPhase.disconnected,
      );

      await controller.retry();
      await controller.retry();

      expect(retryCalls, 2);
      expect(controller.state.isRetrying, isFalse);
    });

    test('dispose cancels timer and fences late retry completion', () async {
      final pending = Completer<void>();
      controller.dispose();
      controller = ChatConnectionController(
        onRetry: () => pending.future,
        delayFactory: clock.schedule,
        initialPhase: ChatConnectionPhase.joining,
      );
      final retry = controller.retry();
      final beforeDispose = controller.state;
      controller.dispose();
      clock.delays.last.fire();
      pending.complete();
      await retry;

      expect(clock.delays.last.cancelled, isTrue);
      expect(controller.state.phase, beforeDispose.phase);
      expect(controller.state.showBanner, beforeDispose.showBanner);
    });

    testWidgets('repeated joining updates preserve elapsed grace', (
      tester,
    ) async {
      controller.dispose();
      controller = ChatConnectionController(
        onRetry: () async {},
        initialPhase: ChatConnectionPhase.joining,
      );

      await tester.pump(const Duration(seconds: 2));
      controller.update(
        phase: ChatConnectionPhase.joining,
        rpcAvailable: false,
      );
      await tester.pump(const Duration(seconds: 2));

      expect(controller.state.rpcAvailable, isFalse);
      expect(controller.state.showBanner, isTrue);
    });

    test(
      'failed retry remains nonthrowing and can be attempted again',
      () async {
        controller.dispose();
        controller = ChatConnectionController(
          onRetry: () async {
            retryCalls += 1;
            if (retryCalls == 1) throw StateError('offline');
          },
          initialPhase: ChatConnectionPhase.disconnected,
        );

        await controller.retry();
        expect(controller.state.showBanner, isTrue);
        expect(controller.state.isRetrying, isFalse);
        await controller.retry();
        expect(retryCalls, 2);
      },
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '320dp text scale 2 ${brightness.name} keeps banner and composer operable',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final submitter = _Submitter();
        final composer = ComposerController(
          conversationId: 'conversation',
          submitter: submitter,
        );
        final connection = ChatConnectionController(
          onRetry: () async {},
          initialPhase: ChatConnectionPhase.disconnected,
          rpcAvailable: true,
        );
        addTearDown(composer.dispose);
        addTearDown(connection.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: ChatScreen(
                title: '연결 상태',
                conversationId: 'conversation',
                messages: Stream<List<ChatMessage>>.value(const []),
                composerController: composer,
                connectionController: connection,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ConnectionBanner), findsOneWidget);
        expect(find.textContaining('메시지는 계속 보낼 수 있습니다'), findsOneWidget);
        final retry = find.widgetWithText(TextButton, '다시 시도');
        expect(tester.getSize(retry).shortestSide, greaterThanOrEqualTo(44));
        expect(find.bySemanticsLabel('실시간 연결 다시 시도'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'RPC 작성 가능');
        await tester.pump();
        final send = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send),
        );
        expect(send.onPressed, isNotNull);
        await tester.tap(find.widgetWithIcon(IconButton, Icons.send));
        await tester.pump();
        expect(submitter.calls, 1);
        semantics.dispose();
      },
    );
  }

  testWidgets('polling copy and retry transition remain explicit', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final retryPending = Completer<void>();
    final connection = ChatConnectionController(
      onRetry: () => retryPending.future,
      initialPhase: ChatConnectionPhase.polling,
      rpcAvailable: false,
    );
    addTearDown(connection.dispose);

    Future<void> pumpBanner() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionBanner(
            state: connection.state,
            onRetry: () => connection.retry(),
          ),
        ),
      ),
    );

    await pumpBanner();
    expect(find.textContaining('새 메시지를 확인 중입니다'), findsOneWidget);
    expect(find.textContaining('메시지 전송 연결도 확인해 주세요'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await pumpBanner();
    expect(find.text('시도 중'), findsOneWidget);
    expect(find.bySemanticsLabel('실시간 연결 다시 시도 중'), findsOneWidget);

    retryPending.complete();
    await tester.pump();
    await pumpBanner();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.textContaining('새 메시지를 확인 중입니다'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'actual 320dp viewport with keyboard and text scale 2 does not overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final connection = ChatConnectionController(
        onRetry: () async {},
        initialPhase: ChatConnectionPhase.disconnected,
      );
      addTearDown(connection.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            title: '연결 상태',
            messages: Stream<List<ChatMessage>>.value(const []),
            connectionController: connection,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard banner layout adapts across height boundary and five attachments',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final brightness in Brightness.values) {
        for (final height in <double>[639, 640, 641, 660, 680, 681, 700]) {
          tester.view.physicalSize = Size(320, height);
          final composer = ComposerController(
            conversationId: 'conversation',
            submitter: _Submitter(),
            attachmentClientMessageId: 'draft',
            attachmentSource: _FailedAttachmentSource(),
          );
          final connection = ChatConnectionController(
            onRetry: () async {},
            initialPhase: ChatConnectionPhase.disconnected,
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: ChatScreen(
                title: '연결 상태',
                conversationId: 'conversation',
                messages: Stream<List<ChatMessage>>.value(const []),
                composerController: composer,
                connectionController: connection,
                onAddAttachment: _noOp,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${brightness.name}, height=$height, short input',
          );

          await tester.enterText(find.byType(TextField), '긴 입력 ' * 30);
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${brightness.name}, height=$height, long input',
          );
          expect(find.byTooltip('첨부 추가'), findsOneWidget);
          expect(find.byTooltip('메시지 보내기'), findsOneWidget);
          expect(find.byTooltip('실패한 첨부 제거'), findsNWidgets(5));

          await tester.pumpWidget(const SizedBox.shrink());
          composer.dispose();
          connection.dispose();
        }
      }
    },
  );

  testWidgets(
    'short landscape banner keeps multiline composer controls reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(852, 393);
      tester.view.viewInsets = const FakeViewPadding(bottom: 216);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final composer = ComposerController(
        conversationId: 'conversation',
        submitter: _Submitter(),
        attachmentClientMessageId: 'draft',
        attachmentSource: _FailedAttachmentSource(),
      );
      final connection = ChatConnectionController(
        onRetry: () async {},
        initialPhase: ChatConnectionPhase.disconnected,
      );
      addTearDown(composer.dispose);
      addTearDown(connection.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            title: '연결 상태',
            conversationId: 'conversation',
            messages: Stream<List<ChatMessage>>.value(const []),
            composerController: composer,
            connectionController: connection,
            onAddAttachment: _noOp,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      final textField = find.byType(TextField);
      await tester.drag(
        find.byKey(const ValueKey<String>('connection-keyboard-scroll')),
        const Offset(0, -240),
      );
      await tester.pump();
      expect(textField.hitTestable(), findsOneWidget);
      await tester.enterText(textField, '첫 줄\n둘째 줄\n' * 10);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(composer.draft, contains('\n'));
      expect(find.byTooltip('첨부 추가'), findsOneWidget);
      expect(find.byTooltip('메시지 보내기'), findsOneWidget);
      expect(find.byTooltip('실패한 첨부 제거'), findsNWidgets(5));
    },
  );

  testWidgets(
    'keyboard banner toggles preserve focus selection and one stream subscription',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(852, 393);
      tester.view.viewInsets = const FakeViewPadding(bottom: 216);
      addTearDown(tester.view.reset);
      final messages = StreamController<List<ChatMessage>>();
      final composer = ComposerController(
        conversationId: 'conversation',
        submitter: _Submitter(),
      );
      final connection = ChatConnectionController(
        onRetry: () async {},
        initialPhase: ChatConnectionPhase.connected,
      );
      addTearDown(messages.close);
      addTearDown(composer.dispose);
      addTearDown(connection.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            title: '연결 상태',
            conversationId: 'conversation',
            messages: messages.stream,
            composerController: composer,
            connectionController: connection,
          ),
        ),
      );
      messages.add(const <ChatMessage>[]);
      await tester.pump();
      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.enterText(textField, '선택을 유지할 입력');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      await tester.pump();
      expect(editable.focusNode.hasFocus, isTrue);

      connection.update(
        phase: ChatConnectionPhase.disconnected,
        rpcAvailable: true,
      );
      await tester.pump();
      final afterShow = tester.widget<EditableText>(find.byType(EditableText));
      expect(tester.takeException(), isNull);
      expect(afterShow.focusNode.hasFocus, isTrue);
      expect(afterShow.controller.text, '선택을 유지할 입력');
      expect(
        afterShow.controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );

      connection.update(
        phase: ChatConnectionPhase.connected,
        rpcAvailable: true,
      );
      await tester.pump();
      final afterHide = tester.widget<EditableText>(find.byType(EditableText));
      expect(tester.takeException(), isNull);
      expect(afterHide.focusNode.hasFocus, isTrue);
      expect(afterHide.controller.text, '선택을 유지할 입력');
      expect(
        afterHide.controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );
    },
  );

  testWidgets('banner status has one semantics announcement', (tester) async {
    final handle = tester.ensureSemantics();
    const message = '실시간 연결이 끊겼습니다.';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectionBanner(
            state: ChatConnectionState(
              phase: ChatConnectionPhase.disconnected,
              rpcAvailable: true,
              showBanner: true,
            ),
            onRetry: _noOp,
          ),
        ),
      ),
    );
    final labels = <String>[];
    void visit(SemanticsNode node) {
      labels.add(node.getSemanticsData().label);
      node.visitChildren((SemanticsNode child) {
        visit(child);
        return true;
      });
    }

    visit(
      tester
          .binding
          .renderViews
          .single
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    expect(labels.where((label) => label.contains(message)), hasLength(1));
    handle.dispose();
  });
}

void _noOp() {}
