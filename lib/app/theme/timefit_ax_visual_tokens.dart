import 'package:flutter/material.dart';

/// Presentation-local colors sampled from the supplied JPEG references.
///
/// Light values are estimates, not approved global brand tokens. The dark
/// variant is a product accessibility proposal because no dark source exists.
@immutable
final class TimeFitAxVisualTokens
    extends ThemeExtension<TimeFitAxVisualTokens> {
  const TimeFitAxVisualTokens({
    required this.primary,
    required this.deepText,
    required this.secondaryText,
    required this.canvas,
    required this.sidebar,
    required this.paleBlue,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.success,
    required this.warning,
    required this.mint,
    required this.lavender,
    required this.orange,
  });

  static const TimeFitAxVisualTokens light = TimeFitAxVisualTokens(
    primary: Color(0xFF1978F8),
    deepText: Color(0xFF071022),
    secondaryText: Color(0xFF626876),
    canvas: Color(0xFFFEFEFE),
    sidebar: Color(0xFFF6F9FE),
    paleBlue: Color(0xFFEFF6FE),
    surface: Color(0xFFFFFFFF),
    subtleSurface: Color(0xFFF5F8FC),
    border: Color(0xFFE8ECF2),
    success: Color(0xFF58B970),
    warning: Color(0xFFE9A43A),
    mint: Color(0xFFE9F8F3),
    lavender: Color(0xFFF1EDFF),
    orange: Color(0xFFFFF2E7),
  );

  static const TimeFitAxVisualTokens dark = TimeFitAxVisualTokens(
    primary: Color(0xFF8EB9FF),
    deepText: Color(0xFFF4F7FF),
    secondaryText: Color(0xFFB8C0CF),
    canvas: Color(0xFF0E1117),
    sidebar: Color(0xFF151A23),
    paleBlue: Color(0xFF172D4E),
    surface: Color(0xFF171B23),
    subtleSurface: Color(0xFF202631),
    border: Color(0xFF343C49),
    success: Color(0xFF76D18D),
    warning: Color(0xFFF1BA65),
    mint: Color(0xFF17362E),
    lavender: Color(0xFF292442),
    orange: Color(0xFF3B2A1D),
  );

  final Color primary;
  final Color deepText;
  final Color secondaryText;
  final Color canvas;
  final Color sidebar;
  final Color paleBlue;
  final Color surface;
  final Color subtleSurface;
  final Color border;
  final Color success;
  final Color warning;
  final Color mint;
  final Color lavender;
  final Color orange;

  /// Screen-specific JPEG sample anchors. These remain separate instead of
  /// being averaged into one global production brand seed.
  Color get mobileHomePrimary => const Color(0xFF1975FD);
  Color get expandedHomePrimary => const Color(0xFF1E7DFE);
  Color get approvalExpandedPrimary => const Color(0xFF0D71FF);
  Color get analysisExpandedPrimary => const Color(0xFF207CFC);
  Color get scheduleExpandedPrimary => const Color(0xFF1D7AFD);

  static TimeFitAxVisualTokens of(BuildContext context) =>
      Theme.of(context).extension<TimeFitAxVisualTokens>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  TimeFitAxVisualTokens copyWith({
    Color? primary,
    Color? deepText,
    Color? secondaryText,
    Color? canvas,
    Color? sidebar,
    Color? paleBlue,
    Color? surface,
    Color? subtleSurface,
    Color? border,
    Color? success,
    Color? warning,
    Color? mint,
    Color? lavender,
    Color? orange,
  }) => TimeFitAxVisualTokens(
    primary: primary ?? this.primary,
    deepText: deepText ?? this.deepText,
    secondaryText: secondaryText ?? this.secondaryText,
    canvas: canvas ?? this.canvas,
    sidebar: sidebar ?? this.sidebar,
    paleBlue: paleBlue ?? this.paleBlue,
    surface: surface ?? this.surface,
    subtleSurface: subtleSurface ?? this.subtleSurface,
    border: border ?? this.border,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    mint: mint ?? this.mint,
    lavender: lavender ?? this.lavender,
    orange: orange ?? this.orange,
  );

  @override
  TimeFitAxVisualTokens lerp(covariant TimeFitAxVisualTokens? other, double t) {
    if (other == null) return this;
    return TimeFitAxVisualTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      deepText: Color.lerp(deepText, other.deepText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      paleBlue: Color.lerp(paleBlue, other.paleBlue, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
    );
  }
}
