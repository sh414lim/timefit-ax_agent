import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/message_dao.dart';
import 'package:timefit_native/features/chat/application/history_controller.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/drift_history_page_store.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';
import 'package:timefit_native/features/chat/domain/chat_message.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';
import 'package:timefit_native/features/chat/presentation/widgets/message_bubble.dart';
import 'package:timefit_native/features/chat/presentation/widgets/message_list.dart';

void main() {
  setUpAll(() async {
    final Uint8List bytes = File(
      'test/fixtures/fonts/nanum_gothic/NanumGothic-Regular.ttf',
    ).readAsBytesSync();
    final FontLoader loader = FontLoader(_fontFamily)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  testWidgets('sequence 3,1,2 renders 1,2,3 and duplicate sequence once', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Stream<List<ChatMessage>>.value(<ChatMessage>[
        _message(3, displayedAt: _baseTime.subtract(const Duration(days: 2))),
        _message(1, displayedAt: _baseTime.add(const Duration(days: 2))),
        _message(2, body: '교체 전', displayedAt: _baseTime),
        _message(2, body: '교체됨', displayedAt: _baseTime),
      ]),
    );

    final List<MessageBubble> bubbles = tester
        .widgetList<MessageBubble>(find.byType(MessageBubble))
        .toList();
    expect(bubbles.map((bubble) => bubble.message.sequence), <int>[1, 2, 3]);
    expect(find.text('교체됨'), findsOneWidget);
    expect(find.text('교체 전'), findsNothing);
  });

  testWidgets('pending promotes canonically by stable client identity', (
    WidgetTester tester,
  ) async {
    final StreamController<List<ChatMessage>> stream =
        StreamController<List<ChatMessage>>();
    addTearDown(stream.close);
    await _pump(tester, stream.stream);
    stream.add(<ChatMessage>[
      _message(1),
      _message(null, clientMessageId: 'stable', body: '로컬 전송 중'),
      _message(3),
    ]);
    await tester.pump();
    expect(
      tester
          .widgetList<MessageBubble>(find.byType(MessageBubble))
          .map((bubble) => bubble.message.clientMessageId),
      <String>['client-1', 'client-3', 'stable'],
    );

    stream.add(<ChatMessage>[
      _message(1),
      _message(null, clientMessageId: 'stable', body: '로컬 전송 중'),
      _message(2, clientMessageId: 'stable', body: '서버 확정'),
      _message(3),
    ]);
    await tester.pumpAndSettle();

    final List<MessageBubble> promoted = tester
        .widgetList<MessageBubble>(find.byType(MessageBubble))
        .toList();
    expect(promoted.map((bubble) => bubble.message.clientMessageId), <String>[
      'client-1',
      'stable',
      'client-3',
    ]);
    expect(find.text('서버 확정'), findsOneWidget);
    expect(find.text('로컬 전송 중'), findsNothing);
  });

  testWidgets('pending retains stream order without timestamp sorting', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Stream<List<ChatMessage>>.value(<ChatMessage>[
        _message(
          null,
          clientMessageId: 'first-pending',
          displayedAt: _baseTime.add(const Duration(days: 2)),
        ),
        _message(
          null,
          clientMessageId: 'second-pending',
          displayedAt: _baseTime.subtract(const Duration(days: 2)),
        ),
      ]),
    );
    expect(
      tester
          .widgetList<MessageBubble>(find.byType(MessageBubble))
          .map((bubble) => bubble.message.clientMessageId),
      <String>['first-pending', 'second-pending'],
    );
  });

  testWidgets('all delivery states expose accessible text', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        Stream<List<ChatMessage>>.value(<ChatMessage>[
          for (
            var index = 0;
            index < MessageDeliveryState.values.length;
            index++
          )
            _message(index + 1, delivery: MessageDeliveryState.values[index]),
        ]),
      );

      for (final String label in <String>[
        '전송 대기 중',
        '업로드 중',
        '전송 중',
        '전송됨',
        '전송 실패, 재시도 필요',
      ]) {
        expect(find.bySemanticsLabel(RegExp(label)), findsOneWidget);
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('new message preserves a past position and shows a button', (
    WidgetTester tester,
  ) async {
    final StreamController<List<ChatMessage>> stream =
        StreamController<List<ChatMessage>>();
    addTearDown(stream.close);
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(tester, stream.stream, scrollController: scroll);
    stream.add(_messages(80));
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pump();
    final double before = scroll.offset;

    stream.add(<ChatMessage>[..._messages(80), _message(81)]);
    await tester.pumpAndSettle();

    expect(scroll.offset, before);
    expect(find.text('새 메시지'), findsOneWidget);
  });

  testWidgets('new message auto-scrolls only from the latest region', (
    WidgetTester tester,
  ) async {
    final StreamController<List<ChatMessage>> stream =
        StreamController<List<ChatMessage>>();
    addTearDown(stream.close);
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(tester, stream.stream, scrollController: scroll);
    stream.add(_messages(50));
    await tester.pumpAndSettle();

    stream.add(<ChatMessage>[..._messages(50), _message(51)]);
    await tester.pumpAndSettle();

    expect(scroll.position.extentAfter, 0);
    expect(find.text('새 메시지'), findsNothing);
  });

  testWidgets('variable 500 messages preserve anchor on prepend and append', (
    WidgetTester tester,
  ) async {
    final StreamController<List<ChatMessage>> stream =
        StreamController<List<ChatMessage>>();
    addTearDown(stream.close);
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(tester, stream.stream, scrollController: scroll);
    stream.add(<ChatMessage>[
      for (var sequence = 2; sequence <= 501; sequence++)
        _message(sequence, body: _variableBody(sequence)),
    ]);
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.maxScrollExtent / 2);
    await tester.pump();
    final List<MessageBubble> visibleBubbles = tester
        .widgetList<MessageBubble>(find.byType(MessageBubble))
        .toList();
    final ChatMessage anchorMessage =
        visibleBubbles[visibleBubbles.length ~/ 2].message;
    final Finder anchor = find.text(anchorMessage.body);
    final double before = tester.getTopLeft(anchor).dy;

    stream.add(<ChatMessage>[
      for (var sequence = 1; sequence <= 502; sequence++)
        _message(sequence, body: _variableBody(sequence)),
    ]);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(anchor).dy, closeTo(before, 1));
    expect(find.text('새 메시지'), findsOneWidget);
    expect(find.byType(MessageBubble), findsWidgets);
  });

  testWidgets('top trigger exposes loading error retry and terminal state', (
    WidgetTester tester,
  ) async {
    final _FakeHistorySource source = _FakeHistorySource();
    final HistoryController history = HistoryController(
      source: source,
      conversationId: 'conversation',
      earliestSequence: 501,
    );
    addTearDown(history.dispose);
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(
      tester,
      Stream<List<ChatMessage>>.value(<ChatMessage>[
        for (var sequence = 1; sequence <= 500; sequence++)
          _message(sequence, body: _variableBody(sequence)),
      ]),
      conversationId: 'conversation',
      historyController: history,
      scrollController: scroll,
    );
    await tester.pumpAndSettle();
    expect(source.requests, isEmpty);

    scroll.jumpTo(250);
    await tester.pump();
    expect(source.requests, hasLength(1));
    expect(
      find.byKey(const ValueKey<String>('history-loading')),
      findsOneWidget,
    );

    source.pending.single.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('history-error')), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(source.requests, hasLength(2));
    expect(source.requests.last.beforeSequence, 501);
    source.pending.last.complete(_historyPage(451, 500, hasMoreBefore: false));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('history-complete')),
      findsOneWidget,
    );
    scroll.jumpTo(0);
    await tester.pump();
    expect(source.requests, hasLength(2));
  });

  testWidgets('remaining near top requests consecutive history pages', (
    WidgetTester tester,
  ) async {
    final _FakeHistorySource source = _FakeHistorySource();
    final HistoryController history = HistoryController(
      source: source,
      conversationId: 'conversation',
      earliestSequence: 501,
    );
    addTearDown(history.dispose);
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(
      tester,
      Stream<List<ChatMessage>>.value(<ChatMessage>[
        for (var sequence = 1; sequence <= 500; sequence++)
          _message(sequence, body: _variableBody(sequence)),
      ]),
      conversationId: 'conversation',
      historyController: history,
      scrollController: scroll,
    );
    await tester.pumpAndSettle();

    scroll.jumpTo(250);
    await tester.pump();
    source.pending.single.complete(_historyPage(451, 500));
    await tester.pump();
    await tester.pump();

    expect(source.requests.map((request) => request.beforeSequence), <int>[
      501,
      451,
    ]);
    source.pending.last.complete(_historyPage(401, 450, hasMoreBefore: false));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'persistence conflicts leave cached data and expose retry without loading lock',
    (WidgetTester tester) async {
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      final MessageRepositoryImpl repository = MessageRepositoryImpl(
        database: database,
      );
      final DateTime now = DateTime.utc(2026, 10, 20);
      await SendMessage(
        database: database,
        clock: () => now,
        clientMessageId: () => 'client-2',
      ).submit(conversationId: 'conversation', bodyText: 'body');
      await database.customStatement(
        "UPDATE outbox_commands SET state = 'cancelled' WHERE id = 'client-2'",
      );
      final _ImmediateHistorySource source = _ImmediateHistorySource(
        CanonicalHistoryPage(
          conversationId: 'conversation',
          canonicalMessages: <CanonicalLocalMessage>[
            for (var sequence = 1; sequence <= 3; sequence++)
              CanonicalLocalMessage(
                serverId: 'server-$sequence',
                conversationId: 'conversation',
                clientMessageId: 'client-$sequence',
                sequence: sequence,
                senderKind: 'user',
                bodyText: 'body',
                messageKind: 'text',
                serverCreatedAt: now,
              ),
          ],
          hasMoreBefore: false,
        ),
      );
      final HistoryController history = HistoryController(
        source: source,
        conversationId: 'conversation',
        earliestSequence: 4,
        persistence: DriftHistoryPageStore(database: database),
      );
      addTearDown(() async {
        history.dispose();
        await repository.dispose();
        await database.close();
      });

      await _pump(
        tester,
        repository.watchCachedMessages('conversation'),
        conversationId: 'conversation',
        historyController: history,
      );
      await tester.pumpAndSettle();

      expect(history.state.isLoading, isFalse);
      expect(history.state.failure, HistoryFailure.persistenceFailed);
      expect(
        find.byKey(const ValueKey<String>('history-error')),
        findsOneWidget,
      );
      expect(find.text('body'), findsOneWidget);
      expect(await database.messageDao.getAll(), hasLength(1));
      expect((await database.outboxDao.getAll()).single.state, 'cancelled');

      source.page = HistoryPage(
        conversationId: 'conversation',
        messages: <ChatMessage>[
          for (var sequence = 1; sequence <= 3; sequence++)
            _message(sequence, body: 'projection only'),
        ],
        hasMoreBefore: false,
      );
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(source.requests, 2);
      expect(history.state.isLoading, isFalse);
      expect(history.state.failure, HistoryFailure.persistenceFailed);
      expect(
        find.byKey(const ValueKey<String>('history-error')),
        findsOneWidget,
      );
      expect(find.text('body'), findsOneWidget);
      expect(await database.messageDao.getAll(), hasLength(1));
      expect((await database.outboxDao.getAll()).single.state, 'cancelled');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('stable visible identity survives resize and keyboard inset', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    final Stream<List<ChatMessage>> messages =
        Stream<List<ChatMessage>>.value(<ChatMessage>[
          for (var sequence = 1; sequence <= 120; sequence++)
            _message(sequence, body: _variableBody(sequence)),
        ]);
    await _pump(tester, messages, scrollController: scroll);
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.maxScrollExtent / 2);
    await tester.pump();
    final List<MessageBubble> visible = tester
        .widgetList<MessageBubble>(find.byType(MessageBubble))
        .toList();
    final ChatMessage identity = visible[visible.length ~/ 2].message;
    final Finder anchor = find.text(identity.body);
    final double before = tester.getTopLeft(anchor).dy;

    await tester.binding.setSurfaceSize(const Size(390, 520));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(anchor).dy, closeTo(before, 1));

    final double beforeKeyboard = tester.getTopLeft(anchor).dy;
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetViewInsets);
    await _pump(tester, messages, scrollController: scroll);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(anchor).dy, closeTo(beforeKeyboard, 1));
  });

  testWidgets(
    'conversation switch detaches old history and ignores its late result',
    (WidgetTester tester) async {
      final _FakeHistorySource oldSource = _FakeHistorySource();
      final _FakeHistorySource newSource = _FakeHistorySource();
      final HistoryController oldHistory = HistoryController(
        source: oldSource,
        conversationId: 'old',
        earliestSequence: 501,
      );
      final HistoryController newHistory = HistoryController(
        source: newSource,
        conversationId: 'new',
        earliestSequence: 501,
      );
      addTearDown(oldHistory.dispose);
      addTearDown(newHistory.dispose);
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      final List<ChatMessage> messages = <ChatMessage>[
        for (var sequence = 1; sequence <= 500; sequence++)
          _message(sequence, body: _variableBody(sequence)),
      ];
      await _pump(
        tester,
        Stream<List<ChatMessage>>.value(messages),
        conversationId: 'old',
        historyController: oldHistory,
        scrollController: scroll,
      );
      await tester.pumpAndSettle();
      scroll.jumpTo(250);
      await tester.pump();
      expect(oldSource.requests, hasLength(1));

      await _pump(
        tester,
        Stream<List<ChatMessage>>.value(messages),
        conversationId: 'new',
        historyController: newHistory,
        scrollController: scroll,
      );
      await tester.pumpAndSettle();
      oldSource.pending.single.completeError(StateError('late old failure'));
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('history-error')), findsNothing);
      expect(tester.takeException(), isNull);
      scroll.jumpTo(250);
      await tester.pump();
      expect(newSource.requests, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      newSource.pending.single.complete(
        _historyPage(451, 500, conversationId: 'new'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active user scroll suppresses auto-scroll inside threshold', (
    WidgetTester tester,
  ) async {
    final StreamController<List<ChatMessage>> stream =
        StreamController<List<ChatMessage>>();
    addTearDown(stream.close);
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(tester, stream.stream, scrollController: scroll);
    stream.add(_messages(40));
    await tester.pumpAndSettle();
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(Scrollable)),
    );
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(scroll.position.extentAfter, lessThanOrEqualTo(80));

    stream.add(<ChatMessage>[..._messages(40), _message(41)]);
    await tester.pump();
    await tester.pump();

    expect(find.text('새 메시지'), findsOneWidget);
    expect(scroll.position.extentAfter, greaterThan(0));
    await gesture.up();
  });

  testWidgets('320dp and textScale2 render without clipping', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      Stream<List<ChatMessage>>.value(<ChatMessage>[
        _message(
          1,
          body: '글자 크기가 커져도 긴 메시지와 전송 상태를 읽을 수 있어야 합니다.',
          delivery: MessageDeliveryState.failed,
        ),
      ]),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('전송 실패, 재시도 필요'), findsOneWidget);
  });

  testWidgets('screen error and revoked access are distinct', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const Stream<List<ChatMessage>>.empty(),
      status: ChatScreenStatus.error,
    );
    expect(find.text('메시지를 표시하지 못했습니다'), findsOneWidget);

    await _pump(
      tester,
      const Stream<List<ChatMessage>>.empty(),
      status: ChatScreenStatus.accessRevoked,
    );
    expect(find.text('대화에 접근할 수 없습니다'), findsOneWidget);
  });

  testWidgets(
    'stream replacement unsubscribes old stream and dispose is safe',
    (WidgetTester tester) async {
      final StreamController<List<ChatMessage>> oldStream =
          StreamController<List<ChatMessage>>();
      final StreamController<List<ChatMessage>> newStream =
          StreamController<List<ChatMessage>>();
      addTearDown(oldStream.close);
      addTearDown(newStream.close);
      await _pump(tester, oldStream.stream);
      oldStream.add(<ChatMessage>[_message(1, body: '이전 스트림')]);
      await tester.pump();
      expect(find.text('이전 스트림'), findsOneWidget);

      await _pump(tester, newStream.stream);
      oldStream.add(<ChatMessage>[_message(2, body: '늦은 이전 값')]);
      newStream.add(<ChatMessage>[_message(3, body: '새 스트림')]);
      await tester.pumpAndSettle();
      expect(find.text('늦은 이전 값'), findsNothing);
      expect(find.text('새 스트림'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      newStream.add(<ChatMessage>[_message(4, body: 'dispose 이후')]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('access revoked immediately hides previously rendered data', (
    WidgetTester tester,
  ) async {
    final StreamController<List<ChatMessage>> stream =
        StreamController<List<ChatMessage>>();
    addTearDown(stream.close);
    await _pump(tester, stream.stream);
    stream.add(<ChatMessage>[_message(1, body: '민감한 기존 메시지')]);
    await tester.pump();
    expect(find.text('민감한 기존 메시지'), findsOneWidget);

    await _pump(tester, stream.stream, status: ChatScreenStatus.accessRevoked);
    expect(find.text('민감한 기존 메시지'), findsNothing);
    expect(find.text('대화에 접근할 수 없습니다'), findsOneWidget);
  });

  group('goldens', () {
    testWidgets('timeline light', (WidgetTester tester) async {
      await _golden(tester, 'light');
    });

    testWidgets('timeline dark', (WidgetTester tester) async {
      await _golden(tester, 'dark', brightness: Brightness.dark);
    });

    testWidgets('timeline text scale 2', (WidgetTester tester) async {
      await _golden(
        tester,
        'text_scale_2',
        size: const Size(320, 568),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

final DateTime _baseTime = DateTime.utc(2026, 10, 19, 12);

ChatMessage _message(
  int? sequence, {
  String? clientMessageId,
  String? body,
  MessageDeliveryState delivery = MessageDeliveryState.sent,
  DateTime? displayedAt,
}) {
  return ChatMessage(
    clientMessageId: clientMessageId ?? 'client-$sequence',
    sequence: sequence,
    body: body ?? '메시지 $sequence',
    displayedAt:
        displayedAt ?? _baseTime.add(Duration(minutes: sequence ?? 10000)),
    isMine: sequence?.isEven ?? true,
    deliveryState: delivery,
  );
}

List<ChatMessage> _messages(int count) => <ChatMessage>[
  for (var sequence = 1; sequence <= count; sequence++) _message(sequence),
];

String _variableBody(int sequence) => sequence.isEven
    ? '메시지 $sequence — 높이가 다른 행을 검증하기 위한 긴 본문입니다. 줄바꿈이 생겨도 anchor가 유지되어야 합니다.'
    : '메시지 $sequence';

Future<void> _pump(
  WidgetTester tester,
  Stream<List<ChatMessage>> messages, {
  ScrollController? scrollController,
  ChatScreenStatus status = ChatScreenStatus.ready,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  String? conversationId,
  HistoryController? historyController,
}) async {
  final ThemeData base = brightness == Brightness.light
      ? AppTheme.light()
      : AppTheme.dark();
  await tester.pumpWidget(
    MaterialApp(
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: _fontFamily),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _fontFamily),
      ),
      home: MediaQuery(
        data: MediaQueryData.fromView(
          tester.view,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: ChatScreen(
          title: '주간 계획',
          messages: messages,
          conversationId: conversationId,
          status: status,
          scrollController: scrollController,
          historyController: historyController,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _golden(
  WidgetTester tester,
  String name, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 700),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await _pump(
    tester,
    Stream<List<ChatMessage>>.value(<ChatMessage>[
      _message(1, body: '이번 주 운동 계획을 확인해 주세요.'),
      _message(2, body: '월요일과 수요일 저녁이 좋아요.'),
      _message(3, body: '좋습니다. 두 일정으로 정리했습니다.'),
      _message(4, delivery: MessageDeliveryState.sending),
      _message(5, delivery: MessageDeliveryState.failed),
    ]),
    brightness: brightness,
    textScale: textScale,
  );
  await tester.pumpAndSettle();
  _expectGoldenContentAndLayout(tester);
  final String platformSuffix = Platform.isLinux ? '_linux' : '';
  await expectLater(
    find.byType(ChatScreen),
    matchesGoldenFile('goldens/chat_timeline_$name$platformSuffix.png'),
  );
}

void _expectGoldenContentAndLayout(WidgetTester tester) {
  const List<String> expectedBodies = <String>[
    '이번 주 운동 계획을 확인해 주세요.',
    '월요일과 수요일 저녁이 좋아요.',
    '좋습니다. 두 일정으로 정리했습니다.',
    '메시지 4',
    '메시지 5',
  ];
  final MessageList timeline = tester.widget<MessageList>(
    find.byType(MessageList),
  );
  expect(
    timeline.messages.map((ChatMessage message) => message.body).toList(),
    expectedBodies,
  );
  final List<MessageBubble> visibleBubbles = tester
      .widgetList<MessageBubble>(find.byType(MessageBubble))
      .toList(growable: false);
  expect(find.text('전송 중'), findsOneWidget);
  expect(find.text('전송 실패, 재시도 필요'), findsOneWidget);

  final Rect screen = tester.getRect(find.byType(ChatScreen));
  double previousBottom = -double.infinity;
  for (final MessageBubble visible in visibleBubbles) {
    final Rect bubble = tester.getRect(
      find.ancestor(
        of: find.text(visible.message.body),
        matching: find.byType(MessageBubble),
      ),
    );
    expect(bubble.height, greaterThanOrEqualTo(44));
    expect(bubble.left, greaterThanOrEqualTo(screen.left));
    expect(bubble.right, lessThanOrEqualTo(screen.right));
    expect(bubble.bottom, greaterThan(screen.top));
    expect(bubble.top, lessThan(screen.bottom));
    expect(bubble.top, greaterThanOrEqualTo(previousBottom));
    previousBottom = bubble.bottom;
  }
  expect(tester.takeException(), isNull);
}

const String _fontFamily = 'NanumGothicChatGolden';

final class _FakeHistorySource implements HistoryPageSource {
  final List<HistoryRequest> requests = <HistoryRequest>[];
  final List<Completer<HistoryPage>> pending = <Completer<HistoryPage>>[];

  @override
  Future<HistoryPage> loadBefore(HistoryRequest request) {
    requests.add(request);
    final Completer<HistoryPage> result = Completer<HistoryPage>();
    pending.add(result);
    return result.future;
  }
}

final class _ImmediateHistorySource implements HistoryPageSource {
  _ImmediateHistorySource(this.page);

  HistoryPage page;
  int requests = 0;

  @override
  Future<HistoryPage> loadBefore(HistoryRequest request) async {
    requests += 1;
    return page;
  }
}

HistoryPage _historyPage(
  int from,
  int to, {
  bool hasMoreBefore = true,
  String conversationId = 'conversation',
}) => HistoryPage(
  conversationId: conversationId,
  messages: <ChatMessage>[
    for (var sequence = from; sequence <= to; sequence++) _message(sequence),
  ],
  hasMoreBefore: hasMoreBefore,
);
