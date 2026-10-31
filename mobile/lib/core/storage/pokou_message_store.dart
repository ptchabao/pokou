import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'dart:io';

import 'package:path/path.dart';
// SQLCipher et non sqflite ordinaire : ce fichier contient les messages
// DÉCHIFFRÉS, y compris ceux des conversations chiffrées de bout en bout.
// L'API est la même, à la clé près (voir DatabaseKey).
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_key.dart';
import 'database_recovery.dart';

import '../../features/groups/data/group_model.dart';
import '../../features/messaging/data/direct_message_model.dart';

/// Messages Pokou sur l'appareil — ce qui rend l'app lisible hors ligne et
/// permet de composer sans réseau, façon WhatsApp.
///
/// Ce cache est la SOURCE DE VÉRITÉ de ce qu'affiche une conversation : le
/// réseau ne fait que l'alimenter (historique au chargement, événements
/// WebSocket) et le vider de ses messages en attente. Les écrans lisent
/// toujours ici, jamais directement la réponse HTTP — un seul chemin de
/// lecture, donc un seul ordre de tri et pas de logique de fusion dupliquée
/// entre « en ligne » et « hors ligne ».
///
/// Base séparée de celle de l'assistant (ChatLocalStore) : deux
/// domaines différents, deux durées de vie différentes.
///
/// Chaque ligne garde la charge utile de l'API en JSON dans une colonne, plus
/// les quelques champs nécessaires aux requêtes (interlocuteur, date, état
/// d'envoi). C'est volontairement plus souple qu'une colonne par champ : un
/// champ ajouté côté API n'impose pas de migration de schéma local.
class PokouMessageStore {
  PokouMessageStore({Database? database, DatabaseKey? key})
    : _injectedDb = database,
      _key = key ?? const DatabaseKey();

  final Database? _injectedDb;
  final DatabaseKey _key;
  Database? _db;

  final _updates = StreamController<OutboxUpdate>.broadcast();
  final _syncUpdates = StreamController<SyncInboxEvent>.broadcast();

  /// Résultats des renvois de la file d'attente, pour que les écrans ouverts
  /// remplacent leur message « en attente » par la version confirmée sans
  /// recharger toute la conversation.
  Stream<OutboxUpdate> get updates => _updates.stream;

  Stream<SyncInboxEvent> get syncUpdates => _syncUpdates.stream;

  static const _pendingTrue = 1;
  static const _pendingFalse = 0;

