import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/attachments/application/attachment_download_controller.dart';
import 'package:timefit_native/features/attachments/presentation/attachment_tile.dart';

void main() {
  test(
    'display sanitization leaves identity intact and replaces format controls',
    () {
      const String original =
          'a\u061cb\u180ec\u200bd\u202ee\u2066f\u2069g\ufeffh\ufff9.pdf';
      const AttachmentPreviewMetadata metadata = AttachmentPreviewMetadata(
        attachmentId: 'format-controls',
        displayName: original,
        contentType: 'application/pdf',
      );

      expect(metadata.displayName, original);
      expect(metadata.safeDisplayName, 'a�b�c�d�e�f�g�h�.pdf');
    },
  );

  testWidgets(
    'exact duplicate names stay distinct and expose the correct tap actions',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        final List<String> opened = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  AttachmentTile(
                    metadata: const AttachmentPreviewMetadata(
                      attachmentId: 'attachment-pdf',
                      displayName: '동일.pdf',
                      contentType: 'application/pdf',
                    ),
                    onOpen: () => opened.add('pdf'),
                    itemPosition: 1,
                    itemCount: 2,
                  ),
                  AttachmentTile(
                    metadata: const AttachmentPreviewMetadata(
                      attachmentId: 'attachment-image',
                      displayName: '동일.pdf',
                      contentType: 'application/pdf',
                    ),
                    onOpen: () => opened.add('image'),
                    itemPosition: 2,
                    itemCount: 2,
                  ),
                ],
              ),
            ),
          ),
        );

        final Finder pdf = find.bySemanticsLabel('첨부 동일.pdf 열기, 총 2개 중 1번째');
        final Finder image = find.bySemanticsLabel('첨부 동일.pdf 열기, 총 2개 중 2번째');
        expect(pdf, findsOneWidget);
        expect(image, findsOneWidget);
        expect(tester.getSemantics(pdf).flagsCollection.isButton, isTrue);
        expect(
          tester
              .getSemantics(pdf)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(
          tester
              .getSemantics(image)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );

        tester
            .getSemantics(pdf)
            .owner!
            .performAction(tester.getSemantics(pdf).id, SemanticsAction.tap);
        await tester.pump();
        expect(opened, <String>['pdf']);

        for (final Finder button in <Finder>[
          find.byTooltip('첨부 열기').at(0),
          find.byTooltip('첨부 열기').at(1),
        ]) {
          final Size target = tester.getSize(button);
          expect(target.width, greaterThanOrEqualTo(48));
          expect(target.height, greaterThanOrEqualTo(48));
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'disabled control keeps a sanitized name without exposing a tap action',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AttachmentTile(
                metadata: AttachmentPreviewMetadata(
                  attachmentId: 'attachment-disabled',
                  displayName: '위험\u0000.pdf',
                  contentType: 'application/pdf',
                ),
                onOpen: null,
                itemPosition: 1,
                itemCount: 1,
              ),
            ),
          ),
        );

        final Finder open = find.bySemanticsLabel('첨부 위험�.pdf 열기');
        expect(open, findsOneWidget);
        expect(tester.getSemantics(open).flagsCollection.isButton, isTrue);
        expect(
          tester
              .getSemantics(open)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
        );
        expect(find.bySemanticsLabel(RegExp(r'\u0000')), findsNothing);
        expect(find.byTooltip('첨부 열기'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'sanitized duplicate names remain distinct as the list order changes',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final ValueNotifier<List<String>> order = ValueNotifier<List<String>>(
        <String>['control', 'bidi'],
      );
      addTearDown(order.dispose);
      try {
        final List<String> opened = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<List<String>>(
                valueListenable: order,
                builder: (BuildContext context, List<String> ids, _) => Column(
                  children: <Widget>[
                    for (final (int index, String id) in ids.indexed)
                      AttachmentTile(
                        key: ValueKey<String>(id),
                        metadata: AttachmentPreviewMetadata(
                          attachmentId: id,
                          displayName: id == 'control'
                              ? '동일\u0000.pdf'
                              : '동일\u202e.pdf',
                          contentType: 'application/pdf',
                        ),
                        onOpen: () => opened.add(id),
                        itemPosition: index + 1,
                        itemCount: ids.length,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        final Finder first = find.bySemanticsLabel('첨부 동일�.pdf 열기, 총 2개 중 1번째');
        final Finder second = find.bySemanticsLabel(
          '첨부 동일�.pdf 열기, 총 2개 중 2번째',
        );
        expect(first, findsOneWidget);
        expect(second, findsOneWidget);
        expect(find.text('동일�.pdf'), findsNWidgets(2));

        tester
            .getSemantics(second)
            .owner!
            .performAction(tester.getSemantics(second).id, SemanticsAction.tap);
        await tester.pump();
        expect(opened, <String>['bidi']);

        order.value = <String>['bidi', 'control'];
        await tester.pump();
        tester
            .getSemantics(first)
            .owner!
            .performAction(tester.getSemantics(first).id, SemanticsAction.tap);
        await tester.pump();
        expect(opened, <String>['bidi', 'bidi']);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'long and zero-width names do not shrink targets or overflow at 320dp',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      try {
        final String originalName =
            '${List<String>.filled(180, '가').join()}\u200b.pdf';
        final AttachmentPreviewMetadata metadata = AttachmentPreviewMetadata(
          attachmentId: 'long-name',
          displayName: originalName,
          contentType: 'application/pdf',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: ListView(
                  children: <Widget>[
                    AttachmentTile(
                      metadata: metadata,
                      onOpen: () {},
                      itemPosition: 1,
                      itemCount: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(metadata.displayName, originalName);
        expect(metadata.safeDisplayName, isNot(contains('\u200b')));
        expect(metadata.safeDisplayName, endsWith('�.pdf'));
        expect(
          find.bySemanticsLabel('첨부 ${metadata.safeDisplayName} 열기'),
          findsOneWidget,
        );
        final Size target = tester.getSize(find.byTooltip('첨부 열기'));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
      } finally {
        semantics.dispose();
      }
    },
  );
}
