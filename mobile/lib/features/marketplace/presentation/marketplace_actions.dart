import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/product_model.dart';
import '../../modules/shared/module_ui.dart';
import 'assime_promote.dart';
import 'assime_sale_screens.dart';
import 'marketplace_controller.dart';
import 'product_editor.dart';

/// Assimé 24 · Supprimer l'annonce : trois motifs, un bouton rouge.
class _DeleteSheet extends StatefulWidget {
  const _DeleteSheet();

  @override
  State<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends State<_DeleteSheet> {
  String _reason = 'not_selling';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget option(String value, String title, [String? subtitle]) {
      final selected = _reason == value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? AppColors.accentPrimary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: RadioListTile<String>(
            value: value,
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: subtitle == null ? null : Text(subtitle),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: ModuleSheetTitle(l.assimeDeleteTitle)),
            IconButton(
              tooltip: l.actionClose,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        RadioGroup<String>(
          groupValue: _reason,
          onChanged: (v) => setState(() => _reason = v ?? _reason),
          child: Column(
            children: [
              option('not_selling', l.assimeDeleteNotSelling),
              option(
                'sold_pokou',
                l.assimeDeleteSoldPokou,
                l.assimeDeleteSoldPokouSub,
              ),
              option('sold_elsewhere', l.assimeDeleteSoldElsewhere),
            ],
          ),
        ),
        Text(
          l.assimeDeleteNote,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.feedbackDanger,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.of(context).pop(_reason),
          child: Text(l.assimeDeleteAction),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionCancel),
        ),
      ],
    );
  }
}

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
  ///
  /// Assimé 24 : la feuille demande pourquoi. « Vendue sur Pokou » ouvre
  /// « Marquer comme vendue » pour que l'acheteur puisse noter ; « Vendue
  /// ailleurs » la marque vendue sans acheteur — elle rejoint « Vendues »
  /// au lieu de disparaître. Rend `true` si l'annonce a quitté le marché.
  Future<bool> deleteProduct(
    BuildContext context,
    WidgetRef ref,
    MarketplaceProduct product,
  ) async {
    final reason = await showModuleSheet<String>(
      context: context,
      builder: (_) => const _DeleteSheet(),
    );
    if (reason == null || !context.mounted) return false;
    final repository = ref.read(marketplaceRepositoryProvider);
    try {
      switch (reason) {
        case 'sold_pokou':
          final done = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AssimeMarkSoldScreen(product: product),
            ),
          );
          if (done != true) return false;
        case 'sold_elsewhere':
          await repository.markSold(product.id);
        default:
          await repository.delete(product.id);
      }
      ref.invalidate(myProductsProvider);
      ref.read(marketplaceProductsProvider.notifier).invalidate();
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).marketRemoveFailed)),
        );
      }
      return false;
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
          // Assimé 23 : « Supprimer l'annonce » sous le formulaire.
          onDelete: product == null
              ? null
              : (editorContext) => deleteProduct(editorContext, ref, product),
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
                condition: result.condition,
                negotiable: result.negotiable,
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
                condition: result.condition,
                negotiable: result.negotiable,
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
    final days = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => AssimePromoteScreen(product: product)),
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
