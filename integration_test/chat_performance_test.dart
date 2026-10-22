import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timefit_native/core/database/app_database.dart';
import 'package:timefit_native/features/chat/application/composer_controller.dart';
import 'package:timefit_native/features/chat/application/drift_attachment_composer_source.dart';
import 'package:timefit_native/features/chat/application/send_message.dart';
import 'package:timefit_native/features/chat/data/message_repository_impl.dart';
import 'package:timefit_native/features/chat/presentation/chat_screen.dart';
import 'package:timefit_native/features/chat/presentation/widgets/attachment_chip.dart';

const _conversationId = 'performance-conversation';
const _attachmentAggregateId = 'performance-attachment-aggregate';
const _messageCount = 500;
const _attachmentCount = 5;
const _attachmentBytes = 1000;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real Drift cache renders 500 messages and five attachment updates',
    (tester) async {
      final sandbox = await Directory.systemTemp.createTemp(
        'timefit-chat-performance-',
      );
      final databaseFile = File('${sandbox.path}/chat.sqlite');
      await _seed(databaseFile);

      final database = AppDatabase(NativeDatabase(databaseFile));
      final repository = MessageRepositoryImpl(database: database);
      final attachmentSource = DriftAttachmentComposerSource(
        database: database,
        clock: DateTime.now,
      );
      final composer = ComposerController(
        conversationId: _conversationId,
        submitter: SendMessage(database: database, clock: DateTime.now),
        attachmentClientMessageId: _attachmentAggregateId,
        attachmentSource: attachmentSource,
      );
      final scrollController = ScrollController();

      binding.reportData = <String, dynamic>{
        'schemaVersion': 1,
        'measurementStatus': kProfileMode
            ? 'profile_device_measurement'
            : 'debug_harness_only',
        'environment': <String, Object>{
          'platform': defaultTargetPlatform.name,
          'operatingSystem': Platform.operatingSystem,
          'operatingSystemVersion': Platform.operatingSystemVersion,
          'dartVersion': Platform.version,
          'mode': kProfileMode ? 'profile' : 'debug',
        },
        'fixture': <String, Object>{
          'messageCount': _messageCount,
          'attachmentCount': _attachmentCount,
          'database': 'reopened_local_sqlite',
        },
      };

      try {
        final firstDisplayElapsed = Stopwatch();
        await _measure(binding, 'reopened_sqlite_first_display', () async {
          firstDisplayElapsed.start();
          await tester.pumpWidget(
            MaterialApp(
              home: ChatScreen.repository(
                title: '성능 계측',
                repository: repository,
                conversationId: _conversationId,
                scrollController: scrollController,
                composerController: composer,
              ),
            ),
          );
          await tester.pumpAndSettle(const Duration(milliseconds: 16));
          firstDisplayElapsed.stop();
          expect(
            await repository.readCachedMessages(_conversationId),
            hasLength(_messageCount),
          );
          expect(find.text(_messageBody(_messageCount)), findsOneWidget);
          expect(find.byType(ComposerAttachmentChip), findsNWidgets(5));
        });
        if (kProfileMode) {
          binding.reportData!['reopened_sqlite_first_display_elapsedMicros'] =
              firstDisplayElapsed.elapsedMicroseconds;
        }

        final timeline = find.byKey(const ValueKey<String>('message-timeline'));
        expect(timeline, findsOneWidget);
        expect(scrollController.hasClients, isTrue);
        expect(scrollController.position.maxScrollExtent, greaterThan(0));

        await _measure(binding, 'message_scroll_both_directions', () async {
          var gestures = 0;
          while (scrollController.offset > 1 && gestures < 100) {
            await tester.fling(timeline, const Offset(0, 900), 5000);
            await tester.pumpAndSettle(const Duration(milliseconds: 16));
            gestures += 1;
          }
          expect(scrollController.offset, lessThanOrEqualTo(1));
          expect(find.text(_messageBody(1)), findsOneWidget);

          gestures = 0;
          while (scrollController.position.extentAfter > 1 && gestures < 100) {
            await tester.fling(timeline, const Offset(0, -900), 5000);
            await tester.pumpAndSettle(const Duration(milliseconds: 16));
            gestures += 1;
          }
          expect(scrollController.position.extentAfter, lessThanOrEqualTo(1));
          expect(find.text(_messageBody(_messageCount)), findsOneWidget);
        });

        await _measure(binding, 'five_attachment_progress', () async {
          for (var step = 1; step <= 10; step += 1) {
            await (database.update(database.localAttachments)..where(
                  (row) =>
                      row.conversationId.equals(_conversationId) &
                      row.clientMessageId.equals(_attachmentAggregateId),
                ))
                .write(
                  LocalAttachmentsCompanion(
                    bytesSent: Value(step * (_attachmentBytes ~/ 10)),
                  ),
                );
            await tester.pumpAndSettle(const Duration(milliseconds: 16));
            final progress = tester
                .widgetList<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator),
                )
                .where((indicator) => indicator.value != null)
                .toList(growable: false);
            expect(progress, hasLength(_attachmentCount));
            expect(
              progress.map((indicator) => indicator.value!),
              everyElement(closeTo(step / 10, 0.001)),
            );
          }
          await (database.update(database.localAttachments)..where(
                (row) =>
                    row.conversationId.equals(_conversationId) &
                    row.clientMessageId.equals(_attachmentAggregateId),
              ))
              .write(
                const LocalAttachmentsCompanion(uploadState: Value('ready')),
              );
          await tester.pumpAndSettle(const Duration(milliseconds: 16));
          expect(find.byType(ComposerAttachmentChip), findsNWidgets(5));
          expect(find.textContaining('준비됨'), findsNWidgets(5));
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 16));
        scrollController.dispose();
        composer.dispose();
        await repository.dispose();
        await database.close();
        await sandbox.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _seed(File databaseFile) async {
  final database = AppDatabase(NativeDatabase(databaseFile));
  try {
    final base = DateTime.utc(2026, 10, 22, 12);
    await database.batch((batch) {
      batch.insertAll(database.localMessages, <LocalMessagesCompanion>[
        for (var sequence = 1; sequence <= _messageCount; sequence += 1)
          LocalMessagesCompanion.insert(
            localId: 'performance-message-$sequence',
            serverId: Value('performance-server-$sequence'),
            conversationId: _conversationId,
            clientMessageId: 'performance-client-$sequence',
            sequence: Value(sequence),
            senderKind: sequence.isEven ? 'user' : 'system',
            bodyText: Value(_messageBody(sequence)),
            messageKind: 'text',
            clientCreatedAt: base.add(Duration(seconds: sequence)),
            serverCreatedAt: Value(base.add(Duration(seconds: sequence))),
            deliveryState: const Value('sent'),
          ),
      ]);
      batch.insertAll(database.localAttachments, <LocalAttachmentsCompanion>[
        for (var index = 1; index <= _attachmentCount; index += 1)
          LocalAttachmentsCompanion.insert(
            localId: 'performance-attachment-$index',
            conversationId: _conversationId,
            clientMessageId: _attachmentAggregateId,
            uploadState: const Value('uploading'),
            bytesTotal: const Value(_attachmentBytes),
            bytesSent: const Value(0),
            contentType: index.isEven ? 'image/png' : 'application/pdf',
            sha256: 'fixture-sha256-$index',
          ),
      ]);
    });
  } finally {
    await database.close();
  }
}

