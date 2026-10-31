import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';

/// La règle de l'offline étendu, en une phrase :
///
/// > **Une action effectuée hors ligne ne doit ni disparaître, ni être
/// > exécutée deux fois, ni créer un état contradictoire à la
/// > reconnexion.**
///
/// Les trois se tiennent, et c'est la CLÉ D'IDEMPOTENCE qui les assure
/// ensemble. Elle vaut `{famille}:{cible}` — `reaction:abc-123` —, elle est
/// unique, et une nouvelle action remplace celle qui attendait.
///
/// Sans elle : réagir 👍, retirer, puis réagir ❤️ hors ligne laisserait
/// trois actions en file, rejouées dans un ordre qu'on ne contrôle pas, pour
/// un résultat qui n'est aucun des trois. C'est exactement l'état
/// contradictoire que la règle interdit.
///
/// Même raisonnement que la marque `thread_message_id` des appels : ce n'est
/// pas le rejeu qu'on empêche, c'est le DOUBLON.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late PokouMessageStore store;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    // Le schéma de PRODUCTION, pas une copie : le redéclarer ici le
    // laisserait dériver du vrai sans que rien ne le signale.
    await PokouMessageStore.createSchema(db);
    store = PokouMessageStore(database: db);
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  test('un geste posé hors ligne ne disparaît pas', () async {
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-1',
      payload: {'emoji': '👍'},
    );

    final attente = await store.pendingActions();
    expect(attente, hasLength(1));
    expect(attente.single.kind, 'reaction:set');
    expect(attente.single.targetId, 'msg-1');
    expect(attente.single.payload!['emoji'], '👍');
  });

  test('le même geste deux fois n\'en laisse qu\'un', () async {
    // Un double appui, ou un écran qui renvoie : le destinataire ne doit
    // pas voir la réaction arriver deux fois.
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-1',
      payload: {'emoji': '👍'},
    );
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-1',
      payload: {'emoji': '👍'},
    );

    expect(await store.pendingActions(), hasLength(1));
  });

  test('réagir puis retirer ne laisse que le RETRAIT', () async {
    // L'état contradictoire, dans sa forme la plus simple. Les deux gestes
    // partagent la famille `reaction`, donc la même clé : le second
    // remplace le premier.
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-1',
      payload: {'emoji': '👍'},
    );
    await store.enqueueAction(kind: 'reaction:remove', targetId: 'msg-1');

    final attente = await store.pendingActions();
    expect(attente, hasLength(1));
    expect(attente.single.kind, 'reaction:remove');
  });

  test('trois hésitations ne laissent que la dernière', () async {
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-1',
      payload: {'emoji': '👍'},
    );
    await store.enqueueAction(kind: 'reaction:remove', targetId: 'msg-1');
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-1',
      payload: {'emoji': '❤️'},
    );

    final attente = await store.pendingActions();
    expect(attente, hasLength(1));
    expect(attente.single.kind, 'reaction:set');
    // Celle qu'on voit à l'écran, et aucune autre.
    expect(attente.single.payload!['emoji'], '❤️');
  });

  test('deux cibles différentes ne se chassent pas', () async {
    // La clé porte la CIBLE : réagir à deux messages est deux gestes, pas
    // un qui remplace l'autre.
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-1',
      payload: {'emoji': '👍'},
    );
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-2',
      payload: {'emoji': '❤️'},
    );

    expect(await store.pendingActions(), hasLength(2));
  });

  test(
    'une suppression et une réaction sur la même cible coexistent',
    () async {
      // Familles différentes, clés différentes. C'est l'appelant qui décide
      // laquelle l'emporte — et pour une suppression, il efface les autres
      // (voir messaging_controller.dart::deleteMessage).
      await store.enqueueAction(
        kind: 'reaction:set',
        targetId: 'msg-1',
        payload: {'emoji': '👍'},
      );
      await store.enqueueAction(kind: 'message:delete', targetId: 'msg-1');

      expect(await store.pendingActions(), hasLength(2));
    },
  );

  test('supprimer un message emporte les gestes qui le visaient', () async {
    // Réagir à un message qu'on supprime est contradictoire, et c'est la
    // suppression qui gagne. Sans ce nettoyage, la réaction repartirait
    // vers un message effacé et échouerait indéfiniment.
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-1',
      payload: {'emoji': '👍'},
    );
    await store.enqueueAction(
      kind: 'reaction:set',
      targetId: 'msg-2',
      payload: {'emoji': '👍'},
    );

    await store.dropActionsFor('msg-1');

    final attente = await store.pendingActions();
    expect(attente, hasLength(1));
    expect(attente.single.targetId, 'msg-2');
  });

  test('les gestes repartent du plus ancien au plus récent', () async {
    await store.enqueueAction(kind: 'message:delete', targetId: 'msg-1');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.enqueueAction(kind: 'message:delete', targetId: 'msg-2');

    final attente = await store.pendingActions();
    expect(attente.map((a) => a.targetId).toList(), ['msg-1', 'msg-2']);
  });

  test('un geste rejoué est retiré de la file', () async {
    await store.enqueueAction(kind: 'message:delete', targetId: 'msg-1');
    final action = (await store.pendingActions()).single;

    await store.removeAction(action.id);
    expect(await store.pendingActions(), isEmpty);
  });

  test('la clé regroupe par FAMILLE, pas par type exact', () {
    expect(
      PendingAction.cle('reaction:set', 'msg-1'),
      PendingAction.cle('reaction:remove', 'msg-1'),
    );
    expect(
      PendingAction.cle('reaction:set', 'msg-1'),
      isNot(PendingAction.cle('message:delete', 'msg-1')),
    );
  });
}
