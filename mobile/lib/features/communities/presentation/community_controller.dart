import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/pokou_sync_engine.dart';
import '../../../core/providers.dart';
import '../../../core/sync/offline_list.dart';
import '../../groups/presentation/group_controller.dart';
import '../data/community_repository.dart';
import '../data/community_model.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(apiClient: ref.watch(apiClientProvider));
});

/// Mes communautés. `FutureProvider` comme `myGroupsProvider` : une lecture
/// simple, rafraîchie par `ref.invalidate` après création/adhésion/départ.
final myCommunitiesProvider = StreamProvider<List<Community>>((ref) {
  final repository = ref.watch(communityRepositoryProvider);
  return offlineList(
    store: ref.watch(pokouMessageStoreProvider),
    scope: 'communities',
    fetch: repository.listMineRaw,
    parse: Community.fromJson,
  );
});

/// Tient les listes « mes communautés » / « mes groupes » à jour quand mon
/// appartenance change sans action locale (quelqu'un d'autre m'ajoute ou me
/// retire) — sans ça, la nouvelle communauté/le nouveau groupe reste invisible
/// tant qu'on ne relance pas l'app ou ne tire pas pour rafraîchir Contacts.
/// `group:member:added`/`removed` couvre le cas du groupe autonome (pas
/// rattaché à une communauté), que `community:member:added` seul ne
/// détectait pas.
const _membershipChangeEvents = {
  'community:member:added',
  'group:member:added',
  'group:member:removed',
};

final communityMembershipSyncProvider = Provider<void>((ref) {
  listenDurableEventTypes(ref, (type) {
    if (!_membershipChangeEvents.contains(type)) return;
    ref.invalidate(myCommunitiesProvider);
    ref.invalidate(myGroupsProvider);
  });
});

/// Détail d'une communauté — ses groupes et mes droits dessus.
final communityDetailProvider = FutureProvider.autoDispose
    .family<Community, int>((ref, communityId) {
      return ref.watch(communityRepositoryProvider).get(communityId);
    });
