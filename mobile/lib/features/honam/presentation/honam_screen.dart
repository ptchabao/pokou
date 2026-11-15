import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../core/widgets/pokou_illustration.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/presentation/pokou_page_header.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../data/honam_models.dart';
import 'courier_join_screen.dart' show CourierOfferPrompt;
import 'honam_controller.dart';
import 'honam_order_screen.dart';
import 'honam_orders_screen.dart';
import 'honam_send_screen.dart';
import 'honam_ui.dart';

/// Honam côté patient (écran APP-4).
///
/// Pas de catalogue ni de bouton « + » : on n'achète pas un médicament sur
/// Pokou, on envoie une ordonnance à un pharmacien. L'urgence est en rouge,
/// et dit tout de suite ce que Pokou n'est pas.
///
/// De haut en bas : l'en-tête des onglets, l'envoi d'une ordonnance, « Mes
/// commandes » filtrées par pilules, l'urgence, les pharmacies proches.
class HonamScreen extends ConsumerStatefulWidget {
  const HonamScreen({super.key});

  @override
  ConsumerState<HonamScreen> createState() => _HonamScreenState();
}

class _HonamScreenState extends ConsumerState<HonamScreen> {
  void _openSend() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const HonamSendScreen()));

  void _openOrders() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const HonamOrdersScreen()));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(honamOrdersProvider);
    final orders = async.valueOrNull ?? const <HonamOrder>[];
    final current = orders.where((o) => !o.isFinished).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(honamOrdersProvider);
          ref.invalidate(honamNearbyProvider);
          ref.invalidate(honamEmergencyProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            PokouPageHeader(
              title: l.navHonam,
              subtitle: current.isEmpty
                  ? l.honamSubtitle
                  : l.honamUiInProgressCount(current.length),
              emphasized: current.isNotEmpty,
              // Le logo du module (guide des logos, novembre 2026).
              leading: const PokouModuleLogo(PokouModule.honam, size: 40),
              actions: [
                // Maquette p. 14 : l'icône reçu ouvre « Mes commandes ».
                IconButton(
                  tooltip: l.honamMyOrders,
                  icon: Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: _openOrders,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _SendHero(onSend: _openSend),
            ),
            // Maquette Coursiers 0 : le bandeau de l'offre coursier.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: CourierOfferPrompt(),
            ),
            if (async.hasValue)
              for (final order in current)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _CurrentOrderCard(order: order),
                )
            else if (async.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FlatNotice(
                  illustration: PokouIllustrations.offline,
                  title: l.honamUiOrdersError,
                  message: l.modulesCheckNetwork,
                  actionLabel: l.actionRetry,
                  onAction: () => ref.invalidate(honamOrdersProvider),
                ),
              )
            else
              const _OrdersSkeleton(),
            const _Emergency(),
            _SectionTitle(l.honamNearby),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _Nearby(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le titre d'une section de l'onglet — le même dessin que sur l'Accueil.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
    child: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 20,
        height: 1.3,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

/// L'aplat pastel d'en haut : ce que Honam fait, et le geste pour commencer.
class _SendHero extends StatelessWidget {
  const _SendHero({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.terracottaTint,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.honamSend,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 21,
                        height: 1.2,
                        letterSpacing: -0.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.honamIntro,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const PokouIllustration(PokouIllustrations.honam, height: 96),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: HonamPrimaryButton(
              label: l.honamPhotograph,
              icon: Icons.photo_camera_outlined,
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Commande en cours » (maquette p. 14) : la pharmacie, le montant, la
/// frise, une pastille d'état et le geste qui compte maintenant.
class _CurrentOrderCard extends StatelessWidget {
  const _CurrentOrderCard({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pharmacy = order.pharmacy?.name ?? l.navHonam;
    final line = order.total == null
        ? pharmacy
        : l.honamPCurrentLine(pharmacy, formatFcfa(order.total!));
    final action = switch (order.status) {
      'QUOTED' || 'ACCEPTED' when !order.patientPaidDeclared =>
        l.honamPSeeQuoteAndPay,
      'READY' || 'IN_DELIVERY' when order.courierName != null =>
        l.honamPFollowOrder,
      _ => l.honamUiSeeOrder,
    };
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HonamOrderScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.honamPCurrentOrder,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  honamOrderPill(l, order),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              HonamStepRail(status: order.status),
              const SizedBox(height: 10),
              Text(
                action,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La forme d'une carte de commande, pendant le chargement.
class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SkeletonBox(width: 112, height: 44, radius: 22),
              SizedBox(width: 8),
              SkeletonBox(width: 104, height: 44, radius: 22),
              SizedBox(width: 8),
              SkeletonBox(width: 96, height: 44, radius: 22),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < 2; index++)
          Padding(
            padding: EdgeInsets.fromLTRB(16, index == 0 ? 0 : 10, 16, 0),
            child: const _OrderCardSkeleton(),
          ),
      ],
    ),
  );
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 15, 12, 15),
          child: Row(
            children: [
              SkeletonBox(width: 18, height: 18, radius: 9),
              SizedBox(width: 8),
              SkeletonBox(width: 150, height: 12),
              Spacer(),
              SkeletonBox(width: 52, height: 20, radius: 10),
            ],
          ),
        ),
        HonamHairline(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              SkeletonBox(width: 48, height: 48, radius: 13),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 170, height: 14),
                    SizedBox(height: 9),
                    SkeletonBox(width: 110, height: 12),
                  ],
                ),
              ),
              SkeletonBox(width: 64, height: 12),
            ],
          ),
        ),
        HonamHairline(indent: 16),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              SkeletonBox(width: 140, height: 12),
              Spacer(),
              SkeletonBox(width: 16, height: 16, radius: 8),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Un état vide ou une erreur, à plat : une scène, une phrase, une action.
