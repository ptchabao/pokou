import 'dart:io';

import 'package:path/path.dart';
// SQLCipher et non sqflite ordinaire : ce fichier garde ce que l'utilisateur
// confie à l'assistant (chiffre d'affaires, clients, impayés…). Il mérite
// la même protection au repos que les messages (voir PokouMessageStore).
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/storage/database_key.dart';
import '../../../core/storage/database_recovery.dart';
import 'chat_message_model.dart';

/// On-device chat history — the app's "memory of conversations". The
/// backend's ConversationContext only keeps a short (30min) LLM context
/// window; it isn't meant to be the durable source of truth for what's
/// shown in the thread, so the full history lives here instead.
///
/// Chiffrée avec la même clé d'appareil que la base des messages
/// ([DatabaseKey]) : une seule clé à garder, et l'effacer à la déconnexion
/// rend les deux historiques illisibles d'un coup.
class ChatLocalStore {
  ChatLocalStore({Database? database, DatabaseKey? key})
    : _injectedDb = database,
      _key = key ?? const DatabaseKey();

  final Database? _injectedDb;
  final DatabaseKey _key;
  Database? _db;

  /// Le fichier chiffré, et l'ancien en clair des versions précédentes. Deux
  /// noms distincts pour qu'ils coexistent le temps de la migration.
  static const encryptedFileName = 'pokou_chat_enc.db';
  static const legacyFileName = 'pokou_chat.db';

  Future<Database> get _database async {
    if (_injectedDb != null) return _injectedDb;
    if (_db != null) return _db!;
    final directory = await getDatabasesPath();
    final password = await _key.read();
    await _migrateLegacyDatabase(directory, password);
    final path = join(directory, encryptedFileName);
    try {
      _db = await _openDatabase(path, password);
    } on DatabaseException {
      // Clé perdue (déconnexion) ou fichier abîmé : on met l'ancien de côté
      // et on repart d'une base vide plutôt que de faire planter l'écran.
      await DatabaseRecovery.quarantine(path);
      await _migrateLegacyDatabase(directory, password);
      _db = await _openDatabase(path, password);
    }
    final legacy = File(join(directory, legacyFileName));
    if (await legacy.exists()) await legacy.delete();
    return _db!;
  }

  Future<Database> _openDatabase(String path, String password) => openDatabase(
    path,
    password: password,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          monitor_id INTEGER NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_messages_monitor ON messages(monitor_id)',
      );
    },
  );

  /// Reprend l'historique de l'ancienne base EN CLAIR, puis la supprime —
  /// même procédé que PokouMessageStore._migrateLegacyDatabase.
  ///
  /// L'ancien fichier n'est supprimé qu'après un export réussi : une coupure
  /// au milieu laisse l'original intact, et la migration recommence au
  /// lancement suivant. Un échec laisse l'ancien en place et la base
  /// chiffrée repart vide — dégradé, mais réversible.
  Future<void> _migrateLegacyDatabase(String directory, String password) async {
    final legacy = File(join(directory, legacyFileName));
    if (!legacy.existsSync()) return;
    if (File(join(directory, encryptedFileName)).existsSync()) return;
    Database? plain;
    try {
      plain = await openDatabase(legacy.path);
      await plain.rawQuery('ATTACH DATABASE ? AS chiffre KEY ?', [
        join(directory, encryptedFileName),
        password,
      ]);
      await plain.rawQuery("SELECT sqlcipher_export('chiffre')");
      // La version du schéma ne fait pas partie de l'export : sans elle,
      // `onCreate` tenterait de recréer une table déjà présente.
      await plain.rawQuery('PRAGMA chiffre.user_version = 1');
      await plain.rawQuery('DETACH DATABASE chiffre');
      await plain.close();
      plain = null;
      await legacy.delete();
    } catch (_) {
      await plain?.close();
    }
  }

  Future<ChatMessage> insert(ChatMessage message) async {
    final db = await _database;
    final id = await db.insert('messages', message.toMap()..remove('id'));
    return ChatMessage(
      id: id,
      monitorId: message.monitorId,
      role: message.role,
      content: message.content,
      createdAt: message.createdAt,
    );
  }

  Future<List<ChatMessage>> forMonitor(int monitorId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'monitor_id = ?',
      whereArgs: [monitorId],
      orderBy: 'id ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> deleteForMonitor(int monitorId) async {
    final db = await _database;
    await db.delete(
      'messages',
      where: 'monitor_id = ?',
      whereArgs: [monitorId],
    );
  }

  /// Réécrit l'historique d'un fil d'un coup. Sert à recopier localement une
  /// conversation dont le SERVEUR est la source de vérité (la conversation
  /// Minou, partagée avec WhatsApp) : on ne peut pas la fusionner ligne à
  /// ligne, ce cache ne gardant pas les identifiants serveur — chaque
  /// ouverture dupliquerait tout.
  ///
  /// Dans une transaction : sans elle, une interruption entre la suppression
  /// et les insertions laisserait le fil vide sur l'appareil.
  Future<void> replaceForMonitor(
    int monitorId,
    List<ChatMessage> messages,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        'messages',
        where: 'monitor_id = ?',
        whereArgs: [monitorId],
      );
      for (final message in messages) {
        await txn.insert('messages', message.toMap()..remove('id'));
      }
    });
  }
}
