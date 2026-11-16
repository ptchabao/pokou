import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_halo.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../../modules/shared/module_ui.dart';
import '../data/marketplace_repository.dart';
import '../data/product_model.dart';
import 'assime_sheets.dart';
import 'marketplace_controller.dart';
import 'product_detail_screen.dart';

final favoritesProvider = FutureProvider.autoDispose<List<AssimeSnapshot>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).favorites(),
);

final _alertsProvider = FutureProvider.autoDispose<List<AssimeAlert>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).alerts(),
);

/// La place sponsorisée de la bande des statuts (Assimé 14), ou rien.
final sponsoredStatusProvider = FutureProvider.autoDispose<SponsoredStatus?>((
  ref,
) async {
  try {
    return await ref
        .watch(marketplaceRepositoryProvider)
        .sponsoredStatus(city: ref.watch(marketplaceLocationProvider));
  } catch (_) {
    return null;
  }
});

/// Ouvre la fiche d'une annonce dont on ne connaît que l'identifiant
/// (favori, statut sponsorisé) : la fiche complète vient du serveur.
Future<void> openAssimeProduct(
  BuildContext context,
  WidgetRef ref,
  int productId,
) async {
  final l = L.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final product = await ref
        .read(marketplaceRepositoryProvider)
        .product(productId);
    await navigator.push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.marketUnavailable)));
  }
}

// ── Assimé 12 · Favoris et alertes ───────────────────────────────────────

