import 'package:flutter/material.dart';

import '../../../../app/theme/timefit_ax_visual_tokens.dart';

enum TimeFitAssetKind { squareLogo, tabletSymbol, mobileRobot, assistantMark }

/// Reconstructed source-mapped brand/character geometry.
///
/// These painters are human-controlled traces of the supplied JPEG, not original
/// exports. They intentionally use no stock, Material, or generated mascot.
class TimeFitAssetSlot extends StatelessWidget {
  const TimeFitAssetSlot({
    required this.kind,
    required this.width,
    required this.height,
    this.keyName,
    super.key,
  });

  final TimeFitAssetKind kind;
  final double width;
  final double height;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    final bool robot = kind == TimeFitAssetKind.mobileRobot;
    final bool pending = kind == TimeFitAssetKind.assistantMark;
    final Color primary = kind == TimeFitAssetKind.tabletSymbol
        ? tokens.expandedHomePrimary
        : tokens.mobileHomePrimary;
    return Semantics(
      image: true,
      label: switch (kind) {
        TimeFitAssetKind.squareLogo => 'TimeFit AX 재구성 로고',
        TimeFitAssetKind.tabletSymbol => 'TimeFit AX 재구성 심볼',
        TimeFitAssetKind.mobileRobot => 'TimeFit AX 재구성 로봇',
        TimeFitAssetKind.assistantMark => 'TimeFit AX 도우미 자산 대기',
      },
      child: SizedBox(
        key: keyName == null ? null : Key(keyName!),
        width: width,
        height: height,
        child: CustomPaint(
          painter: pending
              ? _PendingAssetPainter(
                  color: primary.withValues(alpha: .14),
                  background: tokens.paleBlue,
                )
              : robot
              ? _ReconstructedRobotPainter(
                  primary: primary,
                  field: tokens.paleBlue,
                )
              : _ReconstructedMarkPainter(
                  color: primary,
                  square: kind == TimeFitAssetKind.squareLogo,
                ),
        ),
      ),
    );
  }
}

final class _ReconstructedMarkPainter extends CustomPainter {
  const _ReconstructedMarkPainter({required this.color, required this.square});
  final Color color;
  final bool square;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    if (square) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(shortest * .2),
        ),
        Paint()..color = color,
      );
    }
    _paintTimeFitMark(
      canvas,
      Offset.zero & size,
      square ? Colors.white : color,
      strokeFraction: square ? .105 : .09,
    );
  }

  @override
  bool shouldRepaint(covariant _ReconstructedMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.square != square;
}

final class _ReconstructedRobotPainter extends CustomPainter {
  const _ReconstructedRobotPainter({
    required this.primary,
    required this.field,
  });

  final Color primary;
  final Color field;

  @override
  void paint(Canvas canvas, Size size) {
    final fieldRect = Offset.zero & size;
    canvas.drawOval(fieldRect, Paint()..color = field);

    // Source silhouette envelope: roughly 85.2% W × 79.9% H of the field.
    final Rect robot = Rect.fromCenter(
      center: Offset(size.width * .51, size.height * .51),
      width: size.width * .852,
      height: size.height * .799,
    );
    final double unit = robot.shortestSide;
    final Paint blue = Paint()
      ..color = primary
      ..style = PaintingStyle.fill;
    final Paint blueStroke = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .035
      ..strokeCap = StrokeCap.round;

    // Antenna and its round terminal.
    canvas.drawLine(
      Offset(robot.center.dx, robot.top + robot.height * .13),
      Offset(robot.center.dx, robot.top + robot.height * .23),
      blueStroke,
    );
    canvas.drawCircle(
      Offset(robot.center.dx, robot.top + robot.height * .1),
      unit * .035,
      blue,
    );

    // The two asymmetric, rounded emphasis rays observed at upper right.
    canvas.drawLine(
      Offset(robot.left + robot.width * .79, robot.top + robot.height * .19),
      Offset(robot.left + robot.width * .9, robot.top + robot.height * .1),
      blueStroke,
    );
    canvas.drawLine(
      Offset(robot.left + robot.width * .84, robot.top + robot.height * .28),
      Offset(robot.left + robot.width * .96, robot.top + robot.height * .25),
      blueStroke,
    );

    final Rect head = Rect.fromLTWH(
      robot.left + robot.width * .14,
      robot.top + robot.height * .2,
      robot.width * .7,
      robot.height * .46,
    );
    final RRect outerHead = RRect.fromRectAndRadius(
      head,
      Radius.circular(head.height * .27),
    );
    canvas.drawRRect(outerHead, blue);

    // Ear pods connect to the head frame, not to the face panel.
    final Rect leftEar = Rect.fromLTWH(
      robot.left + robot.width * .06,
      head.top + head.height * .27,
      robot.width * .13,
      head.height * .45,
    );
    final Rect rightEar = Rect.fromLTWH(
      robot.left + robot.width * .8,
      head.top + head.height * .27,
      robot.width * .13,
      head.height * .45,
    );
    for (final ear in <Rect>[leftEar, rightEar]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(ear, Radius.circular(ear.width * .48)),
        blue,
      );
    }

