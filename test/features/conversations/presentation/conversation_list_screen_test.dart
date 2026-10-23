import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/conversations/application/conversation_list_controller.dart';
import 'package:timefit_native/features/conversations/domain/conversation_summary.dart';
import 'package:timefit_native/features/conversations/domain/repositories/conversation_repository.dart';
import 'package:timefit_native/features/conversations/presentation/conversation_list_screen.dart';
import 'package:timefit_native/features/conversations/presentation/conversation_menu.dart';
import 'package:timefit_native/features/conversations/presentation/widgets/conversation_list_row.dart';

void main() {
  setUpAll(() async {
    final Uint8List fontBytes = File(
      'test/fixtures/fonts/nanum_gothic/NanumGothic-Regular.ttf',
    ).readAsBytesSync();
    final FontLoader loader = FontLoader(_goldenFontFamily)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)));
    await loader.load();
  });

  test(
    'controller orders by updatedAt then id descending and limits preview',
    () async {
      final String longPreview = List<String>.filled(170, '가').join();
      final _FakeConversationRepository repository =
          _FakeConversationRepository(
            refreshed: <ConversationSummary>[
              _conversation('older', minutesAgo: 20),
              _conversation('newer', minutesAgo: 1, preview: longPreview),
              _conversation('z-tie', minutesAgo: 1),
            ],
          );
      final ConversationListController controller = ConversationListController(
        repository: repository,
      );

      await controller.load();

      expect(controller.state.phase, ConversationListPhase.ready);
      expect(controller.state.conversations.map((item) => item.id), <String>[
        'z-tie',
        'newer',
        'older',
      ]);
      expect(
        controller.state.conversations[1].displayPreview.runes.length,
        ConversationSummary.maximumPreviewCharacters,
      );
    },
  );

  test('controller keeps cache visible when offline refresh fails', () async {
    final _FakeConversationRepository repository = _FakeConversationRepository(
      cached: <ConversationSummary>[_conversation('cached', minutesAgo: 5)],
      refreshError: const ConversationRepositoryException(
        ConversationRepositoryFailureKind.offline,
      ),
    );
    final ConversationListController controller = ConversationListController(
      repository: repository,
    );

    await controller.load();

    expect(controller.state.phase, ConversationListPhase.stale);
    expect(controller.state.conversations.single.id, 'cached');
    expect(controller.state.lastRefreshFailed, isTrue);
    expect(controller.state.isOffline, isTrue);
  });

  test('latest refresh wins when an older request completes last', () async {
    final Completer<List<ConversationSummary>> older =
        Completer<List<ConversationSummary>>();
    final Completer<List<ConversationSummary>> latest =
        Completer<List<ConversationSummary>>();
    final _SequencedConversationRepository repository =
        _SequencedConversationRepository(<Completer<List<ConversationSummary>>>[
          older,
          latest,
        ]);
    final ConversationListController controller = ConversationListController(
      repository: repository,
    );

    final Future<void> olderRequest = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    final Future<void> latestRequest = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    latest.complete(<ConversationSummary>[
      _conversation('latest', minutesAgo: 1),
    ]);
    await latestRequest;
    older.complete(<ConversationSummary>[
      _conversation('older', minutesAgo: 2),
    ]);
    await olderRequest;

    expect(controller.state.conversations.single.id, 'latest');
  });

  test('dispose ignores an in-flight refresh completion', () async {
    final Completer<List<ConversationSummary>> refresh =
        Completer<List<ConversationSummary>>();
    final ConversationListController controller = ConversationListController(
      repository: _FakeConversationRepository(refreshCompleter: refresh),
    );
    var notificationCount = 0;
    controller.addListener((_) => notificationCount += 1);

    final Future<void> request = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    final int countAtDispose = notificationCount;
    controller.dispose();
    refresh.complete(<ConversationSummary>[
      _conversation('late', minutesAgo: 1),
    ]);
    await request;

    expect(notificationCount, countAtDispose);
    expect(controller.state.conversations, isEmpty);
  });

  test(
    'disposing one controller keeps a shared local repository alive',
    () async {
      final _ControllableLocalConversationRepository repository =
          _ControllableLocalConversationRepository();
      final ConversationListController first = ConversationListController(
        repository: repository,
      );
      final ConversationListController second = ConversationListController(
        repository: repository,
      );
      await Future.wait(<Future<void>>[first.load(), second.load()]);

      repository.emit(<ConversationSummary>[
        _conversation('first', minutesAgo: 2),
      ]);
      await Future<void>.delayed(Duration.zero);
      await first.dispose();
      repository.emit(<ConversationSummary>[
        _conversation('second', minutesAgo: 1),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(repository.disposeCalls, 0);
      expect(second.state.conversations.single.id, 'second');

      await second.dispose();
      await repository.dispose();
      expect(repository.disposeCalls, 1);
    },
  );

  test('newer watch value wins over a delayed stale cache read', () async {
    final Completer<List<ConversationSummary>> cacheRead =
        Completer<List<ConversationSummary>>();
    final _ControllableLocalConversationRepository repository =
        _ControllableLocalConversationRepository(cacheRead: cacheRead);
    final ConversationListController controller = ConversationListController(
      repository: repository,
    );

    final Future<void> load = controller.load();
    await Future<void>.delayed(Duration.zero);
    repository.emit(<ConversationSummary>[
      _conversation('new-watch', minutesAgo: 1),
    ]);
    cacheRead.complete(<ConversationSummary>[
      _conversation('old-read', minutesAgo: 10),
    ]);
    await load;

    expect(controller.state.conversations.single.id, 'new-watch');

    await controller.dispose();
    await repository.dispose();
  });

  test('empty cache preserves memory list when reload fails', () async {
    final _MutableConversationRepository repository =
        _MutableConversationRepository(
          refreshed: <ConversationSummary>[
            _conversation('memory', minutesAgo: 1),
          ],
        );
    final ConversationListController controller = ConversationListController(
      repository: repository,
    );
    await controller.load();
    repository.refreshed = const <ConversationSummary>[];
    repository.refreshError = const ConversationRepositoryException(
      ConversationRepositoryFailureKind.unavailable,
    );

    await controller.load();

    expect(controller.state.phase, ConversationListPhase.stale);
    expect(controller.state.conversations.single.id, 'memory');
    expect(controller.state.lastRefreshFailed, isTrue);
  });

  test('successful remote empty response confirms the empty state', () async {
    final _MutableConversationRepository repository =
        _MutableConversationRepository(
          refreshed: <ConversationSummary>[
            _conversation('memory', minutesAgo: 1),
          ],
        );
    final ConversationListController controller = ConversationListController(
      repository: repository,
    );
    await controller.load();
    repository.refreshed = const <ConversationSummary>[];

    await controller.refresh();

    expect(controller.state.phase, ConversationListPhase.empty);
    expect(controller.state.conversations, isEmpty);
  });

  testWidgets('normal empty response shows an explicit new conversation CTA', (
    WidgetTester tester,
  ) async {
    var newConversationCount = 0;
    final ConversationListController controller = await _loadedController(
      _FakeConversationRepository(),
    );

    await _pumpScreen(
      tester,
      controller,
      onNewConversation: () => newConversationCount += 1,
    );

    expect(find.text('아직 대화가 없습니다'), findsOneWidget);
    expect(find.text('새 대화 시작'), findsOneWidget);
    expect(find.text('보관된 대화'), findsOneWidget);
    await tester.tap(find.text('새 대화 시작'));
    expect(newConversationCount, 1);
  });

  testWidgets('settings, archive, and conversation rows invoke callbacks', (
    WidgetTester tester,
  ) async {
    var settingsCount = 0;
    var archiveCount = 0;
    String? openedConversation;
    final ConversationListController controller = await _loadedController(
      _FakeConversationRepository(
        refreshed: <ConversationSummary>[_conversation('tap', minutesAgo: 1)],
      ),
    );

    await _pumpScreen(
      tester,
      controller,
      onOpenSettings: () => settingsCount += 1,
      onOpenArchive: () => archiveCount += 1,
      onOpenConversation: (String id) => openedConversation = id,
    );
    await tester.tap(find.text('설정'));
    await tester.tap(find.text('대화 tap'));
    await tester.tap(find.text('보관된 대화'));

    expect(settingsCount, 1);
    expect(archiveCount, 1);
    expect(openedConversation, 'tap');
  });

  testWidgets('cached list and refresh error are shown together', (
    WidgetTester tester,
  ) async {
    final ConversationListController controller = await _loadedController(
      _FakeConversationRepository(
        cached: <ConversationSummary>[_conversation('cached', minutesAgo: 5)],
        refreshError: const ConversationRepositoryException(
          ConversationRepositoryFailureKind.offline,
        ),
      ),
    );

    await _pumpScreen(tester, controller);

    expect(find.text('대화 cached'), findsOneWidget);
    expect(find.text('오프라인입니다. 저장된 대화를 표시합니다.'), findsOneWidget);
    expect(find.text('아직 대화가 없습니다'), findsNothing);
  });

  testWidgets('row is at least 44dp and exposes one descriptive button node', (
    WidgetTester tester,
  ) async {
    final ConversationListController controller = await _loadedController(
      _FakeConversationRepository(
        refreshed: <ConversationSummary>[
          _conversation('semantic', minutesAgo: 5, preview: '접근성 미리보기'),
        ],
      ),
    );

    await _pumpScreen(tester, controller);
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      expect(
        tester.getSize(find.byType(ConversationListRow)).height,
        greaterThanOrEqualTo(44),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(ConversationListRow),
      );
      expect(node.label, contains('대화 semantic'));
      expect(node.label, contains('접근성 미리보기'));
      expect(node.flagsCollection.isButton, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('conversation action menu is a separate accessible button', (
    WidgetTester tester,
  ) async {
    final ConversationListController controller = await _loadedController(
      _FakeConversationRepository(
        refreshed: <ConversationSummary>[
          _conversation('actions', minutesAgo: 1),
        ],
      ),
    );

    await _pumpScreen(tester, controller, onConversationAction: (_, _) {});
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      expect(find.byTooltip('대화 메뉴'), findsOneWidget);
      final SemanticsNode menu = tester.getSemantics(
        find.bySemanticsLabel('대화 메뉴'),
      );
      expect(menu.label, '대화 메뉴');
      expect(menu.flagsCollection.isButton, isTrue);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('대화 actions'))).label,
        contains('대화 actions'),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('320dp and 200 percent text renders without clipping', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ConversationListController controller = await _loadedController(
      _FakeConversationRepository(
        refreshed: <ConversationSummary>[
          _conversation(
            'scaled',
            minutesAgo: 5,
            preview: '글자 크기가 커져도 대화 제목과 미리보기를 읽을 수 있어야 합니다.',
          ),
        ],
      ),
    );

    await _pumpScreen(tester, controller, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('대화 scaled'), findsOneWidget);
    expect(find.text('새 대화'), findsOneWidget);
  });

  testWidgets(
    'rendered contrast rejects conversation text matching its surface',
    (WidgetTester tester) async {
      final ConversationListController controller = await _loadedController(
        _FakeConversationRepository(refreshed: _conversations.take(1).toList()),
      );
      final ThemeData base = AppTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: _withGoldenFont(
            base.copyWith(
              textTheme: base.textTheme.apply(
                bodyColor: base.scaffoldBackgroundColor,
                displayColor: base.scaffoldBackgroundColor,
              ),
            ),
          ),
          home: ConversationListScreen(
            controller: controller,
            loadOnMount: false,
            currentTime: () => _now,
            onNewConversation: () {},
            onOpenSettings: () {},
            onOpenArchive: () {},
            onOpenConversation: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(
        () => _expectRenderedTextContrast(tester),
        throwsA(isA<TestFailure>()),
      );
    },
  );

  group('goldens', () {
    testWidgets('loading', (WidgetTester tester) async {
      final ConversationListController controller = ConversationListController(
        repository: _FakeConversationRepository(),
      );
      await _expectGolden(tester, controller, 'loading');
    });

    testWidgets('empty', (WidgetTester tester) async {
      final ConversationListController controller = await _loadedController(
        _FakeConversationRepository(),
      );
      await _expectGolden(tester, controller, 'empty');
    });

    testWidgets('list', (WidgetTester tester) async {
      final ConversationListController controller = await _loadedController(
        _FakeConversationRepository(refreshed: _conversations),
      );
      await _expectGolden(tester, controller, 'list');
    });

    testWidgets('stale refresh', (WidgetTester tester) async {
      final Completer<List<ConversationSummary>> refresh =
          Completer<List<ConversationSummary>>();
      final ConversationListController controller = ConversationListController(
        repository: _FakeConversationRepository(
          cached: _conversations,
          refreshCompleter: refresh,
        ),
      );
      unawaited(controller.load());
      await tester.pump();
      await _expectGolden(tester, controller, 'stale');
      refresh.complete(_conversations);
      await tester.pump();
    });

    testWidgets('error', (WidgetTester tester) async {
      final ConversationListController controller = await _loadedController(
        _FakeConversationRepository(
          refreshError: const ConversationRepositoryException(
            ConversationRepositoryFailureKind.unavailable,
          ),
        ),
      );
      await _expectGolden(tester, controller, 'error');
    });

    testWidgets('offline without cache', (WidgetTester tester) async {
      final ConversationListController controller = await _loadedController(
        _FakeConversationRepository(
          refreshError: const ConversationRepositoryException(
            ConversationRepositoryFailureKind.offline,
          ),
        ),
      );
      await _expectGolden(tester, controller, 'offline');
      expect(find.text('오프라인 상태입니다'), findsOneWidget);
    });

    testWidgets('dark', (WidgetTester tester) async {
      final ConversationListController controller = await _loadedController(
        _FakeConversationRepository(refreshed: _conversations),
      );
      await _expectGolden(
        tester,
        controller,
        'dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('text scale 2', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ConversationListController controller = await _loadedController(
        _FakeConversationRepository(refreshed: _conversations.take(1).toList()),
      );
      await _expectGolden(
        tester,
        controller,
        'text_scale_2',
        textScale: 2,
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

final DateTime _now = DateTime.utc(2026, 10, 19, 12);

final List<ConversationSummary> _conversations = <ConversationSummary>[
  _conversation('planning', minutesAgo: 2, preview: '이번 주 운동 일정을 정리했어요.'),
  _conversation('meal', minutesAgo: 45, preview: '저녁 식단과 장보기 목록을 확인합니다.'),
  _conversation('review', minutesAgo: 1440, preview: '지난 기록을 함께 돌아봤어요.'),
];

ConversationSummary _conversation(
  String id, {
  required int minutesAgo,
  String? preview,
}) {
  return ConversationSummary(
    id: id,
    title: '대화 $id',
    preview: preview ?? '대화 미리보기',
    updatedAt: _now.subtract(Duration(minutes: minutesAgo)),
  );
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    this.cached = const <ConversationSummary>[],
    this.refreshed = const <ConversationSummary>[],
    this.refreshError,
    this.refreshCompleter,
  });

  final List<ConversationSummary> cached;
  final List<ConversationSummary> refreshed;
  final Object? refreshError;
  final Completer<List<ConversationSummary>>? refreshCompleter;

  @override
  Future<List<ConversationSummary>> readCachedConversations() async => cached;

  @override
  Future<List<ConversationSummary>> refreshConversations() async {
    if (refreshCompleter
        case final Completer<List<ConversationSummary>> value) {
      return value.future;
    }
    if (refreshError case final Object error) {
      throw error;
    }
    return refreshed;
  }
}

class _SequencedConversationRepository implements ConversationRepository {
  _SequencedConversationRepository(this.refreshes);

  final List<Completer<List<ConversationSummary>>> refreshes;
  var _refreshIndex = 0;

  @override
  Future<List<ConversationSummary>> readCachedConversations() async =>
      const <ConversationSummary>[];

  @override
  Future<List<ConversationSummary>> refreshConversations() {
    return refreshes[_refreshIndex++].future;
  }
}

class _MutableConversationRepository implements ConversationRepository {
  _MutableConversationRepository({required this.refreshed});

  List<ConversationSummary> refreshed;
  Object? refreshError;

  @override
  Future<List<ConversationSummary>> readCachedConversations() async =>
      const <ConversationSummary>[];

  @override
  Future<List<ConversationSummary>> refreshConversations() async {
    if (refreshError case final Object error) {
      throw error;
    }
    return refreshed;
  }
}

class _ControllableLocalConversationRepository
    implements LocalConversationRepository {
  _ControllableLocalConversationRepository({this.cacheRead});

  final Completer<List<ConversationSummary>>? cacheRead;
  final StreamController<List<ConversationSummary>> _cache =
      StreamController<List<ConversationSummary>>.broadcast(sync: true);
  int disposeCalls = 0;

  void emit(List<ConversationSummary> conversations) {
    _cache.add(conversations);
  }

  @override
  Future<List<ConversationSummary>> readCachedConversations() async =>
      cacheRead?.future ?? const <ConversationSummary>[];

  @override
  Stream<List<ConversationSummary>> watchCachedConversations() => _cache.stream;

  @override
  Future<List<ConversationSummary>> refreshConversations() async =>
      throw const ConversationRepositoryException(
        ConversationRepositoryFailureKind.unavailable,
      );

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _cache.close();
  }
}

Future<ConversationListController> _loadedController(
  ConversationRepository repository,
) async {
  final ConversationListController controller = ConversationListController(
    repository: repository,
  );
  await controller.load();
  return controller;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ConversationListController controller, {
  VoidCallback? onNewConversation,
  VoidCallback? onOpenSettings,
  VoidCallback? onOpenArchive,
  ValueChanged<String>? onOpenConversation,
  void Function(ConversationSummary, ConversationMenuAction)?
  onConversationAction,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final ThemeData base = brightness == Brightness.light
      ? AppTheme.light()
      : AppTheme.dark();
  await tester.pumpWidget(
    MaterialApp(
      theme: _withGoldenFont(base),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: ConversationListScreen(
          controller: controller,
          loadOnMount: false,
          currentTime: () => _now,
          onNewConversation: onNewConversation ?? () {},
          onOpenSettings: onOpenSettings ?? () {},
          onOpenArchive: onOpenArchive ?? () {},
          onOpenConversation: onOpenConversation ?? (_) {},
          onConversationAction: onConversationAction,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _expectGolden(
  WidgetTester tester,
  ConversationListController controller,
  String name, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(390, 700),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await _pumpScreen(
    tester,
    controller,
    brightness: brightness,
    textScale: textScale,
  );
  await tester.pump(const Duration(milliseconds: 300));
  _expectRenderedTextContrast(tester);
  _installTextRasterizationComparator(tester);
  await expectLater(
    find.byType(ConversationListScreen),
    matchesGoldenFile('goldens/conversation_list_$name.png'),
  );
}

const String _goldenFontFamily = 'NanumGothicConversationGolden';

ThemeData _withGoldenFont(ThemeData theme) {
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: _goldenFontFamily),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamily: _goldenFontFamily,
    ),
  );
}

void _expectRenderedTextContrast(WidgetTester tester) {
  for (final Element element in find.byType(Text).evaluate()) {
    final Text text = element.widget as Text;
    final TextStyle style = DefaultTextStyle.of(
      element,
    ).style.merge(text.style);
    final Color? foreground = style.color;
    expect(
      foreground,
      isNotNull,
      reason: 'Rendered text must resolve a foreground color: ${text.data}',
    );

    Color? background;
    element.visitAncestorElements((Element ancestor) {
      if (ancestor.widget case final Material material) {
        final Color? candidate = material.color;
        if (candidate != null && candidate.a > 0) {
          background = candidate;
          return false;
        }
      }
      return true;
    });
    expect(
      background,
      isNotNull,
      reason:
          'Rendered text must have an opaque Material surface: ${text.data}',
    );

    final double minimum = (style.fontSize ?? 14) >= 24 ? 3 : 4.5;
    final double ratio = _contrastRatio(foreground!, background!);
    expect(
      ratio,
      greaterThanOrEqualTo(minimum),
      reason:
          '${text.data} resolves to ${ratio.toStringAsFixed(2)}:1; '
          '${minimum.toStringAsFixed(1)}:1 is required',
    );
  }
}

double _contrastRatio(Color foreground, Color background) {
  final Color opaqueForeground = Color.alphaBlend(foreground, background);
  final double foregroundLuminance = opaqueForeground.computeLuminance();
  final double backgroundLuminance = background.computeLuminance();
  final double lighter = math.max(foregroundLuminance, backgroundLuminance);
  final double darker = math.min(foregroundLuminance, backgroundLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

void _installTextRasterizationComparator(WidgetTester tester) {
  final List<Rect> textRegions = find
      .byType(Text)
      .evaluate()
      .map((Element element) {
        final RenderBox box = element.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      })
      .map((Rect region) => region.inflate(1))
      .toList(growable: false);
  final GoldenFileComparator previous = goldenFileComparator;
  goldenFileComparator = _TextRasterizationComparator(
    Uri.parse(
      'test/features/conversations/presentation/'
      'conversation_list_screen_test.dart',
    ),
    textRegions: textRegions,
  );
  addTearDown(() => goldenFileComparator = previous);
}

class _TextRasterizationComparator extends LocalFileComparator {
  _TextRasterizationComparator(super.testFile, {required this.textRegions});

  final List<Rect> textRegions;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final _DecodedImage actual = await _decode(imageBytes);
    final _DecodedImage expected = await _decode(
      Uint8List.fromList(await getGoldenBytes(golden)),
    );
    try {
      if (actual.width != expected.width || actual.height != expected.height) {
        throw FlutterError('Golden image dimensions changed for $golden.');
      }
      var differences = 0;
      for (var y = 0; y < actual.height; y += 1) {
        for (var x = 0; x < actual.width; x += 1) {
          final Offset center = Offset(x + 0.5, y + 0.5);
          if (textRegions.any((Rect region) => region.contains(center))) {
            continue;
          }
          final int offset = (y * actual.width + x) * 4;
          if (actual.bytes.getUint32(offset) !=
              expected.bytes.getUint32(offset)) {
            differences += 1;
          }
        }
      }
      if (differences != 0) {
        throw FlutterError(
          '$golden differs by $differences pixels outside text regions.',
        );
      }
      return true;
    } finally {
      actual.dispose();
      expected.dispose();
    }
  }
}

class _DecodedImage {
  const _DecodedImage(this.image, this.bytes);

  final ui.Image image;
  final ByteData bytes;
  int get width => image.width;
  int get height => image.height;
  void dispose() => image.dispose();
}

Future<_DecodedImage> _decode(Uint8List pngBytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  codec.dispose();
  final ByteData? bytes = await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (bytes == null) {
    frame.image.dispose();
    throw FlutterError('Unable to decode golden pixels.');
  }
  return _DecodedImage(frame.image, bytes);
}
