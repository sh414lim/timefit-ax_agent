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
      '${sandbox.path}/attachments',
    ).create();
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

  test('PDF owner closes normal result once across repeated dispose', () async {
    final _TrackedPdf document = _TrackedPdf();
    final owner = DevLocalPdfDocumentOwner(Future<PdfDocument>.value(document));
    expect(await owner.viewerDocument, same(document));

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
