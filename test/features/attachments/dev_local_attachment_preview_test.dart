import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdfx/src/renderer/interfaces/platform.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/attachments/application/attachment_download_controller.dart';
import 'package:timefit_native/features/attachments/application/dev_local_attachment_preview_controller.dart';
import 'package:timefit_native/features/attachments/presentation/dev_local_attachment_preview_screen.dart';

const String _localId = '12345678-1234-4123-8123-123456789abc';
const List<int> _pdf = <int>[37, 80, 68, 70, 45, 49, 46, 55];
const List<int> _png = <int>[137, 80, 78, 71, 13, 10, 26, 10, 1];

void main() {
  late Directory sandbox;
  late Directory root;
  late AppDatabase database;
  late LocalRepositorySession session;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('local-preview-');
    final Directory created = await Directory(
      '${sandbox.path}/current/timefit-native/dev-local-chat-v1/attachments',
    ).create(recursive: true);
    root = Directory(await created.resolveSymbolicLinks());
    database = AppDatabase(NativeDatabase.memory());
    session = LocalRepositorySession.forDatabase(database);
  });

  tearDown(() async {
    await session.dispose();
    await database.close();
    await sandbox.delete(recursive: true);
  });

  Future<File> persist({
    List<int> bytes = _pdf,
    String contentType = 'application/pdf',
    String displayName = 'synthetic.pdf',
  }) async {
    final File file = File('${root.path}/$_localId');
    await file.writeAsBytes(bytes);
    await database
        .into(database.localAttachments)
        .insert(
          LocalAttachmentsCompanion.insert(
            localId: _localId,
            conversationId: 'conversation',
            clientMessageId: 'draft',
            localFileUri: Value(file.uri.toString()),
            displayName: Value(displayName),
            contentType: contentType,
            bytesTotal: Value(bytes.length),
            sha256: sha256.convert(bytes).toString(),
          ),
        );
    return file;
  }

  DevLocalAttachmentPreviewController controller({
    DevLocalPreviewFileReader? reader,
  }) => DevLocalAttachmentPreviewController(
    database: database,
    session: session,
    privateRoot: root,
    conversationId: 'conversation',
    localId: _localId,
    reader: reader ?? const PrivateCopyPreviewFileReader(),
  );

  test('verified private PDF and image select explicit renderers', () async {
    await persist();
    final pdfController = controller();
    addTearDown(pdfController.dispose);
    await pdfController.load();
    final pdfReady = pdfController.state as DevLocalPreviewReady;
    expect(pdfReady.kind, AttachmentPreviewKind.pdf);
    expect(pdfReady.displayName, 'synthetic.pdf');

    await database.delete(database.localAttachments).go();
    await File('${root.path}/$_localId').writeAsBytes(_png);
    await database
        .into(database.localAttachments)
        .insert(
          LocalAttachmentsCompanion.insert(
            localId: _localId,
            conversationId: 'conversation',
            clientMessageId: 'draft',
            localFileUri: Value(File('${root.path}/$_localId').uri.toString()),
            displayName: const Value('synthetic.png'),
            contentType: 'image/png',
            bytesTotal: Value(_png.length),
            sha256: sha256.convert(_png).toString(),
          ),
        );
    final imageController = controller();
    addTearDown(imageController.dispose);
    await imageController.load();
    expect(
      (imageController.state as DevLocalPreviewReady).kind,
      AttachmentPreviewKind.image,
    );
  });

  test(
    'missing, unsupported, tampered, and outside files fail closed',
    () async {
      final missing = controller();
      addTearDown(missing.dispose);
      await missing.load();
      expect(
        (missing.state as DevLocalPreviewFailed).error,
        DevLocalPreviewError.missing,
      );

      await persist(contentType: 'text/html');
      final unsupported = controller();
      addTearDown(unsupported.dispose);
      await unsupported.load();
      expect(
        (unsupported.state as DevLocalPreviewFailed).error,
        DevLocalPreviewError.unsupportedType,
      );

      await database.delete(database.localAttachments).go();
      final File file = await persist();
      await file.writeAsBytes(<int>[1, 2, 3]);
      final tampered = controller();
      addTearDown(tampered.dispose);
      await tampered.load();
      expect(
        (tampered.state as DevLocalPreviewFailed).error,
        DevLocalPreviewError.readFailed,
      );

      await database.delete(database.localAttachments).go();
      final File outside = File('${sandbox.path}/outside.pdf')
        ..writeAsBytesSync(_pdf);
      await database
          .into(database.localAttachments)
          .insert(
            LocalAttachmentsCompanion.insert(
              localId: _localId,
              conversationId: 'conversation',
              clientMessageId: 'draft',
              localFileUri: Value(outside.uri.toString()),
              displayName: const Value('outside.pdf'),
              contentType: 'application/pdf',
              bytesTotal: Value(_pdf.length),
              sha256: sha256.convert(_pdf).toString(),
            ),
          );
      final unsafe = controller();
      addTearDown(unsafe.dispose);
      await unsafe.load();
      expect(
        (unsafe.state as DevLocalPreviewFailed).error,
        DevLocalPreviewError.readFailed,
      );
    },
  );

  testWidgets('filename stays inert text and renderers receive private file', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(
      () => persist(displayName: '<img src=x onerror=alert(1)>.pdf'),
    );
    final subject = controller();
    await tester.runAsync(subject.load);
    await tester.pumpWidget(
      MaterialApp(
        home: DevLocalAttachmentPreviewScreen(
          controller: subject,
          autoLoad: false,
          imageRenderer: (_, _, _) => const Text('image-renderer'),
          pdfRenderer: (_, file, _) =>
              Text('pdf:${file.uri.pathSegments.last}'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('<img src=x onerror=alert(1)>.pdf'), findsOneWidget);
    expect(find.text('pdf:$_localId'), findsOneWidget);
    expect(find.text('로컬 파일 미리보기 · 서버 미업로드'), findsOneWidget);
    expect(find.byType(HtmlElementView), findsNothing);
  });

  test('dispose fences late read and reader releases its operation', () async {
    await persist();
    final _DelayedReader reader = _DelayedReader();
    final subject = controller(reader: reader);
    final Future<void> loading = subject.load();
    await reader.started.future;
    expect(reader.active, isTrue);
    subject.dispose();
    reader.release.complete();
    await loading;
    expect(reader.active, isFalse);
  });

  test('preview reads never alter messages or outbox', () async {
    await persist();
    final subject = controller();
    addTearDown(subject.dispose);
    await subject.load();
    await subject.load();
    expect(await database.messageDao.getAll(), isEmpty);
    expect(await database.outboxDao.getAll(), isEmpty);
  });

  test('deletion after ready becomes a stable missing-file error', () async {
    final File file = await persist();
    final subject = controller();
    addTearDown(subject.dispose);
    await subject.load();
    expect(subject.state, isA<DevLocalPreviewReady>());

    await file.delete();
    await subject.load();
    expect(
      (subject.state as DevLocalPreviewFailed).error,
      DevLocalPreviewError.missing,
    );
    subject.reportRenderFailure();
    expect(
      (subject.state as DevLocalPreviewFailed).error,
      DevLocalPreviewError.readFailed,
    );
  });

  test(
    'relocated dev namespace resolves UUID and migrates only its URI',
    () async {
      final File current = File('${root.path}/$_localId');
      await current.writeAsBytes(_pdf);
      final File old = File(
        '${sandbox.path}/old/timefit-native/dev-local-chat-v1/attachments/$_localId',
      );
      await database
          .into(database.localAttachments)
          .insert(
            LocalAttachmentsCompanion.insert(
              localId: _localId,
              conversationId: 'conversation',
              clientMessageId: 'draft',
              localFileUri: Value(old.uri.toString()),
              displayName: const Value('relocated.pdf'),
              contentType: 'application/pdf',
              bytesTotal: Value(_pdf.length),
              sha256: sha256.convert(_pdf).toString(),
            ),
          );
      final beforeMessages = await database.messageDao.getAll();
      final beforeOutbox = await database.outboxDao.getAll();
      final subject = controller();
      addTearDown(subject.dispose);

      await subject.load();

      expect(subject.state, isA<DevLocalPreviewReady>());
      final LocalAttachment migrated = await database
          .select(database.localAttachments)
          .getSingle();
      expect(migrated.localFileUri, current.uri.toString());
      expect(await database.messageDao.getAll(), beforeMessages);
      expect(await database.outboxDao.getAll(), beforeOutbox);
    },
  );

  test(
    'relocation rejects an arbitrary old parent with the same UUID',
    () async {
      final File current = File('${root.path}/$_localId');
      await current.writeAsBytes(_pdf);
      final File untrusted = File('${sandbox.path}/outside/$_localId');
      await database
          .into(database.localAttachments)
          .insert(
            LocalAttachmentsCompanion.insert(
              localId: _localId,
              conversationId: 'conversation',
              clientMessageId: 'draft',
              localFileUri: Value(untrusted.uri.toString()),
              contentType: 'application/pdf',
              bytesTotal: Value(_pdf.length),
              sha256: sha256.convert(_pdf).toString(),
            ),
          );
      final subject = controller();
      addTearDown(subject.dispose);

      await subject.load();

      expect(
        (subject.state as DevLocalPreviewFailed).error,
        DevLocalPreviewError.readFailed,
      );
      expect(
        (await database.select(database.localAttachments).getSingle())
            .localFileUri,
        untrusted.uri.toString(),
      );
    },
  );

  testWidgets('late native PDF open is fenced and closed after dispose', (
    tester,
  ) async {
    final PdfxPlatform original = PdfxPlatform.instance;
    final _DelayedPdfPlatform platform = _DelayedPdfPlatform();
    PdfxPlatform.instance = platform;
    addTearDown(() => PdfxPlatform.instance = original);
    await tester.runAsync(persist);
    final subject = controller();
    await tester.runAsync(subject.load);
    await tester.pumpWidget(
      MaterialApp(
        home: DevLocalAttachmentPreviewScreen(
          controller: subject,
          autoLoad: false,
        ),
      ),
    );
    await tester.pump();
    expect(platform.calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    final _TrackedPdf document = _TrackedPdf();
    platform.result.complete(document);
    await tester.pump();
    await tester.pump();

    expect(document.closes, 1);
    expect(tester.takeException(), equals(null));
  });

  testWidgets('late first-page failure is fenced after PDF dispose', (
    tester,
  ) async {
    final PdfxPlatform original = PdfxPlatform.instance;
    final _DelayedPdfPlatform platform = _DelayedPdfPlatform();
    PdfxPlatform.instance = platform;
    addTearDown(() => PdfxPlatform.instance = original);
    await tester.runAsync(persist);
    final subject = controller();
    await tester.runAsync(subject.load);
    await tester.pumpWidget(
      MaterialApp(
        home: DevLocalAttachmentPreviewScreen(
          controller: subject,
          autoLoad: false,
        ),
      ),
    );
    final _DelayedPagePdf document = _DelayedPagePdf();
    platform.result.complete(document);
    await tester.pump();
    await tester.pump();
    expect(document.pageCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    document.page.completeError(StateError('synthetic late page failure'));
    await tester.pump();
    await tester.pump();

    expect(document.closes, 1);
    expect(tester.takeException(), equals(null));
  });

  testWidgets('swapping PDFs attaches a new native renderer', (tester) async {
    const String secondId = '22345678-1234-4123-8123-123456789abc';
    await tester.runAsync(() async {
      await persist();
      final File file = File('${root.path}/$secondId');
      await file.writeAsBytes(_pdf);
      await database
          .into(database.localAttachments)
          .insert(
            LocalAttachmentsCompanion.insert(
              localId: secondId,
              conversationId: 'conversation',
              clientMessageId: 'draft2',
              localFileUri: Value(file.uri.toString()),
              contentType: 'application/pdf',
              sha256: sha256.convert(_pdf).toString(),
            ),
          );
    });
    final first = controller();
    final second = DevLocalAttachmentPreviewController(
      database: database,
      session: session,
      privateRoot: root,
      conversationId: 'conversation',
      localId: secondId,
    );
    await tester.runAsync(first.load);
    await tester.runAsync(second.load);
    final a = _DelayedPagePdf();
    final b = _DelayedPagePdf();
    final PdfxPlatform original = PdfxPlatform.instance;
    final platform = _MultiplePdfPlatform(<PdfDocument>[a, b]);
    PdfxPlatform.instance = platform;
    addTearDown(() => PdfxPlatform.instance = original);

    await tester.pumpWidget(
      MaterialApp(
        home: DevLocalAttachmentPreviewScreen(
          controller: first,
          autoLoad: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(a.pageCalls, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: DevLocalAttachmentPreviewScreen(
          controller: second,
          autoLoad: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(platform.calls, 2);
    expect(a.closes, 1);
    expect(b.pageCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(b.closes, 1);
  });

  test('PDF owner closes normal result once across repeated dispose', () async {
    final _TrackedPdf document = _TrackedPdf();
    final owner = DevLocalPdfDocumentOwner(Future<PdfDocument>.value(document));
    final PdfDocument guarded = await owner.viewerDocument;
    expect(guarded.id, document.id);

    owner.dispose();
    owner.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(document.closes, 1);
  });

  test('PDF owner forwards active open errors without a close', () async {
    final owner = DevLocalPdfDocumentOwner(
      Future<PdfDocument>.error(StateError('synthetic open failure')),
    );
    await expectLater(owner.viewerDocument, throwsStateError);

    owner.dispose();
  });

  test(
    'PDF owner suppresses a late open error after repeated dispose',
    () async {
      final opening = Completer<PdfDocument>();
      final owner = DevLocalPdfDocumentOwner(opening.future);
      owner.dispose();
      owner.dispose();

      opening.completeError(StateError('synthetic late failure'));
      await expectLater(
        owner.viewerDocument.timeout(const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test('PDF owner attempts a failing native close only once', () async {
    final _TrackedPdf document = _TrackedPdf(closeFails: true);
    final owner = DevLocalPdfDocumentOwner(Future<PdfDocument>.value(document));
    await owner.viewerDocument;

    owner.dispose();
    owner.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(document.closes, 1);
  });

  test(
    'late texture is reclaimed without resuming a disposed viewer',
    () async {
      final _DelayedOperationsPage page = _DelayedOperationsPage();
      final _SinglePagePdf document = _SinglePagePdf(page);
      final owner = DevLocalPdfDocumentOwner(
        Future<PdfDocument>.value(document),
      );
      final PdfDocument guarded = await owner.viewerDocument;
      final PdfPage guardedPage = await guarded.getPage(1);
      final Future<PdfPageTexture> pending = guardedPage.createTexture();
      owner.dispose();
      final _TrackedTexture texture = _TrackedTexture();
      page.texture.complete(texture);

      await expectLater(
        pending.timeout(const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      expect(texture.disposes, 1);
    },
  );

  test('late render result does not resume a disposed viewer', () async {
    final _DelayedOperationsPage page = _DelayedOperationsPage();
    final _SinglePagePdf document = _SinglePagePdf(page);
    final owner = DevLocalPdfDocumentOwner(Future<PdfDocument>.value(document));
    final PdfDocument guarded = await owner.viewerDocument;
    final PdfPage guardedPage = await guarded.getPage(1);
    final Future<PdfPageImage?> pending = guardedPage.render(
      width: 10,
      height: 10,
    );
    owner.dispose();
    page.image.complete(_SyntheticPageImage());

    await expectLater(
      pending.timeout(const Duration(milliseconds: 10)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'failing texture cleanup is contained and does not stop peers',
    () async {
      final List<Object> errors = <Object>[];
      final done = Completer<void>();
      runZonedGuarded(() async {
        final failing = _TrackedTexture(disposeFails: true);
        final succeeding = _TrackedTexture();
        final page = _MultipleTexturePage(<PdfPageTexture>[
          failing,
          succeeding,
        ]);
        final document = _SinglePagePdf(page);
        final owner = DevLocalPdfDocumentOwner(
          Future<PdfDocument>.value(document),
        );
        final PdfPage guardedPage = await (await owner.viewerDocument).getPage(
          1,
        );
        await guardedPage.createTexture();
        await guardedPage.createTexture();

        owner.dispose();
        owner.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(document.closes, 1);
        expect(failing.disposes, 1);
        expect(succeeding.disposes, 1);
        done.complete();
      }, (Object error, StackTrace stackTrace) => errors.add(error));
      await done.future.timeout(const Duration(seconds: 2));
      expect(errors, isEmpty);
    },
  );
}

final class _DelayedPdfPlatform extends PdfxPlatform {
  final Completer<PdfDocument> result = Completer<PdfDocument>();
  int calls = 0;

  @override
  Future<PdfDocument> openFile(String filePath, {String? password}) {
    calls += 1;
    return result.future;
  }

  @override
  Future<PdfDocument> openAsset(String name, {String? password}) =>
      throw UnimplementedError();

  @override
  Future<PdfDocument> openData(FutureOr<Uint8List> data, {String? password}) =>
      throw UnimplementedError();
}

final class _MultiplePdfPlatform extends _DelayedPdfPlatform {
  _MultiplePdfPlatform(this.documents);

  final List<PdfDocument> documents;

  @override
  Future<PdfDocument> openFile(String filePath, {String? password}) =>
      Future<PdfDocument>.value(documents[calls++]);
}

final class _TrackedPdf extends PdfDocument {
  _TrackedPdf({this.closeFails = false})
    : super(sourceName: 'synthetic', id: 'synthetic-pdf', pagesCount: 1);

  final bool closeFails;
  int closes = 0;

  @override
  Future<void> close() async {
    closes += 1;
    if (closeFails) throw StateError('synthetic close failure');
    isClosed = true;
  }

  @override
  Future<PdfPage> getPage(int n, {bool autoCloseAndroid = false}) =>
      throw StateError('unexpected page read after dispose');
}

final class _DelayedPagePdf extends _TrackedPdf {
  final Completer<PdfPage> page = Completer<PdfPage>();
  int pageCalls = 0;

  @override
  Future<PdfPage> getPage(int n, {bool autoCloseAndroid = false}) {
    pageCalls += 1;
    return page.future;
  }
}

final class _SinglePagePdf extends _TrackedPdf {
  _SinglePagePdf(this.page);

  final PdfPage page;

  @override
  Future<PdfPage> getPage(int n, {bool autoCloseAndroid = false}) async => page;
}

final class _DelayedOperationsPage extends PdfPage {
  _DelayedOperationsPage()
    : super(
        document: _TrackedPdf(),
        id: 'synthetic-page',
        pageNumber: 1,
        width: 10,
        height: 10,
        autoCloseAndroid: false,
      );

  final Completer<PdfPageTexture> texture = Completer<PdfPageTexture>();
  final Completer<PdfPageImage?> image = Completer<PdfPageImage?>();

  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  Future<PdfPageTexture> createTexture() => texture.future;

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
  }) => image.future;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

final class _TrackedTexture extends PdfPageTexture {
  _TrackedTexture({this.disposeFails = false})
    : super(id: 1, pageId: 'synthetic-page', pageNumber: 1);

  final bool disposeFails;
  int disposes = 0;

  @override
  bool get hasUpdatedTexture => false;

  @override
  int? get textureHeight => 10;

  @override
  int? get textureWidth => 10;

  @override
  Future<void> dispose() async {
    disposes += 1;
    if (disposeFails) throw StateError('synthetic texture dispose failed');
  }

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
  }) async => true;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

final class _MultipleTexturePage extends PdfPage {
  _MultipleTexturePage(this.textures)
    : super(
        document: _TrackedPdf(),
        id: 'synthetic-multiple-page',
        pageNumber: 1,
        width: 10,
        height: 10,
        autoCloseAndroid: false,
      );

  final List<PdfPageTexture> textures;
  int _nextTexture = 0;

  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  Future<PdfPageTexture> createTexture() async => textures[_nextTexture++];

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
  }) => throw UnimplementedError();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

final class _SyntheticPageImage extends PdfPageImage {
  _SyntheticPageImage()
    : super(
        id: 'synthetic-image',
        pageNumber: 1,
        width: 1,
        height: 1,
        bytes: Uint8List(1),
        format: PdfPageImageFormat.png,
        quality: 100,
      );

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

final class _DelayedReader implements DevLocalPreviewFileReader {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  bool active = false;

  @override
  Future<File> verify({
    required Directory privateRoot,
    required Uri uri,
    required String contentType,
    required String sha256Digest,
  }) async {
    active = true;
    started.complete();
    try {
      await release.future;
      return File.fromUri(uri);
    } finally {
      active = false;
    }
  }
}
