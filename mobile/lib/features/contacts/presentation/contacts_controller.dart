import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/offline_list.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/contact_sync_service.dart';

import '../../../core/providers.dart';
import '../data/contact_model.dart';
import '../data/contacts_repository.dart';
import '../data/conversations_repository.dart';
import '../data/device_contacts_service.dart';
import 'discussions_controller.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(apiClient: ref.watch(apiClientProvider));
});

final deviceContactsServiceProvider = Provider<DeviceContactsService>(
  (ref) => DeviceContactsService(),
);

/// Le carnet d'adresses reste lisible sans réseau : c'est par lui qu'on
/// ouvre une conversation, et une conversation s'ouvre hors ligne.
final contactsProvider = StreamProvider.autoDispose<List<PokouContact>>((ref) {
  final repository = ref.watch(contactsRepositoryProvider);
  return offlineList(
    store: ref.watch(pokouMessageStoreProvider),
    scope: 'contacts',
    fetch: repository.listRaw,
    parse: PokouContact.fromJson,
  );
});

final conversationsRepositoryProvider = Provider<ConversationsRepository>((
  ref,
) {
  return ConversationsRepository(
    apiClient: ref.watch(apiClientProvider),
    mutations: ref.watch(mutationQueueProvider),
  );
});

final unreadCountsProvider = FutureProvider.autoDispose<Map<int, int>>((
  ref,
) async {
  final summaries = await ref.watch(conversationsRepositoryProvider).list();
  return {
    for (final summary in summaries)
      if (summary.kind == 'contact' && summary.contactUserId != null)
        summary.contactUserId!: summary.unreadCount,
  };
});

/// Synchronisation du carnet — en direct, sans tirer-pour-rafraîchir.
///
/// Deux flux distincts se rejoignent ici, et ils n'ont pas la même nature :
///
/// - **le répertoire du téléphone → Pokou.** Il faut le RELIRE ; personne ne
///   peut nous prévenir qu'un numéro y a été ajouté. Déclenché au retour au
///   premier plan et à la reconnexion du socket (voir ContactSyncTriggers).
/// - **« quelqu'un de mon carnet vient d'arriver sur Pokou » → moi.** Le
///   serveur le POUSSE (`contact:registered`) au moment où la personne valide
///   son code : lui seul l'apprend à la seconde près, et la fiche existait
///   déjà dans mon carnet, en attente d'un compte à rattacher.
///
/// Vit au niveau de l'application (branché dans main.dart) et non dans
/// l'écran Contacts : une arrivée doit être enregistrée même si on regarde
/// un autre onglet, exactement comme discussionsRealtimeProvider.
final contactSyncProvider = Provider<void>((ref) {
  final ws = ref.watch(wsClientProvider);

  final triggers = ContactSyncTriggers(
    onTrigger: () => _syncDeviceBook(
      myPhone: ref.read(authControllerProvider).user?.phone,
      service: ref.read(deviceContactsServiceProvider),
      repository: ref.read(contactsRepositoryProvider),
      onSynced: () => ref.invalidate(contactsProvider),
    ),
  );
  triggers.start(connectionChanges: ws.connectionChanges);

  final subscription = ws.events.listen((event) {
    if (event['type'] != 'contact:registered') return;
    // La fiche existe déjà et vient d'être rattachée à un compte côté
    // serveur : il n'y a rien à renvoyer, seulement à relire.
    ref.invalidate(contactsProvider);
    ref.invalidate(discussionsProvider);
  });

  ref.onDispose(() {
    subscription.cancel();
    triggers.dispose();
  });
});

/// Garde-fou d'appels rapprochés : le retour au premier plan et la
/// reconnexion du socket arrivent presque toujours ensemble, et relire le
/// répertoire est l'opération la plus coûteuse de l'application — plusieurs
/// centaines d'entrées à lire sur l'appareil, puis à envoyer. Sur un forfait
/// de données compté, la différence n'est pas théorique.
bool _syncing = false;
DateTime? _lastSync;
const _minInterval = Duration(seconds: 20);

