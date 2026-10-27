import 'package:flutter/material.dart';

import '../demo_home_action.dart';

/// Human-controlled traces of the four Home action glyphs observed in the
/// supplied JPEG. These are reconstructed paths, not original exports.
class ReconstructedHomeActionGlyph extends StatelessWidget {
  const ReconstructedHomeActionGlyph({
    required this.action,
    required this.color,
    required this.size,
    super.key,
  });

  final DemoHomeAction action;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _HomeActionGlyphPainter(action, color)),
  );
}

final class _HomeActionGlyphPainter extends CustomPainter {
  const _HomeActionGlyphPainter(this.action, this.color);
  final DemoHomeAction action;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.shortestSide;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (action) {
      case DemoHomeAction.storeOverview:
        final Paint fill = Paint()..color = color;
        for (final bar in <(double, double)>[
          (.19, .47),
          (.43, .3),
          (.67, .16),
        ]) {
          final rect = Rect.fromLTWH(
            size.width * bar.$1,
            size.height * bar.$2,
            size.width * .14,
            size.height * (.78 - bar.$2),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(unit * .07)),
            fill,
          );
        }
      case DemoHomeAction.weeklySchedule:
        final Rect calendar = Rect.fromLTWH(
          size.width * .14,
          size.height * .2,
          size.width * .72,
          size.height * .64,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(calendar, Radius.circular(unit * .1)),
          stroke,
        );
        canvas.drawLine(
          Offset(calendar.left, calendar.top + calendar.height * .27),
          Offset(calendar.right, calendar.top + calendar.height * .27),
          stroke,
        );
        for (final x in <double>[.34, .66]) {
          canvas.drawLine(
            Offset(
              calendar.left + calendar.width * x,
              calendar.top - unit * .08,
            ),
            Offset(
              calendar.left + calendar.width * x,
              calendar.top + unit * .08,
            ),
            stroke,
          );
        }
        for (final point in const <Offset>[
          Offset(.34, .58),
          Offset(.57, .58),
          Offset(.34, .74),
          Offset(.57, .74),
        ]) {
          canvas.drawCircle(
            Offset(size.width * point.dx, size.height * point.dy),
            unit * .035,
            Paint()..color = color,
          );
        }
      case DemoHomeAction.costAnalysis:
        final Rect top = Rect.fromLTWH(
          size.width * .16,
          size.height * .18,
          size.width * .68,
          size.height * .25,
        );
        canvas.drawOval(top, stroke);
        canvas.drawArc(
          Rect.fromLTWH(top.left, size.height * .37, top.width, top.height),
          0,
          3.14159,
          false,
          stroke,
        );
        canvas.drawArc(
          Rect.fromLTWH(top.left, size.height * .57, top.width, top.height),
          0,
          3.14159,
          false,
          stroke,
        );
        canvas.drawLine(
          Offset(top.left, top.center.dy),
          Offset(top.left, size.height * .69),
          stroke,
        );
        canvas.drawLine(
          Offset(top.right, top.center.dy),
          Offset(top.right, size.height * .69),
          stroke,
        );
      case DemoHomeAction.employeeAnnouncement:
        final Path document = Path()
          ..moveTo(size.width * .2, size.height * .12)
          ..lineTo(size.width * .62, size.height * .12)
          ..lineTo(size.width * .78, size.height * .28)
          ..lineTo(size.width * .78, size.height * .78)
          ..quadraticBezierTo(
            size.width * .78,
            size.height * .86,
            size.width * .7,
            size.height * .86,
          )
          ..lineTo(size.width * .2, size.height * .86)
          ..close();
        canvas.drawPath(document, stroke);
        canvas.drawLine(
          Offset(size.width * .34, size.height * .64),
          Offset(size.width * .82, size.height * .2),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * .31, size.height * .68),
          Offset(size.width * .27, size.height * .78),
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _HomeActionGlyphPainter oldDelegate) =>
      oldDelegate.action != action || oldDelegate.color != color;
}
