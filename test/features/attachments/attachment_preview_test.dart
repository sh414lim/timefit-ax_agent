import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/attachments/application/attachment_download_controller.dart';
import 'package:timefit_native/features/attachments/presentation/attachment_preview_screen.dart';

void main() {
  late DateTime now;
  late AttachmentUrlMemoryCache cache;
  late _FakeUrlProvider provider;
  late _Telemetry telemetry;

  setUp(() {
    now = DateTime.utc(2026, 10, 20, 12);
    cache = AttachmentUrlMemoryCache();
    provider = _FakeUrlProvider();
    telemetry = _Telemetry();
  });

  AttachmentDownloadController controller({
    String name = 'private.png',
    String contentType = 'image/png',
  }) => AttachmentDownloadController(
    metadata: AttachmentPreviewMetadata(
      attachmentId: 'attachment-1',
      displayName: name,
      contentType: contentType,
    ),
    provider: provider,
    clock: () => now,
    memoryCache: cache,
    telemetry: telemetry,
  );

  SignedAttachmentUrl signed(String token, Duration lifetime) =>
      SignedAttachmentUrl(
        url: Uri.parse('https://private.invalid/download?token=$token'),
        expiresAt: now.add(lifetime),
      );

  test('memory URL refreshes inside the 30 second expiry window', () async {
    provider.results.add(
      Future.value(signed('first-secret', const Duration(minutes: 2))),
    );
    provider.results.add(
      Future.value(signed('second-secret', const Duration(minutes: 2))),
    );
    final subject = controller();
    addTearDown(subject.dispose);

    await subject.open();
    now = now.add(const Duration(seconds: 80));
    await subject.open();
    expect(provider.calls, 1);
    now = now.add(const Duration(seconds: 11));
    await subject.open();

    expect(provider.calls, 2);
    expect(
      (subject.state as AttachmentPreviewReady).url.queryParameters['token'],
      'second-secret',
    );
    expect(cache.length, 1);
    expect(telemetry.events.join(), isNot(contains('secret')));
    expect(telemetry.events, contains('attachment_url_cache_hit'));
  });

  test('expired provider result is rejected and never cached', () async {
    provider.results.add(
      Future.value(signed('expired', const Duration(seconds: -1))),
    );
    final subject = controller();
    addTearDown(subject.dispose);

    await subject.open();

    expect(
      (subject.state as AttachmentPreviewFailed).error,
      AttachmentPreviewError.expired,
    );
    expect(cache.length, 0);
  });

  test('403 refresh becomes access revoked and clears the URL', () async {
    provider.results.add(
      Future.value(signed('first', const Duration(minutes: 2))),
    );
    provider.results.add(
      Future.error(
        const AttachmentUrlException(AttachmentUrlFailure.forbidden),
      ),
    );
    final subject = controller();
    addTearDown(subject.dispose);
    await subject.open();

    await subject.refreshAfterForbidden();

    expect(
      (subject.state as AttachmentPreviewFailed).error,
      AttachmentPreviewError.accessRevoked,
    );
    expect(cache.length, 0);
    expect(provider.calls, 2);
  });

  test('download provider failure is a redacted unavailable state', () async {
    provider.results.add(
      Future.error(
        const AttachmentUrlException(AttachmentUrlFailure.unavailable),
      ),
    );
    final subject = controller(name: 'private-name.png');
    addTearDown(subject.dispose);

    await subject.open();

    expect(
      (subject.state as AttachmentPreviewFailed).error,
      AttachmentPreviewError.unavailable,
    );
    expect(telemetry.events.join(), isNot(contains('private-name')));
  });

  test('URL cache is memory-only and absent from metadata', () async {
    provider.results.add(
      Future.value(signed('never-persist', const Duration(minutes: 2))),
    );
    final subject = controller();
    addTearDown(subject.dispose);
    await subject.open();

    expect(cache.length, 1);
    expect(AttachmentUrlMemoryCache().length, 0);
    expect(subject.metadata.attachmentId, 'attachment-1');
    expect(subject.metadata.displayName, 'private.png');
    expect(subject.metadata.toString(), isNot(contains('never-persist')));
  });

  test('offline cache hit opens; offline cache miss is explicit', () async {
    cache.put('attachment-1', signed('cached', const Duration(minutes: 2)));
    final cached = controller();
    addTearDown(cached.dispose);
    await cached.open();
    expect(provider.calls, 0);
    expect(cached.state, isA<AttachmentPreviewReady>());

    cache.clear();
    provider.results.add(
      Future.error(const AttachmentUrlException(AttachmentUrlFailure.offline)),
    );
    final missed = controller();
    addTearDown(missed.dispose);
    await missed.open();
    expect(
      (missed.state as AttachmentPreviewFailed).error,
      AttachmentPreviewError.offline,
    );
  });

  test('consecutive taps share one provider request', () async {
    final pending = Completer<SignedAttachmentUrl>();
    provider.results.add(pending.future);
    final subject = controller();
    addTearDown(subject.dispose);

    final first = subject.open();
    final second = subject.open();
    expect(identical(first, second), isTrue);
    expect(provider.calls, 1);
    pending.complete(signed('once', const Duration(minutes: 2)));
    await first;
    expect(subject.state, isA<AttachmentPreviewReady>());
  });

  test('cancel and session transition ignore late private URLs', () async {
    final cancelledResult = Completer<SignedAttachmentUrl>();
    provider.results.add(cancelledResult.future);
    final cancelled = controller();
    addTearDown(cancelled.dispose);
    final cancelledLoad = cancelled.open();
    cancelled.cancel();
    cancelledResult.complete(signed('cancelled', const Duration(minutes: 2)));
    await cancelledLoad;
    expect(cancelled.state, isA<AttachmentPreviewIdle>());
    expect(cache.length, 0);

    final sessionResult = Completer<SignedAttachmentUrl>();
    provider.results.add(sessionResult.future);
    final session = controller();
    addTearDown(session.dispose);
    final sessionLoad = session.open();
    session.closeSession();
    sessionResult.complete(signed('old-session', const Duration(minutes: 2)));
    await sessionLoad;
    expect(
      (session.state as AttachmentPreviewFailed).error,
      AttachmentPreviewError.accessRevoked,
    );
    expect(cache.length, 0);
  });

  testWidgets('unsupported MIME never invokes a renderer or provider', (
    tester,
  ) async {
    final subject = controller(contentType: 'text/html');
    addTearDown(subject.dispose);
    var renderCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AttachmentPreviewScreen(
          controller: subject,
          imageRenderer: (_, _) {
            renderCalls += 1;
            return const Text('image');
          },
          pdfRenderer: (_, _) {
            renderCalls += 1;
            return const Text('pdf');
          },
        ),
      ),
    );

    await tester.tap(find.text('미리보기 열기'));
    await tester.pump();

    expect(find.text('지원하지 않는 첨부 형식입니다.'), findsOneWidget);
    expect(provider.calls, 0);
    expect(renderCalls, 0);
  });

  testWidgets('filename injection is inert text and URL is not displayed', (
    tester,
  ) async {
    provider.results.add(
      Future.value(signed('private-token', const Duration(minutes: 2))),
    );
    final subject = controller(name: '<script>alert(1)</script>\nprivate.png');
    addTearDown(subject.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AttachmentPreviewScreen(
          controller: subject,
          imageRenderer: (_, _) => const Text('safe image renderer'),
          pdfRenderer: (_, _) => const Text('safe pdf renderer'),
        ),
      ),
    );
    await tester.tap(find.text('미리보기 열기'));
    await tester.pumpAndSettle();

    expect(
      find.text('<script>alert(1)</script>�private.png'),
      findsNWidgets(2),
    );
    expect(find.text('safe image renderer'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    expect(telemetry.events.join(), isNot(contains('<script>')));
    final widgetTypes = tester
        .widgetList(find.byWidgetPredicate((_) => true))
        .map((widget) => widget.runtimeType.toString());
    expect(
      widgetTypes.where(
        (name) => name.contains('WebView') || name.contains('HtmlElementView'),
      ),
      isEmpty,
    );
  });

  testWidgets('image and PDF use only their explicit renderers', (
    tester,
  ) async {
    provider.results.add(
      Future.value(signed('image', const Duration(minutes: 2))),
    );
    final image = controller();
    addTearDown(image.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AttachmentPreviewScreen(
          controller: image,
          imageRenderer: (_, _) => const Text('image renderer'),
          pdfRenderer: (_, _) => const Text('pdf renderer'),
        ),
      ),
    );
    await tester.tap(find.text('미리보기 열기'));
    await tester.pumpAndSettle();
    expect(find.text('image renderer'), findsOneWidget);
    expect(find.text('pdf renderer'), findsNothing);

    cache.clear();
    provider.results.add(
      Future.value(signed('pdf', const Duration(minutes: 2))),
    );
    final pdf = controller(name: 'private.pdf', contentType: 'application/pdf');
    addTearDown(pdf.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AttachmentPreviewScreen(
          controller: pdf,
          imageRenderer: (_, _) => const Text('image renderer'),
          pdfRenderer: (_, _) => const Text('pdf renderer'),
        ),
      ),
    );
    await tester.tap(find.text('미리보기 열기'));
    await tester.pumpAndSettle();
    expect(find.text('pdf renderer'), findsOneWidget);
    expect(find.text('image renderer'), findsNothing);
  });

  testWidgets('leaving the screen cancels a late provider result', (
    tester,
  ) async {
    final pending = Completer<SignedAttachmentUrl>();
    provider.results.add(pending.future);
    final subject = controller();
    await tester.pumpWidget(
      MaterialApp(
        home: AttachmentPreviewScreen(
          controller: subject,
          imageRenderer: (_, _) => const Text('image renderer'),
          pdfRenderer: (_, _) => const Text('pdf renderer'),
        ),
      ),
    );
    await tester.tap(find.text('미리보기 열기'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(signed('after-exit', const Duration(minutes: 2)));
    await tester.pump();

    expect(cache.length, 0);
    subject.dispose();
  });
}

final class _FakeUrlProvider implements AttachmentUrlProvider {
  final results = <Future<SignedAttachmentUrl>>[];
  int calls = 0;

  @override
  Future<SignedAttachmentUrl> issue({required String attachmentId}) {
    calls += 1;
    return results.removeAt(0);
  }
}

final class _Telemetry implements AttachmentPreviewTelemetry {
  final events = <String>[];

  @override
  void record(String eventCode) => events.add(eventCode);
}
