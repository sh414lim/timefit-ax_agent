import 'dart:async';
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
typedef DevLocalPdfDocumentOpener =
    Future<PdfDocument> Function(String filePath);

final class DevLocalAttachmentPreviewScreen extends StatefulWidget {
  const DevLocalAttachmentPreviewScreen({
    required this.controller,
    this.imageRenderer,
    this.pdfRenderer,
    this.pdfDocumentOpener,
    this.autoLoad = true,
    super.key,
  });

  final DevLocalAttachmentPreviewController controller;
  final DevLocalFileRenderer? imageRenderer;
  final DevLocalFileRenderer? pdfRenderer;
  final DevLocalPdfDocumentOpener? pdfDocumentOpener;
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
        leading: Semantics(
          button: true,
          label: '미리보기 닫기',
          excludeSemantics: true,
          child: Tooltip(
            message: '미리보기 닫기',
            child: BackButton(onPressed: () => Navigator.maybePop(context)),
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: <Widget>[
          Semantics(
            label: '로컬 파일 미리보기, 서버 미업로드',
            excludeSemantics: true,
            child: const Material(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('로컬 파일 미리보기 · 서버 미업로드'),
              ),
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
          AttachmentPreviewKind.image => Semantics(
            key: const ValueKey<String>('local-image-preview-semantics'),
            label: '이미지 미리보기, 확대 및 이동 가능',
            container: true,
            child: (widget.imageRenderer ?? _imageRenderer)(
              context,
              file,
              widget.controller.reportRenderFailure,
            ),
          ),
          AttachmentPreviewKind.pdf => Semantics(
            key: const ValueKey<String>('local-pdf-preview-semantics'),
            label: 'PDF 미리보기, 확대 및 이동 가능',
            container: true,
            child: widget.pdfRenderer != null
                ? widget.pdfRenderer!(
                    context,
                    file,
                    widget.controller.reportRenderFailure,
                  )
                : _pdfRenderer(
                    context,
                    file,
                    widget.controller.reportRenderFailure,
                    documentOpener:
                        widget.pdfDocumentOpener ?? PdfDocument.openFile,
                  ),
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
  VoidCallback onReadFailure, {
  required DevLocalPdfDocumentOpener documentOpener,
}) => _PrivatePdfRenderer(
  key: ValueKey<String>(file.path),
  file: file,
  onReadFailure: onReadFailure,
  documentOpener: documentOpener,
);

final class _PrivatePdfRenderer extends StatefulWidget {
  const _PrivatePdfRenderer({
    required this.file,
    required this.onReadFailure,
    required this.documentOpener,
    super.key,
  });
  final File file;
  final VoidCallback onReadFailure;
  final DevLocalPdfDocumentOpener documentOpener;

  @override
  State<_PrivatePdfRenderer> createState() => _PrivatePdfRendererState();
}

final class _PrivatePdfRendererState extends State<_PrivatePdfRenderer> {
  late DevLocalPdfDocumentOwner _documentOwner = _newDocumentOwner();
  late PdfControllerPinch _controller = _newController();

  DevLocalPdfDocumentOwner _newDocumentOwner() =>
      DevLocalPdfDocumentOwner(widget.documentOpener(widget.file.path));

  PdfControllerPinch _newController() =>
      PdfControllerPinch(document: _documentOwner.viewerDocument);

  @override
  void didUpdateWidget(_PrivatePdfRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path == widget.file.path) return;
    _controller.dispose();
    _documentOwner.dispose();
    _documentOwner = _newDocumentOwner();
    _controller = _newController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _documentOwner.dispose();
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

/// Owns the native document independently from pdfx's viewer controller.
///
/// pdfx does not cancel its pending document future when a viewer detaches.
/// Completing that future after detach makes its loader dereference a missing
/// view state. This owner therefore withholds late results from the viewer and
/// closes every successfully opened native document exactly once.
@visibleForTesting
final class DevLocalPdfDocumentOwner {
  DevLocalPdfDocumentOwner(Future<PdfDocument> opening) {
    opening.then(_opened, onError: _openFailed);
  }

  final Completer<PdfDocument> _viewerCompleter = Completer<PdfDocument>();
  _GuardedPdfDocument? _document;
  bool _disposed = false;
  bool _closeRequested = false;

  Future<PdfDocument> get viewerDocument => _viewerCompleter.future;

  void _opened(PdfDocument document) {
    final guarded = _GuardedPdfDocument(document);
    if (_disposed) {
      _closeOnce(guarded);
      return;
    }
    _document = guarded;
    _viewerCompleter.complete(guarded);
  }

  void _openFailed(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    _viewerCompleter.completeError(error, stackTrace);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final PdfDocument? document = _document;
    if (document != null) _closeOnce(document);
  }

  void _closeOnce(PdfDocument document) {
    if (_closeRequested) return;
    _closeRequested = true;
    unawaited(document.close().catchError((Object _) {}));
  }
}

/// Prevents every native page/texture future from resuming pdfx after its
/// viewer has detached. Results that arrive late are reclaimed locally.
final class _GuardedPdfDocument extends PdfDocument {
  _GuardedPdfDocument(this._delegate)
    : super(
        sourceName: _delegate.sourceName,
        id: _delegate.id,
        pagesCount: _delegate.pagesCount,
      );

  final PdfDocument _delegate;
  final Set<_GuardedPdfPage> _pages = <_GuardedPdfPage>{};
  bool _disposed = false;
  Future<void>? _closing;

  @override
  Future<PdfPage> getPage(int pageNumber, {bool autoCloseAndroid = false}) {
    final result = Completer<PdfPage>();
    Future<PdfPage>.sync(
      () => _delegate.getPage(pageNumber, autoCloseAndroid: autoCloseAndroid),
    ).then(
      (page) {
        if (_disposed) {
          unawaited(Future<void>.sync(page.close).catchError((Object _) {}));
          return;
        }
        final guarded = _GuardedPdfPage(this, page);
        _pages.add(guarded);
        result.complete(guarded);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_disposed) result.completeError(error, stackTrace);
      },
    );
    return result.future;
  }

  @override
  Future<void> close() {
    final existing = _closing;
    if (existing != null) return existing;
    _disposed = true;
    isClosed = true;
    for (final page in _pages) {
      page._documentDisposed();
    }
    final closing = Future<void>.sync(
      _delegate.close,
    ).catchError((Object _) {});
    _closing = closing;
    return closing;
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

final class _GuardedPdfPage extends PdfPage {
  _GuardedPdfPage(this._owner, this._delegate)
    : super(
        document: _owner,
        id: _delegate.id,
        pageNumber: _delegate.pageNumber,
        width: _delegate.width,
        height: _delegate.height,
        autoCloseAndroid: _delegate.autoCloseAndroid,
      );

  final _GuardedPdfDocument _owner;
  final PdfPage _delegate;
  final Set<_GuardedPdfTexture> _textures = <_GuardedPdfTexture>{};
  bool _disposed = false;
  Future<void>? _closing;

  @override
  Future<PdfPageImage?> render({
    required double width,
    required double height,
    PdfPageImageFormat format = PdfPageImageFormat.jpeg,
    String? backgroundColor,
    Rect? cropRect,
    int quality = 100,
    bool forPrint = false,
    bool removeTempFile = true,
  }) => _fenced<PdfPageImage?>(
    Future<PdfPageImage?>.sync(
      () => _delegate.render(
        width: width,
        height: height,
        format: format,
        backgroundColor: backgroundColor,
        cropRect: cropRect,
        quality: quality,
        forPrint: forPrint,
      ),
    ),
  );

  @override
  Future<PdfPageTexture> createTexture() {
    final result = Completer<PdfPageTexture>();
    Future<PdfPageTexture>.sync(_delegate.createTexture).then(
      (texture) {
        if (_disposed || _owner._disposed) {
          unawaited(
            Future<void>.sync(texture.dispose).catchError((Object _) {}),
          );
          return;
        }
        final guarded = _GuardedPdfTexture(texture);
        _textures.add(guarded);
        result.complete(guarded);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_disposed && !_owner._disposed) {
          result.completeError(error, stackTrace);
        }
      },
    );
    return result.future;
  }

  Future<T> _fenced<T>(Future<T> operation) {
    final result = Completer<T>();
    operation.then(
      (value) {
        if (!_disposed && !_owner._disposed) result.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_disposed && !_owner._disposed) {
          result.completeError(error, stackTrace);
        }
      },
    );
    return result.future;
  }

  void _documentDisposed() {
    if (_disposed) return;
    _disposed = true;
    isClosed = true;
    for (final texture in _textures) {
      unawaited(texture.dispose());
    }
  }

  @override
  Future<void> close() {
    final existing = _closing;
    if (existing != null) return existing;
    _documentDisposed();
    final closing = Future<void>.sync(
      _delegate.close,
    ).catchError((Object _) {});
    _closing = closing;
    return closing;
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

final class _GuardedPdfTexture extends PdfPageTexture {
  _GuardedPdfTexture(this._delegate)
    : super(
        id: _delegate.id,
        pageId: _delegate.pageId,
        pageNumber: _delegate.pageNumber,
      );

  final PdfPageTexture _delegate;
  bool _disposed = false;
  Future<void>? _disposing;

  @override
  int? get textureWidth => _delegate.textureWidth;

  @override
  int? get textureHeight => _delegate.textureHeight;

  @override
  bool get hasUpdatedTexture => _delegate.hasUpdatedTexture;

  @override
  Future<bool> updateRect({
    required String documentId,
    int destinationX = 0,
    int destinationY = 0,
    int? width,
    int? height,
    int sourceX = 0,
    int sourceY = 0,
    int? textureWidth,
    int? textureHeight,
    double? fullWidth,
    double? fullHeight,
    String? backgroundColor,
    bool allowAntiAliasing = true,
  }) {
    final result = Completer<bool>();
    Future<bool>.sync(
      () => _delegate.updateRect(
        documentId: documentId,
        destinationX: destinationX,
        destinationY: destinationY,
        width: width,
        height: height,
        sourceX: sourceX,
        sourceY: sourceY,
        textureWidth: textureWidth,
        textureHeight: textureHeight,
        fullWidth: fullWidth,
        fullHeight: fullHeight,
        backgroundColor: backgroundColor,
        allowAntiAliasing: allowAntiAliasing,
      ),
    ).then(
      (value) {
        if (!_disposed) result.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_disposed) result.completeError(error, stackTrace);
      },
    );
    return result.future;
  }

  @override
  Future<void> dispose() {
    final existing = _disposing;
    if (existing != null) return existing;
    _disposed = true;
    final disposing = Future<void>.sync(
      _delegate.dispose,
    ).catchError((Object _) {});
    _disposing = disposing;
    return disposing;
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

final class _LocalPreviewError extends StatelessWidget {
  const _LocalPreviewError({required this.error, required this.onRetry});
  final DevLocalPreviewError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String message = switch (error) {
      DevLocalPreviewError.missing => '로컬 첨부 파일이 없습니다.',
      DevLocalPreviewError.readFailed => '로컬 첨부 파일을 읽을 수 없습니다.',
      DevLocalPreviewError.unsupportedType => '지원하지 않는 첨부 형식입니다.',
    };
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Semantics(
                      key: const ValueKey<String>(
                        'local-preview-error-semantics',
                      ),
                      container: true,
                      liveRegion: true,
                      label: message,
                      excludeSemantics: true,
                      child: Column(
                        children: <Widget>[
                          const Icon(Icons.error_outline, size: 40),
                          const SizedBox(height: 8),
                          Text(message, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
