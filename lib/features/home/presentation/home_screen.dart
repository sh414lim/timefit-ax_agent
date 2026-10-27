import 'package:flutter/material.dart';

import '../../../app/theme/timefit_ax_visual_tokens.dart';
import '../../../app/theme/tokens.dart';
import '../../conversations/application/conversation_list_controller.dart';
import 'business_preview_screen.dart';
import 'demo_home_action.dart';
import 'widgets/brand_asset_slot.dart';
import 'widgets/demo_quick_composer.dart';
import 'widgets/reconstructed_action_glyph.dart';

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({
    required this.conversationController,
    required this.onOpenConversation,
    required this.onOpenConversationList,
    required this.onOpenArchive,
    required this.onNewConversation,
    this.draftController,
    this.draftFocusNode,
    this.onPreviewAction,
    super.key,
  });

  final ConversationListController conversationController;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onOpenConversationList;
  final VoidCallback onOpenArchive;
  final VoidCallback onNewConversation;
  final TextEditingController? draftController;
  final FocusNode? draftFocusNode;
  final ValueChanged<DemoHomeAction>? onPreviewAction;

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  late ConversationListState _recent = widget.conversationController.state;
  late final TextEditingController _draft =
      widget.draftController ?? TextEditingController();
  late final FocusNode _draftFocus = widget.draftFocusNode ?? FocusNode();
  DemoHomeAction? _preview;

  @override
  void initState() {
    super.initState();
    widget.conversationController.addListener(_handleRecent);
  }

  @override
  void didUpdateWidget(DemoHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationController != widget.conversationController) {
      oldWidget.conversationController.removeListener(_handleRecent);
      _recent = widget.conversationController.state;
      widget.conversationController.addListener(_handleRecent);
    }
  }

  void _handleRecent(ConversationListState state) {
    if (mounted) setState(() => _recent = state);
  }

  void _select(DemoHomeAction action) {
    setState(() => _preview = action);
    widget.onPreviewAction?.call(action);
  }

  @override
  void dispose() {
    widget.conversationController.removeListener(_handleRecent);
    if (widget.draftController == null) _draft.dispose();
    if (widget.draftFocusNode == null) _draftFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    final preview = _preview;
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: preview == null
          ? SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool expanded = constraints.maxWidth >= 900;
                  return expanded
                      ? _ExpandedHome(
                          recent: _recent,
                          onOpenConversation: widget.onOpenConversation,
                          onOpenConversationList: widget.onOpenConversationList,
                          onOpenArchive: widget.onOpenArchive,
                          onNewConversation: widget.onNewConversation,
                          onSelected: _select,
                          draftController: _draft,
                          draftFocusNode: _draftFocus,
                        )
                      : _MobileHome(
                          onOpenConversationList: widget.onOpenConversationList,
                          onSelected: _select,
                          draftController: _draft,
                          draftFocusNode: _draftFocus,
                        );
                },
              ),
            )
          : DemoBusinessPreviewScreen(
              action: preview,
              onBack: () => setState(() => _preview = null),
              draftController: _draft,
              draftFocusNode: _draftFocus,
            ),
    );
  }
}

class _MobileHome extends StatelessWidget {
  const _MobileHome({
    required this.onOpenConversationList,
    required this.onSelected,
    required this.draftController,
    required this.draftFocusNode,
  });

  final VoidCallback onOpenConversationList;
  final ValueChanged<DemoHomeAction> onSelected;
  final TextEditingController draftController;
  final FocusNode draftFocusNode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) => Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                primary: false,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _MobileHomeContent(
                  availableHeight: constraints.maxHeight,
                  onOpenConversationList: onOpenConversationList,
                  onSelected: onSelected,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (constraints.maxHeight - AppTouchTarget.minimum)
                    .clamp(0, double.infinity),
              ),
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DemoQuickComposer(
                  controller: draftController,
                  focusNode: draftFocusNode,
                ),
              ),
            ),
          ],
        ),
        const Positioned(
          top: 54,
          right: 16,
          child: _DemoBadge(key: Key('mobile-home-overlay-demo-badge')),
        ),
      ],
    ),
  );
}

