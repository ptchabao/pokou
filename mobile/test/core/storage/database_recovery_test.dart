import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/storage/database_recovery.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pokou-db-recovery-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'quarantines the database and SQLite sidecars without deleting them',
    () async {
      final path = '${directory.path}/pokou_messages_enc.db';
      await File(path).writeAsString('unreadable database');
      await File('$path-wal').writeAsString('write ahead log');
      await File('$path-shm').writeAsString('shared memory');

      final backupPath = await DatabaseRecovery.quarantine(path);

      expect(backupPath, isNotNull);
      expect(await File(path).exists(), isFalse);
      expect(await File(backupPath!).readAsString(), 'unreadable database');
      expect(await File('$backupPath-wal').readAsString(), 'write ahead log');
      expect(await File('$backupPath-shm').readAsString(), 'shared memory');
    },
  );

  test('does nothing when the database file does not exist', () async {
    final backupPath = await DatabaseRecovery.quarantine(
      '${directory.path}/missing.db',
    );

    expect(backupPath, isNull);
    expect(await directory.list().isEmpty, isTrue);
  });
}
