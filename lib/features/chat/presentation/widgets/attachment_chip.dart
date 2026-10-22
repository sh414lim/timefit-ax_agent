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
    final bool canRemove =
        attachment.state == ComposerAttachmentState.failed &&
        onRemoveFailed != null;
    return Material(
      key: ValueKey<String>('attachment-${attachment.localId}'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              container: true,
              liveRegion: true,
              label: '첨부 ${attachment.contentType}, $label',
              excludeSemantics: true,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: canRemove ? 4 : 12,
                  top: 8,
                  bottom: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (attachment.state == ComposerAttachmentState.uploading)
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress,
                        ),
                      )
                    else
                      Icon(
                        attachment.state == ComposerAttachmentState.failed
                            ? Icons.error_outline
                            : attachment.state == ComposerAttachmentState.ready
                            ? Icons.check_circle_outline
                            : Icons.schedule,
                        size: 18,
                      ),
                    const SizedBox(width: 6),
                    Text('${attachment.contentType} · $label'),
                  ],
                ),
              ),
            ),
            if (canRemove)
              IconButton(
                tooltip: '실패한 첨부 제거',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                onPressed: onRemoveFailed,
                icon: const Icon(Icons.close, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
