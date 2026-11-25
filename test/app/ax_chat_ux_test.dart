import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/app.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/attachments/application/attachment_picker.dart';
import 'package:timefit_native/features/attachments/domain/attachment_policy.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/domain/chat_message.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';
import 'package:timefit_native/features/chat/presentation/widgets/ax_thinking_bubble.dart';
import 'package:timefit_native/features/conversations/presentation/widgets/conversation_list_row.dart';
import 'package:timefit_native/features/home/presentation/widgets/demo_quick_composer.dart';
import 'package:timefit_native/features/home/presentation/widgets/timefit_loading_mark.dart';
import 'package:timefit_native/src/app_environment.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 17; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 15));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
  await tester.pumpAndSettle();
}

Future<Future<void> Function()> _mount(
  WidgetTester tester,
  AppDatabase db, {
  AttachmentPicker? picker,
  Directory? attachmentRoot,
}) async {
  Future<void>? disposed;
  await tester.pumpWidget(
    TimeFitApp(
      environment: AppEnvironment.dev,
      devDatabaseFactory: () async => db,
      devAttachmentRootFactory: () async =>
          attachmentRoot ?? Directory.systemTemp,
      devAttachmentPicker: picker,
      devDisposalObserver: (done) => disposed = done,
    ),
  );
  await _settle(tester);
  return () async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);
    await tester.runAsync(() => disposed!);
  };
}

