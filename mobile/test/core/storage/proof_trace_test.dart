import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';

/// Le mode preuve à deux : la trace est gardée par CET appareil, puisque le
/// serveur n'a jamais lu le texte d'un message chiffré.
void main() {
  late PokouMessageStore store;
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await PokouMessageStore.createSchema(db);
    store = PokouMessageStore(database: db);
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  DirectMessage message({
    String? content,
    bool encrypted = false,
    DateTime? editedAt,
    bool proof = true,
  }) => DirectMessage.fromJson({
    'id': 'm1',
    'sender_id': 2,
    'recipient_id': 1,
    'message_type': 'TEXT',
    'content': content,
    'encryption': encrypted ? 'v1' : null,
    'ciphertext': encrypted ? 'chiffré' : null,
    'envelope': encrypted ? {'n': 1} : null,
    'status': 'SENT',
    'created_at': '2026-11-01T08:00:00',
    'edited_at': editedAt?.toIso8601String(),
    'proof_mode': proof,
  });

  Future<DirectMessage> stored() async =>
      (await store.directConversation(myUserId: 1, contactUserId: 2)).messages.single;

  test('une modification chiffrée en mode preuve garde la version ouverte ici', () async {
    await store.saveDirect([message(content: 'Je te rembourse lundi')]);
    // La modification arrive chiffrée : le serveur n'a pas l'original.
    await store.saveDirect([message(encrypted: true, editedAt: DateTime.utc(2026, 11, 1, 9))]);
    expect((await stored()).originalContent, 'Je te rembourse lundi');

    // Une fois ouverte, la nouvelle version ne recouvre pas la trace.
    await store.saveDirect([message(content: 'Je te rembourse mardi', editedAt: DateTime.utc(2026, 11, 1, 9))]);
    final kept = await stored();
    expect(kept.content, 'Je te rembourse mardi');
    expect(kept.originalContent, 'Je te rembourse lundi');
  });

  test('hors mode preuve, une modification ne garde rien', () async {
    await store.saveDirect([message(content: 'Avant', proof: false)]);
    await store.saveDirect([message(content: 'Après', proof: false, editedAt: DateTime.utc(2026, 11, 1, 9))]);
    expect((await stored()).originalContent, isNull);
  });

  test('un message supprimé en mode preuve reste, barré, et survit au rechargement', () async {
    await store.saveDirect([message(content: 'Je paie demain')]);
    await store.markDirectDeleted('m1', DateTime.utc(2026, 11, 1, 10));
    // Le serveur renvoie l'historique : la marque de suppression reste.
    await store.saveDirect([message(content: 'Je paie demain')]);
    final kept = await stored();
    expect(kept.deletedAt, isNotNull);
    expect(kept.content, 'Je paie demain');

    // L'historique du serveur ne le contient plus (compte supprimé) : la
    // trace reste chez l'autre participant.
    await store.reconcileDirect(
      myUserId: 1,
      contactUserId: 2,
      serverMessages: [
        DirectMessage.fromJson({
          'id': 'autre',
          'sender_id': 1,
          'recipient_id': 2,
          'message_type': 'TEXT',
          'content': 'Bonjour',
          'status': 'SENT',
          'created_at': '2026-11-01T07:00:00',
        }),
      ],
    );
    final ids = (await store.directConversation(myUserId: 1, contactUserId: 2)).messages.map((m) => m.id);
    expect(ids, contains('m1'));
  });
}
