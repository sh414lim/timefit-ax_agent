import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the existing local brand asset. Only a small, isolated transform is
/// ticked for one short pulse; the page and its editor never animate with it.
class TimeFitRobotMotion extends StatefulWidget {
  const TimeFitRobotMotion({required this.child, super.key});

  final Widget child;

  @override
  State<TimeFitRobotMotion> createState() => _TimeFitRobotMotionState();
}

class _TimeFitRobotMotionState extends State<TimeFitRobotMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 840),
  );
  Timer? _idle;
  bool _enabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled =
        !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
    if (enabled == _enabled) return;
    _enabled = enabled;
    _idle?.cancel();
    if (!enabled) {
      _pulse.stop();
      _pulse.value = 0;
      return;
    }
    // Wait out the enter transition; do not compete with first paint or typing.
    _idle = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pulse.forward(from: 0),
    );
  }

  @override
  void dispose() {
    _idle?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _pulse,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) => Transform.translate(
        key: const Key('timefit-robot-pulse'),
        offset: Offset(0, _enabled ? -4 * math.sin(_pulse.value * math.pi) : 0),
        child: child,
      ),
    ),
  );
}
