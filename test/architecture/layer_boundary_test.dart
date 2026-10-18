import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<String> features = <String>[
    'conversations',
    'chat',
    'attachments',
    'settings',
  ];
  const List<String> layers = <String>[
    'presentation',
    'application',
    'domain',
    'data',
  ];

  test('every feature exposes the four required layer directories', () {
    for (final String feature in features) {
      for (final String layer in layers) {
        expect(
          Directory('lib/features/$feature/$layer').existsSync(),
          isTrue,
          reason: '$feature must contain its $layer boundary',
        );
      }
    }
  });

  test('presentation never imports Supabase or Drift implementations', () {
    final List<File> presentationFiles = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (File file) =>
              file.path.endsWith('.dart') &&
              file.path.contains(
                '${Platform.pathSeparator}presentation${Platform.pathSeparator}',
              ),
        )
        .toList();

    expect(presentationFiles, isNotEmpty);

    for (final File file in presentationFiles) {
      final String source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('package:supabase_flutter/')),
        reason: '${file.path} imports the Supabase SDK directly',
      );
      expect(
        source,
        isNot(contains('package:drift/')),
        reason: '${file.path} imports Drift directly',
      );
      expect(
        source,
        isNot(contains('/database/')),
        reason: '${file.path} imports a database implementation directly',
      );
    }
  });
}
