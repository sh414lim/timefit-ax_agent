import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/database/app_database.dart';

void main() {
  test('v1 attachment rows survive additive v3 migrations', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE local_attachments (local_id TEXT PRIMARY KEY, attachment_id TEXT UNIQUE, conversation_id TEXT NOT NULL, client_message_id TEXT NOT NULL, local_file_uri TEXT, upload_state TEXT NOT NULL DEFAULT \'queued\', bytes_total INTEGER NOT NULL DEFAULT 0, bytes_sent INTEGER NOT NULL DEFAULT 0, content_type TEXT NOT NULL, sha256 TEXT NOT NULL, failure_code TEXT)',
          );
          raw.execute(
            "INSERT INTO local_attachments(local_id,conversation_id,client_message_id,local_file_uri,content_type,sha256) VALUES ('legacy-local','conversation','client','file:///private/fixture','application/pdf','sha')",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(database.close);
    final row = await database.select(database.localAttachments).getSingle();
    expect(database.schemaVersion, 3);
    expect(row.localId, 'legacy-local');
    expect(row.localFileUri, 'file:///private/fixture');
    expect(row.uploadObjectPath, equals(null));
    expect(row.verificationFailures, 0);
    expect(row.composerExcluded, isFalse);
  });

  test('v2 attachment rows gain local composer membership in v3', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE local_attachments (local_id TEXT PRIMARY KEY, attachment_id TEXT UNIQUE, conversation_id TEXT NOT NULL, client_message_id TEXT NOT NULL, local_file_uri TEXT, upload_state TEXT NOT NULL DEFAULT \'queued\', bytes_total INTEGER NOT NULL DEFAULT 0, bytes_sent INTEGER NOT NULL DEFAULT 0, content_type TEXT NOT NULL, sha256 TEXT NOT NULL, failure_code TEXT, upload_object_path TEXT, verification_failures INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute(
            "INSERT INTO local_attachments(local_id,conversation_id,client_message_id,content_type,sha256) VALUES ('v2-local','conversation','client','application/pdf','sha')",
          );
          raw.execute('PRAGMA user_version = 2');
        },
      ),
    );
    addTearDown(database.close);

    final row = await database.select(database.localAttachments).getSingle();
    expect(database.schemaVersion, 3);
    expect(row.localId, 'v2-local');
    expect(row.composerExcluded, isFalse);
  });
}