String _messageBody(int sequence) =>
    'Performance message $sequence ${'segment ' * ((sequence % 4) + 1)}';

Future<void> _measure(
  IntegrationTestWidgetsFlutterBinding binding,
  String scenario,
  Future<void> Function() action,
) async {
  if (!kProfileMode) {
    await action();
    binding.reportData!['${scenario}_status'] =
        'not_measured_run_with_profile_device';
    return;
  }

  final timings = <FrameTiming>[];
  final callback = timings.addAll;
  SchedulerBinding.instance.addTimingsCallback(callback);
  try {
    // Flush setup frames delivered after callback registration, then discard
    // them before the scenario boundary starts.
    await Future<void>.delayed(const Duration(seconds: 2));
    timings.clear();
    final startedAt = DateTime.now().toUtc();
    final elapsed = Stopwatch()..start();
    await binding.traceAction(() async {
      await action();
      // Engines may batch FrameTiming delivery for up to one second.
      await Future<void>.delayed(const Duration(seconds: 2));
    }, reportKey: '${scenario}_timeline');
    elapsed.stop();
    binding.reportData!['${scenario}_window'] = <String, Object>{
      'startedAtUtc': startedAt.toIso8601String(),
      'finishedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'elapsedMicros': elapsed.elapsedMicroseconds,
      'frameClock': 'engine_monotonic_microseconds',
    };
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(callback);
  }
  expect(timings, isNotEmpty, reason: '$scenario produced no FrameTiming');
  binding.reportData!['${scenario}_frames'] = <String, Object>{
    'sampleCount': timings.length,
    'samples': <Map<String, int>>[
      for (final timing in timings)
        <String, int>{
          'buildMicros': timing.buildDuration.inMicroseconds,
          'rasterMicros': timing.rasterDuration.inMicroseconds,
          'totalMicros': timing.totalSpan.inMicroseconds,
          'vsyncStartMicros': timing.timestampInMicroseconds(
            FramePhase.vsyncStart,
          ),
          'buildStartMicros': timing.timestampInMicroseconds(
            FramePhase.buildStart,
          ),
          'rasterFinishMicros': timing.timestampInMicroseconds(
            FramePhase.rasterFinish,
          ),
        },
    ],
  };
}
