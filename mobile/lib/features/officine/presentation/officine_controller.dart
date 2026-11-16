import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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

/// Le dossier « Référencer votre officine » (maquettes Officine 14 à 16),
/// ou `null` si Honam est fermé dans le pays. Relu à chaque retour sur
/// « Plus » : la décision du support arrive par une notification.
final officineRegistrationProvider =
    FutureProvider.autoDispose<OfficineRegistration?>((ref) {
      return ref.watch(officineRepositoryProvider).registration();
    });

/// La position du téléphone à l'envoi du dossier, si elle est déjà permise :
/// l'annuaire classe les officines par distance. Jamais de demande
/// d'autorisation ici ; le support complète la position sinon.
final officineRegistrationPositionProvider =
    Provider<Future<({double latitude, double longitude})?> Function()>(
      (ref) => () async {
        try {
          if (!await Geolocator.isLocationServiceEnabled()) return null;
          final permission = await Geolocator.checkPermission();
          if (permission != LocationPermission.always &&
              permission != LocationPermission.whileInUse) {
            return null;
          }
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
          return (latitude: position.latitude, longitude: position.longitude);
        } catch (_) {
          return null;
        }
      },
    );

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

/// Les téléphones du comptoir (Officine 13).
final officinePhonesProvider = FutureProvider.autoDispose<List<CounterPhone>>((
  ref,
) {
  return ref.watch(officineRepositoryProvider).phones();
});

/// Les messages d'un canal (`patient` ou `coursier`) d'une commande.
final officineMessagesProvider = FutureProvider.autoDispose
    .family<List<HonamOrderMessage>, ({int id, String channel})>((ref, key) {
      _live(ref);
      listenDurableEventTypes(ref, (type) {
        if (type == 'honam:order_message') ref.invalidateSelf();
      });
      return ref
          .watch(officineRepositoryProvider)
          .messages(key.id, channel: key.channel);
    });

/// Après une action : la commande, la file et l'accueil se relisent.
void refreshOfficine(WidgetRef ref, [int? orderId]) {
  if (orderId != null) ref.invalidate(officineOrderProvider(orderId));
  ref.invalidate(officineQueueProvider);
  ref.invalidate(officineOrdersByStatusProvider);
  ref.invalidate(officineHistoryProvider);
  ref.invalidate(officineMeProvider);
}
