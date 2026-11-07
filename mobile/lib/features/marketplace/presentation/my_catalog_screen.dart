import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/product_model.dart';
import 'marketplace_actions.dart';
import 'marketplace_controller.dart';
import 'product_detail_screen.dart';
import '../../modules/shared/module_ui.dart';
import 'assime_sale_screens.dart';

/// Le filtre du catalogue.
///
/// « Retirées » n'est pas une coquetterie : c'est le seul endroit de
/// l'application où un vendeur apprend que la modération a sorti une de ses
/// annonces du marché. Le serveur renvoyait déjà `is_active` sur
/// `GET /marketplace/mine`, et aucun écran ne le lisait — l'annonce
/// disparaissait de la liste publique sans que son propriétaire en sache
/// jamais rien.
enum _CatalogFilter { toutes, enLigne, boostees, retirees }

/// « Mon catalogue » — la page de gestion, derrière le chevron de l'écran
/// du marché.
///
/// La bande horizontale de l'accueil montre les annonces ; elle ne permet
/// pas de les GÉRER. Ses cartes font 150 points de large, ce qui réduit
/// « modifier » et « retirer » à deux carrés de 32 points — sous le seuil
/// tactile recommandé, compromis assumé là-bas parce que la bande est une
/// vitrine. Ici il y a toute la largeur, donc les actions reprennent leur
/// taille normale et leur libellé.
class MyCatalogScreen extends ConsumerStatefulWidget {
  const MyCatalogScreen({super.key});

  @override
  ConsumerState<MyCatalogScreen> createState() => _MyCatalogScreenState();
}