    final Rect bezel = head.deflate(head.height * .075);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bezel, Radius.circular(bezel.height * .24)),
      Paint()..color = Colors.white,
    );
    final Rect face = bezel.deflate(bezel.height * .09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(face.height * .2)),
      blue,
    );

    final Paint eye = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * .028
      ..strokeCap = StrokeCap.round;
    Path eyePath(double centerX) => Path()
      ..moveTo(centerX - face.width * .085, face.top + face.height * .56)
      ..quadraticBezierTo(
        centerX,
        face.top + face.height * .46,
        centerX + face.width * .085,
        face.top + face.height * .56,
      );
    canvas.drawPath(eyePath(face.left + face.width * .34), eye);
    canvas.drawPath(eyePath(face.left + face.width * .66), eye);

    final Rect neck = Rect.fromLTWH(
      robot.center.dx - robot.width * .08,
      head.bottom - unit * .01,
      robot.width * .16,
      robot.height * .1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(neck, Radius.circular(neck.width * .2)),
      blue,
    );
    final Rect torso = Rect.fromLTWH(
      robot.left + robot.width * .3,
      robot.top + robot.height * .65,
      robot.width * .4,
      robot.height * .27,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torso, Radius.circular(torso.width * .19)),
      blue,
    );
    _paintTimeFitMark(
      canvas,
      torso.deflate(torso.width * .25),
      Colors.white,
      strokeFraction: .12,
    );
  }

  @override
  bool shouldRepaint(covariant _ReconstructedRobotPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.field != field;
}

void _paintTimeFitMark(
  Canvas canvas,
  Rect rect,
  Color color, {
  required double strokeFraction,
}) {
  final double stroke = rect.shortestSide * strokeFraction;
  final Paint line = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final double left = rect.left + rect.width * .23;
  final double right = rect.right - rect.width * .23;
  final double top = rect.top + rect.height * .31;
  final double centerX = rect.center.dx;
  canvas.drawLine(Offset(left, top), Offset(right, top), line);
  canvas.drawLine(
    Offset(centerX, rect.top + rect.height * .25),
    Offset(centerX, rect.bottom - rect.height * .24),
    line,
  );
  final Offset node = Offset(
    rect.left + rect.width * .75,
    rect.top + rect.height * .2,
  );
  final double nodeRadius = stroke * .65;
  canvas.drawLine(
    node.translate(-nodeRadius, 0),
    node.translate(nodeRadius, 0),
    line..strokeWidth = stroke * .56,
  );
  canvas.drawLine(
    node.translate(0, -nodeRadius),
    node.translate(0, nodeRadius),
    line,
  );
}

final class _PendingAssetPainter extends CustomPainter {
  const _PendingAssetPainter({required this.color, required this.background});
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.shortestSide * .22),
      ),
      Paint()..color = background,
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 12.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PendingAssetPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.background != background;
}