class _FlatNotice extends StatelessWidget {
  const _FlatNotice({
    required this.illustration,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final PokouIllustrations illustration;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        PokouIllustration(illustration, height: 112),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentPrimaryDark,
            minimumSize: const Size(64, 44),
          ),
          child: Text(
            actionLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// L'urgence : en rouge, et dit tout de suite ce que Pokou n'est pas.
class _Emergency extends ConsumerWidget {
  const _Emergency();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final numbers = ref.watch(honamEmergencyProvider).valueOrNull ?? const {};
    final danger = AppColors.securityCritical;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: AppColors.isDark ? 0.14 : 0.07),
          borderRadius: AppRadius.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emergency_outlined,
                    size: 22,
                    color: danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.honamUrgent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: danger,
                        ),
                      ),
                      Text(
                        l.honamNotEmergency,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (numbers.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in numbers.entries)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.feedbackDanger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(64, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:${entry.value}')),
                      icon: const Icon(Icons.call, size: 18),
                      label: Text(
                        '${_label(l, entry.key)} ${entry.value}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _label(L l, String key) => switch (key) {
    'samu' => l.honamUiSamu,
    'pompiers' => l.honamUiFire,
    'police' => l.honamUiPolice,
    _ => key,
  };
}

/// Les officines autour de la personne — sans jamais demander la position :
/// elle n'est lue que si elle est déjà autorisée.
final honamNearbyProvider = FutureProvider.autoDispose<List<Pharmacy>>((
  ref,
) async {
  final position = await currentPosition(ask: false);
  return ref
      .watch(honamRepositoryProvider)
      .pharmacies(lat: position?.latitude, lng: position?.longitude);
});

class _Nearby extends ConsumerWidget {
  const _Nearby();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final pharmacies = ref.watch(honamNearbyProvider);
    final Widget content;
    if (pharmacies.hasValue) {
      final items = pharmacies.requireValue.take(8).toList();
      content = items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Icon(
                    Icons.local_pharmacy_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.honamNoPharmacy,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final (index, pharmacy) in items.indexed) ...[
                  if (index > 0) const HonamHairline(),
                  PharmacyTile(pharmacy: pharmacy),
                ],
              ],
            );
    } else if (pharmacies.hasError) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.honamUiPharmaciesError,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    l.modulesCheckNetwork,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(honamNearbyProvider),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimaryDark,
                minimumSize: const Size(44, 44),
              ),
              child: Text(l.actionRetry),
            ),
          ],
        ),
      );
    } else {
      content = const _NearbySkeleton();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: content,
    );
  }
}

class _NearbySkeleton extends StatelessWidget {
  const _NearbySkeleton();

  static const _names = [150.0, 122.0, 168.0];
  static const _details = [210.0, 184.0, 196.0];

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: Column(
      children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0) const HonamHairline(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                const SkeletonCircle(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: _names[index], height: 14),
                      const SizedBox(height: 8),
                      SkeletonBox(width: _details[index], height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

/// Une officine, au format annuaire : les mêmes informations pour toutes
/// (BM-12). La croix verte dit « officine », pas « recommandée ».
class PharmacyTile extends StatelessWidget {
  const PharmacyTile({
    super.key,
    required this.pharmacy,
    this.onTap,
    this.selected = false,
  });

  final Pharmacy pharmacy;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final details = [
      if (pharmacy.address.isNotEmpty) pharmacy.address,
      if (pharmacy.distanceKm != null)
        l.honamUiKm(
          NumberFormat.decimalPatternDigits(
            locale: Localizations.localeOf(context).toLanguageTag(),
            decimalDigits: 1,
          ).format(pharmacy.distanceKm!),
        ),
      if (pharmacy.openingHours != null) pharmacy.openingHours!,
    ].join(' · ');
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.feedbackSuccess.withValues(
                alpha: AppColors.isDark ? 0.22 : 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_hospital,
              size: 22,
              color: AppColors.feedbackSuccess,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pharmacy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (pharmacy.isOnDuty) ...[
                  const SizedBox(height: 6),
                  HonamPill(
                    l.honamOnDuty,
                    background: AppColors.feedbackSuccess.withValues(
                      alpha: AppColors.isDark ? 0.24 : 0.12,
                    ),
                    ink: AppColors.isDark
                        ? AppColors.textPrimary
                        : AppColors.feedbackSuccess,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onTap != null)
            SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? AppColors.accentPrimaryDark
                    : AppColors.textMuted,
              ),
            )
          else if (pharmacy.phone.isNotEmpty)
            IconButton(
              tooltip: l.honamUiCall(pharmacy.name),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.accentPrimaryDark,
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.call_outlined, size: 20),
              onPressed: () => launchUrl(Uri.parse('tel:${pharmacy.phone}')),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: row,
      ),
    );
  }
}
