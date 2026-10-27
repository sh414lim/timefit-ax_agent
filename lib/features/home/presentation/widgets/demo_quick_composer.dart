import 'package:flutter/material.dart';

import '../../../../app/theme/timefit_ax_visual_tokens.dart';
import '../../../../app/theme/tokens.dart';

class DemoQuickComposer extends StatelessWidget {
  const DemoQuickComposer({
    required this.controller,
    required this.focusNode,
    this.placeholder = 'TimeFit에게 물어보세요',
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    final bool expandedSource = MediaQuery.sizeOf(context).width >= 900;
    final Color sourcePrimary = expandedSource
        ? tokens.expandedHomePrimary
        : tokens.mobileHomePrimary;
    return Semantics(
      container: true,
      label: '데모 입력, 실제 업무 시스템에 연결되지 않음',
      child: Material(
        color: tokens.surface,
        elevation: 2,
        shadowColor: const Color(0x14071A39),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          constraints: BoxConstraints(minHeight: expandedSource ? 54 : 62),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: '샘플 첨부 자리',
                onPressed: () {},
                constraints: const BoxConstraints.tightFor(
                  width: AppTouchTarget.minimum,
                  height: AppTouchTarget.minimum,
                ),
                icon: CustomPaint(
                  size: const Size.square(22),
                  painter: _ReconstructedPaperclipPainter(
                    color: tokens.secondaryText,
                  ),
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.subtleSurface,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: TextStyle(color: tokens.secondaryText),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x12,
                        vertical: AppSpacing.x12,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5),
                child: IconButton.filled(
                  tooltip: '샘플 미리보기',
                  onPressed: () {},
                  style: IconButton.styleFrom(
                    backgroundColor: sourcePrimary,
                    foregroundColor: Colors.white,
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: 46,
                    height: 46,
                  ),
                  icon: const CustomPaint(
                    size: Size.square(22),
                    painter: _ReconstructedSendPainter(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ReconstructedPaperclipPainter extends CustomPainter {
  const _ReconstructedPaperclipPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path path = Path()
      ..moveTo(size.width * .7, size.height * .29)
      ..lineTo(size.width * .38, size.height * .66)
      ..quadraticBezierTo(
        size.width * .23,
        size.height * .82,
        size.width * .1,
        size.height * .68,
      )
      ..quadraticBezierTo(
        size.width * .01,
        size.height * .56,
        size.width * .13,
        size.height * .42,
      )
      ..lineTo(size.width * .56, size.height * .08)
      ..quadraticBezierTo(
        size.width * .77,
        -size.height * .03,
        size.width * .9,
        size.height * .14,
      )
      ..quadraticBezierTo(
        size.width,
        size.height * .29,
        size.width * .86,
        size.height * .43,
      )
      ..lineTo(size.width * .42, size.height * .84);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _ReconstructedPaperclipPainter oldDelegate) =>
      oldDelegate.color != color;
}

final class _ReconstructedSendPainter extends CustomPainter {
  const _ReconstructedSendPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path plane = Path()
      ..moveTo(size.width * .12, size.height * .48)
      ..lineTo(size.width * .88, size.height * .14)
      ..lineTo(size.width * .66, size.height * .86)
      ..lineTo(size.width * .48, size.height * .57)
      ..close();
    canvas.drawPath(plane, stroke);
    canvas.drawLine(
      Offset(size.width * .48, size.height * .57),
      Offset(size.width * .88, size.height * .14),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ReconstructedSendPainter oldDelegate) =>
      oldDelegate.color != color;
}
