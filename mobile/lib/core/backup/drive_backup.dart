import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Sauvegarde sur le compte Google de l'utilisateur (MSG-12), comme
/// WhatsApp : dans le dossier CACHÉ de l'application sur son Google Drive
/// (`appDataFolder`). Ce dossier n'apparaît pas dans Drive, ne se partage
/// pas, et seul Pokou y a accès — avec l'autorisation `drive.appdata`, qui
/// ne donne accès à AUCUN autre fichier du Drive.
///
/// Le bloc est déjà chiffré sur le téléphone (voir BackupService) : Google
/// ne voit qu'un fichier opaque. Les métadonnées utiles à la restauration
/// (sel, itérations, nombre de discussions) voyagent dans `appProperties`.
class DriveBackup {
  DriveBackup({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn(scopes: const [_scope]);

  static const _scope = 'https://www.googleapis.com/auth/drive.appdata';
  static const _fileName = 'pokou-backup.bin';
  final GoogleSignIn _signIn;

  /// Le compte Google déjà connecté sur ce téléphone, sans rien demander.
  Future<GoogleSignInAccount?> silentAccount() async {
    try {
      return await _signIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  /// Choisir le compte Google (fenêtre du système).
  Future<GoogleSignInAccount?> chooseAccount() => _signIn.signIn();

  Future<void> signOut() => _signIn.disconnect().catchError((_) => null);

  Future<Map<String, String>> _headers(GoogleSignInAccount account) =>
      account.authHeaders;

  Future<Map<String, dynamic>?> _find(GoogleSignInAccount account) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': "name = '$_fileName'",
      'fields': 'files(id,size,modifiedTime,appProperties)',
      'pageSize': '1',
    });
    final response = await http.get(uri, headers: await _headers(account));
    if (response.statusCode != 200) {
      throw DriveBackupException(response.statusCode, response.body);
    }
    final files = (jsonDecode(response.body)['files'] as List?) ?? const [];
    return files.isEmpty ? null : files.first as Map<String, dynamic>;
  }

  /// Ce que le Drive garde : `null` s'il n'y a pas de sauvegarde.
  Future<DriveBackupInfo?> info(GoogleSignInAccount account) async {
    final file = await _find(account);
    if (file == null) return null;
    final props =
        (file['appProperties'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DriveBackupInfo(
      fileId: file['id'] as String,
      email: account.email,
      salt: props['salt'] as String? ?? '',
      iterations: int.tryParse('${props['iterations']}') ?? 0,
      discussions: int.tryParse('${props['discussions']}') ?? 0,
      messages: int.tryParse('${props['messages']}') ?? 0,
      sizeBytes: int.tryParse('${file['size']}') ?? 0,
      createdAt:
          DateTime.tryParse(file['modifiedTime'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Dépose (ou remplace) le bloc chiffré.
  Future<void> upload(
    GoogleSignInAccount account,
    List<int> blob, {
    required Map<String, String> properties,
  }) async {
    final existing = await _find(account);
    final metadata = <String, dynamic>{
      'name': _fileName,
      'appProperties': properties,
      if (existing == null) 'parents': ['appDataFolder'],
    };
    const boundary = 'pokou-backup-boundary';
    final body = <int>[
      ...utf8.encode(
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '${jsonEncode(metadata)}\r\n'
        '--$boundary\r\n'
        'Content-Type: application/octet-stream\r\n\r\n',
      ),
      ...blob,
      ...utf8.encode('\r\n--$boundary--'),
    ];
    final uri = existing == null
        ? Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
          )
        : Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files/${existing['id']}?uploadType=multipart',
          );
    final request = http.Request(existing == null ? 'POST' : 'PATCH', uri)
      ..headers.addAll(await _headers(account))
      ..headers['Content-Type'] = 'multipart/related; boundary=$boundary'
      ..bodyBytes = body;
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      throw DriveBackupException(response.statusCode, response.body);
    }
  }

  Future<List<int>> download(GoogleSignInAccount account, String fileId) async {
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      headers: await _headers(account),
    );
    if (response.statusCode != 200) {
      throw DriveBackupException(response.statusCode, response.body);
    }
    return response.bodyBytes;
  }

  Future<void> delete(GoogleSignInAccount account) async {
    final file = await _find(account);
    if (file == null) return;
    await http.delete(
      Uri.parse('https://www.googleapis.com/drive/v3/files/${file['id']}'),
      headers: await _headers(account),
    );
  }
}

class DriveBackupInfo {
  const DriveBackupInfo({
    required this.fileId,
    required this.email,
    required this.salt,
    required this.iterations,
    required this.discussions,
    required this.messages,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String fileId;
  final String email;
  final String salt;
  final int iterations;
  final int discussions;
  final int messages;
  final int sizeBytes;
  final DateTime createdAt;
}

class DriveBackupException implements Exception {
  const DriveBackupException(this.status, this.body);

  final int status;
  final String body;

  @override
  String toString() => 'Google Drive $status';
}
