import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/attachments/application/attachment_download_controller.dart';
import 'package:timefit_native/features/attachments/presentation/attachment_tile.dart';

void main() {
  testWidgets(
    'open controls identify their attachment and expose tap actions',
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
                      displayName: '운동 계획.pdf',
                      contentType: 'application/pdf',
                    ),
                    onOpen: () => opened.add('pdf'),
                  ),
                  AttachmentTile(
                    metadata: const AttachmentPreviewMetadata(
                      attachmentId: 'attachment-image',
                      displayName: '매장 사진.png',
                      contentType: 'image/png',
                    ),
                    onOpen: () => opened.add('image'),
                  ),
                ],
              ),
            ),
          ),
        );

        final Finder pdf = find.bySemanticsLabel('첨부 운동 계획.pdf 열기');
        final Finder image = find.bySemanticsLabel('첨부 매장 사진.png 열기');
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
          expect(target.width, greaterThanOrEqualTo(44));
          expect(target.height, greaterThanOrEqualTo(44));
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
}