/// Les dépendances sont passées en paramètres plutôt que lues depuis un
/// `ref` : `Ref` (providers) et `WidgetRef` (widgets) n'ont pas de supertype
/// commun dans Riverpod, et cette fonction sert aux deux.
Future<void> _syncDeviceBook({
  required String? myPhone,
  required DeviceContactsService service,
  required ContactsRepository repository,
  required void Function() onSynced,
  bool force = false,
}) async {
  if (_syncing) return;
  if (force) {
    _lastSync = null;
  } else {
    final last = _lastSync;
    if (last != null && DateTime.now().difference(last) < _minInterval) return;
  }
  if (myPhone == null) return;

  _syncing = true;
  try {
    if (!await service.hasPermission()) return;
    final entries = await service.readAll(myPhoneE164: myPhone);
    await repository.syncDevice(entries);
    _lastSync = DateTime.now();
    onSynced();
  } catch (_) {
    // Best-effort : permission refusée, hors ligne, répertoire vide. Le
    // carnet côté serveur reste utilisable sans les correspondances locales.
  } finally {
    _syncing = false;
  }
}

/// Forcer une synchronisation — le tirer-pour-rafraîchir, qui court-circuite
/// l'intervalle minimum : c'est le geste de quelqu'un qui SAIT que quelque
/// chose a changé, lui opposer un délai serait absurde.
Future<void> forceContactSync(WidgetRef ref) {
  return _syncDeviceBook(
    myPhone: ref.read(authControllerProvider).user?.phone,
    service: ref.read(deviceContactsServiceProvider),
    repository: ref.read(contactsRepositoryProvider),
    onSynced: () => ref.invalidate(contactsProvider),
    force: true,
  );
}

/// Les gens de mon répertoire qui ne sont PAS encore sur Pokou.
///
/// Le serveur ne peut pas répondre à cette question, et c'est délibéré : il
/// n'enregistre jamais un numéro non inscrit (voir `/contacts/sync`, qui
/// compare sans rien conserver). La liste ne peut donc se construire que
/// sur l'appareil, en retirant du répertoire local tout ce que le carnet
/// Pokou connaît déjà.
///
/// Liste vide plutôt qu'erreur si la permission est refusée : proposer
/// d'inviter des gens est un bonus, pas une raison de casser l'écran.
final invitableContactsProvider =
    FutureProvider.autoDispose<List<DeviceContactEntry>>((ref) async {
      final myPhone = ref.watch(authControllerProvider).user?.phone;
      if (myPhone == null) return const [];

      final service = ref.watch(deviceContactsServiceProvider);
      if (!await service.hasPermission()) return const [];

      final onPokou = {
        for (final contact in await ref.watch(contactsProvider.future))
          contact.phone,
      };

      return invitableFrom(
        deviceBook: await service.readAll(myPhoneE164: myPhone),
        phonesOnPokou: onPokou,
        myPhone: myPhone,
      );
    });

/// Le croisement lui-même, isolé pour être vérifiable.
///
/// Trois pièges, et aucun ne se signale à l'écran : afficher « inviter » à
/// quelqu'un qui est DÉJÀ sur Pokou, répéter le même nom autant de fois
/// qu'il a de numéros, ou se proposer à soi-même.
List<DeviceContactEntry> invitableFrom({
  required List<DeviceContactEntry> deviceBook,
  required Set<String> phonesOnPokou,
  required String myPhone,
}) {
  final seen = <String>{};
  final invitable = <DeviceContactEntry>[];
  for (final entry in deviceBook) {
    if (entry.phone == myPhone) continue;
    if (phonesOnPokou.contains(entry.phone)) continue;
    // Un même contact peut avoir plusieurs numéros, et deux fiches peuvent
    // porter le même : sans ce dédoublonnage la liste répète des noms sans
    // que rien n'explique pourquoi.
    if (!seen.add(entry.phone)) continue;
    invitable.add(entry);
  }
  invitable.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return invitable;
}