class _MyCatalogScreenState extends ConsumerState<MyCatalogScreen>
    with MarketplaceActions<MyCatalogScreen> {
  _CatalogFilter _filtre = _CatalogFilter.toutes;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final mine = ref.watch(myProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PokouAppBar(
        title: l.marketMyCatalogue,
        showStatus: false,
        leading: const PokouBackButton(),
        actions: [
          PokouAppBarAction(
            icon: Icons.add,
            tooltip: l.marketAddProduct,
            onPressed: () => editProduct(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProductsProvider);
          await ref.read(myProductsProvider.future);
        },
        child: mine.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Message(texte: l.marketUnavailable),
          data: (produits) => _Liste(
            produits: produits,
            filtre: _filtre,
            onFiltre: (valeur) => setState(() => _filtre = valeur),
            onEdit: (p) => editProduct(context, ref, product: p),
            onDelete: (p) => deleteProduct(context, ref, p),
            onBoost: (p) => boostProduct(context, ref, p),
            enCoursDeBoost: boostingProductIds,
          ),
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.produits,
    required this.filtre,
    required this.onFiltre,
    required this.onEdit,
    required this.onDelete,
    required this.onBoost,
    required this.enCoursDeBoost,
  });

  final List<MarketplaceProduct> produits;
  final _CatalogFilter filtre;
  final ValueChanged<_CatalogFilter> onFiltre;
  final void Function(MarketplaceProduct) onEdit;
  final void Function(MarketplaceProduct) onDelete;
  final void Function(MarketplaceProduct) onBoost;
  final Set<int> enCoursDeBoost;

  List<MarketplaceProduct> get _visibles => switch (filtre) {
    _CatalogFilter.toutes => produits,
    _CatalogFilter.enLigne => produits.where((p) => p.isActive).toList(),
    _CatalogFilter.boostees => produits.where((p) => p.isBoosted).toList(),
    _CatalogFilter.retirees => produits.where((p) => !p.isActive).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final visibles = _visibles;
    final retirees = produits.where((p) => !p.isActive).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Resume(
          total: produits.length,
          enLigne: produits.where((p) => p.isActive).length,
          boostees: produits.where((p) => p.isBoosted).length,
        ),
        const SizedBox(height: 14),
        _Filtres(
          actif: filtre,
          onChange: onFiltre,
          // Le filtre « Retirées » n'apparaît que s'il a quelque chose à
          // montrer : sur un catalogue sain, il ne ferait qu'inquiéter.
          avecRetirees: retirees > 0,
        ),
        const SizedBox(height: 14),
        if (produits.isEmpty)
          _Vide(
            titre: l.marketCatalogueEmpty,
            corps: l.marketCatalogueEmptyBody,
          )
        else if (visibles.isEmpty)
          _Message(texte: l.marketCatalogueNoneInFilter)
        else
          for (final produit in visibles) ...[
            _LigneProduit(
              produit: produit,
              onEdit: () => onEdit(produit),
              onDelete: () => onDelete(produit),
              onBoost: produit.isBoosted || enCoursDeBoost.contains(produit.id)
                  ? null
                  : () => onBoost(produit),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// Les trois chiffres du catalogue, en Outfit comme tous les nombres.
class _Resume extends StatelessWidget {
  const _Resume({
    required this.total,
    required this.enLigne,
    required this.boostees,
  });

  final int total;
  final int enLigne;
  final int boostees;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Chiffre(valeur: total, libelle: l.marketCatalogueTotal),
          ),
          _Separateur(),
          Expanded(
            child: _Chiffre(valeur: enLigne, libelle: l.marketCatalogueOnline),
          ),
          _Separateur(),
          Expanded(
            child: _Chiffre(
              valeur: boostees,
              libelle: l.marketCatalogueBoostedLabel,
              couleur: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Separateur extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: VerticalDivider(color: AppColors.border, width: 1),
  );
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.valeur, required this.libelle, this.couleur});

  final int valeur;
  final String libelle;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$valeur',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: couleur ?? AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          libelle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Filtres extends StatelessWidget {
  const _Filtres({
    required this.actif,
    required this.onChange,
    required this.avecRetirees,
  });

  final _CatalogFilter actif;
  final ValueChanged<_CatalogFilter> onChange;
  final bool avecRetirees;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final entrees = <(_CatalogFilter, String)>[
      (_CatalogFilter.toutes, l.marketFilterAll),
      (_CatalogFilter.enLigne, l.marketCatalogueOnline),
      (_CatalogFilter.boostees, l.marketCatalogueBoostedLabel),
      if (avecRetirees) (_CatalogFilter.retirees, l.marketCatalogueWithdrawn),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entrees.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (valeur, libelle) = entrees[index];
          final selectionne = valeur == actif;
          return ChoiceChip(
            label: Text(libelle),
            selected: selectionne,
            backgroundColor: AppColors.surfaceElevated,
            selectedColor: AppColors.accentPrimaryDark,
            showCheckmark: false,
            side: BorderSide(
              color: selectionne
                  ? AppColors.accentPrimaryDark
                  : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            labelStyle: TextStyle(
              color: selectionne ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500,
            ),
            onSelected: (_) => onChange(valeur),
          );
        },
      ),
    );
  }
}

/// Une annonce, sur toute la largeur : vignette, prix, état, et les trois
/// actions en toutes lettres.
class _LigneProduit extends ConsumerWidget {
  const _LigneProduit({
    required this.produit,
    required this.onEdit,
    required this.onDelete,
    required this.onBoost,
  });

  final MarketplaceProduct produit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onBoost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: produit),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Vignette(produit: produit),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produit.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: produit.price,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                              TextSpan(
                                text: '  ${produit.currency}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Etiquette(
                              texte: produit.category,
                              couleur: AppColors.textSecondary,
                            ),
                            if (produit.location != null &&
                                produit.location!.trim().isNotEmpty)
                              _Etiquette(
                                texte: produit.location!.trim(),
                                couleur: AppColors.textSecondary,
                                icone: Icons.place_outlined,
                              ),
                            if (produit.isBoosted)
                              _Etiquette(
                                texte: l.marketBoosted48h,
                                couleur: AppColors.accentPrimaryDark,
                                fond: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // L'annonce retirée le dit, et dit quoi faire. C'est la seule
          // information de cette page que le vendeur ne peut trouver nulle
          // part ailleurs.
          if (!produit.isActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: AppColors.chatAiCardBg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 15,
                    color: AppColors.chatAiLinkColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.marketStatusModerated,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.chatAiLinkColor,
                          ),
                        ),
                        Text(
                          l.marketStatusModeratedBody,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.chatAiLinkColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
          // ANN-18 : clore la vente — l'annonce quitte le marché et
          // l'acheteur pourra la noter.
          if (produit.soldAt == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ModuleQuietButton(
                label: l.annSoldTitle,
                icon: Icons.sell_outlined,
                onPressed: () async {
                  final done = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AssimeMarkSoldScreen(product: produit),
                    ),
                  );
                  if (done == true) ref.invalidate(myProductsProvider);
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.feedbackSuccess,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.annSoldBadge,
                    style: TextStyle(
                      color: AppColors.feedbackSuccess,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: _Action(
                    icone: Icons.edit_outlined,
                    libelle: l.conversationEdit,
                    onPressed: onEdit,
                  ),
                ),
                Expanded(
                  child: _Action(
                    icone: Icons.rocket_launch_outlined,
                    libelle: l.marketBoost,
                    couleur: AppColors.accentPrimaryDark,
                    onPressed: onBoost,
                  ),
                ),
                Expanded(
                  child: _Action(
                    icone: Icons.delete_outline,
                    libelle: l.marketRemove,
                    couleur: AppColors.semanticError,
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une action de la ligne — icône ET libellé, sur 44 points de haut.
///
/// La bande horizontale de l'accueil s'en tient à des icônes nues faute de
/// place. Sur cette page il y a la largeur, et une action destructrice mérite
/// son mot : on ne retire pas une annonce en reconnaissant une corbeille.
class _Action extends StatelessWidget {
  const _Action({
    required this.icone,
    required this.libelle,
    required this.onPressed,
    this.couleur,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback? onPressed;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    final teinte = actif
        ? (couleur ?? AppColors.textSecondary)
        : AppColors.textMuted;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: 17, color: teinte),
      label: Text(
        libelle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: teinte,
        ),
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette({
    required this.texte,
    required this.couleur,
    this.icone,
    this.fond = false,
  });

  final String texte;
  final Color couleur;
  final IconData? icone;
  final bool fond;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fond ? 7 : 0,
        vertical: fond ? 2 : 0,
      ),
      decoration: fond
          ? BoxDecoration(
              color: couleur.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 12, color: couleur),
            const SizedBox(width: 3),
          ],
          Text(
            texte,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette({required this.produit});

  final MarketplaceProduct produit;

  @override
  Widget build(BuildContext context) {
    final image = produit.coverImage;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 76,
        height: 76,
        child: image == null
            ? ColoredBox(
                color: AppColors.surfaceElevated,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.accentPrimaryDark,
                  size: 24,
                ),
              )
            // 76 points : l'image est décodée à cette taille, pas en pleine
            // définition. Un catalogue de trente annonces tenait sinon en
            // mémoire trente photos d'appareil photo entières.
            : MediaImage.meta(image, decodeWidth: 76),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.titre, required this.corps});

  final String titre;
  final String corps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 34,
            color: AppColors.accentPrimaryDark,
          ),
          const SizedBox(height: 10),
          Text(
            titre,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            corps,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          texte,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
