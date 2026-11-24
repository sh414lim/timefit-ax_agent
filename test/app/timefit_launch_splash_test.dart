import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/app.dart';
import 'package:timefit_native/app/bootstrap.dart';
import 'package:timefit_native/app/widgets/timefit_launch_gate.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/home/presentation/widgets/timefit_loading_mark.dart';
import 'package:timefit_native/src/app_environment.dart';

void main() {
  const splash = Key('timefit-launch-splash');

  testWidgets(
    '300ms gate leaves startup mounted and blocks focus and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final navigator = GlobalKey<NavigatorState>();
      final engineFirstFrame = Completer<void>();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => TimeFitLaunchGate(
            child: child!,
            firstFrameRasterized: engineFirstFrame.future,
          ),
          home: Scaffold(
            body: TextButton(
              focusNode: focus,
              onPressed: () => presses += 1,
              child: const Text('Ready control'),
            ),
          ),
        ),
      );
      expect(find.byKey(splash), findsOneWidget);
      expect(find.bySemanticsLabel('TimeFit AX 시작 중'), findsOneWidget);
      expect(find.bySemanticsLabel('Ready control'), findsNothing);
      expect(find.text('Ready control'), findsOneWidget);
      expect(focus.canRequestFocus, isFalse);
      await tester.tap(find.text('Ready control'), warnIfMissed: false);
      expect(presses, 0);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(splash), findsOneWidget);
      engineFirstFrame.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.byKey(splash), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(splash), findsNothing);
      expect(find.bySemanticsLabel('Ready control'), findsOneWidget);
      expect(focus.canRequestFocus, isTrue);
      await tester.tap(find.text('Ready control'));
      expect(presses, 1);

      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Next')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsOneWidget);
      expect(find.byKey(splash), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(splash), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'shared DB loader is visible beyond launch and never adds a timer',
    (tester) async {
      final pending = Completer<AppDatabase>();
      var openCalls = 0;
      await tester.pumpWidget(
        TimeFitApp(
          environment: AppEnvironment.dev,
          showLaunchSplash: true,
          devDatabaseFactory: () {
            openCalls += 1;
            return pending.future;
          },
        ),
      );
      expect(openCalls, 1);
      expect(find.byKey(splash), findsOneWidget);
      await tester.pump(TimeFitLaunchGate.duration);
      expect(find.byKey(splash), findsNothing);
      final marker = tester.widget<TimeFitLoadingMark>(
        find.byType(TimeFitLoadingMark),
      );
      expect(marker.label, '로컬 저장소를 불러오는 중');

      // An error is an immediate completion of this loading state. No extra
      // time is advanced after the Future settles.
      pending.completeError(StateError('test-only open failure'));
      await tester.pump();
      expect(find.byType(TimeFitLoadingMark), findsNothing);
      expect(find.text('로컬 저장소를 열지 못했습니다'), findsOneWidget);
      expect(openCalls, 1);
    },
  );

  testWidgets('framework retry does not replay the cold-start splash', (
    tester,
  ) async {
    final runs = <Widget>[];
    final previousBuilder = ErrorWidget.builder;
    try {
      runTimeFitApp(AppEnvironment.staging, appRunner: runs.add);
      await tester.pumpWidget(runs.single);
      expect(find.byKey(splash), findsOneWidget);
      final failure =
          ErrorWidget.builder(
                FlutterErrorDetails(exception: StateError('fixture failure')),
              )
              as MaterialApp;
      (failure.home! as BootstrapFailureScreen).onRetry();
      await tester.pumpWidget(runs.last);
      expect(find.byKey(splash), findsNothing);
      expect(find.text('TimeFit Staging'), findsOneWidget);
    } finally {
      ErrorWidget.builder = previousBuilder;
    }
  });

  testWidgets('disposing before deadline cancels the launch timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TimeFitLaunchGate(child: SizedBox.shrink())),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(TimeFitLaunchGate.duration);
    expect(tester.takeException(), isNull);
  });
}
