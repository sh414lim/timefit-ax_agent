import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/bootstrap.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/app/theme/tokens.dart';

void main() {
  final GoldenFileComparator defaultGoldenFileComparator = goldenFileComparator;

  setUpAll(() {
    goldenFileComparator = _CrossPlatformGoldenComparator(
      Uri.parse('test/app/theme/app_theme_test.dart'),
    );
  });

  tearDownAll(() {
    goldenFileComparator = defaultGoldenFileComparator;
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
          theme: theme,
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
        theme: AppTheme.light(),
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
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TimeFitErrorBoundary(
          failure: StateError('redacted_bootstrap_failure'),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(BootstrapFailureScreen), findsOneWidget);
  });
}

/// Allows only the small rasterization variance produced by Flutter's Linux
/// and macOS test renderers while still rejecting layout and color regressions.
class _CrossPlatformGoldenComparator extends LocalFileComparator {
  _CrossPlatformGoldenComparator(super.testFile);

  static const double _maximumPixelDifference = 0.015;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final bool passed =
        result.passed || result.diffPercent <= _maximumPixelDifference;

    if (passed) {
      result.dispose();
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
