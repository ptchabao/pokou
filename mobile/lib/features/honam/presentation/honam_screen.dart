import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_screen.dart' show KoryStatusPill;
import '../../modules/shared/module_ui.dart';
import '../data/honam_models.dart';
import 'courier_screen.dart';
import 'honam_controller.dart';
import 'honam_order_screen.dart';
import 'honam_send_screen.dart';

/// Honam côté patient (écran APP-4).
///
/// Pas de catalogue ni de bouton « + » : on n'achète pas un médicament sur
/// Pokou, on envoie une ordonnance à un pharmacien. L'urgence est en rouge,
/// et dit tout de suite ce que Pokou n'est pas.
class HonamScreen extends ConsumerWidget {
  const HonamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final orders = ref.watch(honamOrdersProvider).valueOrNull ?? const [];
    final current = orders.where((o) => !o.isFinished).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(honamOrdersProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            PokouAppBar(
              title: l.navHonam,
              actions: [
                IconButton(
                  tooltip: l.honamCourierMode,
                  icon: const Icon(Icons.delivery_dining_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CourierScreen()),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ModuleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.honamSend,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ModuleActionButton(
                      label: l.honamPhotograph,
                      icon: Icons.photo_camera_outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HonamSendScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (current.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ModuleSectionTitle(l.honamCurrentOrder),
              ),
              for (final order in current)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: HonamOrderCard(order: order),
                ),
            ],
            const _Emergency(),
            const _Nearby(),
            if (orders.any((o) => o.isFinished)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ModuleSectionTitle(l.honamMyOrders),
              ),
              for (final order in orders.where((o) => o.isFinished).take(10))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: HonamOrderCard(order: order),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une commande dans une liste. L'état seul, jamais un nom de médicament
/// (HON-04) : la liste se voit par-dessus l'épaule.
class HonamOrderCard extends StatelessWidget {
  const HonamOrderCard({super.key, required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final (icon, color) = switch (order.status) {
      'DELIVERED' => (Icons.check_circle, AppColors.feedbackSuccess),
      'REJECTED' || 'EXPIRED' || 'CANCELLED' => (Icons.cancel_outlined, AppColors.feedbackDanger),
      'QUOTED' || 'ACCEPTED' => (Icons.hourglass_top, AppColors.feedbackWarning),
      _ => (Icons.local_pharmacy_outlined, AppColors.feedbackInfo),
    };
    return ModuleCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HonamOrderScreen(orderId: order.id)),
      ),
      child: Row(
        children: [
          ModuleBadge(icon: Icons.local_pharmacy_outlined, color: AppColors.accentPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.honamOrderTitle('${order.id}'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  order.pharmacy?.name ?? '',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                KoryStatusPill(icon: icon, label: honamStatusLabel(l, order.status), color: color),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _Emergency extends ConsumerWidget {
  const _Emergency();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final numbers = ref.watch(honamEmergencyProvider).valueOrNull ?? const {};
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.feedbackDanger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency_outlined, color: AppColors.feedbackDanger),
                const SizedBox(width: 8),
                Text(
                  l.honamUrgent,
                  style: const TextStyle(
                    color: AppColors.feedbackDanger,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.honamNotEmergency),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in numbers.entries)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.feedbackDanger),
                    onPressed: () => launchUrl(Uri.parse('tel:${entry.value}')),
                    icon: const Icon(Icons.call, size: 18),
                    label: Text('${_label(entry.key)} ${entry.value}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String key) => switch (key) {
    'samu' => 'SAMU',
    'pompiers' => 'Pompiers',
    'police' => 'Police',
    _ => key,
  };
}

final _nearbyProvider = FutureProvider.autoDispose<List<Pharmacy>>((ref) async {
  final position = await currentPosition();
  return ref
      .watch(honamRepositoryProvider)
      .pharmacies(lat: position?.latitude, lng: position?.longitude);
});

class _Nearby extends ConsumerWidget {
  const _Nearby();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final pharmacies = ref.watch(_nearbyProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSectionTitle(l.honamNearby),
          ...pharmacies.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (_, _) => [Text(l.modulesCheckNetwork)],
            data: (items) => items.isEmpty
                ? [Text(l.honamNoPharmacy, style: TextStyle(color: AppColors.textSecondary))]
                : [for (final p in items.take(8)) PharmacyTile(pharmacy: p)],
          ),
        ],
      ),
    );
  }
}

/// Une officine, au format annuaire : les mêmes informations pour toutes
/// (BM-12). La croix verte dit « officine », pas « recommandée ».
class PharmacyTile extends StatelessWidget {
  const PharmacyTile({super.key, required this.pharmacy, this.onTap, this.selected = false});

  final Pharmacy pharmacy;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final details = [
      pharmacy.address,
      if (pharmacy.distanceKm != null) '${pharmacy.distanceKm!.toStringAsFixed(1)} km',
      if (pharmacy.openingHours != null) pharmacy.openingHours!,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      selected: selected,
      leading: const Icon(Icons.local_hospital, color: AppColors.feedbackSuccess),
      title: Text(pharmacy.name),
      subtitle: Text(details),
      trailing: onTap != null
          ? Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off)
          : pharmacy.isOnDuty
          ? KoryStatusPill(
              icon: Icons.nightlight_outlined,
              label: l.honamOnDuty,
              color: AppColors.feedbackSuccess,
            )
          : IconButton(
              tooltip: '${l.navCalls} ${pharmacy.name}',
              icon: const Icon(Icons.call_outlined),
              onPressed: () => launchUrl(Uri.parse('tel:${pharmacy.phone}')),
            ),
    );
  }
}
