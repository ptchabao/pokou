import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../modules/shared/module_ui.dart';
import '../data/product_model.dart';
import 'assime_sale_screens.dart';
import 'marketplace_actions.dart';
import 'marketplace_controller.dart';
import 'product_detail_screen.dart';

/// Les trois onglets de « Mes annonces » (Assimé 9).
///
/// Une annonce retirée par la modération reste sous « En ligne », avec son
/// encart : c'est le seul endroit où le vendeur l'apprend.
enum _Tab { online, sold, expired }

_Tab _tabOf(MarketplaceProduct p) {
  if (p.soldAt != null) return _Tab.sold;
  if (p.isExpired) return _Tab.expired;
  return _Tab.online;
}

/// Assimé 9 · Mes annonces : en ligne, vendues, expirées ; vues, favoris et
/// messages de chaque annonce ; « Marquer vendue », « Modifier »,
/// « Renouveler », « Mettre en avant » ; « Publier une annonce » en bas.
class MyCatalogScreen extends ConsumerStatefulWidget {
  const MyCatalogScreen({super.key});

  @override
  ConsumerState<MyCatalogScreen> createState() => _MyCatalogScreenState();
}

class _MyCatalogScreenState extends ConsumerState<MyCatalogScreen>
    with MarketplaceActions<MyCatalogScreen> {
  _Tab _tab = _Tab.online;

  Future<void> _renew(MarketplaceProduct product) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(marketplaceRepositoryProvider).renew(product.id);
      ref.invalidate(myProductsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l.assimeRenewed)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.koryActionFailed)));
    }
  }

  Future<void> _markSold(MarketplaceProduct product) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssimeMarkSoldScreen(product: product)),
    );
    if (done == true) ref.invalidate(myProductsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final mine = ref.watch(myProductsProvider);
    final me = ref.watch(authControllerProvider).user?.fullName ?? '';
    final products = mine.valueOrNull ?? const <MarketplaceProduct>[];
    int count(_Tab tab) => products.where((p) => _tabOf(p) == tab).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ModuleScaffold(
        title: l.assimeMyListings,
        subtitle: l.assimeMyListingsSub(me, products.length),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final (tab, label) in [
                      (_Tab.online, l.assimeTabOnline(count(_Tab.online))),
                      (_Tab.sold, l.assimeTabSold(count(_Tab.sold))),
                      (_Tab.expired, l.assimeTabExpired(count(_Tab.expired))),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _tab == tab,
                        showCheckmark: false,
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.accentPrimary,
                        side: BorderSide(
                          color: _tab == tab
                              ? AppColors.accentPrimary
                              : AppColors.border,
                        ),
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                          color: _tab == tab
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setState(() => _tab = tab),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myProductsProvider);
                  await ref.read(myProductsProvider.future);
                },
                child: mine.when(
                  loading: () => const SkeletonCards(),
                  error: (_, _) => ListView(
                    children: [
                      ModuleEmptyState(
                        icon: Icons.cloud_off,
                        title: l.marketUnavailable,
                        message: l.modulesCheckNetwork,
                      ),
                    ],
                  ),
                  data: (items) {
                    final visible = items
                        .where((p) => _tabOf(p) == _tab)
                        .toList();
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              l.assimeNoneInTab,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        for (final p in visible) ...[
                          _ListingRow(
                            product: p,
                            boosting: boostingProductIds.contains(p.id),
                            onEdit: () => editProduct(context, ref, product: p),
                            onMarkSold: () => _markSold(p),
                            onRenew: () => _renew(p),
                            onBoost: () => boostProduct(context, ref, p),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (items.isNotEmpty)
                          Text(
                            l.assimeStatsPrivate,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ModuleActionButton(
            label: l.assimePublishCta,
            icon: Icons.add,
            onPressed: () => editProduct(context, ref),
          ),
        ),
      ),
    );
  }
}

/// Une annonce : vignette, titre et badge, prix, chiffres, et les deux
/// actions que son état appelle.
class _ListingRow extends StatelessWidget {
  const _ListingRow({
    required this.product,
    required this.boosting,
    required this.onEdit,
    required this.onMarkSold,
    required this.onRenew,
    required this.onBoost,
  });

  final MarketplaceProduct product;
  final bool boosting;
  final VoidCallback onEdit;
  final VoidCallback onMarkSold;
  final VoidCallback onRenew;
  final VoidCallback onBoost;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final stats = product.stats;
    final now = DateTime.now();
    final tab = _tabOf(product);
    final boostEnd = stats?.boostExpiresAt;
    final daysLeft = product.expiresAt?.difference(now).inDays;
    final (String badge, Color ink, Color bg) = switch (tab) {
      _Tab.sold => (
        l.assimeBadgeSold,
        AppColors.feedbackSuccess,
        AppColors.feedbackSuccess.withValues(alpha: 0.12),
      ),
      _Tab.expired => (
        l.assimeBadgeExpired,
        AppColors.textSecondary,
        AppColors.surfaceElevated,
      ),
      _ when boostEnd != null => (
        l.assimeBadgeSponsored(boostEnd.difference(now).inDays + 1),
        AppColors.textPrimary,
        AppColors.brandOr.withValues(alpha: 0.22),
      ),
      _ when daysLeft != null && daysLeft < 5 => (
        l.assimeBadgeExpiresIn(daysLeft + 1),
        AppColors.feedbackDanger,
        AppColors.feedbackDanger.withValues(alpha: 0.1),
      ),
      _ => (
        l.assimeBadgeOnline,
        AppColors.feedbackSuccess,
        AppColors.feedbackSuccess.withValues(alpha: 0.12),
      ),
    };
    final expiresSoon =
        tab == _Tab.expired ||
        (tab == _Tab.online && daysLeft != null && daysLeft < 5);
    final image = product.coverImage;
    return ModuleCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: image == null
                      ? ColoredBox(
                          color: AppColors.surfaceElevated,
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.textMuted,
                          ),
                        )
                      : MediaImage.meta(image, decodeWidth: 64),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text('${product.price} ${product.currency}'),
                    if (stats != null)
                      Text(
                        l.assimeStatsLine(
                          stats.views,
                          stats.favorites,
                          stats.contacts,
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!product.isActive) ...[
            const SizedBox(height: 8),
            ModuleCallout(
              tone: CalloutTone.amber,
              title: l.marketStatusModerated,
              text: l.marketStatusModeratedBody,
            ),
          ],
          if (tab != _Tab.sold) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (expiresSoon)
                  _RowAction(label: l.assimeRenew, filled: true, onTap: onRenew)
                else
                  _RowAction(label: l.assimeMarkSold, onTap: onMarkSold),
                if (tab == _Tab.online && boostEnd == null && product.isActive)
                  _RowAction(
                    label: l.assimePromote,
                    onTap: boosting ? null : onBoost,
                  )
                else
                  _RowAction(label: l.conversationEdit, onTap: onEdit),
                if (tab == _Tab.online && boostEnd == null && product.isActive)
                  _RowAction(label: l.conversationEdit, onTap: onEdit),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: filled ? Colors.white : AppColors.accentPrimary,
      backgroundColor: filled ? AppColors.accentPrimary : null,
      side: BorderSide(color: AppColors.accentPrimary),
      shape: const StadiumBorder(),
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
    );
    return OutlinedButton(onPressed: onTap, style: style, child: Text(label));
  }
}
