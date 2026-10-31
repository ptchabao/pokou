import 'dart:io';

/// Preserves an unreadable database and its SQLite sidecars before retrying.
class DatabaseRecovery {
  static Future<String?> quarantine(String databasePath) async {
    final database = File(databasePath);
    if (!await database.exists()) return null;

    final suffix = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final backupPath = '$databasePath.unreadable-$suffix';
    await database.rename(backupPath);

    for (final sidecar in ['-wal', '-shm', '-journal']) {
      final file = File('$databasePath$sidecar');
      if (await file.exists()) {
        await file.rename('$backupPath$sidecar');
      }
    }
    return backupPath;
  }
}
