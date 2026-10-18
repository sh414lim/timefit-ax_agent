import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/bootstrap.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/app/theme/tokens.dart';
import 'package:timefit_native/src/app_environment.dart';

void main() {
  setUpAll(() async {
    final Uint8List fontBytes = File(
      'test/fixtures/fonts/nanum_gothic/NanumGothic-Regular.ttf',
    ).readAsBytesSync();
    final FontLoader fontLoader = FontLoader(_goldenFontFamily)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)));
    await fontLoader.load();
  });

  test('shared layout tokens keep the approved scale', () {
    expect(
      <double>[
        AppSpacing.x4,
        AppSpacing.x8,
        AppSpacing.x12,
        AppSpacing.x16,
        AppSpacing.x24,
        AppSpacing.x32,
      ],
      <double>[4, 8, 12, 16, 24, 32],
    );
    expect(AppTouchTarget.minimum, 44);
  });

  test('light and dark themes expose matching brightness', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  for (final (String name, ThemeData theme) in <(String, ThemeData)>[
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('$name theme bootstrap failure golden', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: _withGoldenFont(theme),
          home: BootstrapFailureScreen(onRetry: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(BootstrapFailureScreen),
        matchesGoldenFile('goldens/bootstrap_failure_$name.png'),
      );
    });
  }

  testWidgets('320dp and 200 percent text keeps recovery guidance visible', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: _withGoldenFont(AppTheme.light()),
        home: Builder(
          builder: (BuildContext context) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: BootstrapFailureScreen(onRetry: () {}),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('앱을 시작하지 못했습니다'), findsOneWidget);
    expect(find.textContaining('다시 시도해 주세요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(AppTouchTarget.minimum),
    );
  });

  testWidgets('error boundary renders the recovery screen', (
    WidgetTester tester,
  ) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TimeFitErrorBoundary(
          failure: StateError('redacted_bootstrap_failure'),
          onRetry: () => retryCount += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(BootstrapFailureScreen), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('다시 시도'));
    expect(retryCount, 1);
  });

  testWidgets('framework error retry restarts the app bootstrap', (
    WidgetTester tester,
  ) async {
    final List<Widget> appRuns = <Widget>[];
    final ErrorWidgetBuilder originalErrorBuilder = ErrorWidget.builder;
    try {
      runTimeFitApp(AppEnvironment.dev, appRunner: appRuns.add);
      expect(appRuns, hasLength(1));

      final Widget recovery = ErrorWidget.builder(
        FlutterErrorDetails(exception: StateError('redacted_render_failure')),
      );
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: recovery),
      );

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('다시 시도'));
      expect(appRuns, hasLength(2));
    } finally {
      ErrorWidget.builder = originalErrorBuilder;
    }
  });
}

const String _goldenFontFamily = 'NanumGothicGolden';

ThemeData _withGoldenFont(ThemeData theme) {
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: _goldenFontFamily),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamily: _goldenFontFamily,
    ),
  );
}