  /// Le nom du fichier chiffré. Différent de l'ancien (`pokou_messages.db`)
  /// et c'est voulu : les deux doivent pouvoir coexister le temps de la
  /// migration, et un nom distinct rend impossible d'ouvrir l'un en croyant
  /// ouvrir l'autre.
  static const encryptedFileName = 'pokou_messages_enc.db';
  static const legacyFileName = 'pokou_messages.db';

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
      // A key mismatch or an incompatible/corrupt SQLCipher file must not
      // make every cache read crash. Preserve it before rebuilding; if a
      // plaintext legacy database exists, the migration gets another chance.
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
    version: 4,
    onCreate: (db, version) => createSchema(db),
    // Existing databases are migrated rather than silently recreated.
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await _createConversationsTable(db);
      if (oldVersion < 3) await _createPendingActionsTable(db);
      if (oldVersion < 4) await _createSyncTables(db);
    },
  );

  /// Reprend le contenu de la base EN CLAIR laissée par les versions
  /// précédentes, puis la supprime.
  ///
  /// Sans cette étape, la mise à jour ferait perdre deux choses que le
  /// serveur ne peut PAS renvoyer :
  ///
  /// - les messages composés hors ligne et pas encore partis ;
  /// - le texte déchiffré des messages chiffrés déjà reçus. Le cliquet a
  ///   avancé, personne ne peut les rouvrir — ils seraient définitivement
  ///   illisibles.
  ///
  /// `sqlcipher_export` plutôt qu'une recopie ligne à ligne : c'est la
  /// fonction prévue pour ça, elle copie le schéma et les données d'un coup,
  /// et une recopie manuelle devrait être tenue à jour à chaque changement
  /// de schéma — donc oubliée un jour.
  ///
  /// L'ancien fichier n'est supprimé qu'APRÈS un export réussi. Une coupure
  /// de courant au milieu laisse donc l'original intact et la migration
  /// recommence au prochain lancement.
  Future<void> _migrateLegacyDatabase(String directory, String password) async {
    final legacy = File(join(directory, legacyFileName));
    if (!legacy.existsSync()) return;
    // The encrypted target is removed only after it opens successfully. Do
    // not discard the only plaintext copy just because a target file exists.
    if (File(join(directory, encryptedFileName)).existsSync()) {
      return;
    }

    Database? plain;
    try {
      plain = await openDatabase(legacy.path);
      final target = join(directory, encryptedFileName);
      await plain.rawQuery("ATTACH DATABASE ? AS chiffre KEY ?", [
        target,
        password,
      ]);
      await plain.rawQuery("SELECT sqlcipher_export('chiffre')");
      // La version du schéma ne fait pas partie de l'export : sans cette
      // ligne, la base chiffrée se déclarerait en version 0 et `onCreate`
      // tenterait de recréer des tables déjà présentes.
      await plain.rawQuery('PRAGMA chiffre.user_version = 2');
      await plain.rawQuery('DETACH DATABASE chiffre');
      await plain.close();
      plain = null;
      await legacy.delete();
    } catch (_) {
      // Migration impossible : on laisse l'ancien fichier EN PLACE plutôt
      // que de détruire un historique qu'on ne sait pas récupérer. La base
      // chiffrée repart alors vide et se remplit depuis le serveur ; c'est
      // dégradé, mais réversible.
      await plain?.close();
    }
  }

  /// Schéma exposé pour que les tests ouvrent une base en mémoire avec
  /// EXACTEMENT celui de la production — le redéclarer dans les tests le
  /// laisserait dériver du vrai sans que rien ne le signale.
  static Future<void> createSchema(Database db) async {
    await db.execute('''
          CREATE TABLE direct_messages (
            id TEXT PRIMARY KEY,
            sender_id INTEGER NOT NULL,
            recipient_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            pending INTEGER NOT NULL DEFAULT 0,
            failed INTEGER NOT NULL DEFAULT 0,
            payload TEXT NOT NULL
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_direct_participants ON direct_messages(sender_id, recipient_id)',
    );
    await db.execute(
      'CREATE INDEX idx_direct_pending ON direct_messages(pending)',
    );
    await db.execute('''
          CREATE TABLE group_messages (
            id TEXT PRIMARY KEY,
            group_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            pending INTEGER NOT NULL DEFAULT 0,
            failed INTEGER NOT NULL DEFAULT 0,
            payload TEXT NOT NULL
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_group_messages_group ON group_messages(group_id)',
    );
    await db.execute(
      'CREATE INDEX idx_group_messages_pending ON group_messages(pending)',
    );
    await _createConversationsTable(db);
    await _createPendingActionsTable(db);
    await _createSyncTables(db);
  }

  /// La liste d'accueil, telle que le serveur l'a renvoyée la dernière fois.
  ///
  /// Le JSON BRUT, et non des colonnes : cette liste est composée et triée
  /// par le serveur (épinglées d'abord, puis activité, aperçus, compteurs de
  /// non-lus), et la redécouper en colonnes ici reviendrait à recopier cette
  /// logique — pour ensuite la voir diverger. Ce qu'on veut en cache, c'est
  /// exactement ce qui a été affiché.
  static Future<void> _createConversationsTable(Database db) async {
    // `IF NOT EXISTS` et non `CREATE TABLE` : cette instruction tourne à la
    // fois dans onCreate et dans onUpgrade. Si la table est déjà là, un
    // CREATE nu lève — et c'est l'OUVERTURE de la base qui échoue, donc tout
    // le cache local : conversations illisibles, écrans vides, alors que
    // seule cette table posait problème.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conversations_cache (
        scope TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        saved_at TEXT NOT NULL
      )
    ''');
  }

  /// Les gestes posés sans réseau, qui ne sont pas des messages.
  ///
  /// ── Pourquoi une table, et pas une file en mémoire ──────────────────
  ///
  /// Réagir à un message, en supprimer un : ces gestes échouaient
  /// silencieusement hors ligne. On voyait l'emoji apparaître, puis
  /// disparaître au rechargement — sans explication, et sans moyen de
  /// savoir lequel des deux états était le vrai.
  ///
  /// ── La clé d'idempotence, qui porte tout ────────────────────────────
  ///
  /// La colonne s'appelle `idempotency_ref` et non `..._key`, pour une
  /// raison qui n'est pas cosmétique : un test de sécurité refuse toute
  /// colonne dont le nom contient « key », « secret » ou « token » — les
  /// clés de chiffrement vont au Keystore, jamais dans SQLite. Le garde-fou
  /// est une heuristique sur les noms ; l'affaiblir pour accommoder une
  /// colonne inoffensive aurait coûté plus qu'un mot.
  ///
  /// `idempotency_ref` vaut `{famille}:{cible}` — par exemple
  /// `reaction:abc-123`. Elle est UNIQUE, et une nouvelle action REMPLACE
  /// celle qui attendait sur la même clé.
  ///
  /// C'est ce qui interdit l'état contradictoire. Réagir 👍, retirer, puis
  /// réagir ❤️ hors ligne laisserait sinon trois actions en file, rejouées
  /// dans un ordre qu'on ne contrôle pas, pour un résultat qui n'est aucun
  /// des trois. Ici il n'en reste qu'une : la dernière, celle que la
  /// personne voit à l'écran.
  ///
  /// Même raisonnement que la marque `thread_message_id` des appels
  /// (api/app/services/call_thread_service.py) : ce n'est pas le rejeu
  /// qu'on empêche, c'est le DOUBLON.
  static Future<void> _createPendingActionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_actions (
        id TEXT PRIMARY KEY,
        idempotency_ref TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL,
        target_id TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pending_actions_created '
      'ON pending_actions(created_at)',
    );
  }

  static Future<void> _createSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        scope TEXT PRIMARY KEY,
        cursor TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_inbox (
        event_id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        received_at TEXT NOT NULL,
        processed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_inbox_pending '
      'ON sync_inbox(processed, received_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        operation_id TEXT PRIMARY KEY,
        idempotency_ref TEXT NOT NULL UNIQUE,
        operation_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_created '
      'ON sync_outbox(created_at)',
    );
  }

  /// The last server cursor committed together with its corresponding inbox
  /// events. Cursors are opaque: only the server may interpret their order.
  Future<String?> syncCursor(String scope) async {
    final db = await _database;
    final rows = await db.query(
      'sync_state',
      columns: ['cursor'],
      where: 'scope = ?',
      whereArgs: [scope],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['cursor'] as String?;
  }

  /// Persists changes and advances the cursor atomically. Duplicate event IDs
  /// are ignored, so reconnecting or receiving an event over both transports
  /// cannot apply it twice.
  Future<void> saveSyncBatch({
    required String scope,
    required Iterable<SyncInboxEvent> events,
    required String? cursor,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      for (final event in events) {
        await txn.insert('sync_inbox', {
          'event_id': event.id,
          'event_type': event.type,
          'payload': jsonEncode(event.payload),
          'received_at': now,
          'processed': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.rawInsert(
        'INSERT INTO sync_state (scope, cursor, updated_at) VALUES (?, ?, ?) '
        'ON CONFLICT(scope) DO UPDATE SET '
        'cursor = COALESCE(excluded.cursor, sync_state.cursor), '
        'updated_at = excluded.updated_at',
        [scope, cursor, now],
      );
    });
  }

  /// [types] restreint aux types donnés ; [excludeTypes] écarte ceux-là —
  /// c'est ce qui permet au moteur de solder les événements qu'il ne sait
  /// pas projeter sans toucher à ceux qu'il est en train d'appliquer.
  Future<List<SyncInboxEvent>> pendingSyncEvents({
    int limit = 100,
    List<String>? types,
    List<String>? excludeTypes,
  }) async {
    final db = await _database;
    String placeholders(List<String> values) =>
        List.filled(values.length, '?').join(',');
    final conditions = [
      'processed = 0',
      if (types != null && types.isNotEmpty)
        'event_type IN (${placeholders(types)})',
      if (excludeTypes != null && excludeTypes.isNotEmpty)
        'event_type NOT IN (${placeholders(excludeTypes)})',
    ];
    final rows = await db.query(
      'sync_inbox',
      where: conditions.join(' AND '),
      whereArgs: [...?types, ...?excludeTypes],
      orderBy: 'received_at ASC',
      limit: limit,
    );
    return [
      for (final row in rows)
        SyncInboxEvent(
          id: row['event_id'] as String,
          type: row['event_type'] as String,
          payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        ),
    ];
  }

  Future<void> markSyncEventProcessed(String eventId) async {
    final db = await _database;
    await db.update(
      'sync_inbox',
      {'processed': 1},
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  Future<bool> hasDirectMessage(String id) async {
    final db = await _database;
    final rows = await db.query(
      'direct_messages',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Applies supported inbox events and marks them processed in the same
  /// transaction as their local projection. Reapplying an event is harmless.
  Future<bool> applySyncEvent({
    required SyncInboxEvent event,
    DirectMessage? directMessage,
    GroupMessage? groupMessage,
  }) async {
    final db = await _database;
    final applied = await db.transaction<bool>((txn) async {
      final existing = await txn.query(
        'sync_inbox',
        columns: ['processed'],
        where: 'event_id = ?',
        whereArgs: [event.id],
        limit: 1,
      );
      if (existing.isEmpty || existing.single['processed'] == 1) return false;

      switch (event.type) {
        case 'message:new':
          if (directMessage == null) return false;
          final kept = await _keepOpened(txn, directMessage);
          await txn.insert('direct_messages', {
            'id': kept.id,
            'sender_id': kept.senderId,
            'recipient_id': kept.recipientId,
            'created_at': kept.createdAt.toIso8601String(),
            'pending': _pendingFalse,
            'failed': _pendingFalse,
            'payload': jsonEncode(kept.toJson()),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        case 'message:status':
          if (directMessage == null) return false;
          final rows = await txn.query(
            'direct_messages',
            where: 'id = ?',
            whereArgs: [directMessage.id],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            final payload = _payloadOf(rows.single);
            payload['status'] = directMessage.toJson()['status'];
            await txn.update(
              'direct_messages',
              {'payload': jsonEncode(payload)},
              where: 'id = ?',
              whereArgs: [directMessage.id],
            );
          }
        case 'message:deleted':
          final messageId = event.payload['message_id']?.toString();
          if (messageId == null) return false;
          await txn.delete(
            'direct_messages',
            where: 'id = ?',
            whereArgs: [messageId],
          );
        case 'group:message:new':
          if (groupMessage == null) return false;
          await txn.insert('group_messages', {
            'id': groupMessage.id,
            'group_id': groupMessage.groupId,
            'created_at': groupMessage.createdAt.toIso8601String(),
            'pending': _pendingFalse,
            'failed': _pendingFalse,
            'payload': jsonEncode(groupMessage.toJson()),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        default:
          return false;
      }

      await txn.update(
        'sync_inbox',
        {'processed': 1},
        where: 'event_id = ?',
        whereArgs: [event.id],
      );
      return true;
    });
    if (applied) _syncUpdates.add(event);
    return applied;
  }

  /// Adds a domain operation once. The idempotency reference is supplied by
  /// the caller and remains stable across retries and app restarts.
  ///
  /// [supersede] : une opération de la même référence REMPLACE celle qui
  /// attendait, au lieu d'être ignorée. C'est le cas des réglages — suivre
  /// puis ne plus suivre une chaîne hors ligne ne doit laisser en file que
  /// la dernière intention, celle que l'écran montre.
  Future<void> enqueueSyncOperation({
    required String operationId,
    required String idempotencyRef,
    required String type,
    required Map<String, dynamic> payload,
    bool supersede = false,
  }) async {
    final db = await _database;
    await db.insert(
      'sync_outbox',
      {
        'operation_id': operationId,
        'idempotency_ref': idempotencyRef,
        'operation_type': type,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'attempts': 0,
      },
      conflictAlgorithm: supersede
          ? ConflictAlgorithm.replace
          : ConflictAlgorithm.ignore,
    );
  }

  /// Oublie l'opération en attente sur cette référence.
  ///
  /// Appelé quand le même geste vient de PASSER en direct : sans ça, une
  /// intention plus ancienne restée en file repartirait à la reconnexion et
  /// défairait ce qu'on vient de faire.
  Future<void> dropSyncOperation(String idempotencyRef) async {
    final db = await _database;
    await db.delete(
      'sync_outbox',
      where: 'idempotency_ref = ?',
      whereArgs: [idempotencyRef],
    );
  }

  Future<List<SyncOutboxOperation>> pendingSyncOperations({
    int limit = 100,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'sync_outbox',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return [
      for (final row in rows)
        SyncOutboxOperation(
          id: row['operation_id'] as String,
          idempotencyRef: row['idempotency_ref'] as String,
          type: row['operation_type'] as String,
          payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          attempts: row['attempts'] as int,
        ),
    ];
  }

  Future<void> recordSyncOperationAttempt(String operationId) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE sync_outbox SET attempts = attempts + 1 WHERE operation_id = ?',
      [operationId],
    );
  }

  Future<void> completeSyncOperation(String operationId) async {
    final db = await _database;
    await db.delete(
      'sync_outbox',
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  /// Identifiant provisoire d'un message composé sur l'appareil, avant que le
  /// serveur ne lui donne le sien. Préfixé pour rester reconnaissable dans
  /// les journaux et impossible à confondre avec un UUID serveur.
  String newLocalId() =>
      'local-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

  static bool isLocalId(String id) => id.startsWith('local-');

  // ─── Messages directs ──────────────────────────────────────────────────────

  /// Écrit (ou réécrit) des messages confirmés par le serveur. `INSERT OR
  /// REPLACE` : un message dont le statut passe à DELIVERED/READ écrase
  /// simplement sa version précédente.
  Future<void> saveDirect(
    Iterable<DirectMessage> messages, {
    bool pending = false,
    bool failed = false,
  }) async {
    final db = await _database;
    final batch = db.batch();
    for (final incoming in messages) {
      final message = await _keepOpened(db, incoming);
      batch.insert('direct_messages', {
        'id': message.id,
        'sender_id': message.senderId,
        'recipient_id': message.recipientId,
        'created_at': message.createdAt.toIso8601String(),
        'pending': pending ? _pendingTrue : _pendingFalse,
        'failed': failed ? _pendingTrue : _pendingFalse,
        'payload': jsonEncode(message.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// [incoming], sans perdre ce que cet appareil a déjà DÉCHIFFRÉ.
  ///
  /// Le serveur ne renvoie jamais que le chiffré. Une réaction, un accusé de
  /// réception, un rechargement d'historique ou un événement rejoué
  /// écrasaient donc la ligne ouverte par sa version chiffrée — et comme une
  /// enveloppe ne s'ouvre qu'une fois, le texte, la légende ou la clé d'une
  /// photo étaient perdus pour de bon. Les champs du serveur (statut,
  /// réactions, vue) sont pris de [incoming] ; le clair, de la ligne
  /// existante. Une modification (`edited_at` différent) apporte un NOUVEAU
  /// chiffré : celle-là n'est pas recouverte.
  Future<DirectMessage> _keepOpened(
    DatabaseExecutor db,
    DirectMessage incoming,
  ) async {
    if (!incoming.isEncrypted) return incoming;
    final rows = await db.query(
      'direct_messages',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [incoming.id],
      limit: 1,
    );
    if (rows.isEmpty) return incoming;
    final existing = DirectMessage.fromJson(
      _payloadOf(rows.single),
      fromCache: true,
    );
    final opened = !existing.isEncrypted &&
        (existing.mediaKey != null ||
            (existing.content?.trim().isNotEmpty ?? false));
    if (!opened || existing.editedAt != incoming.editedAt) return incoming;
    return incoming.resolvedWith(existing);
  }

  /// Toute la conversation connue localement, la plus ancienne d'abord —
  /// messages confirmés, en attente d'envoi et en échec confondus, puisque
  /// c'est exactement ce que l'écran doit montrer.
  Future<CachedConversation> directConversation({
    required int myUserId,
    required int contactUserId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'direct_messages',
      where:
          '(sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)',
      whereArgs: [myUserId, contactUserId, contactUserId, myUserId],
      orderBy: 'created_at ASC',
    );
    return CachedConversation(
      messages: [
        for (final row in rows) DirectMessage.fromJson(_payloadOf(row), fromCache: true),
      ],
      pendingIds: {
        for (final row in rows)
          if (row['pending'] == 1) row['id'] as String,
      },
      failedIds: {
        for (final row in rows)
          if (row['failed'] == 1) row['id'] as String,
      },
    );
  }

  /// Le serveur a accepté un message composé localement : la ligne
  /// provisoire disparaît au profit de la version confirmée, dans la même
  /// transaction — sinon un plantage entre les deux laisserait le message en
  /// double à la réouverture.
  Future<void> confirmDirect(String localId, DirectMessage confirmed) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        'direct_messages',
        where: 'id = ?',
        whereArgs: [localId],
      );
      await txn.insert('direct_messages', {
        'id': confirmed.id,
        'sender_id': confirmed.senderId,
        'recipient_id': confirmed.recipientId,
        'created_at': confirmed.createdAt.toIso8601String(),
        'pending': _pendingFalse,
        'failed': _pendingFalse,
        'payload': jsonEncode(confirmed.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    _updates.add(OutboxUpdate(localId: localId, direct: confirmed));
  }

  /// Rejet définitif par le serveur (numéro plus dans les contacts, message
  /// invalide…). On sort la ligne de la file d'attente : la retenter en
  /// boucle ne la ferait jamais passer.
  Future<void> markDirectFailed(String localId) async {
    final db = await _database;
    await db.update(
      'direct_messages',
      {'pending': _pendingFalse, 'failed': _pendingTrue},
      where: 'id = ?',
      whereArgs: [localId],
    );
    _updates.add(OutboxUpdate(localId: localId, failed: true));
  }

  /// La ligne locale [localId] a-t-elle été définitivement refusée ?
  Future<bool> isDirectFailed(String localId) async {
    final db = await _database;
    final rows = await db.query(
      'direct_messages',
      columns: ['failed'],
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['failed'] == _pendingTrue;
  }

  Future<void> deleteDirect(String id) async {
    final db = await _database;
    await db.delete('direct_messages', where: 'id = ?', whereArgs: [id]);
  }

  /// Texte déchiffré de messages précis, par identifiant.
  ///
  /// Sert à l'aperçu de la liste d'accueil : le serveur ne peut pas envoyer
  /// le contenu d'un message chiffré, mais l'appareil l'a déjà déchiffré une
  /// fois et le garde en clair ici. Sans ce rattrapage, chaque conversation
  /// chiffrée afficherait une ligne blanche.
  Future<Map<String, String>> plaintextFor(Iterable<String> messageIds) async {
    final ids = messageIds.toList();
    if (ids.isEmpty) return {};

    final db = await _database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'direct_messages',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    final found = <String, String>{};
    for (final row in rows) {
      final message = DirectMessage.fromJson(_payloadOf(row), fromCache: true);
      // Une ligne qui porte ENCORE son chiffré n'a jamais été ouverte : son
      // `content` est le texte d'échec, pas un clair. La retenir ici
      // rendrait cet échec définitif, y compris s'il n'était dû qu'à un
      // aléa — voir MessagingRepository._openOnce.
      if (message.isEncrypted) continue;
      final content = message.content;
      if (content != null && content.trim().isNotEmpty) {
        found[message.id] = content;
      }
    }
    return found;
  }

  /// Les messages chiffrés déjà OUVERTS sur cet appareil, par identifiant.
  ///
  /// [plaintextFor] ne rend que du texte, et ne retient une ligne que si ce
  /// texte n'est pas vide. Une photo chiffrée sans légende n'a pas de
  /// texte : elle n'y compterait jamais comme ouverte, serait redéchiffrée à
  /// chaque chargement, et ce second déchiffrement échoue — sa clé a été
  /// consommée par le cliquet. Ici, une ligne compte comme ouverte dès
  /// qu'elle porte un texte OU une clé de pièce jointe.
  Future<Map<String, DirectMessage>> decryptedFor(
    Iterable<String> messageIds,
  ) async {
    final ids = messageIds.toList();
    if (ids.isEmpty) return {};

    final db = await _database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'direct_messages',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    final found = <String, DirectMessage>{};
    for (final row in rows) {
      final message = DirectMessage.fromJson(_payloadOf(row), fromCache: true);
      // Même règle que plaintextFor : une ligne qui porte encore son
      // chiffré n'a jamais été ouverte.
      if (message.isEncrypted) continue;
      final content = message.content;
      if (message.mediaKey != null ||
          (content != null && content.trim().isNotEmpty)) {
        found[message.id] = message;
      }
    }
    return found;
  }

  /// Messages directs restés à envoyer, les plus anciens d'abord — l'ordre
  /// de composition est l'ordre d'envoi.
  Future<List<DirectMessage>> pendingDirect() async {
    final db = await _database;
    final rows = await db.query(
      'direct_messages',
      where: 'pending = ?',
      whereArgs: [_pendingTrue],
      orderBy: 'created_at ASC',
    );
    return [for (final row in rows) DirectMessage.fromJson(_payloadOf(row), fromCache: true)];
  }

  /// Aligne le cache sur l'historique renvoyé par le serveur : un message
  /// supprimé pendant qu'on était hors ligne doit disparaître, sinon il
  /// resterait affiché indéfiniment (l'événement WS `message:deleted` a été
  /// manqué). Bornée à la fenêtre couverte par la réponse, et ne touche
  /// jamais aux lignes en attente/en échec, qui n'existent que localement.
  Future<void> reconcileDirect({
    required int myUserId,
    required int contactUserId,
    required List<DirectMessage> serverMessages,
  }) async {
    if (serverMessages.isEmpty) return;
    final db = await _database;
    final oldest = serverMessages
        .map((message) => message.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b)
        .toIso8601String();
    final keptIds = serverMessages.map((message) => message.id).toList();
    final placeholders = List.filled(keptIds.length, '?').join(',');
    await db.delete(
      'direct_messages',
      where:
          '((sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)) '
          'AND created_at >= ? AND pending = 0 AND failed = 0 AND id NOT IN ($placeholders)',
      whereArgs: [
        myUserId,
        contactUserId,
        contactUserId,
        myUserId,
        oldest,
        ...keptIds,
      ],
    );
  }

  // ─── Messages de groupe ────────────────────────────────────────────────────

  Future<void> saveGroup(
    Iterable<GroupMessage> messages, {
    bool pending = false,
    bool failed = false,
  }) async {
    final db = await _database;
    final batch = db.batch();
    for (final message in messages) {
      batch.insert('group_messages', {
        'id': message.id,
        'group_id': message.groupId,
        'created_at': message.createdAt.toIso8601String(),
        'pending': pending ? _pendingTrue : _pendingFalse,
        'failed': failed ? _pendingTrue : _pendingFalse,
        'payload': jsonEncode(message.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<CachedGroupConversation> groupConversation(int groupId) async {
    final db = await _database;
    final rows = await db.query(
      'group_messages',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at ASC',
    );
    return CachedGroupConversation(
      messages: [
        for (final row in rows) GroupMessage.fromJson(_payloadOf(row)),
      ],
      pendingIds: {
        for (final row in rows)
          if (row['pending'] == 1) row['id'] as String,
      },
      failedIds: {
        for (final row in rows)
          if (row['failed'] == 1) row['id'] as String,
      },
    );
  }

  Future<void> confirmGroup(String localId, GroupMessage confirmed) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('group_messages', where: 'id = ?', whereArgs: [localId]);
      await txn.insert('group_messages', {
        'id': confirmed.id,
        'group_id': confirmed.groupId,
        'created_at': confirmed.createdAt.toIso8601String(),
        'pending': _pendingFalse,
        'failed': _pendingFalse,
        'payload': jsonEncode(confirmed.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    _updates.add(OutboxUpdate(localId: localId, group: confirmed));
  }

  Future<void> markGroupFailed(String localId) async {
    final db = await _database;
    await db.update(
      'group_messages',
      {'pending': _pendingFalse, 'failed': _pendingTrue},
      where: 'id = ?',
      whereArgs: [localId],
    );
    _updates.add(OutboxUpdate(localId: localId, failed: true));
  }

  Future<List<GroupMessage>> pendingGroup() async {
    final db = await _database;
    final rows = await db.query(
      'group_messages',
      where: 'pending = ?',
      whereArgs: [_pendingTrue],
      orderBy: 'created_at ASC',
    );
    return [for (final row in rows) GroupMessage.fromJson(_payloadOf(row))];
  }

  Future<void> reconcileGroup({
    required int groupId,
    required List<GroupMessage> serverMessages,
  }) async {
    if (serverMessages.isEmpty) return;
    final db = await _database;
    final oldest = serverMessages
        .map((message) => message.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b)
        .toIso8601String();
    final keptIds = serverMessages.map((message) => message.id).toList();
    final placeholders = List.filled(keptIds.length, '?').join(',');
    await db.delete(
      'group_messages',
      where:
          'group_id = ? AND created_at >= ? AND pending = 0 AND failed = 0 '
          'AND id NOT IN ($placeholders)',
      whereArgs: [groupId, oldest, ...keptIds],
    );
  }

  /// Déconnexion — le cache contient des conversations, il ne doit pas
  /// survivre au compte qui les a reçues sur un appareil partagé.
  // ─── La liste d'accueil, hors ligne ────────────────────────────────────

  /// Garde la dernière liste connue.
  ///
  /// Sans elle, ouvrir l'application sans réseau donnait un écran d'accueil
  /// VIDE — alors que toutes les conversations sont sur l'appareil. C'est ce
  /// qui donnait l'impression que le mode hors ligne ne marchait plus nulle
  /// part : c'est le premier écran, et il ne montrait rien.
  Future<void> saveConversations(String scope, List<dynamic> items) async {
    final db = await _database;
    await db.insert('conversations_cache', {
      'scope': scope,
      'payload': jsonEncode(items),
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// La dernière liste connue, ou `null` si on n'en a jamais reçu.
  ///
  /// `null` et non une liste vide : « je ne sais pas » et « vous n'avez
  /// aucune conversation » demandent deux écrans différents.
  Future<List<dynamic>?> cachedConversations(String scope) async {
    final db = await _database;
    final rows = await db.query(
      'conversations_cache',
      where: 'scope = ?',
      whereArgs: [scope],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['payload'] as String) as List<dynamic>;
    } catch (_) {
      // Cache illisible (format changé) : on l'ignore plutôt que de planter
      // au démarrage.
      return null;
    }
  }

  /// Retouche une liste gardée, sans attendre le serveur.
  ///
  /// Pour un réglage qui attend le réseau (voir core/sync/queued_mutation.dart) :
  /// relire la liste hors ligne ressert le cache TEL QUEL, et le geste
  /// semblait n'avoir rien fait. La prochaine réponse du serveur écrase de
  /// toute façon cette retouche — c'est lui qui a le dernier mot.
  Future<void> updateCachedConversations(
    String scope,
    List<dynamic> Function(List<dynamic> items) transform,
  ) async {
    final items = await cachedConversations(scope);
    if (items == null) return;
    await saveConversations(scope, transform(items));
  }

  /// Déconnexion : ne laisse rien de lisible derrière.
  ///
  /// Supprimer des LIGNES ne suffit pas. SQLite libère les pages sans les
  /// écraser, et leur contenu reste récupérable dans le fichier — ce qui,
  /// sur un téléphone partagé, laisse l'historique de quelqu'un à
  /// disposition du suivant. C'est exactement le scénario que le chiffrement
  /// est censé couvrir.
  ///
  /// On détruit donc la CLÉ, ce qui rend le fichier entier définitivement
  /// inexploitable, puis le fichier lui-même. Les lignes sont quand même
  /// effacées d'abord : une base injectée (tests) n'a ni clé ni fichier, et
  /// doit se vider comme avant.
  Future<void> clear() async {
    final db = await _database;
    await db.delete('direct_messages');
    await db.delete('group_messages');
    await db.delete('conversations_cache');
    // Les gestes en attente aussi : ils portent des identifiants de
    // messages du compte qu'on quitte, et les laisser les ferait rejouer
    // sous le compte suivant — vers des messages qui ne lui appartiennent
    // pas.
    await db.delete('pending_actions');
    await db.delete('sync_state');
    await db.delete('sync_inbox');
    await db.delete('sync_outbox');

    if (_injectedDb != null) return;

    await db.close();
    _db = null;
    await _key.destroy();
    final file = File(join(await getDatabasesPath(), encryptedFileName));
    if (file.existsSync()) await file.delete();
  }

  Map<String, dynamic> _payloadOf(Map<String, Object?> row) =>
      jsonDecode(row['payload'] as String) as Map<String, dynamic>;

  void dispose() {
    _updates.close();
    _syncUpdates.close();
  }
}

/// Ce qu'une conversation directe contient localement. Les identifiants en
/// attente/en échec sont sortis à part plutôt qu'ajoutés au modèle
/// `DirectMessage` : celui-ci décrit ce que le SERVEUR connaît, et n'a pas à
/// porter un état propre à cet appareil.
class CachedConversation {
  const CachedConversation({
    required this.messages,
    required this.pendingIds,
    required this.failedIds,
  });

  final List<DirectMessage> messages;
  final Set<String> pendingIds;
  final Set<String> failedIds;

  bool get isEmpty => messages.isEmpty;
}

class CachedGroupConversation {
  const CachedGroupConversation({
    required this.messages,
    required this.pendingIds,
    required this.failedIds,
  });

  final List<GroupMessage> messages;
  final Set<String> pendingIds;
  final Set<String> failedIds;

  bool get isEmpty => messages.isEmpty;
}

/// Sort de la file d'attente : soit le serveur a accepté le message (`direct`
/// ou `group` renseigné, avec son identifiant définitif), soit il l'a rejeté
/// pour de bon (`failed`).
class OutboxUpdate {
  const OutboxUpdate({
    required this.localId,
    this.direct,
    this.group,
    this.failed = false,
  });

  final String localId;
  final DirectMessage? direct;
  final GroupMessage? group;
  final bool failed;
}

class SyncInboxEvent {
  const SyncInboxEvent({
    required this.id,
    required this.type,
    required this.payload,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
}

class SyncOutboxOperation {
  const SyncOutboxOperation({
    required this.id,
    required this.idempotencyRef,
    required this.type,
    required this.payload,
    required this.attempts,
  });

  final String id;
  final String idempotencyRef;
  final String type;
  final Map<String, dynamic> payload;
  final int attempts;
}

/// Un geste posé sans réseau : réaction, suppression.
///
/// Ce n'est pas un message, et c'est pourquoi il ne vit pas dans la file des
/// messages : il n'a pas de bulle, pas d'expéditeur, pas d'accusé de
/// réception. Ce qu'il a, c'est une CIBLE et un effet à reproduire.
class PendingAction {
  const PendingAction({
    required this.id,
    required this.kind,
    required this.targetId,
    required this.payload,
    required this.createdAt,
  });

  final String id;

  /// `reaction:set`, `reaction:remove`, `message:delete`.
  final String kind;

  /// Le message visé.
  final String targetId;

  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  /// La clé qui interdit le doublon ET l'état contradictoire.
  ///
  /// Une FAMILLE, pas le type exact : `reaction:set` et `reaction:remove`
  /// partagent la même clé sur une même cible, donc l'un remplace l'autre.
  /// Sans ça, réagir puis retirer laisserait les deux en file, rejoués dans
  /// un ordre qu'on ne contrôle pas.
  static String cle(String kind, String targetId) =>
      '${kind.split(':').first}:$targetId';
}

/// L'accès à la file des gestes en attente.
///
/// Séparé de `PokouMessageStore` par une extension plutôt que fondu dedans :
/// le magasin de messages est déjà long, et ces quatre méthodes forment un
/// sujet à part entière qu'on lit mieux ensemble.
extension PendingActionsStore on PokouMessageStore {
  /// Met un geste en file. Un geste de la MÊME famille sur la MÊME cible
  /// remplace celui qui attendait.
  Future<void> enqueueAction({
    required String kind,
    required String targetId,
    Map<String, dynamic>? payload,
  }) async {
    final db = await _database;
    await db.insert('pending_actions', {
      'id': newLocalId(),
      'idempotency_ref': PendingAction.cle(kind, targetId),
      'kind': kind,
      'target_id': targetId,
      'payload': payload == null ? null : jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Les gestes en attente, du plus ancien au plus récent.
  Future<List<PendingAction>> pendingActions() async {
    final db = await _database;
    final lignes = await db.query('pending_actions', orderBy: 'created_at ASC');
    return [
      for (final ligne in lignes)
        PendingAction(
          id: ligne['id'] as String,
          kind: ligne['kind'] as String,
          targetId: ligne['target_id'] as String,
          payload: ligne['payload'] == null
              ? null
              : jsonDecode(ligne['payload'] as String) as Map<String, dynamic>,
          createdAt: DateTime.parse(ligne['created_at'] as String),
        ),
    ];
  }

  Future<void> removeAction(String id) async {
    final db = await _database;
    await db.delete('pending_actions', where: 'id = ?', whereArgs: [id]);
  }

  /// Retire les gestes visant un message qui n'existe plus localement —
  /// typiquement après sa suppression. Sans ce nettoyage, une réaction en
  /// file repartirait vers un message effacé et échouerait indéfiniment.
  Future<void> dropActionsFor(String targetId) async {
    final db = await _database;
    await db.delete(
      'pending_actions',
      where: 'target_id = ?',
      whereArgs: [targetId],
    );
  }
}
