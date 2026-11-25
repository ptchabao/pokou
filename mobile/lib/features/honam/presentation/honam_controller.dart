import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/sync/pokou_sync_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_payment.dart' show isTestPayment;
import '../data/honam_models.dart';
import '../data/honam_repository.dart';

final honamRepositoryProvider = Provider<HonamRepository>((ref) {
  return HonamRepository(apiClient: ref.watch(apiClientProvider));
});

/// Temps réel : devis, paiement, coursier, livraison — le serveur pousse
/// `honam:order_updated` à chaque changement de la commande.
void _liveHonam(Ref ref) => listenDurableEventTypes(ref, (type) {
  if (type == 'honam:order_updated') ref.invalidateSelf();
});

final honamOrdersProvider = FutureProvider.autoDispose<List<HonamOrder>>((ref) {
  _liveHonam(ref);
  return ref.watch(honamRepositoryProvider).orders();
});

final courierStatusProvider = FutureProvider.autoDispose<CourierStatus?>((ref) {
  return ref.watch(honamRepositoryProvider).courierMe();
});

final honamOrderProvider = FutureProvider.autoDispose.family<HonamOrder, int>((
  ref,
  id,
) {
  _liveHonam(ref);
  return ref.watch(honamRepositoryProvider).order(id);
});

/// Les messages d'un canal d'une commande (`patient`, `livraison`…).
final honamOrderMessagesProvider = FutureProvider.autoDispose
    .family<List<HonamOrderMessage>, ({int id, String channel})>((ref, key) {
      _liveHonam(ref);
      listenDurableEventTypes(ref, (type) {
        if (type == 'honam:order_message') ref.invalidateSelf();
      });
      return ref
          .watch(honamRepositoryProvider)
          .orderMessages(key.id, channel: key.channel);
    });

final honamEmergencyProvider = FutureProvider.autoDispose<EmergencyInfo>((ref) {
  return ref.watch(honamRepositoryProvider).emergency();
});

String honamStatusLabel(L l, String status) => switch (status) {
  'SUBMITTED' => l.honamStSubmitted,
  'QUOTED' => l.honamStQuoted,
  'ACCEPTED' => l.honamStAccepted,
  'PAID' => l.honamStPaid,
  'READY' => l.honamStReady,
  'IN_DELIVERY' => l.honamStInDelivery,
  'DELIVERED' => l.honamStDelivered,
  'REJECTED' => l.honamStRejected,
  'EXPIRED' => l.honamStExpired,
  _ => l.honamStCancelled,
};

/// Ouvre la page de paiement CashPay dans le navigateur.
/// [payment] : l'adresse de la passerelle, ou la réponse entière du serveur
/// (`payment_url`, `test_mode`…). Renvoie `true` quand le paiement a été
/// SIMULÉ (pays de test) : son effet est déjà acquis.
Future<bool> openPayment(BuildContext context, Future<Object?> payment) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await payment;
    if (isTestPayment(result)) {
      messenger.showSnackBar(SnackBar(content: Text(l.hnxTestPaymentDone)));
      return true;
    }
    final url = result is Map
        ? result['payment_url'] as String?
        : result as String?;
    if (url == null) throw Exception();
    messenger.showSnackBar(SnackBar(content: Text(l.honamPaymentLinkOpened)));
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.honamFailed)));
  }
  return false;
}
