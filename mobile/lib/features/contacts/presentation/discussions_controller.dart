import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pokou_sync_engine.dart';
import '../../../core/providers.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../../core/sync/offline_list.dart';
import '../../../core/sync/outbox_service.dart';
import '../data/conversation_summary.dart';
import 'contacts_controller.dart';
import '../../communities/presentation/community_controller.dart';
import '../../groups/presentation/group_controller.dart';

/// La clé de cache. Une seule pour l'instant : les archives ont leur propre
/// écran, qu'on n'ouvre pas sans réseau par réflexe.
const _scope = 'inbox';

/// Écran d'accueil (liste des discussions). `FutureProvider` simple plutôt
/// qu'un StateNotifier : la liste est déjà entièrement construite et triée
/// par le serveur, il n'y a rien à recalculer côté client — seulement à la
/// redemander au bon moment (voir discussionsRealtimeProvider ci-dessous).
final discussionsProvider = StreamProvider.autoDispose<List<ConversationSummary>>(
  (ref) async* {
    // Hors ligne, la dernière liste connue EST la réponse (voir
    // core/sync/offline_list.dart). Sans ce repli, l'écran d'ACCUEIL était vide
    // dès qu'on ouvrait l'application sans réseau — alors que toutes les
    // conversations sont sur l'appareil. C'est ce qui donnait l'impression que
    // le mode hors ligne ne marchait plus nulle part : le premier écran ne
    // montrait rien, et on n'allait pas plus loin.
    await for (final summaries in offlineList(
      store: ref.watch(pokouMessageStoreProvider),
      scope: _scope,
      fetch: ref.watch(conversationsRepositoryProvider).listRaw,
      parse: ConversationSummary.fromJson,
    )) {
      yield await _withLocalPreviews(
        ref.read(pokouMessageStoreProvider),
        summaries,
      );
    }
  },
);

/// Les conversations ARCHIVÉES, demandées à part.
///
/// `GET /conversations` filtre par `archived`, et vaut `false` par défaut :
/// la liste principale ne contient donc AUCUNE archivée. C'est pourquoi
/// « Archiver » ne produisait rien de visible — la conversation disparaissait
/// au rechargement suivant, sans que rien n'indique où elle était passée.
///
/// Un provider séparé, et non un second appel fusionné dans le premier : les
/// archives se consultent rarement, et les charger à chaque ouverture de
/// l'application ferait payer un aller-retour de plus sur le chemin le plus
/// chaud, pour une liste que personne ne regarde ce jour-là.
///
/// `autoDispose` : la liste se relit à chaque ouverture de la section, donc
/// une conversation désarchivée entre-temps n'y traîne pas.
final archivedDiscussionsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
      final items = await ref
          .watch(conversationsRepositoryProvider)
          .list(archived: true);
      return _withLocalPreviews(ref.read(pokouMessageStoreProvider), items);
    });

/// La même liste, mais SANS toucher au réseau : uniquement ce que le dernier
/// lancement a laissé sur l'appareil.
///
/// Elle sert de première image à l'ouverture. Le réseau met entre une demi-
/// seconde et plusieurs secondes à répondre selon l'endroit et l'opérateur,
/// et pendant tout ce temps l'accueil n'affichait qu'un rond qui tourne —
/// alors que les conversations à montrer étaient déjà là, à quelques
/// millisecondes de lecture SQLite. On montre donc la liste connue tout de
/// suite, et `discussionsProvider` la remplace dès que le serveur répond.
///
/// Renvoie une liste vide plutôt qu'une erreur quand il n'y a rien en cache :
/// c'est un fond d'écran d'attente, pas une source de vérité. L'écran
/// retombe alors sur son indicateur de chargement habituel.
final cachedDiscussionsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
      final store = ref.watch(pokouMessageStoreProvider);
      final cached = await store.cachedConversations(_scope);
      if (cached == null) return const [];
      final summaries = cached
          .cast<Map<String, dynamic>>()
          .map(ConversationSummary.fromJson)
          .toList();
      return _withLocalPreviews(store, summaries);
    });

