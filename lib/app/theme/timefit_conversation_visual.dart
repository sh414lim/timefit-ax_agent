import 'package:flutter/material.dart';

/// Conversation-only palette and native type hierarchy inspired by public
/// mobile design-system roles. No third-party font or image is embedded.
@immutable
final class TimeFitConversationVisual {
  const TimeFitConversationVisual({
    required this.canvas,
    required this.fill,
    required this.ink,
    required this.secondary,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentFill,
  });

  static const light = TimeFitConversationVisual(
    canvas: Colors.white,
    fill: Color(0xFFF2F4F6),
    ink: Color(0xFF191F28),
    secondary: Color(0xFF4E5968),
    muted: Color(0xFF647184),
    line: Color(0xFFE5E8EB),
    accent: Color(0xFF2258C5),
    accentFill: Color(0xFFEAF2FF),
  );

  static const dark = TimeFitConversationVisual(
    canvas: Color(0xFF161B24),
    fill: Color(0xFF222A36),
    ink: Color(0xFFF2F5FC),
    secondary: Color(0xFFCBD3E1),
    muted: Color(0xFFA9B5C7),
    line: Color(0xFF354051),
    accent: Color(0xFF9DC3FF),
    accentFill: Color(0xFF203754),
  );

  final Color canvas, fill, ink, secondary, muted, line, accent, accentFill;

  static TimeFitConversationVisual of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // Keep the OS font resolution, including Hangul fallback, and let
  // Flutter apply the user's configured text scaler rather than capping it.
  TextStyle get hero => text(26, weight: FontWeight.w700);
  TextStyle get pageTitle => text(24, weight: FontWeight.w700);
  TextStyle get roomTitle => text(20, weight: FontWeight.w700);
  TextStyle get rowTitle => text(17, weight: FontWeight.w600);
  TextStyle get summary => text(15, color: secondary);
  TextStyle get detail => text(13, color: muted);
  TextStyle editor({bool placeholder = false}) =>
      text(17, color: placeholder ? muted : null);

  TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    height: size >= 24
        ? 1.24
        : size >= 17
        ? 1.37
        : 1.42,
    letterSpacing: size >= 24
        ? -.55
        : size >= 17
        ? -.35
        : -.15,
    color: color ?? ink,
  );

  OutlineInputBorder get fieldBorder => OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.circular(14),
  );
}
