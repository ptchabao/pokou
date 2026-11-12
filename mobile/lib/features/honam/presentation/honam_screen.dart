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
import 'honam_controller.dart';
import 'honam_order_screen.dart';
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
  /// La pilule choisie. `null` tant que la personne n'a rien touché : on
  /// ouvre alors sur la première catégorie qui a quelque chose à montrer.
  HonamOrderFilter? _picked;

  void _openSend() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const HonamSendScreen()));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(honamOrdersProvider);
    final orders = async.valueOrNull ?? const <HonamOrder>[];
    final current = orders.where((o) => !o.isFinished).toList();
    final filter =
        _picked ??
        HonamOrderFilter.values.firstWhere(
          (f) => orders.any((o) => honamFilterOf(o) == f),
          orElse: () => HonamOrderFilter.toReceive,
        );

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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _SendHero(onSend: _openSend),
            ),
            _SectionTitle(l.honamMyOrders),
            if (async.hasValue)
              _Orders(
                orders: orders,
                filter: filter,
                onFilter: (f) => setState(() => _picked = f),
                onSend: _openSend,
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

/// « Mes commandes » : les pilules, puis les cartes de la catégorie choisie.
class _Orders extends StatelessWidget {
  const _Orders({
    required this.orders,
    required this.filter,
    required this.onFilter,
    required this.onSend,
  });

  final List<HonamOrder> orders;
  final HonamOrderFilter filter;
  final ValueChanged<HonamOrderFilter> onFilter;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Rien du tout : pas de pilules pour trier du vide, une scène qui invite.
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _FlatNotice(
          illustration: PokouIllustrations.delivery,
          title: l.honamUiEmptyTitle,
          message: l.honamUiEmptyBody,
          actionLabel: l.honamSend,
          onAction: onSend,
        ),
      );
    }
    final shown = orders.where((o) => honamFilterOf(o) == filter);
    // L'historique reste court : les dix dernières, comme avant.
    final visible = filter == HonamOrderFilter.toReceive
        ? shown.toList()
        : shown.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterPills(filter: filter, onFilter: onFilter),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _EmptyLine(switch (filter) {
              HonamOrderFilter.toReceive => l.honamUiEmptyTitle,
              HonamOrderFilter.completed => l.honamUiEmptyCompleted,
              HonamOrderFilter.cancelled => l.honamUiEmptyCancelled,
            }),
          )
        else
          for (final (index, order) in visible.indexed)
            Padding(
              padding: EdgeInsets.fromLTRB(16, index == 0 ? 0 : 10, 16, 0),
              child: HonamOrderCard(key: ValueKey(order.id), order: order),
            ),
      ],
    );
  }
}

/// À recevoir / Terminées / Annulées — la pilule active en fond plein.
class _FilterPills extends StatelessWidget {
  const _FilterPills({required this.filter, required this.onFilter});

