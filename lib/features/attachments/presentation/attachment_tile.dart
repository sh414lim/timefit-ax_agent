import 'package:flutter/material.dart';

import '../application/attachment_download_controller.dart';

final class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    required this.metadata,
    required this.onOpen,
    super.key,
  });

  final AttachmentPreviewMetadata metadata;
  final VoidCallback? onOpen;

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
      label: '첨부 ${metadata.safeDisplayName} 열기',
      onTap: onOpen,
      excludeSemantics: true,
      child: IconButton(
        tooltip: '첨부 열기',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onOpen,
        icon: const Icon(Icons.open_in_new),
      ),
    ),
  );
}
