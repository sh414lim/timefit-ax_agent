import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../application/attachment_download_controller.dart';
import '../application/dev_local_attachment_preview_controller.dart';

typedef DevLocalFileRenderer =
    Widget Function(
      BuildContext context,
      File file,
      VoidCallback onReadFailure,
    );

final class DevLocalAttachmentPreviewScreen extends StatefulWidget {
  const DevLocalAttachmentPreviewScreen({
    required this.controller,
    this.imageRenderer,
    this.pdfRenderer,
    this.autoLoad = true,
    super.key,
  });

  final DevLocalAttachmentPreviewController controller;
  final DevLocalFileRenderer? imageRenderer;
  final DevLocalFileRenderer? pdfRenderer;
  final bool autoLoad;

  @override
  State<DevLocalAttachmentPreviewScreen> createState() =>
      _DevLocalAttachmentPreviewScreenState();
}

final class _DevLocalAttachmentPreviewScreenState
    extends State<DevLocalAttachmentPreviewScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    if (widget.autoLoad) widget.controller.load();
  }

  @override
  void didUpdateWidget(DevLocalAttachmentPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_changed);
    oldWidget.controller.dispose();
    widget.controller.addListener(_changed);
    if (widget.autoLoad) widget.controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final String title = state is DevLocalPreviewReady
        ? state.displayName
        : '첨부 미리보기';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: <Widget>[
          const Material(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('로컬 파일 미리보기 · 서버 미업로드'),
            ),
          ),
          Expanded(child: _body(context, state)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, DevLocalPreviewState state) =>
      switch (state) {
        DevLocalPreviewLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        DevLocalPreviewReady(:final file, :final kind) => switch (kind) {
          AttachmentPreviewKind.image =>
            (widget.imageRenderer ?? _imageRenderer)(
              context,
              file,
              widget.controller.reportRenderFailure,
            ),
          AttachmentPreviewKind.pdf => (widget.pdfRenderer ?? _pdfRenderer)(
            context,
            file,
            widget.controller.reportRenderFailure,
          ),
        },
        DevLocalPreviewFailed(:final error) => _LocalPreviewError(
          error: error,
          onRetry: widget.controller.load,
        ),
      };
}

Widget _imageRenderer(
  BuildContext context,
  File file,
  VoidCallback onReadFailure,
) => InteractiveViewer(
  child: Center(
    child: Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onReadFailure());
        return const SizedBox.shrink();
      },
    ),
  ),
);

Widget _pdfRenderer(
  BuildContext context,
  File file,
  VoidCallback onReadFailure,
) => _PrivatePdfRenderer(file: file, onReadFailure: onReadFailure);

final class _PrivatePdfRenderer extends StatefulWidget {
  const _PrivatePdfRenderer({required this.file, required this.onReadFailure});
  final File file;
  final VoidCallback onReadFailure;

  @override
  State<_PrivatePdfRenderer> createState() => _PrivatePdfRendererState();
}

final class _PrivatePdfRendererState extends State<_PrivatePdfRenderer> {
  late PdfControllerPinch _controller = _newController();

  PdfControllerPinch _newController() =>
      PdfControllerPinch(document: PdfDocument.openFile(widget.file.path));

  @override
  void didUpdateWidget(_PrivatePdfRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path == widget.file.path) return;
    _controller.dispose();
    _controller = _newController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PdfViewPinch(
    controller: _controller,
    builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
      options: const DefaultBuilderOptions(),
      documentLoaderBuilder: (_) =>
          const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, _) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onReadFailure(),
        );
        return const SizedBox.shrink();
      },
    ),
  );
}

final class _LocalPreviewError extends StatelessWidget {
  const _LocalPreviewError({required this.error, required this.onRetry});
  final DevLocalPreviewError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(switch (error) {
          DevLocalPreviewError.missing => '로컬 첨부 파일이 없습니다.',
          DevLocalPreviewError.readFailed => '로컬 첨부 파일을 읽을 수 없습니다.',
          DevLocalPreviewError.unsupportedType => '지원하지 않는 첨부 형식입니다.',
        }),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}
