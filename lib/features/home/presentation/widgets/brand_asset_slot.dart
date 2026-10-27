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
    final bool assistant = kind == TimeFitAssetKind.assistantMark;
    final Color primary = kind == TimeFitAssetKind.tabletSymbol
        ? tokens.expandedHomePrimary
        : tokens.mobileHomePrimary;
    return Semantics(
      image: true,
      label: switch (kind) {
        TimeFitAssetKind.squareLogo => 'TimeFit AX 재구성 로고',
        TimeFitAssetKind.tabletSymbol => 'TimeFit AX 재구성 심볼',
        TimeFitAssetKind.mobileRobot => 'TimeFit AX 재구성 로봇',
        TimeFitAssetKind.assistantMark => 'TimeFit AX 재구성 도우미',
      },
      child: SizedBox(
        key: keyName == null ? null : Key(keyName!),
        width: width,
        height: height,
        child: CustomPaint(
          painter: assistant
              ? _ReconstructedAssistantPainter(
                  primary: primary,
                  field: tokens.paleBlue,
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

final class _ReconstructedAssistantPainter extends CustomPainter {
  const _ReconstructedAssistantPainter({
    required this.primary,
    required this.field,
  });

  final Color primary;
  final Color field;

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.shortestSide;
    // Source chat avatars use the TimeFit mark rather than a robot face.
    canvas.drawCircle(
      size.center(Offset.zero),
      unit * .5,
      Paint()..color = primary,
    );
    _paintTimeFitMark(
      canvas,
      Rect.fromLTWH(
        size.width * .16,
        size.height * .15,
        size.width * .68,
        size.height * .7,
      ),
      Colors.white,
      strokeFraction: .1,
    );
  }

  @override
  bool shouldRepaint(covariant _ReconstructedAssistantPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.field != field;
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
    canvas.drawOval(
      fieldRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            field,
            field.withValues(alpha: .64),
            field.withValues(alpha: 0),
          ],
          stops: const <double>[0, .72, 1],
        ).createShader(fieldRect),
    );

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
      robot.left + robot.width * .145,
      robot.top + robot.height * .205,
      robot.width * .71,
      robot.height * .435,
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
    final Rect face = bezel.deflate(bezel.height * .105);
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
      robot.left + robot.width * .28,
      robot.top + robot.height * .63,
      robot.width * .44,
      robot.height * .285,
    );
    final Path torsoShape = Path()
      ..moveTo(torso.left + torso.width * .22, torso.top)
      ..quadraticBezierTo(
        torso.left,
        torso.top,
        torso.left,
        torso.top + torso.height * .28,
      )
      ..lineTo(torso.left, torso.top + torso.height * .68)
      ..quadraticBezierTo(
        torso.left,
        torso.bottom,
        torso.left + torso.width * .25,
        torso.bottom,
      )
      ..lineTo(torso.left + torso.width * .35, torso.bottom)
      ..lineTo(
        torso.left + torso.width * .24,
        torso.bottom + torso.height * .19,
      )
      ..lineTo(torso.left + torso.width * .58, torso.bottom)
      ..lineTo(torso.left + torso.width * .76, torso.bottom)
      ..quadraticBezierTo(
        torso.right,
        torso.bottom,
        torso.right,
        torso.top + torso.height * .68,
      )
      ..lineTo(torso.right, torso.top + torso.height * .28)
      ..quadraticBezierTo(
        torso.right,
        torso.top,
        torso.left + torso.width * .78,
        torso.top,
      )
      ..close();
    canvas.drawPath(torsoShape, blue);
    _paintTimeFitMark(
      canvas,
      Rect.fromCenter(
        center: Offset(torso.center.dx, torso.center.dy + torso.height * .02),
        width: torso.width * .56,
        height: torso.height * .58,
      ),
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
  final Paint fill = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  // Controlled trace of the source mark: broad cap, hooked/check stem and
  // independent sparkle. The argument remains for call-site compatibility
  // while the geometry is expressed as filled paths instead of generic lines.
  final double capHeight = rect.height * (.2 + strokeFraction * .16);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + rect.width * .12,
        rect.top + rect.height * .2,
        rect.width * .61,
        capHeight,
      ),
      Radius.circular(rect.shortestSide * .12),
    ),
    fill,
  );
  final Path stem = Path()
    ..moveTo(rect.left + rect.width * .39, rect.top + rect.height * .31)
    ..lineTo(rect.left + rect.width * .58, rect.top + rect.height * .31)
    ..lineTo(rect.left + rect.width * .58, rect.top + rect.height * .55)
    ..cubicTo(
      rect.left + rect.width * .58,
      rect.top + rect.height * .7,
      rect.left + rect.width * .65,
      rect.top + rect.height * .75,
      rect.left + rect.width * .76,
      rect.top + rect.height * .63,
    )
    ..lineTo(rect.left + rect.width * .86, rect.top + rect.height * .73)
    ..cubicTo(
      rect.left + rect.width * .69,
      rect.top + rect.height * .92,
      rect.left + rect.width * .39,
      rect.top + rect.height * .82,
      rect.left + rect.width * .39,
      rect.top + rect.height * .56,
    )
    ..close();
  canvas.drawPath(stem, fill);

  final Offset sparkle = Offset(
    rect.left + rect.width * .82,
    rect.top + rect.height * .27,
  );
  final double ray = rect.shortestSide * .12;
  final Path diamond = Path()
    ..moveTo(sparkle.dx, sparkle.dy - ray)
    ..quadraticBezierTo(
      sparkle.dx + ray * .2,
      sparkle.dy - ray * .2,
      sparkle.dx + ray,
      sparkle.dy,
    )
    ..quadraticBezierTo(
      sparkle.dx + ray * .2,
      sparkle.dy + ray * .2,
      sparkle.dx,
      sparkle.dy + ray,
    )
    ..quadraticBezierTo(
      sparkle.dx - ray * .2,
      sparkle.dy + ray * .2,
      sparkle.dx - ray,
      sparkle.dy,
    )
    ..quadraticBezierTo(
      sparkle.dx - ray * .2,
      sparkle.dy - ray * .2,
      sparkle.dx,
      sparkle.dy - ray,
    )
    ..close();
  canvas.drawPath(diamond, fill);
}