/// Une page, deux sections : les recherches enregistrées (bascule pour
/// couper une alerte sans la perdre) et les annonces favorites (une annonce
/// vendue reste, barrée, avec « Vendu »).
class FavoritesAlertsScreen extends ConsumerWidget {
  const FavoritesAlertsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final query = TextEditingController();
    final maxPrice = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.assimeNewAlert),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: query,
              autofocus: true,
              decoration: InputDecoration(labelText: l.assimeAlertQuery),
            ),
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: maxPrice,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.assimeAlertMaxPrice),
            ),
            const SizedBox(height: 8),
            Text(
              l.assimeAlertNote,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.actionSave),
          ),
        ],
      ),
    );
    final text = query.text;
    final price = int.tryParse(maxPrice.text.replaceAll(RegExp(r'\D'), ''));
    query.dispose();
    maxPrice.dispose();
    if (ok != true || text.trim().isEmpty) return;
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .createAlert(query: text, maxPrice: price);
      ref.invalidate(_alertsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final alerts = ref.watch(_alertsProvider);
    final favorites = ref.watch(favoritesProvider);
    return ModuleScaffold(
      title: l.assimeFavoritesAlerts,
      actions: [
        IconButton(
          tooltip: l.assimeNewAlert,
          icon: const Icon(Icons.add_alert_outlined),
          onPressed: () => _create(context, ref),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_alertsProvider);
          ref.invalidate(favoritesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            ModuleSectionTitle(l.assimeSavedSearches),
            alerts.when(
              loading: () => const SkeletonCards(),
              error: (_, _) => Text(l.modulesCheckNetwork),
              data: (items) => items.isEmpty
                  ? Text(
                      l.assimeNoAlerts,
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  : ModuleCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: AppColors.border),
                            _AlertRow(alert: items[i]),
                          ],
                        ],
                      ),
                    ),
            ),
            ModuleSectionTitle(l.assimeFavoriteListings),
            favorites.when(
              loading: () => const SkeletonCards(),
              error: (_, _) => Text(l.modulesCheckNetwork),
              data: (items) => items.isEmpty
                  ? Text(
                      l.assimeFavoritesHint,
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.72,
                      children: [
                        for (final item in items) _FavoriteCard(item: item),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.alert});

  final AssimeAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final title = [
      if (alert.query != null) '« ${alert.query} »',
      if (alert.category != null) alert.category!,
      if (alert.location != null) alert.location!,
      if (alert.maxPrice != null) l.assimeAlertUpTo('${alert.maxPrice}'),
    ].join(' · ');
    return Dismissible(
      key: ValueKey('alert-${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.feedbackDanger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        await ref.read(marketplaceRepositoryProvider).deleteAlert(alert.id);
        ref.invalidate(_alertsProvider);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    alert.paused
                        ? l.assimeAlertPaused
                        : l.assimeAlertFound(alert.matchesCount),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: !alert.paused,
              onChanged: (on) async {
                await ref
                    .read(marketplaceRepositoryProvider)
                    .setAlertPaused(alert.id, !on);
                ref.invalidate(_alertsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends ConsumerWidget {
  const _FavoriteCard({required this.item});

  final AssimeSnapshot item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final muted = TextStyle(fontSize: 11, color: AppColors.textSecondary);
    return ModuleCard(
      padding: EdgeInsets.zero,
      onTap: () => openAssimeProduct(context, ref, item.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: item.imageMediaId == null
                      ? ColoredBox(color: AppColors.surfaceElevated)
                      : MediaImage(
                          mediaId: item.imageMediaId!,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      await ref
                          .read(marketplaceRepositoryProvider)
                          .setFavorite(item.id, false);
                      ref.invalidate(favoritesProvider);
                    },
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.favorite,
                        size: 15,
                        color: AppColors.feedbackDanger,
                        semanticLabel: l.assimeRemoveFavorite,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.price} ${item.currency}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: item.sold ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  [
                    if (item.location != null) item.location!,
                    if (item.sold) l.assimeSoldBadge,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                Text(
                  item.sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assimé 16 · Pourquoi je vois ça ──────────────────────────────────────

/// Ce que la personne voit d'une annonce payée, et ce qu'elle peut en
/// faire : masquer l'annonce, ne plus voir le vendeur, la signaler.
Future<void> showWhySponsored(
  BuildContext context,
  WidgetRef ref, {
  required int productId,
  required int sellerId,
  String? whyText,
}) async {
  final l = L.of(context);
  var text = whyText;
  if (text == null) {
    try {
      text = await ref
          .read(marketplaceRepositoryProvider)
          .whySponsored(productId);
    } catch (_) {
      text = null;
    }
  }
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(marketplaceRepositoryProvider);
  final choice = await showModuleSheet<String>(
    context: context,
    builder: (sheetContext) {
      Widget row(IconData icon, String label, String value, {Color? color}) =>
          ListTile(
            leading: Icon(icon, color: color ?? AppColors.textPrimary),
            title: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.of(sheetContext).pop(value),
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuleSheetTitle(l.assimeWhyTitle, subtitle: text ?? l.assimeWhyNotSponsored),
          const SizedBox(height: 12),
          ModuleCallout(tone: CalloutTone.beige, text: l.assimeWhyPrivacy),
          const SizedBox(height: 12),
          ModuleCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  row(Icons.visibility_outlined, l.assimeHideListing, 'hide'),
                  row(Icons.block, l.assimeHideSeller, 'seller'),
                  row(
                    Icons.outlined_flag,
                    l.assimeReportListing,
                    'report',
                    color: AppColors.feedbackDanger,
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(l.actionClose),
          ),
        ],
      );
    },
  );
  try {
    switch (choice) {
      case 'hide':
        await repository.hideProduct(productId);
        messenger.showSnackBar(SnackBar(content: Text(l.assimeHidden)));
      case 'seller':
        await repository.hideSeller(sellerId);
        messenger.showSnackBar(SnackBar(content: Text(l.assimeSellerHidden)));
      case 'report':
        if (context.mounted) await showReportListing(context, ref, productId);
        return;
      default:
        return;
    }
    ref.read(marketplaceProductsProvider.notifier).invalidate();
    ref.invalidate(sponsoredStatusProvider);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
  }
}

// ── Assimé 17 · Bilan de la mise en avant ────────────────────────────────

final _boostReportProvider = FutureProvider.autoDispose
    .family<List<BoostReport>, int>(
      (ref, productId) =>
          ref.watch(marketplaceRepositoryProvider).boostReport(productId),
    );

/// Le bilan, pour le seul vendeur : avancement, quatre chiffres, vues par
/// jour (résultats et statuts).
class BoostReportScreen extends ConsumerWidget {
  const BoostReportScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  final int productId;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final report = ref.watch(_boostReportProvider(productId));
    final latest = report.valueOrNull?.firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ModuleScaffold(
        title: latest == null || latest.active
            ? l.assimeBoostRunning
            : l.assimeBoostEnded,
        subtitle: latest?.days == null
            ? productName
            : l.assimeBoostSub(productName, latest!.days!),
        child: report.when(
          loading: () => const SkeletonCards(),
          error: (_, _) => ModuleEmptyState(
            icon: Icons.cloud_off,
            title: l.honamFailed,
            message: l.modulesCheckNetwork,
          ),
          data: (items) {
            final b = items.firstOrNull;
            if (b == null) {
              return ModuleEmptyState(
                icon: Icons.campaign_outlined,
                title: l.assimeReportEmpty,
                message: '',
              );
            }
            final total = b.days ?? b.expiresAt.difference(b.startsAt).inDays;
            final day = (DateTime.now().difference(b.startsAt).inDays + 1)
                .clamp(1, total < 1 ? 1 : total);
            final end = DateFormat(
              'EEEE d MMM à HH:mm',
              locale,
            ).format(b.expiresAt.toLocal());
            Widget figure(String label, int value, [String? sub]) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                ModuleCard(
                  backgroundColor: AppColors.surfaceElevated,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.assimeBoostDayOf(day, total),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            l.assimeBoostEnds(end),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ModuleProgressBar(
                        value: total == 0 ? 1 : day / total,
                        color: AppColors.accentPrimary,
                        height: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: figure(l.assimeViewsResults, b.impressions)),
                    Expanded(child: figure(l.assimeViewsStatus, b.statusViews)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: figure(l.assimeOpens, b.opens)),
                    Expanded(
                      child: figure(
                        l.assimeMessagesReceived,
                        b.messages,
                        l.assimeMessagesBefore(b.messagesBefore),
                      ),
                    ),
                  ],
                ),
                if (b.statusModeration == 'PENDING') ...[
                  const SizedBox(height: 10),
                  ModuleCallout(tone: CalloutTone.amber, text: l.assimeStatusPending),
                ],
                if (b.statusModeration == 'REJECTED') ...[
                  const SizedBox(height: 10),
                  ModuleCallout(tone: CalloutTone.red, text: l.assimeStatusRejected),
                ],
                const SizedBox(height: 14),
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.assimeViewsPerDay,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _DailyChart(daily: b.daily, locale: locale),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Legend(color: AppColors.accentPrimary, label: l.assimeLegendResults),
                          const SizedBox(width: 12),
                          _Legend(color: AppColors.brandOr, label: l.assimeLegendStatus),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l.assimeBoostNote,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ModuleActionButton(
            label: l.assimeSeeListing,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
    ],
  );
}

/// Les barres jumelles du bilan : résultats en terre cuite, statuts en or.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.daily, required this.locale});

  final List<({DateTime day, int results, int status})> daily;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final max = daily.fold<int>(
      1,
      (m, d) => [m, d.results, d.status].reduce((a, b) => a > b ? a : b),
    );
    const height = 90.0;
    Widget bar(int value, Color color) => Container(
      width: 8,
      height: value == 0 ? 2 : height * value / max,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return SizedBox(
      height: height + 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final d in daily.length > 7 ? daily.sublist(daily.length - 7) : daily)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    bar(d.results, AppColors.accentPrimary),
                    const SizedBox(width: 3),
                    bar(d.status, AppColors.brandOr),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.E(locale).format(d.day),
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Assimé 14-15 · Statut sponsorisé ─────────────────────────────────────

/// La place sponsorisée dans la bande des statuts : un halo doré, toujours
/// dite « Sponsorisé », jamais déguisée en statut d'un ami.
class SponsoredStatusTile extends ConsumerWidget {
  const SponsoredStatusTile({super.key, required this.sponsored});

  final SponsoredStatus sponsored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return Semantics(
      button: true,
      label: '${l.assimeSponsored} · ${sponsored.product.name}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => SponsoredStatusViewer(sponsored: sponsored),
          ),
        ),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              StatusHalo(
                size: 60,
                thickness: 3,
                seen: true,
                seenColor: AppColors.brandOr,
                child: ClipOval(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: sponsored.product.imageMediaId == null
                        ? Container(
                            color: AppColors.surface,
                            child: const PokouIcon(PokouModuleIcon.assime),
                          )
                        : MediaImage(
                            mediaId: sponsored.product.imageMediaId!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.assimeSponsored,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Assimé 15 · le statut sponsorisé en plein écran : la photo, le vendeur
/// et « Sponsorisé », « Voir l'annonce » et « Écrire ». Toucher à droite
/// passe au statut suivant ; le ⋮ ouvre « Pourquoi je vois ça ».
class SponsoredStatusViewer extends ConsumerStatefulWidget {
  const SponsoredStatusViewer({super.key, required this.sponsored});

  final SponsoredStatus sponsored;

  @override
  ConsumerState<SponsoredStatusViewer> createState() =>
      _SponsoredStatusViewerState();
}

class _SponsoredStatusViewerState extends ConsumerState<SponsoredStatusViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..forward();

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _seeListing() async {
    _progress.stop();
    final repository = ref.read(marketplaceRepositoryProvider);
    repository.countSponsoredOpen(widget.sponsored.boostId).ignore();
    await openAssimeProduct(context, ref, widget.sponsored.product.id);
  }

  Future<void> _write() async {
    _progress.stop();
    final product = widget.sponsored.product;
    final myUserId = ref.read(authControllerProvider).user?.id;
    ref
        .read(marketplaceRepositoryProvider)
        .countSponsoredContact(widget.sponsored.boostId)
        .ignore();
    if (myUserId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          myUserId: myUserId,
          contactUserId: product.sellerId,
          contactName: product.sellerName,
          product: MarketplaceProduct(
            id: product.id,
            sellerId: product.sellerId,
            sellerName: product.sellerName,
            name: product.name,
            description: null,
            price: product.price,
            currency: product.currency,
            location: product.location,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final product = widget.sponsored.product;
    final initials = product.sellerName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    const white = TextStyle(color: Colors.white);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (details.localPosition.dx > MediaQuery.sizeOf(context).width / 2) {
            Navigator.of(context).maybePop();
          }
        },
        onLongPressStart: (_) => _progress.stop(),
        onLongPressEnd: (_) => _progress.forward(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (_, _) => LinearProgressIndicator(
                    value: _progress.value,
                    minHeight: 2.5,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: l.actionClose,
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.sellerName,
                          style: white.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandOr,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.assimeSponsored,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.assimeWhyTitle,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () async {
                      _progress.stop();
                      await showWhySponsored(
                        context,
                        ref,
                        productId: product.id,
                        sellerId: product.sellerId,
                        whyText: widget.sponsored.why,
                      );
                      if (mounted) _progress.forward();
                    },
                  ),
                ],
              ),
              Expanded(
                child: product.imageMediaId == null
                    ? const Center(
                        child: PokouIcon(PokouModuleIcon.assime, size: 64),
                      )
                    : MediaImage(
                        mediaId: product.imageMediaId!,
                        fit: BoxFit.contain,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.name} · ${product.price} ${product.currency}',
                      style: white.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      [
                        if (product.location != null) product.location!,
                        l.assimeAdAssime,
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(0, 46),
                            ),
                            onPressed: _seeListing,
                            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                            label: Text(l.assimeSeeListing),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              minimumSize: const Size(0, 46),
                            ),
                            onPressed: _write,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(l.assimeWrite),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.assimeNextHint,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
