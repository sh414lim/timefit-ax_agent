import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/conversations/application/conversation_list_controller.dart';
import 'package:timefit_native/features/conversations/domain/conversation_summary.dart';
import 'package:timefit_native/features/conversations/domain/repositories/conversation_repository.dart';

void main() {
  for (final readFails in <bool>[false, true]) {
    test(
      'late ${readFails ? 'failed' : 'successful'} local read cannot replace watch',
      () async {
        final repository = _DelayedLocalRepository();
        final controller = ConversationListController(
          repository: repository,
          localOnly: true,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.events.close();
        });

        final load = controller.load();
        repository.events.add(<ConversationSummary>[_item('new')]);
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.conversations.map((item) => item.id), <String>[
          'new',
        ]);

        if (readFails) {
          repository.reads.single.completeError(StateError('synthetic'));
        } else {
          repository.reads.single.complete(<ConversationSummary>[]);
        }
        await load;
        expect(controller.state.conversations.map((item) => item.id), <String>[
          'new',
        ]);
        expect(repository.remoteCalls, 0);
      },
    );
  }

  test('new refresh generation and watch fence older local reads', () async {
    final repository = _DelayedLocalRepository();
    final controller = ConversationListController(
      repository: repository,
      localOnly: true,
    );
    addTearDown(() async {
      await controller.dispose();
      await repository.events.close();
    });

    final load = controller.load();
    final refresh = controller.refresh();
    repository.events.add(<ConversationSummary>[_item('current')]);
    await Future<void>.delayed(Duration.zero);
    repository.reads[1].complete(<ConversationSummary>[_item('stale')]);
    await refresh;
    repository.reads[0].complete(<ConversationSummary>[_item('oldest')]);
    await load;
    expect(controller.state.conversations.single.id, 'current');

    final next = controller.refresh();
    repository.reads[2].complete(<ConversationSummary>[]);
    await next;
    expect(controller.state.phase, ConversationListPhase.empty);
    expect(repository.remoteCalls, 0);
  });

  test('dispose fences delayed local read and watch notifications', () async {
    final repository = _DelayedLocalRepository();
    final controller = ConversationListController(
      repository: repository,
      localOnly: true,
    );
    var notifications = 0;
    controller.addListener((_) => notifications += 1);
    final load = controller.load();
    await controller.dispose();
    final notificationsAtDispose = notifications;
    repository.events.add(<ConversationSummary>[_item('late')]);
    repository.reads.single.complete(<ConversationSummary>[_item('late')]);
    await load;
    await Future<void>.delayed(Duration.zero);
    expect(notifications, notificationsAtDispose);
    expect(repository.remoteCalls, 0);
    await repository.events.close();
  });
}

ConversationSummary _item(String id) => ConversationSummary(
  id: id,
  title: id,
  preview: 'local',
  updatedAt: DateTime.utc(2026),
);

final class _DelayedLocalRepository implements LocalConversationRepository {
  final reads = <Completer<List<ConversationSummary>>>[];
  final events = StreamController<List<ConversationSummary>>();
  var remoteCalls = 0;

  @override
  Future<List<ConversationSummary>> readCachedConversations() {
    final read = Completer<List<ConversationSummary>>();
    reads.add(read);
    return read.future;
  }

  @override
  Stream<List<ConversationSummary>> watchCachedConversations() => events.stream;

  @override
  Future<List<ConversationSummary>> refreshConversations() async {
    remoteCalls += 1;
    return <ConversationSummary>[];
  }

  @override
  Future<void> dispose() async {}
}
