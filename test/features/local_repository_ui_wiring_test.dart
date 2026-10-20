import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/daos/message_dao.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';
import 'package:timefit_native/features/chat/domain/chat_message.dart';
import 'package:timefit_native/features/chat/domain/repositories/message_repository.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';
import 'package:timefit_native/features/conversations/application/conversation_list_controller.dart';
import 'package:timefit_native/features/conversations/data/conversation_repository_impl.dart';
import 'package:timefit_native/features/conversations/presentation/conversation_list_screen.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 10, 20, 12);

  testWidgets('conversation DB stream updates UI without rebuild read growth', (
    WidgetTester tester,
  ) async {
    final _ReadProbe probe = _ReadProbe();
    final AppDatabase database = AppDatabase(
      NativeDatabase.memory().interceptWith(probe),
    );
    final ConversationRepositoryImpl repository = ConversationRepositoryImpl(
      database: database,
    );
    final ConversationListController controller = ConversationListController(
      repository: repository,
    );
    addTearDown(database.close);
    addTearDown(controller.dispose);
    await _insertConversation(database, 'one', now);

    await _pumpConversationList(tester, controller);
    await tester.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
    final int readsAfterInitial = probe.conversationSelects;

    await _pumpConversationList(tester, controller);
    await tester.pump();
    expect(probe.conversationSelects, readsAfterInitial);

    await _insertConversation(
      database,
      'two',
      now.add(const Duration(hours: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.text('two'), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
    expect(probe.conversationSelects, lessThanOrEqualTo(readsAfterInitial + 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(controller.dispose);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(database.close);
  });

  testWidgets(
    'message repository renders empty, pending, and canonical update',
    (WidgetTester tester) async {
      final _ReadProbe probe = _ReadProbe();
      final AppDatabase database = AppDatabase(
        NativeDatabase.memory().interceptWith(probe),
      );
      final MessageRepositoryImpl repository = MessageRepositoryImpl(
        database: database,
      );
      addTearDown(repository.dispose);
      addTearDown(database.close);

      await _pumpRepositoryChat(tester, repository, conversationId: 'one');
      await tester.pumpAndSettle();
      expect(find.text('아직 메시지가 없습니다'), findsOneWidget);
      final int readsAfterInitial = probe.messageSelects;

      await _insertPending(database, 'pending', 'one', now);
      await _insertCanonical(database, 'canonical-1', 'one', 1, now);
      await tester.pumpAndSettle();
      expect(find.text('pending'), findsOneWidget);
      expect(find.text('canonical-1'), findsOneWidget);

      await database.messageDao.upsertCanonical(
        CanonicalLocalMessage(
          serverId: 'server-pending',
          conversationId: 'one',
          clientMessageId: 'pending',
          sequence: 2,
          senderKind: 'user',
          bodyText: 'pending promoted',
          messageKind: 'text',
          serverCreatedAt: now.add(const Duration(minutes: 2)),
        ),
        fallbackLocalId: 'pending',
        fallbackClientCreatedAt: now,
      );
      await tester.pumpAndSettle();
      expect(find.text('pending'), findsNothing);
      expect(find.text('pending promoted'), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);

      final int readsBeforeRebuild = probe.messageSelects;
      await _pumpRepositoryChat(tester, repository, conversationId: 'one');
      await tester.pump();
      expect(probe.messageSelects, readsBeforeRebuild);
      expect(probe.messageSelects, greaterThan(readsAfterInitial));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(repository.dispose);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(database.close);
    },
  );

  testWidgets('repository failure is distinct from an empty timeline', (
    WidgetTester tester,
  ) async {
    final _ErrorMessageRepository repository = _ErrorMessageRepository();

    await _pumpRepositoryChat(tester, repository, conversationId: 'one');
    await tester.pump();

    expect(find.text('메시지를 표시하지 못했습니다'), findsOneWidget);
    expect(find.text('아직 메시지가 없습니다'), findsNothing);
  });

  testWidgets('awaited session switch drops old events and revoked data', (
    WidgetTester tester,
  ) async {
    final AppDatabase oldDatabase = AppDatabase(NativeDatabase.memory());
    final AppDatabase newDatabase = AppDatabase(NativeDatabase.memory());
    final MessageRepositoryImpl oldRepository = MessageRepositoryImpl(
      database: oldDatabase,
    );
    final MessageRepositoryImpl newRepository = MessageRepositoryImpl(
      database: newDatabase,
    );
    addTearDown(oldRepository.dispose);
    addTearDown(newRepository.dispose);
    addTearDown(oldDatabase.close);
    addTearDown(newDatabase.close);
    await _insertCanonical(oldDatabase, 'old data', 'one', 1, now);
    await _pumpRepositoryChat(tester, oldRepository, conversationId: 'one');
    await tester.pumpAndSettle();
    expect(find.text('old data'), findsOneWidget);

    await _pumpRepositoryChat(
      tester,
      oldRepository,
      conversationId: 'one',
      status: ChatScreenStatus.accessRevoked,
    );
    expect(find.text('old data'), findsNothing);
    expect(find.text('대화에 접근할 수 없습니다'), findsOneWidget);

    await tester.runAsync(oldRepository.dispose);
    await _pumpRepositoryChat(tester, newRepository, conversationId: 'one');
    await _insertCanonical(oldDatabase, 'late old event', 'one', 2, now);
    await _insertCanonical(newDatabase, 'new namespace', 'one', 1, now);
    await tester.pumpAndSettle();
    expect(find.text('late old event'), findsNothing);
    expect(find.text('new namespace'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(newRepository.dispose);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(oldDatabase.close);
    await tester.runAsync(newDatabase.close);
    expect(tester.takeException(), isNull);
  });
}

class _ReadProbe extends QueryInterceptor {
  int conversationSelects = 0;
  int messageSelects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('FROM local_conversations c')) {
      conversationSelects += 1;
    }
    if (statement.contains('FROM local_messages')) {
      messageSelects += 1;
    }
    return super.runSelect(executor, statement, args);
  }
}

Future<void> _pumpConversationList(
  WidgetTester tester,
  ConversationListController controller,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: ConversationListScreen(
        controller: controller,
        onNewConversation: () {},
        onOpenSettings: () {},
        onOpenArchive: () {},
        onOpenConversation: (_) {},
      ),
    ),
  );
}

Future<void> _pumpRepositoryChat(
  WidgetTester tester,
  MessageRepository repository, {
  required String conversationId,
  ChatScreenStatus status = ChatScreenStatus.ready,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: ChatScreen.repository(
        title: '연결 테스트',
        repository: repository,
        conversationId: conversationId,
        status: status,
      ),
    ),
  );
}

final class _ErrorMessageRepository implements MessageRepository {
  @override
  Future<void> dispose() async {}

  @override
  Future<List<ChatMessage>> readCachedMessages(String conversationId) async =>
      throw const LocalRepositoryException(LocalRepositoryFailure.readFailed);

  @override
  Stream<List<ChatMessage>> watchCachedMessages(String conversationId) =>
      Stream<List<ChatMessage>>.error(
        const LocalRepositoryException(LocalRepositoryFailure.readFailed),
      );
}

Future<void> _insertConversation(
  AppDatabase database,
  String id,
  DateTime updatedAt,
) {
  return database.conversationDao.upsert(
    LocalConversationsCompanion.insert(
      id: id,
      title: Value(id),
      serverCreatedAt: updatedAt,
      serverUpdatedAt: updatedAt,
      lastSyncedAt: updatedAt,
    ),
  );
}

Future<void> _insertPending(
  AppDatabase database,
  String id,
  String conversationId,
  DateTime createdAt,
) {
  return database
      .into(database.localMessages)
      .insert(
        LocalMessagesCompanion.insert(
          localId: id,
          conversationId: conversationId,
          clientMessageId: id,
          senderKind: 'user',
          bodyText: Value(id),
          messageKind: 'text',
          clientCreatedAt: createdAt,
        ),
      );
}

Future<void> _insertCanonical(
  AppDatabase database,
  String id,
  String conversationId,
  int sequence,
  DateTime createdAt,
) {
  return database.messageDao
      .upsertCanonical(
        CanonicalLocalMessage(
          serverId: 'server-$id',
          conversationId: conversationId,
          clientMessageId: 'client-$id',
          sequence: sequence,
          senderKind: 'user',
          bodyText: id,
          messageKind: 'text',
          serverCreatedAt: createdAt,
        ),
        fallbackLocalId: 'local-$id',
        fallbackClientCreatedAt: createdAt,
      )
      .then((_) {});
}
