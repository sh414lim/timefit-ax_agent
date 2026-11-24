import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/timefit_ax_visual_tokens.dart';
import '../../../home/presentation/widgets/brand_asset_slot.dart';

enum AxRequestStage { accepted, providerStarted, completed, uncertain, failed }

/// Presentation-only. A transport must attest providerStarted; local enqueue
/// and an accepted acknowledgement alone never imply model work.
final class AxRequestProgress {
  const AxRequestProgress({
    required this.conversationId,
    required this.requestId,
    required this.revision,
    required this.stage,
  });

  final String conversationId;
  final String requestId;
  final int revision;
  final AxRequestStage stage;

  AxRequestProgress apply(AxRequestProgress update) {
    if (conversationId != update.conversationId ||
        requestId != update.requestId ||
        stage == AxRequestStage.completed ||
        stage == AxRequestStage.failed ||
        update.revision <= revision ||
        (stage == AxRequestStage.uncertain &&
            update.stage == AxRequestStage.providerStarted) ||
        (stage == AxRequestStage.providerStarted &&
            update.stage == AxRequestStage.accepted)) {
      return this;
    }
    return update;
  }
}

/// Display a known request state without implying the provider has started.
class AxRequestNotice extends StatelessWidget {
  const AxRequestNotice(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ),
  );
}

class AxThinkingBubble extends StatefulWidget {
  const AxThinkingBubble({super.key});

  @override
  State<AxThinkingBubble> createState() => _AxThinkingBubbleState();
}

class _AxThinkingBubbleState extends State<AxThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (_animate) {
      _animation.repeat();
    } else {
      _animation.stop();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Semantics(
      label: 'TimeFit AX, 생각 중입니다',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const TimeFitAssetSlot(
                kind: TimeFitAssetKind.assistantMark,
                width: 30,
                height: 30,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('TimeFit AX'),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.paleBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, _) {
                            final t = _animation.value;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Transform.translate(
                                  offset: Offset(
                                    0,
                                    _animate
                                        ? -2.5 * math.sin(t * 2 * math.pi)
                                        : 0,
                                  ),
                                  child: const Text('🤔'),
                                ),
                                const SizedBox(width: 8),
                                const Flexible(child: Text('생각 중입니다')),
                                if (_animate) ...<Widget>[
                                  const SizedBox(width: 6),
                                  for (var i = 0; i < 3; i++)
                                    Opacity(
                                      opacity: (t * 3).floor() == i ? 1 : .35,
                                      child: const Text('·'),
                                    ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
