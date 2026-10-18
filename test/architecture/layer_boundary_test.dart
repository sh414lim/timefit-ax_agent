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
        forbiddenPresentationImports(source),
        isEmpty,
        reason: '${file.path} imports an implementation directly',
      );
    }
  });

  test('Supabase lower-level SDK import is rejected by the boundary rule', () {
    final String source = File(
      'test/architecture/fixtures/supabase_subsdk_import.dart.fixture',
    ).readAsStringSync();

    expect(forbiddenPresentationImports(source), contains('package:supabase/'));
  });
}

Set<String> forbiddenPresentationImports(String source) {
  final Set<String> violations = <String>{};
  if (RegExp(r"package:supabase(?:_flutter)?/").hasMatch(source)) {
    violations.add(
      source.contains('package:supabase_flutter/')
          ? 'package:supabase_flutter/'
          : 'package:supabase/',
    );
  }
  if (source.contains('package:drift/')) {
    violations.add('package:drift/');
  }
  if (source.contains('/database/')) {
    violations.add('/database/');
  }
  return violations;
}
