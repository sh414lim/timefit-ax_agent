import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
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
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: ChatScreen(
          title: '주간 계획',
          messages: messages,
          status: status,
          scrollController: scrollController,
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
