import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/conversations/application/conversation_list_controller.dart';
import 'package:timefit_native/features/conversations/domain/conversation_summary.dart';
import 'package:timefit_native/features/conversations/domain/repositories/conversation_repository.dart';

void main() {
  test('late local read cannot replace a newer watched snapshot', () async {
    final repository = _DelayedLocalRepository();
    final controller = ConversationListController(
      repository: repository,
      localOnly: true,
    );

    final load = controller.load();
    repository.events.add(<ConversationSummary>[
      ConversationSummary(
        id: 'new',
        title: 'new',
        preview: 'local',
        updatedAt: DateTime.utc(2026),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.conversations.map((item) => item.id), <String>[
      'new',
    ]);

    repository.read.complete(<ConversationSummary>[]);
    await load;
    expect(controller.state.conversations.map((item) => item.id), <String>[
      'new',
    ]);
    expect(repository.remoteCalls, 0);

    await controller.dispose();
    await repository.events.close();
  });
}

final class _DelayedLocalRepository implements LocalConversationRepository {
  final read = Completer<List<ConversationSummary>>();
  final events = StreamController<List<ConversationSummary>>();
  var remoteCalls = 0;

  @override
  Future<List<ConversationSummary>> readCachedConversations() => read.future;

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
