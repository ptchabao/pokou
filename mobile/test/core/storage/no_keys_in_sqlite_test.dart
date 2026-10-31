import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';

/// Aucune clé cryptographique ne doit se trouver dans SQLite.
///
/// Le magasin local est maintenant chiffré, mais une clé rangée DEDANS
/// annulerait tout : on aurait mis le coffre et sa clé au même endroit. Les
/// clés — identité de bout en bout, pré-clés, sessions, clé de la base
/// elle-même — vivent dans le Keystore Android / la Keychain iOS, protégés
/// par le matériel quand l'appareil le permet.
///
/// Ce test regarde le SCHÉMA, pas les intentions : il lit les colonnes
/// réellement créées et refuse tout nom qui sente la clé. Une colonne
/// ajoutée un jour par commodité le fera tomber.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Les mots qui désignent un secret. Volontairement large : mieux vaut un
  /// faux positif qui oblige à réfléchir qu'un secret qui passe.
  const suspects = [
    'key',
    'secret',
    'private',
    'identity',
    'prekey',
    'session',
    'password',
    'token',
  ];

  test('aucune colonne du schéma ne porte une clé', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await PokouMessageStore.createSchema(db);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final trouvees = <String>[];
    for (final table in tables) {
      final nom = table['name'] as String;
      if (nom.startsWith('sqlite_')) continue;
      for (final column in await db.rawQuery('PRAGMA table_info($nom)')) {
        final colonne = (column['name'] as String).toLowerCase();
        if (suspects.any(colonne.contains)) trouvees.add('$nom.$colonne');
      }
    }

    expect(trouvees, isEmpty,
        reason: 'colonnes suspectes : $trouvees — les clés vont au Keystore');
    await db.close();
  });

  test('le schéma est bien celui qu\'on croit', () async {
    // Garde-fou du test précédent : s'il ne créait plus rien, il passerait
    // pour de mauvaises raisons.
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await PokouMessageStore.createSchema(db);

    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    ))
        .map((row) => row['name'] as String)
        .toSet();

    expect(
      tables,
      containsAll([
        'direct_messages',
        'group_messages',
        'conversations_cache',
        // La file des gestes hors ligne : elle porte des identifiants de
        // messages, donc elle doit exister ici comme elle doit être vidée à
        // la déconnexion (test suivant).
        'pending_actions',
      ]),
    );
    await db.close();
  });

  test('la déconnexion vide toutes les tables', () async {
    // Y compris le cache de la liste d'accueil, qui porte les aperçus des
    // dernières conversations — c'est-à-dire des noms et des bouts de
    // messages. Il était oublié.
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await PokouMessageStore.createSchema(db);
    await db.insert('conversations_cache', {
      'scope': 'inbox',
      'payload': '[{"name":"Kodjo"}]',
      'saved_at': DateTime.now().toIso8601String(),
    });

    await db.insert('pending_actions', {
      'id': 'local-1',
      'idempotency_ref': 'reaction:msg-1',
      'kind': 'reaction:set',
      'target_id': 'msg-1',
      'payload': '{"emoji":"👍"}',
      'created_at': DateTime.now().toIso8601String(),
    });

    await PokouMessageStore(database: db).clear();

    expect(await db.query('conversations_cache'), isEmpty);
    // Les gestes en attente portent des identifiants de messages du compte
    // qu'on quitte : les laisser les ferait rejouer sous le compte suivant.
    expect(await db.query('pending_actions'), isEmpty);
    await db.close();
  });
}
