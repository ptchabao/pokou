import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/identity_providers.dart';
import '../../../core/sync/offline_list.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/sync/pokou_sync_engine.dart';
import '../../../core/providers.dart';
import '../data/status_model.dart';
import '../data/status_repository.dart';

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return StatusRepository(
    apiClient: ref.watch(apiClientProvider),
    mutations: ref.watch(mutationQueueProvider),
  );
});

final statusFeedProvider = StreamProvider.autoDispose<List<StatusFeedItem>>((
  ref,
) {
  final repository = ref.watch(statusRepositoryProvider);
  return offlineList(
    store: ref.watch(pokouMessageStoreProvider),
    scope: 'status_feed',
    fetch: repository.getFeedRaw,
    parse: StatusFeedItem.fromJson,
  );
});

/// Qui a, en ce moment, au moins un statut que je n'ai pas vu.
///
/// Cette information EXISTAIT déjà — `viewed_by_me` arrive avec chaque
/// statut — et aucun écran hors de l'onglet Actus ne la lisait. L'anneau
/// autour d'une photo se dessine pourtant dans la liste des discussions,
/// dans les contacts, en tête d'une conversation.
///
/// Ce provider recopie donc l'état du fil dans une source que toute
/// l'application peut lire, sans que chaque écran ait à charger le fil des
/// statuts pour savoir s'il faut dessiner un cercle.
///
/// Branché dans `main.dart`, comme le temps réel ci-dessous : l'anneau doit
/// être juste dès l'ouverture de l'application, pas seulement après un
/// passage par l'onglet Actus.
final statusRingSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<StatusFeedItem>>>(statusFeedProvider, (_, next) {
    final items = next.valueOrNull;
    if (items == null) return;
    ref.read(unseenStatusUsersProvider.notifier).state = {
      for (final item in items)
        if (item.hasUnseen) item.userId,
    };
  }, fireImmediately: true);
});

/// Rallume l'anneau d'un contact dès qu'il publie, sans rien demander.
///
/// « Actualités » était le seul pan de l'application sans aucune poussée : un
/// statut publié restait invisible jusqu'à ce que quelqu'un pense à recharger
/// l'onglet. C'est précisément l'écran qu'on regarde SANS rien demander, donc
/// celui où l'absence de temps réel se remarque le plus.
///
/// Écoute globale (branchée dans main.dart) : l'anneau doit s'allumer même
/// quand on regarde un autre onglet, sinon on n'apprend l'existence du statut
/// qu'en ouvrant celui-ci — ce qui revient au point de départ.
///
/// Le serveur n'envoie que « untel a publié » ; on relit le fil, ce qui
/// applique au passage les filtres de confidentialité et les « déjà vus »
/// calculés côté serveur, au lieu de dupliquer cette logique ici.
final statusRealtimeProvider = Provider<void>((ref) {
  listenDurableEventTypes(ref, (type) {
    if (type == 'status:new' || type == 'status:deleted') {
      ref.invalidate(statusFeedProvider);
    }
  });
});

class StatusPostController extends StateNotifier<bool> {
  StatusPostController(this._repository, this._media) : super(false);

  final StatusRepository _repository;
  final MediaRepository _media;

  Future<PokouStatus> postText(String text) async {
    state = true;
    try {
      return await _repository.createText(text);
    } finally {
      state = false;
    }
  }

  Future<PokouStatus> postMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String contentType,
    String? caption,
  }) async {
    state = true;
    try {
      final uploaded = await _media.upload(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        messageType: contentType,
      );
      return await _repository.createMedia(
        contentType: contentType,
        mediaAssetId: uploaded.id,
        caption: caption,
      );
    } finally {
      state = false;
    }
  }
}

final statusPostControllerProvider =
    StateNotifierProvider.autoDispose<StatusPostController, bool>((ref) {
      return StatusPostController(
        ref.watch(statusRepositoryProvider),
        ref.watch(mediaRepositoryProvider),
      );
    });
