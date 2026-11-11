import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/status_halo.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../marketplace/data/vitrine.dart';
import '../../marketplace/data/product_model.dart';
import '../../marketplace/presentation/marketplace_actions.dart';
import '../../marketplace/presentation/marketplace_controller.dart';
import '../../marketplace/presentation/vitrine_viewer.dart';
import '../../../core/widgets/pokou_icon.dart';

/// La première page de la vitrine. Une erreur (hors ligne) donne une
/// vitrine vide — la bande disparaît, les discussions restent.
final discoveryProductsProvider = FutureProvider.autoDispose<VitrinePage>((
  ref,
) async {
  final myUserId = ref.watch(authControllerProvider).user?.id;
  try {
    return await loadVitrinePage(
      ref.watch(marketplaceRepositoryProvider),
      myUserId: myUserId,
    );
  } catch (_) {
    return (items: const <MarketplaceProduct>[], nextOffset: null);
  }
});

/// La vitrine en tête des Discussions : des articles du Marché, comme une
/// bande de stories.
///
/// Toucher un article ouvre la vitrine plein écran, qui fait défiler les
/// articles d'elle-même — c'est du lèche-vitrine : on regarde passer, et
/// on touche celui qui intéresse (voir VitrineViewer).
///
/// En tête, avant les articles des autres, la case de l'utilisateur : elle
/// ouvre le formulaire d'annonce. Celui qui regarde passer les articles est
/// aussi celui qui a quelque chose à vendre — comme « Mon statut » ouvre la
/// bande des statuts. Elle reste là même quand la vitrine est vide : c'est
/// alors le seul moyen de la remplir.
///
/// Les statuts des contacts n'y figurent pas : ils ont leur onglet, et un
/// article mêlé aux visages des proches se lirait comme un statut d'ami.
class DiscoveryStrip extends ConsumerStatefulWidget {
  const DiscoveryStrip({super.key});

  @override
  ConsumerState<DiscoveryStrip> createState() => _DiscoveryStripState();
}

class _DiscoveryStripState extends ConsumerState<DiscoveryStrip>
    with MarketplaceActions<DiscoveryStrip> {
  static const _height = 80.0;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(discoveryProductsProvider).valueOrNull;
    final products = page?.items ?? const <MarketplaceProduct>[];

    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        itemCount: products.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (itemContext, index) {
          // Le même chemin que le bouton « + » du Marché et que « Mon
          // catalogue » : même formulaire, mêmes invalidations de cache.
          if (index == 0) {
            return _SellTile(onTap: () => editProduct(context, ref));
          }
          final i = index - 1;
          return _ProductTile(
            product: products[i],
            onTap: () => VitrineViewer.open(
              itemContext,
              products: products,
              initialIndex: i,
              nextOffset: page?.nextOffset,
            ),
          );
        },
      ),
    );
  }
}

/// La case de l'utilisateur : sa photo, ou une silhouette, et un « + ».
///
/// Même rond que les articles — c'est la place de SON article à venir —
/// mais sans anneau : rien n'est encore à voir.
class _SellTile extends ConsumerWidget {
  const _SellTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(authControllerProvider).user?.avatar;
    return Semantics(
      button: true,
      label: L.of(context).marketAddProduct,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _thumb,
          height: _thumb,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: avatar != null
                        ? MediaImage.meta(
                            avatar,
                            decodeWidth: _thumb,
                            placeholder: ColoredBox(
                              color: AppColors.surfaceElevated,
                            ),
                          )
                        : ColoredBox(
                            color: AppColors.surfaceElevated,
                            child: PokouIcon(
                              PokouModuleIcon.assime,
                              color: AppColors.textSecondary,
                              size: 28,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La vignette : la photo seule. Pas de prix — la bande donne envie de
/// regarder, la fiche dira combien.
const _thumb = 64.0;

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});

  final MarketplaceProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${product.name}. ${L.of(context).vitrineTitle}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        // L'auréole cuivrée des statuts : la bande se lit d'un coup d'œil
        // comme « quelque chose à regarder ».
        child: StatusHalo(
          size: _thumb,
          thickness: product.isBoosted ? 3.5 : 3,
          gap: 1.5,
          child: ClipOval(
            child: Hero(
              tag: vitrineHeroTag(product),
              child: MediaImage.meta(
                product.coverImage!,
                decodeWidth: _thumb,
                placeholder: ColoredBox(color: AppColors.surfaceElevated),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
