import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x48 = 48;
}

abstract final class AppRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double pill = 999;
}

abstract final class AppTouchTarget {
  static const double minimum = 44;
}

abstract final class AppPalette {
  static const Color lightPrimary = Color(0xFF2457C5);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF9FAFC);
  static const Color lightOnSurface = Color(0xFF191C20);

  static const Color darkPrimary = Color(0xFFADC6FF);
  static const Color darkOnPrimary = Color(0xFF002E69);
  static const Color darkSurface = Color(0xFF111318);
  static const Color darkOnSurface = Color(0xFFE2E2E9);
}

abstract final class AppTypography {
  static const TextStyle headline = TextStyle(
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(fontSize: 16, height: 1.5);
  static const TextStyle label = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
}
