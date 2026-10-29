import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/chat/application/chat_session_coordinator.dart';
import 'package:timefit_native/features/chat/presentation/chat_session_gate.dart';

void main() {
  testWidgets('active renders the existing child without a gate status', (
    WidgetTester tester,
  ) async {
    final coordinator = _FakeGateCoordinator(LocalChatSessionState.active);
    addTearDown(coordinator.dispose);

    await _pumpGate(tester, coordinator: coordinator);

    expect(find.text(_sensitiveBody), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('chat-session-gate-scroll')),
      findsNothing,
    );
  });

  testWidgets('logging out removes sensitive content and announces once', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final coordinator = _FakeGateCoordinator(LocalChatSessionState.active);
    addTearDown(coordinator.dispose);
    await _pumpGate(tester, coordinator: coordinator);

    coordinator.state = LocalChatSessionState.loggingOut;
    await tester.pump();

    expect(find.text(_sensitiveBody), findsNothing);
    expect(find.text(_sensitiveFilename), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('채팅 데이터를 안전하게 정리하고 있습니다'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(_sensitiveCanary)), findsNothing);
    semantics.dispose();
  });

  testWidgets('cleanup failure is generic and repeated retry shares one run', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final coordinator = _FakeGateCoordinator(
      LocalChatSessionState.cleanupPending,
    );
    addTearDown(coordinator.dispose);
    final retry = Completer<void>();
    coordinator.retryResult = retry.future;
    await _pumpGate(tester, coordinator: coordinator);

    expect(find.text('이 기기의 채팅 데이터를 정리하지 못했습니다'), findsOneWidget);
    expect(find.text(_sensitiveBody), findsNothing);
    expect(find.text(_sensitiveFilename), findsNothing);
    expect(find.textContaining(_sensitiveCanary), findsNothing);
    final retryButton = find.byKey(
      const ValueKey<String>('chat-session-gate-retry'),
    );
    expect(tester.getSize(retryButton).height, greaterThanOrEqualTo(44));
    final retrySemantics = tester.getSemantics(retryButton);
    expect(retrySemantics.label, contains('다시 시도'));
    expect(
      retrySemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(retryButton);
    await tester.tap(retryButton, warnIfMissed: false);
    await tester.pump();

    expect(coordinator.retryCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(retryButton, findsNothing);
    expect(find.bySemanticsLabel('채팅 데이터 정리를 다시 시도하고 있습니다'), findsOneWidget);

    retry.completeError(StateError(_sensitiveCanary));
    await tester.pumpAndSettle();

    expect(find.textContaining(_sensitiveCanary), findsNothing);
    expect(find.bySemanticsLabel(RegExp(_sensitiveCanary)), findsNothing);
    expect(retryButton, findsOneWidget);
    expect(find.text('정리를 완료하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('synchronous retry failure stays private and allows retry', (
    WidgetTester tester,
  ) async {
    final coordinator = _FakeGateCoordinator(
      LocalChatSessionState.cleanupPending,
    )..synchronousFailure = StateError(_sensitiveCanary);
    addTearDown(coordinator.dispose);
    await _pumpGate(tester, coordinator: coordinator);

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-session-gate-retry')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(coordinator.retryCalls, 1);
    expect(find.textContaining(_sensitiveCanary), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('chat-session-gate-retry')),
      findsOneWidget,
    );
  });

  testWidgets('retry stays single-flight across working and failed states', (
    WidgetTester tester,
  ) async {
    final coordinator = _FakeGateCoordinator(
      LocalChatSessionState.cleanupPending,
    );
    addTearDown(coordinator.dispose);
    final retry = Completer<void>();
    coordinator.retryResult = retry.future;
    await _pumpGate(tester, coordinator: coordinator);

    final retryButton = find.byKey(
      const ValueKey<String>('chat-session-gate-retry'),
    );
    await tester.tap(retryButton);
    coordinator.state = LocalChatSessionState.loggingOut;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    coordinator.state = LocalChatSessionState.cleanupPending;
    await tester.pump();
    expect(retryButton, findsNothing);
    expect(coordinator.retryCalls, 1);

    retry.completeError(StateError(_sensitiveCanary));
    await tester.pumpAndSettle();
    expect(retryButton, findsOneWidget);
    expect(coordinator.retryCalls, 1);
  });

  testWidgets('successful retry and disposed states never restore old child', (
    WidgetTester tester,
  ) async {
    final coordinator = _FakeGateCoordinator(
      LocalChatSessionState.cleanupPending,
    );
    addTearDown(coordinator.dispose);
    final retry = Completer<void>();
    coordinator.retryResult = retry.future;
    await _pumpGate(tester, coordinator: coordinator);

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-session-gate-retry')),
    );
    coordinator.state = LocalChatSessionState.idle;
    retry.complete();
    await tester.pumpAndSettle();

    expect(find.text(_sensitiveBody), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('chat-session-gate-empty')),
      findsOneWidget,
    );

    coordinator.state = LocalChatSessionState.disposed;
    await tester.pump();
    expect(find.text(_sensitiveBody), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('chat-session-gate-empty')),
      findsOneWidget,
    );
  });

  testWidgets('late retry completion cannot affect a replacement coordinator', (
    WidgetTester tester,
  ) async {
    final first = _FakeGateCoordinator(LocalChatSessionState.cleanupPending);
    final second = _FakeGateCoordinator(LocalChatSessionState.cleanupPending);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final lateRetry = Completer<void>();
    first.retryResult = lateRetry.future;
    final current = ValueNotifier<ChatSessionGateCoordinator>(first);
    addTearDown(current.dispose);

    await _pumpGate(tester, coordinator: first, coordinatorListenable: current);
    await tester.tap(
      find.byKey(const ValueKey<String>('chat-session-gate-retry')),
    );
    current.value = second;
    await tester.pump();
    lateRetry.completeError(StateError(_sensitiveCanary));
    await tester.pumpAndSettle();

    expect(find.textContaining(_sensitiveCanary), findsNothing);
    expect(find.text('이전 채팅 내용은 안전을 위해 숨겨져 있습니다.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('chat-session-gate-retry')),
      findsOneWidget,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '320dp text 200% keyboard layout is scrollable in ${brightness.name}',
      (WidgetTester tester) async {
        final coordinator = _FakeGateCoordinator(
          LocalChatSessionState.cleanupPending,
        );
        addTearDown(coordinator.dispose);
        await _pumpGate(
          tester,
          coordinator: coordinator,
          brightness: brightness,
          size: const Size(320, 640),
          textScale: 2,
          keyboardInset: 280,
        );

        expect(tester.takeException(), isNull);
        final retry = find.byKey(
          const ValueKey<String>('chat-session-gate-retry'),
        );
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
        await tester.tap(retry);
        await tester.pump();
        expect(coordinator.retryCalls, 1);
        expect(find.text(_sensitiveBody), findsNothing);
      },
    );
  }
}

const _sensitiveBody = '급여 협의 원문';
const _sensitiveFilename = 'private-canary-token.pdf';
const _sensitiveCanary = 'private-canary-token';

Future<void> _pumpGate(
  WidgetTester tester, {
  required ChatSessionGateCoordinator coordinator,
  ValueListenable<ChatSessionGateCoordinator>? coordinatorListenable,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 760),
  double textScale = 1,
  double keyboardInset = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  Widget buildGate(ChatSessionGateCoordinator value) =>
      ChatSessionGate(coordinator: value, child: const _SensitiveChild());

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: Scaffold(
        resizeToAvoidBottomInset: true,
        body: coordinatorListenable == null
            ? buildGate(coordinator)
            : ValueListenableBuilder<ChatSessionGateCoordinator>(
                valueListenable: coordinatorListenable,
                builder: (_, value, __) => buildGate(value),
              ),
      ),
    ),
  );
  await tester.pump();
}

final class _SensitiveChild extends StatelessWidget {
  const _SensitiveChild();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        Text(_sensitiveBody),
        Text(_sensitiveFilename),
        TextField(decoration: InputDecoration(labelText: '메시지 입력')),
      ],
    );
  }
}

final class _FakeGateCoordinator extends ChangeNotifier
    implements ChatSessionGateCoordinator {
  _FakeGateCoordinator(this._state);

  LocalChatSessionState _state;
  Future<void> retryResult = Future<void>.value();
  Object? synchronousFailure;
  var retryCalls = 0;

  @override
  LocalChatSessionState get state => _state;

  set state(LocalChatSessionState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  @override
  Future<void> retryCleanup() {
    retryCalls += 1;
    if (synchronousFailure case final Object error) throw error;
    return retryResult;
  }
}