/// Reporte sur la liste d'accueil gardée un réglage qui attend le réseau —
/// épingler, archiver, mettre en sourdine hors ligne.
///
/// [remove] retire la conversation (archivée : elle quitte la liste
/// principale). Une conversation épinglée remonte en tête, là où le serveur
/// la placera ; le reste de l'ordre ne bouge pas.
Future<void> applyQueuedDiscussionSetting(
  PokouMessageStore store, {
  required String kind,
  required int id,
  Map<String, dynamic> fields = const {},
  bool remove = false,
}) {
  return store.updateCachedConversations(_scope, (items) {
    bool matches(dynamic item) =>
        item is Map && (item['kind'] ?? 'contact') == kind && item['id'] == id;
    final target = items.where(matches).firstOrNull;
    if (target == null) return items;
    final rest = [...items.where((item) => !matches(item))];
    if (remove) return rest;
    final patched = {...(target as Map).cast<String, dynamic>(), ...fields};
    if (fields['is_pinned'] == true) return [patched, ...rest];
    return [for (final item in items) matches(item) ? patched : item];
  });
}

/// Rattrapage des aperçus chiffrés. Le serveur ne peut pas envoyer le texte
/// d'un message qu'il ne peut pas lire ; l'appareil, lui, l'a déjà déchiffré
/// et le garde en clair dans son cache. Sans ces quelques lignes, chaque
/// conversation chiffrée afficherait une ligne BLANCHE dans la liste
/// d'accueil — la fonctionnalité aurait l'air cassée alors qu'elle marche.
Future<List<ConversationSummary>> _withLocalPreviews(
  PokouMessageStore store,
  List<ConversationSummary> summaries,
) async {
  final encryptedIds = [
    for (final summary in summaries)
      if (summary.lastMessage?.encrypted == true)
        summary.lastMessage!.messageId,
  ];
  if (encryptedIds.isEmpty) return summaries;

  final plaintext = await store.plaintextFor(encryptedIds);
  for (final summary in summaries) {
    final preview = summary.lastMessage;
    if (preview == null || !preview.encrypted) continue;
    preview.localContent = plaintext[preview.messageId];
  }
  return summaries;
}

/// Tient la liste des discussions à jour EN DIRECT, sans que l'écran ait
/// besoin d'être rouvert ou tiré-pour-rafraîchir. Écoute globale (comme
/// callSignalingProvider/shieldControllerProvider dans main.dart) plutôt que
/// locale à l'écran : un message qui arrive doit faire remonter sa
/// conversation en tête de liste même si on regarde un autre onglet au
/// moment où il arrive.
///
/// Invalide plutôt que de corriger l'état en mémoire : la liste dépend du
/// tri serveur (épinglées, puis activité) et de calculs qu'on ne veut pas
/// dupliquer côté client (unread_count, is_muted évalué à l'instant T) —
/// un simple GET est largement assez rapide pour rester "instantané" à
/// l'échelle humaine, et rester correct compte plus que gagner un aller-
/// retour réseau.
final discussionsRealtimeProvider = Provider<void>((ref) {
  const relevantEvents = {
    'message:new',
    // Émis à l'EXPÉDITEUR quand il vient d'envoyer. Sans lui, écrire à
    // quelqu'un puis revenir laissait la liste telle qu'elle était : il
    // fallait tirer pour rafraîchir. Distinct de `message:new` à dessein —
    // la conversation ouverte a déjà ajouté ce message, le relui pousser
    // l'afficherait deux fois.
    'conversation:updated',
    'message:deleted',
    'message:status',
    'message:edited',
    'message:reaction',
    'group:message:new',
    'group:message:edited',
    'group:message:reaction',
    'group:updated',
    'group:member:added',
    'group:member:removed',
  };
  listenDurableEventTypes(ref, (type) {
    if (relevantEvents.contains(type)) {
      ref.invalidate(discussionsProvider);
      ref.invalidate(unreadCountsProvider);
    }
    if (type == 'contact:registered') {
      ref.invalidate(contactsProvider);
    }
    // Un contact a changé de nom, de photo ou d'« à propos » : la liste des
    // discussions, le carnet et les groupes affichent son identité.
    if (type == 'user:profile_updated') {
      ref.invalidate(contactsProvider);
      ref.invalidate(discussionsProvider);
      ref.invalidate(myGroupsProvider);
    }
    if (type == 'community:member:added' ||
        type == 'community:member:removed' ||
        type == 'group:member:added' ||
        type == 'group:member:removed' ||
        type == 'group:updated') {
      ref.invalidate(myCommunitiesProvider);
      ref.invalidate(myGroupsProvider);
    }
  });
  // Un réglage posé hors ligne (épingle, archive, sourdine) vient d'être
  // accepté : la liste relue entre-temps ne le montrait peut-être pas.
  final replayed = ref.watch(outboxServiceProvider).replayedMutations.listen((
    key,
  ) {
    if (!key.startsWith('conversation:')) return;
    ref.invalidate(discussionsProvider);
    ref.invalidate(archivedDiscussionsProvider);
  });
  ref.onDispose(replayed.cancel);
});
