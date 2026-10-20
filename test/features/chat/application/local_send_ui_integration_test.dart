import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/message_reconciler.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 10, 20, 12);

  testWidgets('local send and canonical reconciliation flow through Drift UI', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final LocalRepositorySession session = LocalRepositorySession.forDatabase(
      database,
    );
    final MessageRepositoryImpl repository = MessageRepositoryImpl(
      database: database,
      session: session,
    );
    final SendMessage send = SendMessage(
      database: database,
      session: session,
      clock: () => now,
      clientMessageId: () => 'client-1',
    );
    final MessageReconciler reconciler = MessageReconciler(
      database: database,
      session: session,
      clock: () => now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen.repository(
          title: '통합 검증',
          repository: repository,
          conversationId: 'conversation-1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 메시지가 없습니다'), findsOneWidget);

    await tester.runAsync(
      () => send.submit(conversationId: 'conversation-1', bodyText: '통합 메시지'),
    );
    await tester.pumpAndSettle();
    expect(find.text('통합 메시지'), findsOneWidget);
    expect(find.text('전송 대기 중'), findsOneWidget);

    await tester.runAsync(
      () => reconciler.reconcile(
        commandId: 'client-1',
        canonical: CanonicalTextMessage(
          serverId: 'server-1',
          conversationId: 'conversation-1',
          clientMessageId: 'client-1',
          sequence: 1,
          bodyText: '통합 메시지',
          serverCreatedAt: now.add(const Duration(seconds: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('통합 메시지'), findsOneWidget);
    expect(find.text('전송됨'), findsOneWidget);
    expect((await database.messageDao.getAll()).single.serverId, 'server-1');
    expect((await database.outboxDao.getAll()).single.state, 'completed');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(repository.dispose);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(database.close);
  });

  test('session disposal blocks old read and write handles', () async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final MessageRepositoryImpl repository = MessageRepositoryImpl(
      database: database,
    );
    final SendMessage send = SendMessage(
      database: database,
      clock: () => now,
      clientMessageId: () => 'client-2',
    );
    final MessageReconciler reconciler = MessageReconciler(
      database: database,
      clock: () => now,
    );
    addTearDown(database.close);

    await repository.dispose();

    await expectLater(
      repository.readCachedMessages('conversation-1'),
      throwsA(isA<LocalRepositoryException>()),
    );
    await expectLater(
      send.submit(conversationId: 'conversation-1', bodyText: '차단'),
      throwsA(isA<LocalRepositoryException>()),
    );
    await expectLater(
      reconciler.reconcile(
        commandId: 'client-2',
        canonical: CanonicalTextMessage(
          serverId: 'server-2',
          conversationId: 'conversation-1',
          clientMessageId: 'client-2',
          sequence: 1,
          bodyText: '차단',
          serverCreatedAt: now,
        ),
      ),
      throwsA(isA<LocalRepositoryException>()),
    );
    expect(await database.messageDao.getAll(), isEmpty);
    expect(await database.outboxDao.getAll(), isEmpty);
  });
}
