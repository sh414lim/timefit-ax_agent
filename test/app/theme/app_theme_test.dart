import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

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

      expect(find.text('앱을 시작하지 못했습니다'), findsOneWidget);
      expect(find.text('네트워크 상태를 확인한 뒤 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      _expectRenderedTextContrast(tester);
      _installTextRasterizationComparator(tester);

      await expectLater(
        find.byType(BootstrapFailureScreen),
        matchesGoldenFile('goldens/bootstrap_failure_$name.png'),
      );
    });
  }

  testWidgets('resolved contrast rejects invisible and low contrast text', (
    WidgetTester tester,
  ) async {
    final ThemeData base = AppTheme.light();
    final Color surface = base.scaffoldBackgroundColor;
    final List<ThemeData> invalidThemes = <ThemeData>[
      base.copyWith(
        textTheme: base.textTheme.copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            color: Colors.transparent,
          ),
        ),
      ),
      base.copyWith(
        textTheme: base.textTheme.copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(color: surface),
        ),
      ),
      base.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff777777),
            foregroundColor: const Color(0xff888888),
          ),
        ),
      ),
    ];

    for (final ThemeData invalidTheme in invalidThemes) {
      await tester.pumpWidget(
        MaterialApp(
          theme: _withGoldenFont(invalidTheme),
          home: BootstrapFailureScreen(onRetry: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        () => _expectRenderedTextContrast(tester),
        throwsA(isA<TestFailure>()),
      );
    }
  });

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

void _expectRenderedTextContrast(WidgetTester tester) {
  _expectTextContrast(
    tester,
    finder: find.text('앱을 시작하지 못했습니다'),
    minimumRatio: 3,
    role: 'large heading',
  );
  _expectTextContrast(
    tester,
    finder: find.text('네트워크 상태를 확인한 뒤 잠시 후 다시 시도해 주세요.'),
    minimumRatio: 4.5,
    role: 'body copy',
  );
  _expectTextContrast(
    tester,
    finder: find.text('다시 시도'),
    minimumRatio: 4.5,
    role: 'button label',
  );
}

void _expectTextContrast(
  WidgetTester tester, {
  required Finder finder,
  required double minimumRatio,
  required String role,
}) {
  final Element textElement = tester.element(finder);
  final Text textWidget = tester.widget<Text>(finder);
  final TextStyle resolvedStyle = DefaultTextStyle.of(
    textElement,
  ).style.merge(textWidget.style);
  final Color? foreground = resolvedStyle.color;
  expect(foreground, isNotNull, reason: '$role must resolve a text color');

  Material? nearestMaterial;
  textElement.visitAncestorElements((Element ancestor) {
    if (ancestor.widget case final Material material) {
      nearestMaterial = material;
      return false;
    }
    return true;
  });
  final Color? background = nearestMaterial?.color;
  expect(
    background,
    isNotNull,
    reason: '$role must render on a colored surface',
  );

  final double ratio = _contrastRatio(foreground!, background!);
  expect(
    ratio,
    greaterThanOrEqualTo(minimumRatio),
    reason:
        '$role resolves to ${ratio.toStringAsFixed(2)}:1 contrast; '
        '${minimumRatio.toStringAsFixed(1)}:1 is required',
  );
}

double _contrastRatio(Color foreground, Color background) {
  final Color opaqueForeground = Color.alphaBlend(foreground, background);
  final double foregroundLuminance = opaqueForeground.computeLuminance();
  final double backgroundLuminance = background.computeLuminance();
  final double lighter = math.max(foregroundLuminance, backgroundLuminance);
  final double darker = math.min(foregroundLuminance, backgroundLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

void _installTextRasterizationComparator(WidgetTester tester) {
  final GoldenFileComparator previousComparator = goldenFileComparator;
  goldenFileComparator = _TextRasterizationComparator(
    Uri.parse('test/app/theme/app_theme_test.dart'),
    textRegions: <Rect>[
      tester.getRect(find.text('앱을 시작하지 못했습니다')).inflate(1),
      tester.getRect(find.text('네트워크 상태를 확인한 뒤 잠시 후 다시 시도해 주세요.')).inflate(1),
      tester.getRect(find.text('다시 시도')).inflate(1),
    ],
  );
  addTearDown(() => goldenFileComparator = previousComparator);
}

/// Compares every pixel exactly except inside the measured text line boxes.
///
/// Flutter rasterizes the same bundled font differently on macOS and Linux.
/// The exact Korean strings are asserted separately above, while this
/// comparator keeps layout, spacing, surfaces, and button pixels strict.
class _TextRasterizationComparator extends LocalFileComparator {
  _TextRasterizationComparator(super.testFile, {required this.textRegions});

  final List<Rect> textRegions;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final _DecodedImage actual = await _decode(imageBytes);
    final _DecodedImage expected = await _decode(
      Uint8List.fromList(await getGoldenBytes(golden)),
    );
    try {
      if (actual.width != expected.width || actual.height != expected.height) {
        throw FlutterError(
          'Golden $golden has ${expected.width}x${expected.height} pixels, '
          'but the test rendered ${actual.width}x${actual.height}.',
        );
      }

      var differenceCount = 0;
      for (var y = 0; y < actual.height; y += 1) {
        for (var x = 0; x < actual.width; x += 1) {
          if (_isTextPixel(x, y)) {
            continue;
          }
          final int offset = (y * actual.width + x) * 4;
          if (actual.bytes.getUint32(offset) !=
              expected.bytes.getUint32(offset)) {
            differenceCount += 1;
          }
        }
      }

      if (differenceCount != 0) {
        throw FlutterError(
          'Golden $golden differs by $differenceCount pixels outside the '
          'measured text rasterization regions.',
        );
      }
      return true;
    } finally {
      actual.dispose();
      expected.dispose();
    }
  }

  bool _isTextPixel(int x, int y) {
    final Offset pixelCenter = Offset(x + 0.5, y + 0.5);
    return textRegions.any((Rect region) => region.contains(pixelCenter));
  }
}

class _DecodedImage {
  const _DecodedImage(this.image, this.bytes);

  final ui.Image image;
  final ByteData bytes;

  int get width => image.width;
  int get height => image.height;

  void dispose() => image.dispose();
}

Future<_DecodedImage> _decode(Uint8List pngBytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  codec.dispose();
  final ByteData? bytes = await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (bytes == null) {
    frame.image.dispose();
    throw FlutterError('Unable to decode golden image pixels.');
  }
  return _DecodedImage(frame.image, bytes);
}
