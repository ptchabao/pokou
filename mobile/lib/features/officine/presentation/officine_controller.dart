import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/sync/pokou_sync_engine.dart';
import '../../honam/data/honam_models.dart' show HonamOrderMessage;
import '../data/officine_models.dart';
import '../data/officine_repository.dart';

final officineRepositoryProvider = Provider<OfficineRepository>((ref) {
  return OfficineRepository(apiClient: ref.watch(apiClientProvider));
});

/// Temps réel : le serveur pousse `honam:order_updated` à chaque changement
/// d'une commande, à la patiente comme à l'équipe de l'officine.
void _live(Ref ref) => listenDurableEventTypes(ref, (type) {
  if (type == 'honam:order_updated') ref.invalidateSelf();
});

/// L'officine du compte, ou `null` : l'entrée « Espace officine » de Plus ne
/// s'affiche que si elle existe.
final officineMeProvider = FutureProvider.autoDispose<OfficineMe?>((ref) {
  _live(ref);
  return ref.watch(officineRepositoryProvider).me();
});

/// La file en cours (tout sauf les commandes closes).
final officineQueueProvider = FutureProvider.autoDispose<List<OfficineOrder>>((
  ref,
) {
  _live(ref);
  return ref.watch(officineRepositoryProvider).orders();
});

/// Les commandes d'un état (DELIVERED, CANCELLED, REJECTED, EXPIRED).
final officineOrdersByStatusProvider = FutureProvider.autoDispose
    .family<List<OfficineOrder>, String>((ref, status) {
      _live(ref);
      return ref.watch(officineRepositoryProvider).orders(status: status);
    });

final officineOrderProvider = FutureProvider.autoDispose
    .family<OfficineOrder, int>((ref, id) {
      _live(ref);
      return ref.watch(officineRepositoryProvider).order(id);
    });

/// L'historique d'un mois (le premier jour du mois en clé).
final officineHistoryProvider = FutureProvider.autoDispose
    .family<OfficineHistory, DateTime>((ref, month) {
      return ref.watch(officineRepositoryProvider).history(month);
    });

final officineDeliveryPriceProvider = FutureProvider.autoDispose<int?>((ref) {
  return ref.watch(officineRepositoryProvider).deliveryPrice();
});

final officineCouriersProvider = FutureProvider.autoDispose<OfficineCouriers>((
  ref,
) {
  return ref.watch(officineRepositoryProvider).couriers();
});

final officineMessagesProvider = FutureProvider.autoDispose
    .family<List<HonamOrderMessage>, int>((ref, id) {
      _live(ref);
      return ref.watch(officineRepositoryProvider).messages(id);
    });

/// Après une action : la commande, la file et l'accueil se relisent.
void refreshOfficine(WidgetRef ref, [int? orderId]) {
  if (orderId != null) ref.invalidate(officineOrderProvider(orderId));
  ref.invalidate(officineQueueProvider);
  ref.invalidate(officineOrdersByStatusProvider);
  ref.invalidate(officineHistoryProvider);
  ref.invalidate(officineMeProvider);
}
