import 'package:flutter/material.dart';

@immutable
class WorkflowResultStyle {
  const WorkflowResultStyle({
    this.primary = const Color(0xFF237FFE),
    this.canvas = const Color(0xFFFEFEFE),
    this.ink = const Color(0xFF071022),
    this.muted = const Color(0xFF626876),
    this.border = const Color(0xFFE8ECF2),
    this.paleBlue = const Color(0xFFF2F7FE),
    this.success = const Color(0xFF52B582),
  });

  final Color primary;
  final Color canvas;
  final Color ink;
  final Color muted;
  final Color border;
  final Color paleBlue;
  final Color success;

  WorkflowResultStyle copyWith({Color? primary}) => WorkflowResultStyle(
    primary: primary ?? this.primary,
    canvas: canvas,
    ink: ink,
    muted: muted,
    border: border,
    paleBlue: paleBlue,
    success: success,
  );
}

typedef WorkflowAssetBuilder =
    Widget Function(BuildContext context, String role, double size);
