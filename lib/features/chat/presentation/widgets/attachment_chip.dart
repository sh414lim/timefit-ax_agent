import 'package:flutter/material.dart';

import '../../application/composer_controller.dart';

class ComposerAttachmentChip extends StatelessWidget {
  const ComposerAttachmentChip({
    required this.attachment,
    this.onRemoveFailed,
    super.key,
  });

  final ComposerAttachment attachment;
  final VoidCallback? onRemoveFailed;

  @override
  Widget build(BuildContext context) {
    final label = switch (attachment.state) {
      ComposerAttachmentState.queued => '대기 중',
      ComposerAttachmentState.uploading => '업로드 중',
      ComposerAttachmentState.failed => '업로드 실패',
      ComposerAttachmentState.ready => '준비됨',
    };
    final progress = attachment.bytesTotal <= 0
        ? null
        : attachment.bytesSent / attachment.bytesTotal;
    return Semantics(
      label: '첨부 ${attachment.contentType}, $label',
      child: InputChip(
        key: ValueKey<String>('attachment-${attachment.localId}'),
        avatar: attachment.state == ComposerAttachmentState.uploading
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress,
                ),
              )
            : Icon(
                attachment.state == ComposerAttachmentState.failed
                    ? Icons.error_outline
                    : attachment.state == ComposerAttachmentState.ready
                    ? Icons.check_circle_outline
                    : Icons.schedule,
                size: 18,
              ),
        label: Text('${attachment.contentType} · $label'),
        onDeleted: attachment.state == ComposerAttachmentState.failed
            ? onRemoveFailed
            : null,
        deleteButtonTooltipMessage: '실패한 첨부 제거',
      ),
    );
  }
}
