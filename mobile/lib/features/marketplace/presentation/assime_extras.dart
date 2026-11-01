import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/status_halo.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/presentation/conversation_screen.dart';
import '../../modules/shared/module_ui.dart';
import '../data/marketplace_repository.dart';
import 'marketplace_controller.dart';

final favoritesProvider = FutureProvider.autoDispose<List<AssimeSnapshot>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).favorites(),
);

final _alertsProvider = FutureProvider.autoDispose<List<AssimeAlert>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).alerts(),
);

/// La place sponsorisée de la bande des statuts (Assimé 14), ou rien.
final sponsoredStatusProvider = FutureProvider.autoDispose<SponsoredStatus?>((ref) async {
  try {
    return await ref
        .watch(marketplaceRepositoryProvider)
        .sponsoredStatus(city: ref.watch(marketplaceLocationProvider));
  } catch (_) {
    return null;
  }
});

/// Favoris et alertes (maquette Assimé 12).
class FavoritesAlertsScreen extends ConsumerWidget {
  const FavoritesAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return DefaultTabController(
      length: 2,
      child: ModuleScaffold(
        title: l.assimeFavoritesAlerts,
        child: Column(
          children: [
            TabBar(tabs: [Tab(text: l.assimeFavorites), Tab(text: l.assimeAlerts)]),
            const Expanded(child: TabBarView(children: [_Favorites(), _Alerts()])),
          ],
        ),
      ),
    );
  }
}

class _Favorites extends ConsumerWidget {
  const _Favorites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return ref.watch(favoritesProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ModuleEmptyState(icon: Icons.cloud_off, title: l.honamFailed, message: l.modulesCheckNetwork),
      data: (items) => items.isEmpty
          ? ModuleEmptyState(icon: Icons.favorite_border, title: l.assimeNoFavorites, message: l.assimeFavoritesHint)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _Thumb(mediaId: item.imageMediaId),
                    title: Text(item.name),
                    subtitle: Text('${item.price} ${item.currency}${item.location != null ? ' · ${item.location}' : ''}'),
                    trailing: IconButton(
                      tooltip: l.assimeRemoveFavorite,
                      icon: const Icon(Icons.favorite, color: AppColors.feedbackDanger),
                      onPressed: () async {
                        await ref.read(marketplaceRepositoryProvider).setFavorite(item.id, false);
                        ref.invalidate(favoritesProvider);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Alerts extends ConsumerWidget {
  const _Alerts();

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
            TextField(controller: query, autofocus: true, decoration: InputDecoration(labelText: l.assimeAlertQuery)),
            TextField(
              controller: maxPrice,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.assimeAlertMaxPrice),
            ),
            const SizedBox(height: 8),
            Text(l.assimeAlertNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l.actionSave)),
        ],
      ),
    );
    final text = query.text;
    final price = int.tryParse(maxPrice.text.replaceAll(RegExp(r'\D'), ''));
    query.dispose();
    maxPrice.dispose();
    if (ok != true || text.trim().isEmpty) return;
    try {
      await ref.read(marketplaceRepositoryProvider).createAlert(query: text, maxPrice: price);
      ref.invalidate(_alertsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return ref.watch(_alertsProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ModuleEmptyState(icon: Icons.cloud_off, title: l.honamFailed, message: l.modulesCheckNetwork),
      data: (alerts) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ModuleActionButton(
            label: l.assimeNewAlert,
            icon: Icons.notifications_active_outlined,
            onPressed: () => _create(context, ref),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty) Text(l.assimeNoAlerts, style: TextStyle(color: AppColors.textSecondary)),
          for (final alert in alerts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined),
              title: Text(alert.query ?? alert.category ?? ''),
              subtitle: Text([
                if (alert.maxPrice != null) l.assimeAlertUpTo('${alert.maxPrice}'),
                l.assimeAlertMatches('${alert.matchesCount}'),
              ].join(' · ')),
              trailing: IconButton(
                tooltip: l.actionDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(marketplaceRepositoryProvider).deleteAlert(alert.id);
                  ref.invalidate(_alertsProvider);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.mediaId, this.size = 48});

  final int? mediaId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: mediaId == null
            ? Container(color: AppColors.surface, child: const Icon(Icons.image_outlined))
            : MediaImage(mediaId: mediaId!, fit: BoxFit.cover),
      ),
    );
  }
}

