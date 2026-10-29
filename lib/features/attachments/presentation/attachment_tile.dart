import 'package:flutter/material.dart';

import '../application/attachment_download_controller.dart';

final class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    required this.metadata,
    required this.onOpen,
    required this.itemPosition,
    required this.itemCount,
    super.key,
  }) : assert(itemPosition >= 1),
       assert(itemCount >= 1),
       assert(itemPosition <= itemCount);

  final AttachmentPreviewMetadata metadata;
  final VoidCallback? onOpen;
  final int itemPosition;
  final int itemCount;

  String get _openLabel {
    final String action = '첨부 ${metadata.safeDisplayName} 열기';
    if (itemCount == 1) return action;
    return '$action, 총 $itemCount개 중 $itemPosition번째';
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(switch (metadata.previewKind) {
      AttachmentPreviewKind.image => Icons.image_outlined,
      AttachmentPreviewKind.pdf => Icons.picture_as_pdf_outlined,
      null => Icons.attachment_outlined,
    }),
    title: Text(metadata.safeDisplayName),
    subtitle: Text(metadata.contentType),
    trailing: Semantics(
      button: true,
      enabled: onOpen != null,
      label: _openLabel,
      onTap: onOpen,
      excludeSemantics: true,
      child: IconButton(
        tooltip: '첨부 열기',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onOpen,
        icon: const Icon(Icons.open_in_new),
      ),
    ),
  );
}
