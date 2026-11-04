import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../data/honam_models.dart';
import '../data/honam_repository.dart';

final honamRepositoryProvider = Provider<HonamRepository>((ref) {
  return HonamRepository(apiClient: ref.watch(apiClientProvider));
});

final honamOrdersProvider = FutureProvider.autoDispose<List<HonamOrder>>((ref) {
  return ref.watch(honamRepositoryProvider).orders();
});

final honamOrderProvider = FutureProvider.autoDispose.family<HonamOrder, int>((
  ref,
  id,
) {
  return ref.watch(honamRepositoryProvider).order(id);
});

final honamOrderMessagesProvider = FutureProvider.autoDispose
    .family<List<HonamOrderMessage>, int>((ref, id) {
      return ref.watch(honamRepositoryProvider).orderMessages(id);
    });

final honamEmergencyProvider = FutureProvider.autoDispose<Map<String, String>>((
  ref,
) {
  return ref.watch(honamRepositoryProvider).emergencyNumbers();
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
Future<void> openPayment(BuildContext context, Future<String?> payment) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final url = await payment;
    if (url == null) throw Exception();
    messenger.showSnackBar(SnackBar(content: Text(l.honamPaymentLinkOpened)));
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.honamFailed)));
  }
}