  final HonamOrderFilter filter;
  final ValueChanged<HonamOrderFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (index, value) in HonamOrderFilter.values.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            _Pill(
              label: switch (value) {
                HonamOrderFilter.toReceive => l.honamUiFilterToReceive,
                HonamOrderFilter.completed => l.honamUiFilterCompleted,
                HonamOrderFilter.cancelled => l.honamUiFilterCancelled,
              },
              selected: value == filter,
              onTap: () => onFilter(value),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.actionButtonBackground : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.transparent : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppColors.actionButtonForeground
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Une commande dans une liste : une carte plate, en trois bandes.
///
/// 1. l'état, daté, et le numéro de la commande ;
/// 2. l'ordonnance — la pharmacie, le nombre d'articles, le prix — et, à la
///    demande, la course ;
/// 3. le total, et le chevron qui ouvre le détail.
///
/// L'état seul, jamais un nom de médicament (HON-04) : la liste se voit
/// par-dessus l'épaule. Les noms ne sont que dans le détail.
class HonamOrderCard extends StatefulWidget {
  const HonamOrderCard({super.key, required this.order});

  final HonamOrder order;

  @override
  State<HonamOrderCard> createState() => _HonamOrderCardState();
}

class _HonamOrderCardState extends State<HonamOrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = widget.order;
    final hasQuote = order.quoteItems.isNotEmpty;
    final hasDeliveryLine = order.deliveryPrice != null && order.total != null;
    final accent = AppColors.accentPrimaryDark;
    final footer = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: accent,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. L'état et le numéro.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Icon(
                    honamStatusIcon(order.status),
                    size: 18,
                    color: honamStatusColor(order),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      honamStatusPhrase(context, order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  HonamPill(
                    l.honamUiOrderNo('${order.id}'),
                    background: AppColors.surfaceElevated,
                    ink: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const HonamHairline(),
            // ── 2. L'ordonnance, et la course à la demande.
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                // « Voir plus » porte déjà sa propre hauteur de toucher.
                hasDeliveryLine && order.isFinished ? 2 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OrderLine(
                    thumb: const PokouIcon(PokouModuleIcon.honam),
                    title: order.pharmacy?.name ?? l.navHonam,
                    subtitle: l.honamUiPrescription,
                    quantity: hasQuote ? '×${honamItemsCount(order)}' : null,
                    price: order.medicinesTotal == null
                        ? null
                        : formatFcfa(order.medicinesTotal!),
                  ),
                  if (hasDeliveryLine && _expanded) ...[
                    const SizedBox(height: 12),
                    _OrderLine(
                      thumb: const PokouIcon(PokouModuleIcon.coursier),
                      title: l.honamDelivery,
                      subtitle: order.deliveryAddress,
                      price: formatFcfa(order.deliveryPrice!),
                    ),
                  ],
                  if (hasDeliveryLine)
                    _MoreToggle(
                      expanded: _expanded,
                      onTap: () => setState(() => _expanded = !_expanded),
                    ),
                  if (!order.isFinished) ...[
                    SizedBox(height: hasDeliveryLine ? 6 : 14),
                    _StepBar(order: order),
                  ],
                ],
              ),
            ),
            const HonamHairline(indent: 16),
            // ── 3. Le total, et l'accès au détail.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                children: [
                  if (order.total != null) ...[
                    Text(
                      l.honamUiItemsCount(honamItemsCount(order)),
                      style: footer,
                    ),
                    Container(
                      width: 1,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: Text(
                        formatFcfa(order.total!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: footer,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        order.status == 'SUBMITTED'
                            ? l.honamUiQuotePending
                            : l.honamUiSeeOrder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: footer,
                      ),
                    ),
                  Icon(Icons.chevron_right, color: accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de commande : vignette, nom sur une ligne, quantité en
/// pastille, prix à droite.
class _OrderLine extends StatelessWidget {
  const _OrderLine({
    required this.thumb,
    required this.title,
    required this.subtitle,
    this.quantity,
    this.price,
  });

  final Widget thumb;
  final String title;
  final String subtitle;
  final String? quantity;
  final String? price;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      HonamThumb(child: thumb),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (quantity != null) ...[
                        const SizedBox(width: 8),
                        HonamPill(quantity!),
                      ],
                    ],
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    price!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// « + Voir plus » / « − Voir moins », sous les lignes d'une commande.
class _MoreToggle extends StatelessWidget {
  const _MoreToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final accent = AppColors.accentPrimaryDark;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                expanded ? Icons.remove : Icons.add,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                expanded ? l.honamUiSeeLess : l.honamUiSeeMore,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les cinq temps d'une commande en cours, en un trait segmenté : envoyée,
/// devis, payée, en route, livrée.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final active = honamStepIndex(order.status);
    return Semantics(
      label: L.of(context).honamUiStepOf(active + 1, honamStepCount),
      child: Row(
        children: [
          for (var index = 0; index < honamStepCount; index++) ...[
            if (index > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: index <= active
                      ? AppColors.accentPrimaryDark
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
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

/// Une catégorie sans commande : une ligne discrète, pas une scène.
class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(Icons.inbox_outlined, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
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
