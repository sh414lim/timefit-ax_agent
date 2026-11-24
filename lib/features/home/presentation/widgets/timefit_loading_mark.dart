import 'package:flutter/material.dart';

import 'brand_asset_slot.dart';

/// A shared visual for pending data, not an indicator of model activity.
class TimeFitLoadingMark extends StatelessWidget {
  const TimeFitLoadingMark({this.label = '불러오는 중', this.size = 44, super.key});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: label,
    child: ExcludeSemantics(
      child: TimeFitAssetSlot(
        kind: TimeFitAssetKind.squareLogo,
        width: size,
        height: size,
      ),
    ),
  );
}