/// « Pourquoi je vois ça » (Assimé 16).
Future<void> showWhySponsored(BuildContext context, WidgetRef ref, int productId) async {
  final l = L.of(context);
  String? text;
  try {
    text = await ref.read(marketplaceRepositoryProvider).whySponsored(productId);
  } catch (_) {
    text = null;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.assimeWhyTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(text ?? l.assimeWhyNotSponsored),
          ],
        ),
      ),
    ),
  );
}

final _boostReportProvider = FutureProvider.autoDispose.family<List<BoostReport>, int>(
  (ref, productId) => ref.watch(marketplaceRepositoryProvider).boostReport(productId),
);

/// Le bilan de la mise en avant (Assimé 17), pour le seul vendeur.
class BoostReportScreen extends ConsumerWidget {
  const BoostReportScreen({super.key, required this.productId, required this.productName});

  final int productId;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final report = ref.watch(_boostReportProvider(productId));
    return ModuleScaffold(
      title: l.assimeReportTitle,
      subtitle: productName,
      child: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(icon: Icons.cloud_off, title: l.honamFailed, message: l.modulesCheckNetwork),
        data: (items) => items.isEmpty
            ? ModuleEmptyState(icon: Icons.campaign_outlined, title: l.assimeReportEmpty, message: '')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final b in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ModuleCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.assimeReportPeriod(
                                '${b.days ?? '?'}',
                                DateFormat.MMMd(locale).format(b.startsAt.toLocal()),
                                DateFormat.MMMd(locale).format(b.expiresAt.toLocal()),
                              ),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(l.assimeReportImpressions('${b.impressions}')),
                            if (b.days == 7) Text(l.assimeReportStatusViews('${b.statusViews}')),
                            Text(l.assimeReportContacts('${b.contacts}')),
                            if (b.statusModeration == 'PENDING')
                              Text(l.assimeStatusPending, style: const TextStyle(color: AppColors.feedbackWarning)),
                            if (b.statusModeration == 'REJECTED')
                              Text(l.assimeStatusRejected, style: const TextStyle(color: AppColors.feedbackDanger)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// La place sponsorisée dans la bande des statuts : toujours dite
/// « Sponsorisé », jamais déguisée en statut d'un ami.
class SponsoredStatusTile extends ConsumerWidget {
  const SponsoredStatusTile({super.key, required this.sponsored});

  final SponsoredStatus sponsored;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final product = sponsored.product;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Thumb(mediaId: product.imageMediaId, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.assimeSponsored, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(product.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        Text('${product.price} ${product.currency}'),
                        Text(product.sellerName, style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ModuleActionButton(
                label: l.productDiscuss,
                icon: Icons.chat_bubble_outline,
                onPressed: () async {
                  final repository = ref.read(marketplaceRepositoryProvider);
                  final myUserId = ref.read(authControllerProvider).user?.id;
                  Navigator.pop(sheetContext);
                  try {
                    await repository.countSponsoredContact(sponsored.boostId);
                    await repository.shareProduct(productId: product.id);
                  } catch (_) {
                    // La discussion s'ouvre quand même : le vendeur reste
                    // joignable même si la fiche n'a pas pu être épinglée.
                  }
                  if (!context.mounted || myUserId == null) return;
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ConversationScreen(
                      myUserId: myUserId,
                      contactUserId: product.sellerId,
                      contactName: product.sellerName,
                    ),
                  ));
                },
              ),
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: sheetContext,
                  backgroundColor: AppColors.surface,
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.assimeWhyTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(sponsored.why),
                        ],
                      ),
                    ),
                  ),
                ),
                child: Text(l.assimeWhyTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return Semantics(
      button: true,
      label: '${l.assimeSponsored} · ${sponsored.product.name}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _open(context, ref),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              StatusHalo(
                size: 60,
                thickness: 3,
                seenColor: AppColors.border,
                seen: true,
                child: ClipOval(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: sponsored.product.imageMediaId == null
                        ? Container(color: AppColors.surface, child: const Icon(Icons.storefront_outlined))
                        : MediaImage(mediaId: sponsored.product.imageMediaId!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.assimeSponsored,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
