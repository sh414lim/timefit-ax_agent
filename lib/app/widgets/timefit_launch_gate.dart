import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/home/presentation/widgets/timefit_loading_mark.dart';
import '../theme/timefit_ax_visual_tokens.dart';

/// Covers the first Flutter frame while the app underneath starts normally.
/// The timer is owned by this launch instance, not by routes or app resumes.
class TimeFitLaunchGate extends StatefulWidget {
  const TimeFitLaunchGate({
    required this.child,
    this.firstFrameRasterized,
    super.key,
  });

  static const Duration duration = Duration(milliseconds: 300);
  final Widget child;

  /// Provide the real engine signal on a cold launch. The test harness can
  /// provide a controlled signal or render without binding an engine.
  final Future<void>? firstFrameRasterized;

  @override
  State<TimeFitLaunchGate> createState() => _TimeFitLaunchGateState();
}

class _TimeFitLaunchGateState extends State<TimeFitLaunchGate> {
  Timer? _timer;
  bool _cover = true;

  @override
  void initState() {
    super.initState();
    final firstFrame = widget.firstFrameRasterized;
    if (firstFrame == null) {
      _startVisiblePeriod();
    } else {
      unawaited(firstFrame.then((_) => _startVisiblePeriod()));
    }
  }

  void _startVisiblePeriod() {
    if (!mounted) return;
    _timer = Timer(TimeFitLaunchGate.duration, () {
      if (mounted) setState(() => _cover = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeFocus(
        excluding: _cover,
        child: ExcludeSemantics(
          excluding: _cover,
          child: AbsorbPointer(absorbing: _cover, child: widget.child),
        ),
      ),
      if (_cover)
        ColoredBox(
          key: const Key('timefit-launch-splash'),
          color: TimeFitAxVisualTokens.of(context).canvas,
          child: const SafeArea(
            child: Center(
              child: TimeFitLoadingMark(label: 'TimeFit AX 시작 중', size: 72),
            ),
          ),
        ),
    ],
  );
}
