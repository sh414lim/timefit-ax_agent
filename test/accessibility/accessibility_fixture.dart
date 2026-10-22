import 'package:flutter/material.dart';

final class AccessibilityFixture {
  const AccessibilityFixture({
    required this.width,
    required this.textScale,
    required this.brightness,
  });

  final double width;
  final double textScale;
  final Brightness brightness;

  String get name => '${width.toInt()}dp-${textScale}x-${brightness.name}';
}

final List<AccessibilityFixture> accessibilityFixtures = <AccessibilityFixture>[
  for (final double width in <double>[320, 390, 430])
    for (final double textScale in <double>[1, 1.5, 2])
      for (final Brightness brightness in Brightness.values)
        AccessibilityFixture(
          width: width,
          textScale: textScale,
          brightness: brightness,
        ),
];
