import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/core/database/local_repository_session.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/outbox/outbox_worker.dart';
import 'package:timefit_native/features/chat/application/outbox/production_chat_executor.dart';
import 'package:timefit_native/features/chat/application/outbox/retry_policy.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';
import 'package:timefit_native/features/chat/infrastructure/production_chat_transport.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';

// Test-only: the exact restart entrypoint is admitted only in dev/debug simulator.
void registerProductionChatLoopbackFixture() {
  const phase = String.fromEnvironment('TIMEFIT_LOCAL_PRODUCTION_PHASE');
  testWidgets(
    'local Python chat UI $phase with native restart persistence',
    (tester) async {
      const runId = String.fromEnvironment('TIMEFIT_LOCAL_PRODUCTION_RUN_ID');
      const token = String.fromEnvironment('TIMEFIT_LOCAL_PRODUCTION_TOKEN');
      final origin = Uri.parse(
        const String.fromEnvironment('TIMEFIT_LOCAL_PRODUCTION_ORIGIN'),
      );
      expect(Platform.isIOS, isTrue);
      expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(runId), isTrue);
      expect(origin.scheme, 'https');
      expect(origin.host, '127.0.0.1');
      expect(<String>['send', 'recover'], contains(phase));
      final ca = base64Decode(
        const String.fromEnvironment('TIMEFIT_LOCAL_PRODUCTION_CA'),
      );
      final context = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificatesBytes(ca);
      final api = ProductionChatTransport(
        origin: origin,
        allowedHosts: {origin.authority},
        accessToken: () async => token,
        clientFactory: () => HttpClient(context: context),
      );
      final scope = ProductionChatScope(
        tenantId: '11111111-1111-4111-8111-111111111111',
        conversationId: '22222222-2222-4222-8222-222222222222',
      );
      String id(int n) =>
          '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
      late Directory root;
      late File manifest;
      late AppDatabase db;
      late MessageRepositoryImpl repository;
      late ComposerController composer;
      var now = DateTime.now().toUtc();
      var nextId = phase == 'send' ? 1 : 7;
      final initialized = await tester.runAsync(() async {
        final support = await getApplicationSupportDirectory();
        root = Directory('${support.path}/local-production-fixture/$runId');
        final file = File('${root.path}/chat.sqlite');
        manifest = File('${root.path}/manifest.json');
        if (phase == 'send') {
          expect(await file.exists(), isFalse);
          await root.create(recursive: true);
        } else {
          expect(await file.exists(), isTrue);
          final previous = jsonDecode(await manifest.readAsString()) as Map;
          expect(previous['processId'], isNot(pid));
        }
        db = AppDatabase(NativeDatabase(file));
        if (phase == 'send') {
          await db
              .into(db.localConversations)
              .insert(
                LocalConversationsCompanion.insert(
                  id: scope.conversationId,
                  serverCreatedAt: now,
                  serverUpdatedAt: now,
                  lastSyncedAt: now,
                ),
              );
        }
        repository = MessageRepositoryImpl(database: db);
        composer = ComposerController(
          conversationId: scope.conversationId,
          submitter: SendMessage(
            database: db,
            clock: () => now,
            clientMessageId: () => id(nextId++),
          ),
        );
        return true;
      });
      if (initialized != true) return;
      OutboxWorker worker() => OutboxWorker(
        dao: db.outboxDao,
        scope: 'ios-loopback-$runId-$pid',
        clock: () => now,
        retryPolicy: RetryPolicy(() => 0.5),
        executor: ProductionChatExecutor(
          database: db,
          session: LocalRepositorySession.forDatabase(db),
          api: api,
          scope: scope,
          isCurrentSession: () => true,
          clock: () => now,
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: ChatScreen.repository(
              title: '로컬 서버 기능 테스트',
              repository: repository,
              conversationId: scope.conversationId,
              composerController: composer,
            ),
          ),
        );
        await settle();
        if (phase == 'send') {
          for (var n = 1; n <= 6; n++) {
            await tester.enterText(
              find.byType(TextField),
              n == 6 ? 'synthetic-failure' : 'synthetic-turn-$n',
            );
            await tester.pump();
            await tester.tap(find.byTooltip('메시지 보내기'));
            await tester.pump();
            await tester.runAsync(() async {
              final deadline = DateTime.now().add(const Duration(seconds: 5));
              while (composer.isSubmitting &&
                  DateTime.now().isBefore(deadline)) {
                await Future<void>.delayed(const Duration(milliseconds: 10));
              }
              expect(composer.isSubmitting, isFalse);
              expect(composer.lastError, isNull);
              await worker().wake();
            });
            await settle();
          }
        } else {
          await tester.runAsync(() => worker().wake());
          await settle();
        }
        late List<String?> assistantIds;
        await tester.runAsync(() async {
          final rows = await db.messageDao.readTimeline(scope.conversationId);
          expect(rows, hasLength(11));
          expect(
            rows
                .where((r) => r.senderKind == 'user')
                .map((r) => r.clientMessageId),
            orderedEquals(List.generate(6, (i) => id(i + 1))),
          );
          assistantIds = rows
              .where((r) => r.senderKind == 'system')
              .map((r) => r.serverId)
              .toList();
          expect(assistantIds.toSet(), hasLength(5));
          expect(assistantIds, isNot(contains(null)));
          final outbox = await db.outboxDao.getAll();
          expect(outbox, hasLength(6));
          expect(outbox.every((r) => r.state == 'completed'), isTrue);
          expect(outbox.last.lastErrorCode, 'production_dispatch_unknown');
          if (phase == 'recover') {
            final previous = jsonDecode(await manifest.readAsString()) as Map;
            expect(
              assistantIds,
              orderedEquals(previous['assistantIds'] as List),
            );
          }
        });
        expect(find.text('로컬 테스트 응답 5'), findsWidgets);
        debugPrint('TIMEFIT_LOCAL_PRODUCTION_UI_READY phase=$phase pid=$pid');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 5)),
        );
        await tester.runAsync(() async {
          if (phase == 'send') {
            await manifest.writeAsString(
              jsonEncode({'processId': pid, 'assistantIds': assistantIds}),
            );
            // Persist a lost local finish, then stop this actual native process.
            await (db.update(
              db.outboxCommands,
            )..where((r) => r.id.equals(id(1)))).write(
              OutboxCommandsCompanion(
                state: const Value('retry_wait'),
                nextAttemptAt: Value(now),
                lastErrorCode: const Value('production_dispatch_started'),
              ),
            );
          } else {
            await SendMessage(
              database: db,
              clock: () => now,
              clientMessageId: () => id(7),
            ).submit(
              conversationId: scope.conversationId,
              bodyText: 'never-dispatch',
            );
            await (db.update(
              db.outboxCommands,
            )..where((r) => r.id.equals(id(7)))).write(
              const OutboxCommandsCompanion(
                lastErrorCode: Value('production_dispatch_started'),
              ),
            );
            now = now.add(const Duration(seconds: 2));
            await worker().wake();
            final pending = (await db.outboxDao.getAll()).last;
            expect(pending.lastErrorCode, 'production_outcome_unknown');
            expect(pending.attemptCount, 0);
            expect(pending.state, 'retry_wait');
            final untrusted = ProductionChatTransport(
              origin: origin,
              allowedHosts: {origin.authority},
              accessToken: () async => token,
            );
            await expectLater(
              untrusted.lookup(scope, id(1)),
              throwsA(
                isA<ProductionChatFailure>()
                    .having(
                      (e) => e.code,
                      'code',
                      'production_transport_unavailable',
                    )
                    .having((e) => e.commandSent, 'commandSent', isFalse),
              ),
            );
            final previous = jsonDecode(await manifest.readAsString()) as Map;
            await manifest.writeAsString(
              jsonEncode({
                ...previous,
                'recoverProcessId': pid,
                'storedUserRows': 7,
                'storedAssistantRows': 5,
                'outboxRows': 7,
              }),
            );
          }
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        composer.dispose();
        await tester.runAsync(() async {
          await repository.dispose();
          await db.close();
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