class _MobileHomeContent extends StatelessWidget {
  const _MobileHomeContent({
    required this.availableHeight,
    required this.onOpenConversationList,
    required this.onSelected,
  });

  final double availableHeight;
  final VoidCallback onOpenConversationList;
  final ValueChanged<DemoHomeAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 52,
          child: Row(
            children: <Widget>[
              const TimeFitAssetSlot(
                kind: TimeFitAssetKind.squareLogo,
                width: 40,
                height: 40,
                keyName: 'mobile-home-logo-slot',
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Text(
                  'TimeFit AX',
                  style: TextStyle(
                    color: tokens.deepText,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SourceHeaderButton(
                tooltip: '알림 샘플',
                onPressed: () {},
                glyph: _HeaderGlyph.bell,
              ),
              _SourceHeaderButton(
                tooltip: '메뉴 샘플',
                onPressed: onOpenConversationList,
                glyph: _HeaderGlyph.more,
              ),
            ],
          ),
        ),
        SizedBox(height: (availableHeight * .035).clamp(24, 34)),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double robotWidth = (MediaQuery.sizeOf(context).width * .398)
                .clamp(136, 176);
            return Center(
              child: TimeFitAssetSlot(
                kind: TimeFitAssetKind.mobileRobot,
                width: robotWidth,
                height: robotWidth,
                keyName: 'mobile-home-robot-slot',
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.x16),
        Text(
          '무엇을 도와드릴까요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tokens.deepText,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.x12),
        Text(
          '매장 운영부터 근무, 비용, 커뮤니케이션까지\nTimeFit AX가 함께합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.secondaryText, height: 1.45),
        ),
        SizedBox(height: (availableHeight * .1).clamp(64, 88)),
        _ActionGrid(expanded: false, onSelected: onSelected),
        const SizedBox(height: AppSpacing.x12),
      ],
    );
  }
}

class _ExpandedHome extends StatelessWidget {
  const _ExpandedHome({
    required this.recent,
    required this.onOpenConversation,
    required this.onOpenConversationList,
    required this.onOpenArchive,
    required this.onNewConversation,
    required this.onSelected,
    required this.draftController,
    required this.draftFocusNode,
  });

