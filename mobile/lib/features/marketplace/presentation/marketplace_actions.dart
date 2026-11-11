import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';
import 'product_editor.dart';

/// Les trois gestes qu'un vendeur pose sur sa propre annonce : la modifier,
/// la retirer, la booster.
///
/// Ils vivaient dans l'état de l'écran du marché. La page « Mon catalogue »
/// pose exactement les mêmes, sur les mêmes produits, avec les mêmes
/// invalidations de cache derrière — les recopier aurait garanti qu'un jour
/// l'un des deux écrans oublie d'invalider, et affiche un prix périmé après
/// modification.
///
/// C'est un `mixin` et non trois fonctions libres parce que le boost a besoin
/// d'un état local : le temps que le paiement Mobile Money aboutisse, le
/// bouton doit rester désarmé sur CE produit-là, et lui seul.
mixin MarketplaceActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Les produits dont le paiement de boost est en cours. Un `Set` et non un
  /// booléen : le vendeur peut lancer un second boost pendant que le premier
  /// attend sa confirmation, et seul le bouton concerné doit se figer.
  final Set<int> boostingProductIds = {};

  /// Retirer une de ses annonces.
  ///
  /// Le geste n'existait NULLE PART : le dépôt savait appeler la route, et
  /// aucun écran ne l'appelait. Un vendeur ne pouvait pas retirer un produit
  /// vendu ou publié par erreur.
  ///
  /// La confirmation dit ce qui se passe RÉELLEMENT côté serveur — l'annonce
  /// sort du marché, les conversations qui la citent restent lisibles. Sans
  /// cette phrase, on hésite à supprimer de peur de casser une discussion en
  /// cours avec un acheteur.
  Future<void> deleteProduct(
    BuildContext context,
    WidgetRef ref,
    MarketplaceProduct product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).marketRemoveProduct(product.name)),
        content: Text(L.of(context).marketRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(context).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              L.of(context).marketRemove,
              style: TextStyle(color: AppColors.semanticError),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(marketplaceRepositoryProvider).delete(product.id);
      ref.invalidate(myProductsProvider);
      ref.invalidate(marketplaceProductsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).marketRemoveFailed)),
        );
      }
    }
  }

  Future<void> editProduct(
    BuildContext context,
    WidgetRef ref, {
    MarketplaceProduct? product,
  }) async {
    final repo = ref.read(marketplaceRepositoryProvider);
    // L'envoi se fait DEPUIS le formulaire, qui reste ouvert tant que le
    // serveur n'a pas accepté l'annonce (voir ProductEditor.onSubmit).
    final saved = await Navigator.of(context).push<ProductDraft>(
      MaterialPageRoute(
        builder: (_) => ProductEditor(
          product: product,
          onSubmit: (result) async {
            if (product == null) {
              await repo.create(
                name: result.name,
                description: result.description,
                category: result.category,
                location: result.location,
                latitude: result.latitude,
                longitude: result.longitude,
                price: result.price,
                currency: result.currency,
                imageMediaId: result.imageMediaId,
                galleryMediaIds: result.galleryMediaIds,
              );
            } else {
              await repo.update(
                id: product.id,
                name: result.name,
                description: result.description,
                category: result.category,
                location: result.location,
                latitude: result.latitude,
                longitude: result.longitude,
                price: result.price,
                currency: result.currency,
                imageMediaId: result.imageMediaId,
                galleryMediaIds: result.galleryMediaIds,
              );
            }
          },
        ),
      ),
    );
    if (saved == null) return;
    ref.read(marketplaceProductsProvider.notifier).invalidate();
    ref.invalidate(myProductsProvider);
  }

  Future<void> boostProduct(
    BuildContext context,
    WidgetRef ref,
    MarketplaceProduct product,
  ) async {
    if (boostingProductIds.contains(product.id)) return;
    // 3 jours : en tête des résultats ; 7 jours : résultats et bande des
    // statuts (maquette Assimé 10).
    final l = L.of(context);
    final days = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l.marketBoost,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: Text(l.marketBoost3),
              onTap: () => Navigator.pop(sheetContext, 3),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text(l.marketBoost7),
              onTap: () => Navigator.pop(sheetContext, 7),
            ),
          ],
        ),
      ),
    );
    if (days == null || !mounted) return;
    setState(() => boostingProductIds.add(product.id));
    try {
      final payment = await ref
          .read(marketplaceRepositoryProvider)
          .boostProduct(product.id, days: days);
      final paymentId = payment['payment_id'] as int?;
      final paymentUrl = payment['payment_url'] as String?;
      if (paymentId == null || paymentUrl == null || paymentUrl.isEmpty) {
        throw StateError(L.of(context).marketPaymentUnavailable);
      }
      final launched = await launchUrl(
        Uri.parse(paymentUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw StateError(L.of(context).marketCheckoutUnreachable);

      var status = 'pending';
      for (var attempt = 0; attempt < 30 && status == 'pending'; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        status = await ref
            .read(marketplaceRepositoryProvider)
            .marketplacePaymentStatus(paymentId);
      }
      if (!mounted) return;
      if (status == 'confirmed') {
        ref.read(marketplaceProductsProvider.notifier).invalidate();
        ref.invalidate(myProductsProvider);
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).marketBoostDone)));
      } else {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text(L.of(context).marketBoostPending)),
        );
      }
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).marketBoostFailed)),
        );
    } finally {
      if (mounted) setState(() => boostingProductIds.remove(product.id));
    }
  }
}
