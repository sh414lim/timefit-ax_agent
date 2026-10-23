import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/conversations/data/dev_local_conversation_repository.dart';

void main() {
  late AppDatabase database;
  late LocalRepositorySession session;
  late DevLocalConversationRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    session = LocalRepositorySession.forDatabase(database);
    repository = DevLocalConversationRepository(
      database: database,
      session: session,
      clock: () => DateTime.utc(2026, 10, 23),
      conversationId: () => 'conversation-1',
    );
  });

  tearDown(() async {
    await session.dispose();
    await database.close();
  });

  test('blank title persists as null and displays the default title', () async {
    final String id = await repository.createConversation();
    await repository.renameConversation(id, null);

    final row = (await database.conversationDao.getAll()).single;
    expect(row.title, isNull);
    expect(row.syncState, 'stale');
    expect((await repository.readCachedConversations()).single.title, '새 대화');
  });

  test(
    'soft archive leaves the row and moves it to archived queries',
    () async {
      final String id = await repository.createConversation();
      await repository.renameConversation(id, '보관할 대화');
      await repository.archiveConversation(id);

      final row = (await database.conversationDao.getAll()).single;
      expect(row.status, 'archived');
      expect(await repository.readCachedConversations(), isEmpty);
      final archived = await repository.readArchivedConversations();
      expect(archived.single.id, id);
      expect(archived.single.title, '보관할 대화');
    },
  );

  test('failed updates retain the existing row', () async {
    final String id = await repository.createConversation();

    await expectLater(
      repository.archiveConversation('missing'),
      throwsStateError,
    );
    await expectLater(
      repository.renameConversation('missing', '이름'),
      throwsStateError,
    );

    final row = (await database.conversationDao.getAll()).single;
    expect(row.id, id);
    expect(row.status, 'active');
    expect(row.title, isNull);
  });
}
