import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/attachments/application/attachment_download_controller.dart';
import 'package:timefit_native/features/attachments/presentation/attachment_preview_screen.dart';
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
    final FontLoader materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await materialIcons.load();
  });

  testWidgets('preview error action survives 320dp 200 percent text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AttachmentDownloadController(
      metadata: const AttachmentPreviewMetadata(
        attachmentId: 'attachment',
        displayName: '긴 파일명.pdf',
        contentType: 'application/pdf',
      ),
      provider: _OfflineProvider(),
      clock: DateTime.now,
      memoryCache: AttachmentUrlMemoryCache(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2),
            padding: EdgeInsets.only(top: 24, bottom: 34, left: 16, right: 16),
          ),
          child: AttachmentPreviewScreen(
            controller: controller,
            imageRenderer: (_, _) => const SizedBox(),
            pdfRenderer: (_, _) => const SizedBox(),
          ),
        ),
      ),
    );
    await controller.open();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('다시 시도').hitTestable(), findsOneWidget);
  });

  for (final mode in <String>[
    'last',
    'failure',
    'dispose',
    'switch',
    'roundtrip',
  ]) {
    testWidgets('late attachment removal preserves focus boundary $mode', (
      WidgetTester tester,
    ) async {
      final source = _PendingAttachmentSource();
      final oldController = ComposerController(
        conversationId: 'old',
        submitter: _Submitter(),
        attachmentClientMessageId: 'aggregate',
        attachmentSource: source,
      );
      final nextController = ComposerController(
        conversationId: 'next',
        submitter: _Submitter(),
      );
      final sentinel = FocusNode();
      Widget view(ComposerController controller) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              TextButton(
                focusNode: sentinel,
                onPressed: () {},
                child: const Text('sentinel'),
              ),
              ChatComposer(controller: controller),
            ],
          ),
        ),
      );

      await tester.pumpWidget(view(oldController));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('실패한 첨부 제거'));
      await tester.pump();
      if (mode == 'switch') {
        await tester.pumpWidget(view(nextController));
        await tester.pump();
      }
      if (mode == 'roundtrip') {
        await tester.pumpWidget(view(nextController));
        await tester.pump();
        await tester.pumpWidget(view(oldController));
        await tester.pumpAndSettle();
      }
      if (mode == 'dispose') {
        await tester.pumpWidget(
          MaterialApp(
            home: TextButton(
              focusNode: sentinel,
              onPressed: () {},
              child: const Text('sentinel'),
            ),
          ),
        );
        await tester.pump();
      }
      sentinel.requestFocus();
      await tester.pump();
      expect(sentinel.hasFocus, isTrue);

      if (mode == 'failure') {
        source.completeError(StateError('remove failed'));
      } else {
        source.complete();
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      if (mode == 'last') {
        expect(find.byTooltip('실패한 첨부 제거'), findsNothing);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
      } else {
        expect(
          sentinel.hasFocus,
          isTrue,
          reason: 'late removal must not steal focus after $mode',
        );
      }

      await tester.pumpWidget(const SizedBox());
      oldController.dispose();
      nextController.dispose();
      sentinel.dispose();
      await source.dispose();
    });
  }

  for (final bool hasMessage in <bool>[false, true]) {
    testWidgets('five attachments fit and removal retains useful focus '
        'hasMessage=$hasMessage', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _MutableAttachmentSource(<ComposerAttachment>[
        for (var index = 0; index < 5; index++)
          _attachment('f$index', ComposerAttachmentState.failed),
      ]);
      addTearDown(source.dispose);
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
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
            ),
            child: ChatScreen(
              title: 'QA',
              conversationId: 'conversation',
              messages: Stream<List<ChatMessage>>.value(<ChatMessage>[
                if (hasMessage) _message(MessageDeliveryState.failed),
              ]),
              composerController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ComposerAttachmentChip), findsNWidgets(5));
      final Finder last = find.byKey(const ValueKey<String>('attachment-f4'));
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      final Finder remove = find.descendant(
        of: last,
        matching: find.byType(IconButton),
      );
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      expect(remove.hitTestable(), findsOneWidget);
      final FocusNode removeFocus = Focus.of(
        tester.element(
          find.descendant(of: remove, matching: find.byIcon(Icons.close)),
        ),
      );
      removeFocus.requestFocus();
      await tester.pump();
      expect(removeFocus.hasFocus, isTrue);

      await tester.tap(remove);
      await tester.pumpAndSettle();

      expect(last, findsNothing);
      expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
    });
  }

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
      final SemanticsHandle semantics = tester.ensureSemantics();
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
      expect(find.bySemanticsLabel('첨부 image/png, 대기 중'), findsOneWidget);
      expect(find.bySemanticsLabel('첨부 image/png, 업로드 중'), findsOneWidget);
      expect(find.bySemanticsLabel('첨부 image/png, 업로드 실패'), findsOneWidget);
      expect(find.bySemanticsLabel('첨부 image/png, 준비됨'), findsOneWidget);
      final Rect composer = tester.getRect(find.byType(TextField));
      expect(composer.bottom, lessThanOrEqualTo(640 - 280 - 16));
      final String platformSuffix = Platform.isLinux ? '_linux' : '';
      await expectLater(
        find.byType(ChatScreen),
        matchesGoldenFile(
          'goldens/chat_composer_320_text2_keyboard_attachments_dark'
          '$platformSuffix.png',
        ),
      );

      final Finder retry = find.widgetWithText(TextButton, '재시도');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      final Rect timeline = tester.getRect(
        find.byKey(const ValueKey<String>('message-timeline')),
      );
      final Rect retryRect = tester.getRect(retry);
      expect(timeline.contains(retryRect.topLeft), isTrue);
      expect(timeline.contains(retryRect.bottomRight), isTrue);
      expect(find.bySemanticsLabel('재시도'), findsOneWidget);

      final Finder failedRemoval = find.byTooltip('실패한 첨부 제거');
      await tester.ensureVisible(failedRemoval);
      await tester.pumpAndSettle();
      expect(failedRemoval.hitTestable(), findsOneWidget);
      semantics.dispose();
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
              onOpen: () {},
            ),
          ),
        ),
      );

      final Finder status = find.bySemanticsLabel('첨부 image/png, 업로드 실패');
      expect(status, findsOneWidget);
      final SemanticsNode statusNode = tester.getSemantics(status);
      expect(statusNode.flagsCollection.isLiveRegion, isTrue);
      expect(statusNode.hint, '미리보기 열기');
      final Finder remove = find.byTooltip('실패한 첨부 제거');
      expect(remove, findsOneWidget);
      expect(tester.getSize(remove).shortestSide, greaterThanOrEqualTo(44));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('progress byte updates keep one stable semantics status', (
    WidgetTester tester,
  ) async {
    final source = _MutableAttachmentSource(<ComposerAttachment>[
      const ComposerAttachment(
        localId: 'uploading',
        contentType: 'image/png',
        state: ComposerAttachmentState.uploading,
        bytesSent: 10,
        bytesTotal: 100,
      ),
    ]);
    addTearDown(source.dispose);
    final controller = ComposerController(
      conversationId: 'conversation',
      submitter: _Submitter(),
      attachmentClientMessageId: 'aggregate',
      attachmentSource: source,
    );
    addTearDown(controller.dispose);
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatComposer(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final Finder status = find.byKey(
        const ValueKey<String>('attachment-status-uploading'),
      );
      final SemanticsNode before = tester.getSemantics(status);
      expect(before.label, '첨부 image/png, 업로드 중');

      source.emit(<ComposerAttachment>[
        const ComposerAttachment(
          localId: 'uploading',
          contentType: 'image/png',
          state: ComposerAttachmentState.uploading,
          bytesSent: 90,
          bytesTotal: 100,
        ),
      ]);
      await tester.pump();
      final SemanticsNode after = tester.getSemantics(status);

      expect(after.id, before.id);
      expect(after.label, before.label);
      expect(find.bySemanticsLabel('첨부 image/png, 업로드 중'), findsOneWidget);
      expect(after.value, isEmpty);
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

final class _MutableAttachmentSource implements AttachmentComposerSource {
  _MutableAttachmentSource(List<ComposerAttachment> initial)
    : _attachments = List<ComposerAttachment>.of(initial);

  final StreamController<List<ComposerAttachment>> _events =
      StreamController<List<ComposerAttachment>>.broadcast();
  final List<ComposerAttachment> _attachments;

  void emit(List<ComposerAttachment> attachments) {
    _attachments
      ..clear()
      ..addAll(attachments);
    _events.add(List<ComposerAttachment>.unmodifiable(_attachments));
  }

  Future<void> dispose() => _events.close();

  @override
  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) async {
    _attachments.removeWhere((attachment) => attachment.localId == localId);
    _events.add(List<ComposerAttachment>.unmodifiable(_attachments));
  }

  @override
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  }) async* {
    yield List<ComposerAttachment>.unmodifiable(_attachments);
    yield* _events.stream;
  }
}

final class _PendingAttachmentSource implements AttachmentComposerSource {
  final Completer<void> _pending = Completer<void>();
  final StreamController<List<ComposerAttachment>> _events =
      StreamController<List<ComposerAttachment>>.broadcast();

  void complete() => _pending.complete();

  void completeError(Object error) => _pending.completeError(error);

  Future<void> dispose() => _events.close();

  @override
  Future<void> removeFailed({
    required String conversationId,
    required String clientMessageId,
    required String localId,
  }) async {
    await _pending.future;
    _events.add(const <ComposerAttachment>[]);
  }

  @override
  Stream<List<ComposerAttachment>> watch({
    required String conversationId,
    required String clientMessageId,
  }) async* {
    yield const <ComposerAttachment>[
      ComposerAttachment(
        localId: 'last',
        contentType: 'image/png',
        state: ComposerAttachmentState.failed,
        bytesSent: 0,
        bytesTotal: 0,
      ),
    ];
    yield* _events.stream;
  }
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

final class _OfflineProvider implements AttachmentUrlProvider {
  @override
  Future<SignedAttachmentUrl> issue({required String attachmentId}) async =>
      throw const AttachmentUrlException(AttachmentUrlFailure.offline);
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
