import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pokou_sync_engine.dart';
import '../../../core/providers.dart';
import '../../../core/sync/offline_list.dart';
import '../../../core/sync/outbox_service.dart';
import '../data/channel_model.dart';
import '../data/channel_repository.dart';

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepository(
    apiClient: ref.watch(apiClientProvider),
    mutations: ref.watch(mutationQueueProvider),
  );
});

final myChannelsProvider = StreamProvider.autoDispose((ref) {
  final repository = ref.watch(channelRepositoryProvider);
  return offlineList(
    store: ref.watch(pokouMessageStoreProvider),
    scope: 'channels',
    fetch: repository.listMineRaw,
    parse: PokouChannel.fromJson,
  );
});

/// Quelques chaînes à suivre, pour qui n'en suit aucune.
///
/// Pas de cache hors ligne ici, contrairement à `myChannelsProvider` : une
/// suggestion périmée n'a aucune valeur, et sans réseau il n'y a de toute
/// façon rien à découvrir. L'écran vide reste alors vide, ce qui est la
/// réponse honnête.
final suggestedChannelsProvider =
    FutureProvider.autoDispose<List<PokouChannel>>((ref) {
      return ref.watch(channelRepositoryProvider).suggested();
    });

/// Une chaîne se consulte comme un fil d'information : on l'ouvre pour voir
/// ce qu'il y a de neuf. Sans poussée, « de neuf » voulait dire « depuis le
/// dernier tirer-pour-rafraîchir », ce qui vide une chaîne de son intérêt —
/// l'annonce d'un arrivage n'arrivait que quand le lecteur y repensait.
///
/// Ne rafraîchit que la LISTE des chaînes (compteurs, dernière activité) :
/// l'écran d'une chaîne ouverte écoute le même événement de son côté et
/// recharge ses publications lui-même, parce que lui seul sait laquelle il
/// affiche.
final channelsRealtimeProvider = Provider<void>((ref) {
  listenDurableEventTypes(ref, (type) {
    if (type == 'channel:post') ref.invalidate(myChannelsProvider);
  });
  // Suivre / ne plus suivre posé hors ligne : la liste « mes chaînes » ne
  // l'apprend qu'une fois le serveur d'accord.
  final replayed = ref.watch(outboxServiceProvider).replayedMutations.listen((
    key,
  ) {
    if (key.startsWith('channel:follow:')) ref.invalidate(myChannelsProvider);
  });
  ref.onDispose(replayed.cancel);
});
