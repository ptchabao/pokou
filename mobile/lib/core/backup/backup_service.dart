import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers.dart';
import '../time/server_time.dart';

/// Ce que le serveur sait d'une sauvegarde : jamais son contenu, seulement
/// de quoi la proposer (CNX-2) et la déchiffrer avec le mot de passe.
class BackupInfo {
  const BackupInfo({
    required this.mediaId,
    required this.salt,
    required this.iterations,
    required this.discussions,
    required this.messages,
    required this.sizeBytes,
    required this.createdAt,
  });

  final int mediaId;
  final String salt;
  final int iterations;
  final int discussions;
  final int messages;
  final int sizeBytes;
  final DateTime createdAt;

  static BackupInfo? fromJson(Map<String, dynamic> json) {
    if (json['exists'] != true || json['media_id'] == null) return null;
    return BackupInfo(
      mediaId: json['media_id'] as int,
      salt: json['salt'] as String,
      iterations: json['iterations'] as int,
      discussions: json['discussions'] as int? ?? 0,
      messages: json['messages'] as int? ?? 0,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      createdAt:
          tryParseServerTime(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Le mot de passe ne correspond pas à la sauvegarde.
class BackupWrongPasswordException implements Exception {
  const BackupWrongPasswordException();
}

/// Avancement d'une restauration (CNX-3).
class RestoreProgress {
  const RestoreProgress({required this.done, required this.total});

  final int done;
  final int total;

  double get fraction => total == 0 ? 1 : (done / total).clamp(0, 1).toDouble();
  bool get finished => done >= total;
}

/// Sauvegarde chiffrée des discussions (MSG-12).
///
/// Le chiffrement se fait SUR LE TÉLÉPHONE : AES-256-GCM, avec une clé tirée
/// d'un mot de passe choisi par l'utilisateur (PBKDF2-HMAC-SHA256). Pokou ne
/// reçoit qu'un bloc opaque ; sans le mot de passe, personne — Pokou
/// compris — ne peut le lire. La clé dérivée est gardée dans le trousseau
/// du téléphone pour les sauvegardes suivantes ; le mot de passe, jamais.
class BackupService {
  BackupService(this._ref, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final Ref _ref;
  final FlutterSecureStorage _storage;

  static const _iterations = 120000;
  static const _keyKey = 'pokou_backup_key_v1';
  static const _saltKey = 'pokou_backup_salt_v1';
  static const _lastKey = 'pokou_backup_last_v1';
  static const _format = 'pokou-backup-v1';

  final _aes = AesGcm.with256bits();

  Future<BackupInfo?> info() async {
    final json =
        await _ref.read(apiClientProvider).get('/backup')
            as Map<String, dynamic>;
    return BackupInfo.fromJson(json);
  }

  /// Un mot de passe a-t-il été choisi sur ce téléphone ?
  Future<bool> hasPassword() async => await _storage.read(key: _keyKey) != null;

  Future<DateTime?> lastBackupAt() async =>
      DateTime.tryParse(await _storage.read(key: _lastKey) ?? '');

  Future<SecretKey> _derive(String password, String salt, int iterations) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: base64Decode(salt));

  /// Choisir (ou changer) le mot de passe de sauvegarde.
  Future<void> setPassword(String password) async {
    final random = Random.secure();
    final salt = base64Encode(
      List<int>.generate(18, (_) => random.nextInt(256)),
    );
    final key = await _derive(password, salt, _iterations);
    await _storage.write(
      key: _keyKey,
      value: base64Encode(await key.extractBytes()),
    );
    await _storage.write(key: _saltKey, value: salt);
  }

  /// Sauvegarde maintenant. Lève [StateError] sans mot de passe choisi.
  Future<BackupInfo> backupNow() async {
    final keyB64 = await _storage.read(key: _keyKey);
    final salt = await _storage.read(key: _saltKey);
    if (keyB64 == null || salt == null) {
      throw StateError('Aucun mot de passe de sauvegarde');
    }
    final store = _ref.read(pokouMessageStoreProvider);
    final rows = await store.exportForBackup();
    final discussions = <String>{
      for (final r in rows.direct)
        _pair(r['sender_id'] as int, r['recipient_id'] as int),
      for (final r in rows.group) 'g${r['group_id']}',
    };
    final plain = utf8.encode(
      jsonEncode({
        'format': _format,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'direct': rows.direct,
        'group': rows.group,
      }),
    );
    final packed = gzip.encode(plain);
    final box = await _aes.encrypt(
      packed,
      secretKey: SecretKey(base64Decode(keyB64)),
    );
    final blob = box.concatenation();
    final uploaded = await _ref
        .read(mediaRepositoryProvider)
        .upload(
          bytes: blob,
          filename: 'pokou-backup.bin',
          mimeType: 'application/octet-stream',
          messageType: 'DOCUMENT',
          memoriser: false,
        );
    final json =
        await _ref
                .read(apiClientProvider)
                .put(
                  '/backup',
                  body: {
                    'media_id': uploaded.id,
                    'salt': salt,
                    'iterations': _iterations,
                    'discussions': discussions.length,
                    'messages': rows.direct.length + rows.group.length,
                    'size_bytes': blob.length,
                  },
                )
            as Map<String, dynamic>;
    await _storage.write(
      key: _lastKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
    return BackupInfo.fromJson(json)!;
  }

  /// Sauvegarde quotidienne, en silence, si un mot de passe a été choisi.
  Future<void> backupIfDue() async {
    if (!await hasPassword()) return;
    final last = await lastBackupAt();
    if (last != null && DateTime.now().difference(last).inHours < 24) return;
    try {
      await backupNow();
    } catch (_) {
      // Réseau : réessayé à la prochaine ouverture.
    }
  }

  /// Restaure la sauvegarde avec [password] (CNX-3). Les discussions
  /// reviennent par lots ; [onProgress] suit leur nombre.
  Future<void> restore(
    String password, {
    void Function(RestoreProgress progress)? onProgress,
  }) async {
    final backup = await info();
    if (backup == null) throw StateError('Aucune sauvegarde');
    final key = await _derive(password, backup.salt, backup.iterations);
    final blob = await _ref
        .read(apiClientProvider)
        .getBytes('/media/${backup.mediaId}');
    List<int> packed;
    try {
      packed = await _aes.decrypt(
        SecretBox.fromConcatenation(
          blob,
          nonceLength: _aes.nonceLength,
          macLength: _aes.macAlgorithm.macLength,
        ),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupWrongPasswordException();
    }
    final data =
        jsonDecode(utf8.decode(gzip.decode(packed))) as Map<String, dynamic>;
    if (data['format'] != _format) throw const FormatException('Sauvegarde');
    final direct = (data['direct'] as List).cast<Map<String, dynamic>>();
    final group = (data['group'] as List).cast<Map<String, dynamic>>();

    // Discussion par discussion, pour que l'avancement parle en
    // discussions (« 160 discussions sur 248 »).
    final byDiscussion =
        <
          String,
          ({List<Map<String, dynamic>> d, List<Map<String, dynamic>> g})
        >{};
    for (final r in direct) {
      final k = _pair(r['sender_id'] as int, r['recipient_id'] as int);
      (byDiscussion[k] ??= (d: [], g: [])).d.add(r);
    }
    for (final r in group) {
      (byDiscussion['g${r['group_id']}'] ??= (d: [], g: [])).g.add(r);
    }
    final store = _ref.read(pokouMessageStoreProvider);
    var done = 0;
    final total = byDiscussion.length;
    onProgress?.call(RestoreProgress(done: 0, total: total));
    for (final batch in byDiscussion.values) {
      await store.importFromBackup(direct: batch.d, group: batch.g);
      done++;
      onProgress?.call(RestoreProgress(done: done, total: total));
    }
    // Les sauvegardes suivantes reprennent le même mot de passe.
    await _storage.write(
      key: _keyKey,
      value: base64Encode(await key.extractBytes()),
    );
    await _storage.write(key: _saltKey, value: backup.salt);
  }

  Future<void> deleteBackup() async {
    await _ref.read(apiClientProvider).delete('/backup');
    await _storage.delete(key: _keyKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _lastKey);
  }

  static String _pair(int a, int b) => a < b ? 'd$a-$b' : 'd$b-$a';
}

final backupServiceProvider = Provider<BackupService>(BackupService.new);

/// La restauration en cours (CNX-3), affichée en tête des Discussions.
/// `null` : aucune restauration en cours.
final restoreProgressProvider = StateProvider<RestoreProgress?>((_) => null);
