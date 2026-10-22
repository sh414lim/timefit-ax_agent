import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/attachments/application/attachment_download_controller.dart';
import 'package:timefit_native/features/attachments/presentation/attachment_tile.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/domain/chat_message.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';
import 'package:timefit_native/features/chat/presentation/widgets/attachment_chip.dart';
import 'package:timefit_native/features/chat/presentation/widgets/chat_composer.dart';
import 'package:timefit_native/features/chat/presentation/widgets/message_bubble.dart';
import 'package:timefit_native/features/conversations/domain/conversation_summary.dart';
import 'package:timefit_native/features/conversations/presentation/widgets/conversation_list_row.dart';

import 'accessibility_fixture.dart';

void main() {
  setUpAll(() async {
    final Uint8List bytes = File(
      'test/fixtures/fonts/nanum_gothic/NanumGothic-Regular.ttf',
    ).readAsBytesSync();
    final FontLoader loader = FontLoader(_fontFamily)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  for (final fixture in accessibilityFixtures) {
    testWidgets('${fixture.name} renders the shared presentation fixture', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(fixture.width, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = ComposerController(
        conversationId: 'conversation',
        submitter: _Submitter(),
      );
      addTearDown(controller.dispose);
      final ThemeData theme = _theme(fixture.brightness);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(fixture.width, 760),
              textScaler: TextScaler.linear(fixture.textScale),
            ),
            child: Scaffold(
              body: ListView(
                children: <Widget>[
                  ConversationListRow(
                    conversation: ConversationSummary(
                      id: 'conversation',
                      title: '주간 계획 대화',
                      preview: '확대된 글자에서도 미리보기와 시간이 겹치지 않습니다.',
                      updatedAt: DateTime.utc(2026, 10, 22),
                    ),
                    updatedAtLabel: '방금 전',
                    onTap: () {},
                  ),
                  MessageBubble(
                    message: _message(MessageDeliveryState.failed),
                    onRetry: (_) async => true,
                  ),
                  ChatComposer(controller: controller),
                  AttachmentTile(
                    metadata: const AttachmentPreviewMetadata(
                      attachmentId: 'attachment',
                      displayName: '운동 계획 미리보기.pdf',
                      contentType: 'application/pdf',
                    ),
                    onOpen: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('주간 계획 대화'), findsOneWidget);
      expect(find.text('재시도'), findsOneWidget);
      expect(find.byTooltip('메시지 보내기'), findsOneWidget);
      expect(find.byTooltip('첨부 열기'), findsOneWidget);
    });
  }

  testWidgets(
    '320dp 200 percent text keyboard and multiple attachments stay operable',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _AttachmentSource(<ComposerAttachment>[
        _attachment('queued', ComposerAttachmentState.queued),
        _attachment('uploading', ComposerAttachmentState.uploading),
        _attachment('failed', ComposerAttachmentState.failed),
        _attachment('ready', ComposerAttachmentState.ready),
      ]);
      final controller = ComposerController(
        conversationId: 'conversation',
        submitter: _Submitter(),
        attachmentClientMessageId: 'aggregate',
        attachmentSource: source,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(Brightness.dark),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: 280),
              padding: EdgeInsets.only(bottom: 16),
            ),
            child: ChatScreen(
              title: '접근성 검증',
              conversationId: 'conversation',
              messages: Stream<List<ChatMessage>>.value(<ChatMessage>[
                _message(MessageDeliveryState.failed),
              ]),
              composerController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ComposerAttachmentChip), findsNWidgets(4));
      expect(find.byTooltip('실패한 첨부 제거'), findsOneWidget);
      expect(
        tester.getSize(find.byTooltip('실패한 첨부 제거')).shortestSide,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byTooltip('메시지 보내기')).shortestSide,
        greaterThanOrEqualTo(44),
      );
      final Rect composer = tester.getRect(find.byType(TextField));
      expect(composer.bottom, lessThanOrEqualTo(640 - 280 - 16));
      await expectLater(
        find.byType(ChatScreen),
        matchesGoldenFile(
          'goldens/chat_composer_320_text2_keyboard_attachments_dark.png',
        ),
      );
    },
  );

  testWidgets('delivery failure is one live status with an operable retry', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: _message(MessageDeliveryState.failed),
              onRetry: (_) async => true,
            ),
          ),
        ),
      );

      final SemanticsNode bubble = tester.getSemantics(
        find.byType(MessageBubble),
      );
      expect(bubble.flagsCollection.isLiveRegion, isTrue);
      expect(bubble.label, contains('전송 실패, 재시도 필요'));
      final Finder retry = find.widgetWithText(TextButton, '재시도');
      expect(tester.getSize(retry).shortestSide, greaterThanOrEqualTo(44));
      expect(tester.getSemantics(retry).flagsCollection.isButton, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('attachment progress is announced once and removal is separate', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComposerAttachmentChip(
              attachment: _attachment('failed', ComposerAttachmentState.failed),
              onRemoveFailed: () {},
            ),
          ),
        ),
      );

      final Finder status = find.bySemanticsLabel('첨부 image/png, 업로드 실패');
      expect(status, findsOneWidget);
      expect(tester.getSemantics(status).flagsCollection.isLiveRegion, isTrue);
      final Finder remove = find.byTooltip('실패한 첨부 제거');
      expect(remove, findsOneWidget);
      expect(tester.getSize(remove).shortestSide, greaterThanOrEqualTo(44));
    } finally {
      semantics.dispose();
    }
  });
}

ChatMessage _message(MessageDeliveryState state) => ChatMessage(
  clientMessageId: 'message',
  sequence: null,
  body: '실패한 메시지',
  displayedAt: DateTime.utc(2026, 10, 22),
  isMine: true,
  deliveryState: state,
);

ComposerAttachment _attachment(String id, ComposerAttachmentState state) =>
    ComposerAttachment(
      localId: id,
      contentType: 'image/png',
      state: state,
      bytesSent: state == ComposerAttachmentState.uploading ? 50 : 0,
      bytesTotal: state == ComposerAttachmentState.uploading ? 100 : 0,
    );

final class _AttachmentSource implements AttachmentComposerSource {
  _AttachmentSource(this.attachments);
  final List<ComposerAttachment> attachments;

  @override
  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) async {}

  @override
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  }) => Stream<List<ComposerAttachment>>.value(attachments);
}

final class _Submitter implements TextMessageSubmitter {
  @override
  Future<bool> retry(String commandId) async => true;

  @override
  Future<LocalTextCommand> submit({
    required String conversationId,
    required String bodyText,
  }) => throw UnimplementedError();
}

const String _fontFamily = 'NanumGothicAccessibilityGolden';

ThemeData _theme(Brightness brightness) {
  final ThemeData base = brightness == Brightness.light
      ? AppTheme.light()
      : AppTheme.dark();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: _fontFamily),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _fontFamily),
  );
}
