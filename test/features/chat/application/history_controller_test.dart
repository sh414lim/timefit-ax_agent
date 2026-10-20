import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/chat/application/history_controller.dart';
import 'package:timefit_native/features/chat/domain/chat_message.dart';

class FakePages implements HistoryPageSource {
  final requests = <HistoryRequest>[];
  final pending = <Completer<HistoryPage>>[];
  @override
  Future<HistoryPage> loadBefore(HistoryRequest request) {
    requests.add(request);
    final result = Completer<HistoryPage>();
    pending.add(result);
    return result.future;
  }
}

ChatMessage message(int sequence, {String? id}) => ChatMessage(
  clientMessageId: id ?? '$sequence',
  sequence: sequence,
  body: 'fixture',
  displayedAt: DateTime.utc(2026),
  isMine: true,
  deliveryState: MessageDeliveryState.sent,
);
HistoryPage page(
  int from,
  int to, {
  bool more = true,
  String conversation = 'one',
}) => HistoryPage(
  conversationId: conversation,
  messages: [for (var i = from; i <= to; i++) message(i)],
  hasMoreBefore: more,
);

void main() {
  late FakePages source;
  late HistoryController controller;
  setUp(() {
    source = FakePages();
    controller = HistoryController(
      source: source,
      conversationId: 'one',
      earliestSequence: 121,
    );
  });
  tearDown(() => controller.dispose());
  test(
    '120 messages over three keyset pages and terminal state suppresses requests',
    () async {
      final seen = <int>[];
      for (final bounds in [(71, 120, true), (21, 70, true), (1, 20, false)]) {
        final result = controller.loadMore();
        source.pending.last.complete(
          page(bounds.$1, bounds.$2, more: bounds.$3),
        );
        seen.addAll((await result)!.messages.map((m) => m.sequence!));
      }
      expect(source.requests.map((r) => r.beforeSequence), [121, 71, 21]);
      expect(source.requests.map((r) => r.limit), everyElement(50));
      expect(seen.toSet(), hasLength(120));
      for (var i = 0; i < 5; i++) {
        expect(await controller.onTopDistance(0), equals(null));
      }
      expect(source.requests, hasLength(3));
    },
  );
  test('top threshold and concurrent callers share the exact future', () async {
    expect(await controller.onTopDistance(301), equals(null));
    final first = controller.onTopDistance(300);
    expect(identical(first, controller.loadMore()), isTrue);
    expect(source.requests, hasLength(1));
    source.pending.single.complete(page(71, 120));
    await first;
  });
  test('duplicate boundary and duplicate identity are not exposed', () async {
    final first = controller.loadMore();
    source.pending.last.complete(page(71, 120));
    await first;
    final next = controller.loadMore();
    source.pending.last.complete(
      HistoryPage(
        conversationId: 'one',
        messages: [message(71), message(70), message(70), message(69)],
        hasMoreBefore: true,
      ),
    );
    expect((await next)!.messages.map((m) => m.sequence), [69, 70]);
    expect(controller.state.beforeSequence, 69);
  });
  test('error preserves cursor and retry requests the same key', () async {
    final first = controller.loadMore();
    source.pending.last.completeError(StateError('private source failure'));
    expect(await first, equals(null));
    expect(controller.state.failure, HistoryFailure.sourceUnavailable);
    expect(controller.state.beforeSequence, 121);
    final retry = controller.retry();
    source.pending.last.complete(page(71, 120));
    await retry;
    expect(source.requests.map((r) => r.beforeSequence), [121, 121]);
    expect(controller.state.failure, equals(null));
  });
  test(
    'empty terminal page stops; empty nonterminal page fails without advancing',
    () async {
      final first = controller.loadMore();
      source.pending.last.complete(page(1, 0));
      expect(await first, equals(null));
      expect(controller.state.failure, HistoryFailure.invalidPage);
      final retry = controller.retry();
      source.pending.last.complete(page(1, 0, more: false));
      expect((await retry)!.messages, isEmpty);
      expect(controller.state.hasMoreBefore, isFalse);
    },
  );
  test(
    'invalid sequence identity and conversation are rejected atomically',
    () async {
      for (final invalid in [
        page(120, 121, conversation: 'other'),
        page(122, 123),
        HistoryPage(
          conversationId: 'one',
          messages: [
            message(5, id: 'same'),
            message(6, id: 'same'),
          ],
          hasMoreBefore: true,
        ),
        HistoryPage(
          conversationId: 'one',
          messages: [
            message(5, id: 'a'),
            message(5, id: 'b'),
          ],
          hasMoreBefore: true,
        ),
        page(1, 51),
      ]) {
        final result = controller.loadMore();
        source.pending.last.complete(invalid);
        expect(await result, equals(null));
        expect(controller.state.beforeSequence, 121);
        expect(controller.state.failure, HistoryFailure.invalidPage);
      }
    },
  );
  test(
    'switch cancels old request and late response cannot overwrite new state',
    () async {
      final old = controller.loadMore();
      controller.switchConversation(
        conversationId: 'two',
        earliestSequence: 51,
      );
      expect(source.requests.first.isCancelled, isTrue);
      expect(await old.timeout(const Duration(seconds: 1)), equals(null));
      final current = controller.loadMore();
      source.pending.last.complete(
        page(1, 50, more: false, conversation: 'two'),
      );
      await current;
      source.pending.first.complete(page(71, 120));
      expect(await old, equals(null));
      expect(controller.state.conversationId, 'two');
      expect(controller.state.hasMoreBefore, isFalse);
    },
  );
  test(
    'dispose suppresses late data and errors and prevents new work',
    () async {
      final old = controller.loadMore();
      controller.dispose();
      expect(await old.timeout(const Duration(seconds: 1)), equals(null));
      source.pending.single.completeError(StateError('late'));
      expect(await old, equals(null));
      expect(await controller.retry(), equals(null));
      expect(source.requests, hasLength(1));
    },
  );
  test('anchor delta preserves the visible bubble offset', () {
    expect(
      HistoryController.prependAnchorOffset(
        previousPixels: 125,
        previousMaxExtent: 1000,
        currentMaxExtent: 1700,
      ),
      825,
    );
    expect(
      HistoryController.prependAnchorOffset(
        previousPixels: 0,
        previousMaxExtent: 0,
        currentMaxExtent: 0,
      ),
      0,
    );
  });
  test(
    'no canonical cursor does not fabricate one from pending timestamps',
    () async {
      controller.switchConversation(
        conversationId: 'one',
        earliestSequence: null,
      );
      expect(await controller.loadMore(), equals(null));
      expect(source.requests, isEmpty);
    },
  );
}
