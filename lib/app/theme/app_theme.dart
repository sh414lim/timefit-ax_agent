import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: isLight ? AppPalette.lightPrimary : AppPalette.darkPrimary,
      brightness: brightness,
      primary: isLight ? AppPalette.lightPrimary : AppPalette.darkPrimary,
      onPrimary: isLight ? AppPalette.lightOnPrimary : AppPalette.darkOnPrimary,
      surface: isLight ? AppPalette.lightSurface : AppPalette.darkSurface,
      onSurface: isLight ? AppPalette.lightOnSurface : AppPalette.darkOnSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme:
          const TextTheme(
            headlineMedium: AppTypography.headline,
            headlineSmall: AppTypography.headline,
            bodyLarge: AppTypography.body,
            labelLarge: AppTypography.label,
          ).apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            AppTouchTarget.minimum,
            AppTouchTarget.minimum,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x24,
            vertical: AppSpacing.x12,
          ),
        ),
      ),
    );
  }
}
