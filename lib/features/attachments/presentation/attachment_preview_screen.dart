import 'package:flutter/material.dart';

import '../application/attachment_download_controller.dart';
import 'attachment_tile.dart';

typedef AttachmentRenderer = Widget Function(BuildContext context, Uri url);

final class AttachmentPreviewScreen extends StatefulWidget {
  const AttachmentPreviewScreen({
    required this.controller,
    required this.imageRenderer,
    required this.pdfRenderer,
    super.key,
  });

  final AttachmentDownloadController controller;
  final AttachmentRenderer imageRenderer;
  final AttachmentRenderer pdfRenderer;

  @override
  State<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

final class _AttachmentPreviewScreenState
    extends State<AttachmentPreviewScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant AttachmentPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    oldWidget.controller.cancel();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.controller.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: Text(controller.metadata.safeDisplayName)),
      body: Column(
        children: <Widget>[
          AttachmentTile(
            metadata: controller.metadata,
            onOpen: controller.canOpen ? controller.open : null,
            itemPosition: 1,
            itemCount: 1,
          ),
          Expanded(child: Center(child: _body(controller))),
        ],
      ),
    );
  }

  Widget _body(AttachmentDownloadController controller) =>
      switch (controller.state) {
        AttachmentPreviewIdle() => FilledButton(
          onPressed: controller.open,
          child: const Text('미리보기 열기'),
        ),
        AttachmentPreviewLoading() => const CircularProgressIndicator(),
        AttachmentPreviewReady(:final kind, :final url) => switch (kind) {
          AttachmentPreviewKind.image => widget.imageRenderer(context, url),
          AttachmentPreviewKind.pdf => widget.pdfRenderer(context, url),
        },
        AttachmentPreviewFailed(:final error) => _PreviewError(
          error: error,
          onRetry:
              error == AttachmentPreviewError.unsupportedType ||
                  error == AttachmentPreviewError.accessRevoked
              ? null
              : controller.open,
        ),
      };
}

final class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.error, required this.onRetry});
  final AttachmentPreviewError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      AttachmentPreviewError.offline => '오프라인에서는 새 미리보기를 열 수 없습니다.',
      AttachmentPreviewError.accessRevoked => '이 첨부에 대한 접근 권한이 없습니다.',
      AttachmentPreviewError.expired => '미리보기 주소가 만료되었습니다.',
      AttachmentPreviewError.unsupportedType => '지원하지 않는 첨부 형식입니다.',
      AttachmentPreviewError.unavailable => '첨부를 열 수 없습니다.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}