  final ConversationListState recent;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onOpenConversationList;
  final VoidCallback onOpenArchive;
  final VoidCallback onNewConversation;
  final ValueChanged<DemoHomeAction> onSelected;
  final TextEditingController draftController;
  final FocusNode draftFocusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    final double width = MediaQuery.sizeOf(context).width;
    return Row(
      children: <Widget>[
        SizedBox(
          key: const Key('expanded-home-sidebar'),
          width: width * .178,
          child: _ExpandedNavigation(
            recent: recent,
            onOpenConversation: onOpenConversation,
            onShowAll: onOpenConversationList,
            onShowArchive: onOpenArchive,
            onNewConversation: onNewConversation,
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: tokens.canvas,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: (constraints.maxHeight - 104).clamp(
                                  0,
                                  double.infinity,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const TimeFitAssetSlot(
                                    kind: TimeFitAssetKind.tabletSymbol,
                                    width: 90,
                                    height: 78,
                                    keyName: 'expanded-home-symbol-slot',
                                  ),
                                  const SizedBox(height: AppSpacing.x20),
                                  Text.rich(
                                    TextSpan(
                                      children: <InlineSpan>[
                                        const TextSpan(text: '무엇을 '),
                                        TextSpan(
                                          text: '도와드릴까요?',
                                          style: TextStyle(
                                            color: tokens.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: tokens.deepText,
                                      fontSize: 38,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.x12),
                                  Text(
                                    '매장 운영부터 근무, 비용, 커뮤니케이션까지',
                                    style: TextStyle(
                                      color: tokens.secondaryText,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 34),
                                  _ActionGrid(
                                    expanded: true,
                                    onSelected: onSelected,
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                        DemoQuickComposer(
                          controller: draftController,
                          focusNode: draftFocusNode,
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandedNavigation extends StatelessWidget {
  const _ExpandedNavigation({
    required this.recent,
    required this.onOpenConversation,
    required this.onShowAll,
    required this.onShowArchive,
    required this.onNewConversation,
  });

  final ConversationListState recent;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onShowAll;
  final VoidCallback onShowArchive;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return ColoredBox(
      color: tokens.sidebar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Column(
                children: <Widget>[
                  const TimeFitAssetSlot(
                    kind: TimeFitAssetKind.squareLogo,
                    width: 72,
                    height: 72,
                    keyName: 'expanded-home-logo-slot',
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  Text(
                    'TimeFit AX',
                    style: TextStyle(
                      color: tokens.deepText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x24),
            FilledButton.icon(
              onPressed: onNewConversation,
              icon: const Icon(Icons.add),
              label: const Text('새 대화'),
              style: FilledButton.styleFrom(backgroundColor: tokens.primary),
            ),
            const SizedBox(height: AppSpacing.x24),
            Text(
              '최근 대화',
              style: TextStyle(
                color: tokens.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.x8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: AppTouchTarget.minimum,
              leading: const Icon(Icons.chat_bubble_outline, size: 20),
              title: const Text('모든 대화'),
              onTap: onShowAll,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final conversation in recent.conversations.take(4))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.chat_bubble_outline, size: 18),
                      title: Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onOpenConversation(conversation.id),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.archive_outlined, size: 20),
                    title: const Text('보관'),
                    onTap: onShowArchive,
                  ),
                ],
              ),
            ),
            const _DemoBadge(),
            const SizedBox(height: AppSpacing.x8),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.settings_outlined),
              title: Text('설정'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.expanded, required this.onSelected});
  final bool expanded;
  final ValueChanged<DemoHomeAction> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
      final int columns = largeText || (!expanded && constraints.maxWidth < 360)
          ? 1
          : expanded
          ? 4
          : 2;
      final double gap = expanded ? 12 : 8;
      final double cardWidth =
          (constraints.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: <Widget>[
          for (final action in DemoHomeAction.values)
            SizedBox(
              width: cardWidth,
              child: _ActionCard(
                action: action,
                expanded: expanded,
                largeText: largeText,
                cardWidth: cardWidth,
                onTap: () => onSelected(action),
              ),
            ),
        ],
      );
    },
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.expanded,
    required this.largeText,
    required this.cardWidth,
    required this.onTap,
  });

  final DemoHomeAction action;
  final bool expanded;
  final bool largeText;
  final double cardWidth;
  final VoidCallback onTap;

  Color _tint(TimeFitAxVisualTokens tokens) {
    if (!expanded) return tokens.paleBlue;
    return switch (action) {
      DemoHomeAction.storeOverview => tokens.paleBlue,
      DemoHomeAction.weeklySchedule => tokens.mint,
      DemoHomeAction.costAnalysis => tokens.lavender,
      DemoHomeAction.employeeAnnouncement => tokens.orange,
    };
  }

  Color _glyphColor(TimeFitAxVisualTokens tokens) {
    if (!expanded) return tokens.mobileHomePrimary;
    return switch (action) {
      DemoHomeAction.storeOverview => tokens.expandedHomePrimary,
      DemoHomeAction.weeklySchedule => const Color(0xFF42A681),
      DemoHomeAction.costAnalysis => const Color(0xFF765BC5),
      DemoHomeAction.employeeAnnouncement => const Color(0xFFE78A42),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    final Widget content = expanded
        ? Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _ActionIcon(
                    action: action,
                    color: _tint(tokens),
                    glyphColor: _glyphColor(tokens),
                    square: true,
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  Text(action.label, style: _titleStyle(tokens)),
                  const SizedBox(height: AppSpacing.x4),
                  Padding(
                    padding: const EdgeInsets.only(right: 34),
                    child: Text(
                      action.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.secondaryText,
                        fontSize: 10.5,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: tokens.subtleSurface,
                  foregroundColor: tokens.secondaryText,
                  child: const Icon(Icons.arrow_forward, size: 18),
                ),
              ),
            ],
          )
        : Row(
            children: <Widget>[
              _ActionIcon(
                action: action,
                color: _tint(tokens),
                glyphColor: _glyphColor(tokens),
                square: false,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: _titleStyle(tokens),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.description,
                      key: Key('home-action-description-${action.name}'),
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: tokens.secondaryText,
                        fontSize: 9,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.secondaryText, size: 12),
            ],
          );
    return Semantics(
      button: true,
      label: '${action.label}, ${action.description}, 샘플 미리보기',
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        // The source cards are compact at 100%, while accessibility scaling
        // needs enough height for the same unabridged label and description.
        height: _height,
        child: Material(
          color: tokens.surface,
          elevation: 1,
          shadowColor: const Color(0x12071A39),
          borderRadius: BorderRadius.circular(expanded ? 16 : 13),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(expanded ? 16 : 13),
            child: Container(
              padding: EdgeInsets.all(expanded ? 16 : 5),
              decoration: BoxDecoration(
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(expanded ? 16 : 13),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  double get _height {
    if (expanded) return largeText ? 280 : 162;
    if (largeText) return 170;
    // At the 432 logical source viewport this resolves to the measured
    // 2.15:1 card aspect. Narrower accessibility adaptations get a small
    // content floor instead of clipping the Korean two-line descriptions.
    if (cardWidth >= 190 && cardWidth <= 220) return cardWidth / 2.15;
    return 98;
  }

  TextStyle _titleStyle(TimeFitAxVisualTokens tokens) => TextStyle(
    color: tokens.deepText,
    fontWeight: FontWeight.w700,
    fontSize: expanded ? 16 : 12,
  );
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.action,
    required this.color,
    required this.glyphColor,
    required this.square,
  });

  final DemoHomeAction action;
  final Color color;
  final Color glyphColor;
  final bool square;

  @override
  Widget build(BuildContext context) => Container(
    width: square ? 48 : 32,
    height: square ? 48 : 32,
    decoration: BoxDecoration(
      color: color,
      shape: square ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: square ? BorderRadius.circular(12) : null,
    ),
    child: Center(
      child: ReconstructedHomeActionGlyph(
        action: action,
        color: glyphColor,
        size: square ? 25 : 18,
      ),
    ),
  );
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = TimeFitAxVisualTokens.of(context);
    return Semantics(
      label: '데모 화면, 실제 업무 시스템에 연결되지 않음',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: tokens.paleBlue,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '데모',
          style: TextStyle(
            color: tokens.primary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

enum _HeaderGlyph { bell, more }

class _SourceHeaderButton extends StatelessWidget {
  const _SourceHeaderButton({
    required this.tooltip,
    required this.onPressed,
    required this.glyph,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final _HeaderGlyph glyph;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: CustomPaint(
      size: const Size.square(23),
      painter: _SourceHeaderGlyphPainter(
        glyph: glyph,
        color: TimeFitAxVisualTokens.of(context).deepText,
      ),
    ),
  );
}

final class _SourceHeaderGlyphPainter extends CustomPainter {
  const _SourceHeaderGlyphPainter({required this.glyph, required this.color});
  final _HeaderGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (glyph == _HeaderGlyph.more) {
      final Paint dot = Paint()..color = color;
      for (final y in const <double>[.24, .5, .76]) {
        canvas.drawCircle(
          Offset(size.width * .5, size.height * y),
          size.shortestSide * .075,
          dot,
        );
      }
      return;
    }
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path bell = Path()
      ..moveTo(size.width * .22, size.height * .68)
      ..quadraticBezierTo(
        size.width * .31,
        size.height * .57,
        size.width * .31,
        size.height * .39,
      )
      ..quadraticBezierTo(
        size.width * .31,
        size.height * .16,
        size.width * .5,
        size.height * .16,
      )
      ..quadraticBezierTo(
        size.width * .69,
        size.height * .16,
        size.width * .69,
        size.height * .39,
      )
      ..quadraticBezierTo(
        size.width * .69,
        size.height * .57,
        size.width * .78,
        size.height * .68,
      )
      ..close();
    canvas.drawPath(bell, stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .67),
        width: size.width * .25,
        height: size.height * .25,
      ),
      0,
      3.14159,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SourceHeaderGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