void main() {
  testWidgets(
    'list, home and new chat keep the same hero and separate drafts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final close = await _mount(tester, db);
      final hero = find.byKey(const Key('mobile-home-robot-slot'));
      final Size homeHero = tester.getSize(hero);
      expect(find.byType(DemoQuickComposer), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'HOME만 남기는 초안');
      await _tap(tester, find.byTooltip('메뉴 샘플'));
      await _tap(tester, find.byTooltip('새 채팅'));

      expect(tester.getSize(hero), homeHero);
      expect(find.textContaining('TimeFit AX가 함께합니다.'), findsOneWidget);
      expect(find.byType(DemoQuickComposer), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      await _tap(tester, find.text('비용 분석'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '비용 분석',
      );
      expect(await tester.runAsync(db.conversationDao.getAll), isEmpty);
      await _tap(tester, find.byType(BackButton));
      await _tap(tester, find.byType(BackButton));
      expect(find.text('HOME만 남기는 초안'), findsOneWidget);
      await close();
    },
  );

  testWidgets('search clear resets an unmatched query without changing data', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final close = await _mount(tester, db);
    await _tap(tester, find.byTooltip('메뉴 샘플'));
    await tester.enterText(find.byType(TextField), '검색어 예시');
    await _settle(tester);
    expect(find.text('검색 결과가 없습니다'), findsOneWidget);
    await _tap(tester, find.byTooltip('검색어 지우기'));
    expect(find.text('아직 대화가 없습니다'), findsOneWidget);
    expect(find.text('보관된 대화'), findsOneWidget);
    expect(await tester.runAsync(db.conversationDao.getAll), isEmpty);
    await close();
  });

  testWidgets(
    'home card only fills, edited text makes one durable room and outbox',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('timefit-ux-'),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/chat.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      final close = await _mount(tester, db);
      await _tap(tester, find.text('비용 분석'));
      expect(find.text('비용 분석'), findsWidgets);
      expect(await tester.runAsync(db.conversationDao.getAll), isEmpty);
      await tester.enterText(find.byType(TextField), 'Edited AX question');
      final send = find.byTooltip('메시지 보내기');
      await tester.tap(send);
      await tester.tap(send, warnIfMissed: false);
      await _settle(tester);
      expect(find.text('Edited AX question'), findsOneWidget);
      final commands = (await tester.runAsync(db.outboxDao.getAll))!;
      expect(commands, hasLength(1));
      final room = (await tester.runAsync(db.conversationDao.getAll))!.single;
      final message = LocalTextCommand.decode(commands.single.payloadJson);
      expect(message.conversationId, room.id);
      expect(message.bodyText, 'Edited AX question');
      await close();
      final reopened = AppDatabase(NativeDatabase(file));
      final closeReopened = await _mount(tester, reopened);
      await _tap(tester, find.byTooltip('메뉴 샘플'));
      await _tap(tester, find.byType(ConversationListRow));
      expect(find.text('Edited AX question'), findsOneWidget);
      expect(await tester.runAsync(reopened.outboxDao.getAll), hasLength(1));
      await closeReopened();
    },
  );

  testWidgets(
    'blank new room does not persist, search and A to B to A drafts survive navigation',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final close = await _mount(tester, db);
      await _tap(tester, find.byTooltip('메뉴 샘플'));
      await _tap(tester, find.byTooltip('새 채팅'));
      expect(find.text('새 채팅'), findsOneWidget);
      await _tap(tester, find.byTooltip('메시지 보내기'));
      await _tap(tester, find.byType(BackButton));
      expect(await tester.runAsync(db.conversationDao.getAll), isEmpty);
      for (final text in ['첫 번째 질문', '두 번째 질문']) {
        await _tap(tester, find.byTooltip('새 채팅'));
        await tester.enterText(find.byType(TextField), text);
        await _tap(tester, find.byTooltip('메시지 보내기'));
        expect(find.text(text), findsOneWidget);
        await _tap(tester, find.byType(BackButton));
      }
      Finder filter() => find.byType(TextField);
      await tester.enterText(filter(), '첫 번째');
      await _settle(tester);
      expect(find.byType(ConversationListRow), findsOneWidget);
      await _tap(tester, find.byType(ConversationListRow));
      await tester.enterText(find.byType(TextField), 'A 전용 초안');
      await _tap(tester, find.byType(BackButton));
      expect(tester.widget<TextField>(filter()).controller?.text, '첫 번째');
      await tester.enterText(filter(), '두 번째');
      await _settle(tester);
      await _tap(tester, find.byType(ConversationListRow));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '',
      );
      await tester.enterText(find.byType(TextField), 'B 전용 초안');
      await _tap(tester, find.byType(BackButton));
      await tester.enterText(filter(), '첫 번째');
      await _settle(tester);
      await _tap(tester, find.byType(ConversationListRow));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'A 전용 초안',
      );
      expect(await tester.runAsync(db.outboxDao.getAll), hasLength(2));
      await close();
    },
  );

  testWidgets(
    'new UX keeps attachment picker and unsent files in a persisted room',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('timefit-attach-ux-'),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      final picker = _PdfPicker();
      final close = await _mount(
        tester,
        db,
        picker: picker,
        attachmentRoot: dir,
      );
      await _tap(tester, find.byTooltip('메뉴 샘플'));
      await _tap(tester, find.byTooltip('새 채팅'));
      expect(find.byTooltip('첨부 추가'), findsNothing);
      await _tap(tester, find.byTooltip('첨부 안내'));
      expect(find.text('첫 메시지를 먼저 보내 주세요'), findsOneWidget);
      expect(picker.calls, 0);
      expect(await tester.runAsync(db.conversationDao.getAll), isEmpty);
      await _tap(tester, find.text('확인'));
      await tester.enterText(find.byType(TextField), 'A first question');
      await _tap(tester, find.byTooltip('메시지 보내기'));
      expect(find.text('A first question'), findsOneWidget);
      await _tap(tester, find.byTooltip('첨부 추가'));
      await _tap(tester, find.text('파일 선택'));
      final attachments = (await tester.runAsync(
        () => db.select(db.localAttachments).get(),
      ))!;
      expect(picker.calls, 1);
      expect(attachments.single.displayName, 'fixture.pdf');
      expect(attachments.single.uploadState, 'queued');
      expect(await tester.runAsync(db.outboxDao.getAll), hasLength(1));
      await close();
    },
  );

  testWidgets(
    '320dp large-text new chat stays usable above keyboard; back keeps room draft',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = AppDatabase(NativeDatabase.memory());
      final close = await _mount(tester, db);
      await _tap(tester, find.byTooltip('메뉴 샘플'));
      await _tap(tester, find.byTooltip('새 채팅'));
      final field = find.byType(TextField);
      final mode = find.text('개발용 로컬 모드 · 로그인/서버 연결 없음');
      expect(
        tester.getTopLeft(find.byType(BackButton)).dy -
            tester.getBottomLeft(mode).dy,
        lessThan(18),
        reason: 'the mode banner already consumes the top window safe area',
      );
      await tester.enterText(field, '긴 한글 첫 질문을 작성합니다\n' * 10);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      tester.view.padding = const FakeViewPadding(top: 24);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final send = find.byTooltip('메시지 보내기');
      expect(tester.getRect(send).bottom, lessThanOrEqualTo(320));
      expect(tester.getSize(send).width, greaterThanOrEqualTo(48));
      final draft = tester.widget<TextField>(field).controller!.text;
      expect(send.hitTestable(), findsOneWidget);
      await tester.tap(send);
      await _settle(tester);
      tester.view.resetViewInsets();
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(draft), findsOneWidget);
      await tester.enterText(find.byType(TextField), '재입장할 때 남는 초안');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('재입장할 때 남는 초안'), findsOneWidget);
      expect(find.byType(ConversationListRow), findsNothing);
      tester.view.resetViewInsets();
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ConversationListRow), findsOneWidget);
      await _tap(tester, find.byType(ConversationListRow));
      expect(find.text('재입장할 때 남는 초안'), findsOneWidget);
      expect(await tester.runAsync(db.outboxDao.getAll), hasLength(1));
      expect(tester.takeException(), isNull);
      await close();
    },
  );

  testWidgets(
    'iOS edge drag cancels without losing draft; completed drag returns to search',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final close = await _mount(tester, db);
      await _tap(tester, find.byTooltip('메뉴 샘플'));
      await _tap(tester, find.byTooltip('새 채팅'));
      await tester.enterText(find.byType(TextField), 'iOS swipe fixture');
      await _tap(tester, find.byTooltip('메시지 보내기'));
      await tester.pumpAndSettle();
      expect(find.text('iOS swipe fixture'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '유지하는 iOS 초안');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final title = find.text('로컬 대화');
      final double originalX = tester.getTopLeft(title).dx;
      final gesture = await tester.startGesture(const Offset(1, 350));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(45, 0));
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getTopLeft(title).dx, greaterThan(originalX + 10));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('유지하는 iOS 초안'), findsOneWidget);
      expect(tester.getTopLeft(title).dx, closeTo(originalX, .1));
      expect(find.byType(ConversationListRow), findsNothing);

      final commit = await tester.startGesture(const Offset(1, 350));
      await commit.moveBy(const Offset(30, 0));
      await commit.moveBy(const Offset(270, 0));
      await tester.pump(const Duration(milliseconds: 180));
      await commit.up();
      await tester.pumpAndSettle();
      expect(find.byType(ConversationListRow), findsOneWidget);
      expect(find.byKey(const Key('new-chat-composer')), findsNothing);
      await _tap(tester, find.byType(ConversationListRow));
      await tester.pumpAndSettle();
      expect(find.text('유지하는 iOS 초안'), findsOneWidget);
      expect(await tester.runAsync(db.outboxDao.getAll), hasLength(1));
      expect(tester.takeException(), isNull);
      await close();
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}),
  );

  testWidgets(
    'one explicit Back with keyboard up reveals ready list without loading',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final close = await _mount(tester, db);
      await _tap(tester, find.byTooltip('메뉴 샘플'));
      await _tap(tester, find.byTooltip('새 채팅'));
      await tester.enterText(find.byType(TextField), 'Back continuity fixture');
      await _tap(tester, find.byTooltip('메시지 보내기'));
      expect(find.text('Back continuity fixture'), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      final search = find.byType(TextField);
      await tester.enterText(search, 'continuity');
      await _settle(tester);
      await _tap(tester, find.byType(ConversationListRow));
      await tester.enterText(find.byType(TextField), '한 번만 뒤로 가기');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(ConversationListRow), findsOneWidget);
      expect(find.byType(TimeFitLoadingMark), findsNothing);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller?.text, 'continuity');
      await _tap(tester, find.byType(ConversationListRow));
      expect(find.text('한 번만 뒤로 가기'), findsOneWidget);
      await close();
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}),
  );

  testWidgets(
    'reduce motion keeps explicit back without a slide',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final db = AppDatabase(NativeDatabase.memory());
      final close = await _mount(tester, db);
      await _tap(tester, find.byTooltip('메뉴 샘플'));
      await _tap(tester, find.byTooltip('새 채팅'));
      final route =
          ModalRoute.of(
                tester.element(find.byKey(const Key('new-chat-composer'))),
              )!
              as PageRoute<void>;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      await _tap(tester, find.byType(BackButton));
      expect(find.byTooltip('새 채팅'), findsOneWidget);
      expect(await tester.runAsync(db.conversationDao.getAll), isEmpty);
      await close();
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}),
  );

  testWidgets('resize shares room, draft and query across tablet and phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    final close = await _mount(tester, db);
    await _tap(tester, find.byTooltip('메뉴 샘플'));
    await _tap(tester, find.byTooltip('새 채팅'));
    await tester.enterText(find.byType(TextField), 'tablet resize fixture');
    await _tap(tester, find.byTooltip('메시지 보내기'));
    await tester.pumpAndSettle();
    await _tap(tester, find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tablet');
    await _settle(tester);
    await _tap(tester, find.byType(ConversationListRow));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '방 전용 초안');

    tester.view.physicalSize = const Size(1040, 810);
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('방 전용 초안'), findsOneWidget);
    expect(find.text('tablet'), findsOneWidget);
    expect(
      tester
          .widget<ConversationListRow>(find.byType(ConversationListRow))
          .selected,
      isTrue,
    );

    tester.view.physicalSize = const Size(390, 844);
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('방 전용 초안'), findsOneWidget);
    expect(find.byType(ConversationListRow), findsNothing);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('tablet'), findsOneWidget);
    expect(await tester.runAsync(db.outboxDao.getAll), hasLength(1));
    expect(tester.takeException(), isNull);
    await close();
  });
  test('failed outbox rolls back first room and message together', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      'CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox_commands BEGIN SELECT RAISE(ABORT, \'fixture fail\'); END;',
    );
    final send = SendMessage(database: db, clock: DateTime.now);
    await expectLater(
      send.startConversation(bodyText: 'atomic test'),
      throwsA(isA<Exception>()),
    );
    expect(await db.conversationDao.getAll(), isEmpty);
    expect(await db.select(db.localMessages).get(), isEmpty);
    expect(await db.outboxDao.getAll(), isEmpty);
  });

  testWidgets(
    'start is source-confirmed, scoped and terminal; reduced motion is static',
    (tester) async {
      final question = ChatMessage(
        clientMessageId: 'req-a',
        sequence: null,
        body: 'fixture question',
        displayedAt: DateTime(2026),
        isMine: true,
        deliveryState: MessageDeliveryState.pending,
      );
      final answer = ChatMessage(
        clientMessageId: 'answer-a',
        sequence: null,
        body: '저장된 AX 답변',
        displayedAt: DateTime(2026),
        isMine: false,
        deliveryState: MessageDeliveryState.sent,
      );
      AxRequestProgress progress(String room, int n, AxRequestStage stage) =>
          AxRequestProgress(
            conversationId: room,
            requestId: 'req-a',
            revision: n,
            stage: stage,
          );
      final accepted = progress('room-a', 1, AxRequestStage.accepted);
      final started = accepted.apply(
        progress('room-a', 2, AxRequestStage.providerStarted),
      );
      final complete = started.apply(
        progress('room-a', 3, AxRequestStage.completed),
      );
      expect(
        complete.apply(progress('room-a', 4, AxRequestStage.providerStarted)),
        same(complete),
      );
      Future<void> draw(AxRequestProgress status) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: child!,
            ),
            home: ChatScreen(
              title: 'fixture',
              messages: Stream.value([
                question,
                if (status.stage == AxRequestStage.completed) answer,
              ]),
              conversationId: 'room-a',
              requestProgress: status,
              axBranding: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await draw(accepted);
      expect(find.byType(AxThinkingBubble), findsNothing);
      expect(find.text('답변 대기 중'), findsOneWidget);
      await draw(progress('room-b', 2, AxRequestStage.providerStarted));
      expect(find.text('답변 대기 중'), findsNothing);
      expect(find.byType(AxThinkingBubble), findsNothing);
      await draw(started);
      expect(find.text('생각 중입니다'), findsOneWidget);
      expect(find.text('·'), findsNothing);
      await draw(progress('room-a', 3, AxRequestStage.uncertain));
      expect(find.byType(AxThinkingBubble), findsNothing);
      expect(find.text('연결이 끊겼어요 · 상태 확인 중'), findsOneWidget);
      await draw(progress('room-a', 4, AxRequestStage.failed));
      expect(find.text('답변을 받지 못했어요'), findsOneWidget);
      expect(find.text('저장된 AX 답변'), findsNothing);
      await draw(complete);
      expect(find.byType(AxThinkingBubble), findsNothing);
      expect(find.text('저장된 AX 답변'), findsOneWidget);
    },
  );
}

final class _PdfPicker implements AttachmentPicker {
  int calls = 0;

  @override
  Future<List<AttachmentInput>?> pick(AttachmentPickerKind kind) async {
    if (kind != AttachmentPickerKind.files) return null;
    calls += 1;
    return [
      AttachmentInput(
        name: 'fixture.pdf',
        declaredMime: 'application/pdf',
        openRead: () => Stream.value([37, 80, 68, 70, 45, 49, 46, 55]),
      ),
    ];
  }
}
