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

  testWidgets('owned overlay loses rendering semantics focus and hits', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final coordinator = _FakeGateCoordinator(LocalChatSessionState.active);
    final focusNode = FocusNode();
    var taps = 0;
    addTearDown(coordinator.dispose);
    addTearDown(focusNode.dispose);
    await _pumpGate(
      tester,
      coordinator: coordinator,
      child: _OwnedOverlayChild(focusNode: focusNode, onTap: () => taps += 1),
    );
    await tester.pump();

    final overlay = find.byKey(
      const ValueKey<String>('owned-sensitive-overlay'),
    );
    expect(overlay, findsOneWidget);
    expect(find.bySemanticsLabel(_sensitiveCanary), findsWidgets);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    final oldCenter = tester.getCenter(overlay);

    coordinator.state = LocalChatSessionState.loggingOut;
    await tester.pump();

    expect(overlay, findsNothing);
    expect(find.bySemanticsLabel(_sensitiveCanary), findsNothing);
    expect(focusNode.hasFocus, isFalse);
    await tester.tapAt(oldCenter);
    await tester.pump();
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets('unrelated app root overlay is preserved outside chat scope', (
    WidgetTester tester,
  ) async {
    final coordinator = _FakeGateCoordinator(LocalChatSessionState.active);
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    addTearDown(coordinator.dispose);
    await _pumpGate(
      tester,
      coordinator: coordinator,
      rootNavigatorKey: rootNavigatorKey,
    );
    final unrelated = OverlayEntry(
      builder: (_) => const Positioned(
        top: 8,
        left: 8,
        child: Material(
          child: Text(
            'unrelated-app-overlay',
            key: ValueKey<String>('unrelated-app-overlay'),
          ),
        ),
      ),
    );
    rootNavigatorKey.currentState!.overlay!.insert(unrelated);
    addTearDown(unrelated.remove);
    await tester.pump();

    coordinator.state = LocalChatSessionState.cleanupPending;
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('unrelated-app-overlay')),
      findsOneWidget,
    );
    expect(find.text(_sensitiveBody), findsNothing);
  });

  testWidgets('owned dialog sheet and route are revoked with the session', (
    WidgetTester tester,
  ) async {
    final coordinator = _FakeGateCoordinator(LocalChatSessionState.active);
    addTearDown(coordinator.dispose);
    await _pumpGate(
      tester,
      coordinator: coordinator,
      child: const _OwnedSurfaceButtons(),
    );

    await tester.tap(find.text('owned-dialog-button'));
    await tester.pumpAndSettle();
    expect(find.text('owned-dialog-content'), findsOneWidget);
    await tester.tap(find.text('owned-nested-sheet-button'));
    await tester.pumpAndSettle();
    expect(find.text('owned-nested-sheet-content'), findsOneWidget);
    coordinator.state = LocalChatSessionState.loggingOut;
    await tester.pump();
    expect(find.text('owned-dialog-content'), findsNothing);
    expect(find.text('owned-nested-sheet-content'), findsNothing);

    coordinator.state = LocalChatSessionState.active;
    await tester.pumpAndSettle();
    await tester.tap(find.text('owned-sheet-button'));
    await tester.pumpAndSettle();
    expect(find.text('owned-sheet-content'), findsOneWidget);
    coordinator.state = LocalChatSessionState.cleanupPending;
    await tester.pump();
    expect(find.text('owned-sheet-content'), findsNothing);

    coordinator.state = LocalChatSessionState.active;
    await tester.pumpAndSettle();
    await tester.tap(find.text('owned-route-button'));
    await tester.pumpAndSettle();
    expect(find.text('owned-route-content'), findsOneWidget);
    coordinator.state = LocalChatSessionState.disposed;
    await tester.pump();
    expect(find.text('owned-route-content'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late owned dialog request cannot recreate a blocked surface', (
    WidgetTester tester,
  ) async {
    final coordinator = _FakeGateCoordinator(LocalChatSessionState.active);
    final release = Completer<void>();
    addTearDown(coordinator.dispose);
    await _pumpGate(
      tester,
      coordinator: coordinator,
      child: _LateOwnedDialogChild(release: release.future),
    );

    coordinator.state = LocalChatSessionState.cleanupPending;
    await tester.pump();
    release.complete();
    await tester.pumpAndSettle();

    expect(find.text('late-owned-dialog'), findsNothing);
    expect(find.text(_sensitiveBody), findsNothing);
    expect(tester.takeException(), isNull);
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
  GlobalKey<NavigatorState>? rootNavigatorKey,
  Widget child = const _SensitiveChild(),
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
      ChatSessionGate(coordinator: value, child: child);

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: rootNavigatorKey,
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

final class _OwnedOverlayChild extends StatefulWidget {
  const _OwnedOverlayChild({required this.focusNode, required this.onTap});

  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_OwnedOverlayChild> createState() => _OwnedOverlayChildState();
}

final class _OwnedOverlayChildState extends State<_OwnedOverlayChild> {
  var _inserted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inserted) return;
    _inserted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Overlay.of(context).insert(
        OverlayEntry(
          builder: (_) => Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Semantics(
                  label: _sensitiveCanary,
                  button: true,
                  child: Focus(
                    focusNode: widget.focusNode,
                    autofocus: true,
                    child: FilledButton(
                      key: const ValueKey<String>('owned-sensitive-overlay'),
                      onPressed: widget.onTap,
                      child: const Text(_sensitiveCanary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Text(_sensitiveBody);
}

final class _OwnedSurfaceButtons extends StatelessWidget {
  const _OwnedSurfaceButtons();

  @override
  Widget build(BuildContext context) {
    final surfaceHandle = ChatSessionOwnedSurfaces.capture(context);
    return Column(
      children: <Widget>[
        TextButton(
          onPressed: () {
            unawaited(
              ChatSessionOwnedSurfaces.showOwnedDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('owned-dialog-content'),
                      TextButton(
                        onPressed: () {
                          unawaited(
                            surfaceHandle?.openBottomSheet<void>(
                              builder: (_) => const SizedBox(
                                height: 120,
                                child: Center(
                                  child: Text('owned-nested-sheet-content'),
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('owned-nested-sheet-button'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: const Text('owned-dialog-button'),
        ),
        TextButton(
          onPressed: () {
            unawaited(
              ChatSessionOwnedSurfaces.showOwnedBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(
                  height: 160,
                  child: Center(child: Text('owned-sheet-content')),
                ),
              ),
            );
          },
          child: const Text('owned-sheet-button'),
        ),
        TextButton(
          onPressed: () {
            unawaited(
              ChatSessionOwnedSurfaces.pushOwnedRoute<void>(
                context: context,
                route: MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('owned-route-content')),
                  ),
                ),
              ),
            );
          },
          child: const Text('owned-route-button'),
        ),
      ],
    );
  }
}

final class _LateOwnedDialogChild extends StatefulWidget {
  const _LateOwnedDialogChild({required this.release});

  final Future<void> release;

  @override
  State<_LateOwnedDialogChild> createState() => _LateOwnedDialogChildState();
}

final class _LateOwnedDialogChildState extends State<_LateOwnedDialogChild> {
  ChatSessionOwnedSurfaceHandle? _surfaceHandle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final firstCapture = _surfaceHandle == null;
    _surfaceHandle ??= ChatSessionOwnedSurfaces.capture(context);
    if (firstCapture && _surfaceHandle != null) {
      unawaited(_openWhenReleased());
    }
  }

  Future<void> _openWhenReleased() async {
    await widget.release;
    await _surfaceHandle?.openDialog<void>(
      builder: (_) => const AlertDialog(content: Text('late-owned-dialog')),
    );
  }

  @override
  Widget build(BuildContext context) => const Text(_sensitiveBody);
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
