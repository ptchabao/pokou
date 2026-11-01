import 'assime_extras.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../core/theme/app_radius.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';
import 'create_ad_screen.dart';
import 'marketplace_actions.dart';
import 'my_catalog_screen.dart';
import 'product_detail_screen.dart';
import 'ad_card.dart';
import 'seller_verification_screen.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/verified_badge.dart';

const _kAdEvery = 8;

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with MarketplaceActions<MarketplaceScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = 200.0;
    if (maxScroll - currentScroll <= delta) {
      final notifier = ref.read(marketplaceProductsProvider.notifier);
      notifier.loadMore();
    }
  }

  Future<void> _showLocationPicker(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: ref.read(marketplaceLocationProvider),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).marketYourArea),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: L.of(context).marketCityOrArea,
              ),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  if (!await Geolocator.isLocationServiceEnabled()) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(L.of(context).marketLocationCleared),
                        ),
                      );
                    }
                    return;
                  }
                  var perm = await Geolocator.checkPermission();
                  if (perm == LocationPermission.denied)
                    perm = await Geolocator.requestPermission();
                  if (perm == LocationPermission.denied ||
                      perm == LocationPermission.deniedForever)
                    return;
                  final pos = await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.medium,
                    ),
                  );
                  controller.text =
                      '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
                } catch (_) {}
              },
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(L.of(context).marketUseGps),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(L.of(context).actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(L.of(context).marketApply),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    ref.read(marketplaceLocationProvider.notifier).state = value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(marketplaceProductsProvider);
    final mine = ref.watch(myProductsProvider);
    final myUserId = ref.watch(authControllerProvider).user?.id;
    final selectedCategory = ref.watch(marketplaceCategoryProvider);
    final config = ref.watch(marketplaceConfigProvider);
    final authUser = ref.watch(authControllerProvider).user;
    final sellerStatus = ref.watch(mySellerCertificationProvider).valueOrNull;
    final isVerified =
        (sellerStatus?.isCertifiedSeller == true) ||
        (authUser?.isCertifiedSeller == true);
    final isPending =
        (sellerStatus?.isPending == true) ||
        (authUser?.isCertificationPending == true);
    final location = ref.watch(marketplaceLocationProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      // La barre verte du système de design, à la place de l'`AppBar`
      // Material par défaut. Elle porte le même menu et la même action
      // d'ajout — seule sa peau change.
      appBar: _MarketAppBar(
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              // Deux ÉCRANS, et non plus deux boîtes de dialogue. L'un
              // ouvrait la galerie sans un mot d'explication pour réclamer
              // une pièce d'identité, l'autre demandait 10 000 FCFA avec
              // deux champs et rien d'autre. Dans les deux cas l'utilisateur
              // s'apprête à dépenser sans savoir ce qui va se passer.
              if (value == 'ad') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateAdScreen()),
                );
              }
              if (value == 'favorites') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FavoritesAlertsScreen()),
                );
              }
              if (value == 'verification') {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const SellerVerificationScreen(),
                      ),
                    )
                    .then((_) => ref.invalidate(mySellerCertificationProvider));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'favorites',
                child: Text(L.of(context).assimeFavoritesAlerts),
              ),
              PopupMenuItem(
                value: 'ad',
                child: Text(L.of(context).marketCreateAd),
              ),
              if (isVerified)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 18,
                        color: AppColors.accentPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(L.of(context).profileSellerCertified),
                    ],
                  ),
                )
              else if (isPending)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(L.of(context).profileCertificationPending),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'verification',
                  child: Text(L.of(context).marketBecomeSeller),
                ),
            ],
          ),
          IconButton(
            onPressed: () => editProduct(context, ref),
            icon: const Icon(Icons.add),
            tooltip: L.of(context).marketAddProduct,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(marketplaceProductsProvider.notifier).invalidate();
          ref.invalidate(myProductsProvider);
          ref.invalidate(adFeedProvider('MARKET'));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 +
                kBottomNavigationBarHeight +
                MediaQuery.paddingOf(context).bottom,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // La zone ne s'AFFICHE plus : ni le nom du lieu détecté, ni le
            // relevé GPS. Elle reste un filtre — le serveur s'en sert pour
            // restreindre les résultats — d'où le bouton conservé à côté de
            // la recherche, mais elle n'a plus à annoncer où se trouve celui
            // qui regarde.
            Row(
              children: [
                const Expanded(child: _MarketplaceSearchField()),
                IconButton(
                  onPressed: () => _showLocationPicker(context, ref),
                  icon: Icon(
                    Icons.tune,
                    size: 18,
                    // Le filtre se signale quand il est actif : sans cela,
                    // une liste restreinte à une zone ressemblerait à un
                    // marché vide.
                    color: location.trim().isEmpty
                        ? AppColors.textMuted
                        : AppColors.accentPrimaryDark,
                  ),
                  tooltip: L.of(context).marketPickArea,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: config.filterSlugs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = config.filterSlugs[index];
                  return ChoiceChip(
                    // Le LIBELLÉ vient de l'admin, la valeur reste le code :
                    // la barre affichait « TELEPHONES » en capitales parce
                    // qu'elle montrait l'identifiant enregistré en base.
                    label: Text(
                      category == 'TOUT'
                          ? L.of(context).marketFilterAll
                          : config.labelOf(category),
                    ),
                    selected: selectedCategory == category,
                    backgroundColor: AppColors.surfaceElevated,
                    selectedColor: AppColors.accentPrimaryLight,
                    side: BorderSide(
                      color: selectedCategory == category
                          ? AppColors.accentPrimaryDark
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelStyle: TextStyle(
                      color: selectedCategory == category
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: selectedCategory == category
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    onSelected: (_) =>
                        ref.read(marketplaceCategoryProvider.notifier).state =
                            category,
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            // ── Le catalogue AVANT la liste du marché ─────────────────
            //
            // Il était en dessous, et la liste du marché est devenue
            // infinie : elle se recharge à l'approche du bas, si bien que
            // le bas ne vient jamais. Le vendeur ne pouvait plus atteindre
            // ses propres annonces en défilant — elles reculaient à chaque
            // page chargée.
            //
            // Rien ne doit suivre une liste qui s'allonge toute seule.
            _MyCatalogHorizontal(
              mine: mine,
              onEdit: (product) => editProduct(context, ref, product: product),
              onDelete: (product) => deleteProduct(context, ref, product),
              onBoost: (product) => boostProduct(context, ref, product),
              myUserId: myUserId,
            ),
            const SizedBox(height: 26),
            Text(
              L.of(context).marketNearYou,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _buildProductsList(productsState, myUserId, context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList(
    ProductsPaginationState state,
    int? myUserId,
    BuildContext context,
    WidgetRef ref,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(child: Text(L.of(context).marketUnavailable));
    }
    if (state.items.isEmpty) {
      return Text(
        ref.watch(marketplaceQueryProvider).trim().isEmpty
            ? L.of(context).marketNoProduct
            : L.of(context).marketNoMatch,
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    // Une publicité tous les [_kAdEvery] produits, en rotation. Le marché
    // reste en tête : la première arrive après un premier bloc d'articles,
    // jamais avant — sauf s'il y a moins d'articles que ça.
    final ads = ref.watch(adFeedProvider('MARKET')).valueOrNull ?? const [];
    final chunks = <List<MarketplaceProduct>>[
      for (var i = 0; i < state.items.length; i += _kAdEvery)
        state.items.sublist(
          i,
          i + _kAdEvery > state.items.length
              ? state.items.length
              : i + _kAdEvery,
        ),
    ];
    return Column(
      children: [
        for (var c = 0; c < chunks.length; c++) ...[
          if (c > 0) const SizedBox(height: 10),
          _productGrid(chunks[c], myUserId, context, ref),
          if (ads.isNotEmpty && (chunks[c].length == _kAdEvery || c == 0)) ...[
            const SizedBox(height: 10),
            AdCard(ad: ads[c % ads.length]),
          ],
        ],
        if (state.isLoading && state.items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!state.hasMore && state.items.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                L.of(context).marketAllShown,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _productGrid(
    List<MarketplaceProduct> products,
    int? myUserId,
    BuildContext context,
    WidgetRef ref,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _MarketProductTile(
          product: product,
          onEdit: product.sellerId == myUserId
              ? () => editProduct(context, ref, product: product)
              : null,
          onBoost:
              product.sellerId == myUserId &&
                  !product.isBoosted &&
                  !boostingProductIds.contains(product.id)
              ? () => boostProduct(context, ref, product)
              : null,
        );
      },
    );
  }
}

class _MyCatalogHorizontal extends StatelessWidget {
  const _MyCatalogHorizontal({
    required this.mine,
    required this.onEdit,
    required this.onDelete,
    required this.onBoost,
    required this.myUserId,
  });

  final AsyncValue<List<MarketplaceProduct>> mine;
  final void Function(MarketplaceProduct) onEdit;
  final void Function(MarketplaceProduct) onDelete;
  final void Function(MarketplaceProduct) onBoost;
  final int? myUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Le chevron mène quelque part ──────────────────────────────
        //
        // Il ne menait nulle part : une icône décorative, posée au bout d'un
        // titre, qui promettait une suite inexistante. La bande horizontale
        // était TOUT ce qu'un vendeur avait pour gérer ses annonces.
        //
        // Le titre entier devient la cible, et non la seule icône de 20
        // points : c'est ce qu'on vise naturellement, et ça donne une zone
        // tactile de toute la largeur. Le libellé « Tout voir » accompagne
        // le chevron, parce qu'une flèche seule ne dit pas où elle va.
        Semantics(
          button: true,
          label: L.of(context).marketCatalogueOpen,
          child: InkWell(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MyCatalogScreen())),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      L.of(context).marketMyCatalogue,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    L.of(context).marketCatalogueSeeAll,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentPrimaryDark,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.accentPrimaryDark,
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(
          L.of(context).marketSwipeCatalogue,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        mine.when(
          data: (items) {
            if (items.isEmpty) {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.card,
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 32,
                      color: AppColors.accentPrimaryDark,
                    ),
                    SizedBox(height: 8),
                    Text(
                      L.of(context).marketCatalogueEmpty,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      L.of(context).marketCatalogueEmptyBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }
            return SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final product = items[index];
                  return _HorizontalProductCard(
                    product: product,
                    onEdit: () => onEdit(product),
                    onDelete: product.sellerId == myUserId
                        ? () => onDelete(product)
                        : null,
                    onBoost: product.sellerId == myUserId && !product.isBoosted
                        ? () => onBoost(product)
                        : null,
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Une action secondaire d'une carte produit — un carré, pas un bouton large.
///
/// `minimumSize: Size.zero` et `shrinkWrap` ne sont pas du réglage fin : un
/// OutlinedButton réserve 64 points de large et 48 de haut par défaut, soit
/// plus que la carte n'en a pour ses trois actions réunies. C'est ce qui
/// poussait « Booster » à la ligne.
///
/// 32 points de côté, c'est en dessous des 44 recommandés pour une cible
/// tactile. Compromis assumé sur une carte de 150 points de large : ces deux
/// actions sont secondaires, elles portent une icône universelle, et la
/// suppression demande de toute façon une confirmation.
class _CardIconAction extends StatelessWidget {
  const _CardIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.expanded = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: expanded ? const Size(0, 30) : const Size(32, 30),
          fixedSize: expanded ? null : const Size(32, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: color,
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
    return expanded ? Expanded(child: button) : button;
  }
}

class _HorizontalProductCard extends ConsumerWidget {
  const _HorizontalProductCard({
    required this.product,
    this.onEdit,
    this.onDelete,
    this.onBoost,
  });

  final MarketplaceProduct product;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onBoost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: product,
            heroTag: 'market-mine-${product.id}',
          ),
        ),
      ),
      borderRadius: AppRadius.card,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                width: double.infinity,
                child: product.coverImage == null
                    ? ColoredBox(
                        color: AppColors.surfaceElevated,
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.accentPrimaryDark,
                          size: 28,
                        ),
                      )
                    : Hero(
                        tag: 'market-mine-${product.id}',
                        child: MediaImage.meta(
                          product.coverImage!,
                          decodeWidth: 150,
                        ),
                      ),
              ),
            ),
            if (product.isBoosted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                color: AppColors.accentPrimaryDark.withOpacity(0.1),
                child: Text(
                  L.of(context).marketBoosted,
                  style: TextStyle(
                    color: AppColors.accentPrimaryDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Le prix en Outfit, en vert, la devise DÉTACHÉE et plus
                  // discrète. C'est l'information qu'on cherche en premier
                  // sur une carte : le montant doit se lire avant l'unité,
                  // pas se noyer dedans.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: product.price,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '  ${product.currency}',
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
                  // ── Les actions de la carte ────────────────────────
                  //
                  // La carte fait 150 points de large. Les trois boutons se
                  // partageaient cet espace avec DEUX `Expanded`, ce qui
                  // laissait une trentaine de points à « Booster » — le mot
                  // passait à la ligne et la carte débordait.
                  //
                  // « Booster » prend donc tout l'espace restant : c'est la
                  // seule action porteuse d'un LIBELLÉ, et la seule qui
                  // rapporte. Modifier et retirer deviennent des carrés de
                  // taille fixe — leurs icônes se comprennent sans texte.
                  //
                  // `minimumSize: Size.zero` et `shrinkWrap` sont
                  // indispensables : un OutlinedButton réserve sinon 64
                  // points de large par défaut, soit plus que la carte
                  // n'en a pour ses trois boutons.
                  Row(
                    children: [
                      if (onBoost != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onBoost,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(
                                color: AppColors.accentPrimaryDark,
                              ),
                            ),
                            child: Text(
                              L.of(context).marketBoost,
                              maxLines: 1,
                              // Garde-fou : même si la place venait à
                              // manquer sur un écran très étroit, le mot
                              // se tronque au lieu de casser la carte.
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.accentPrimaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _CardIconAction(
                        icon: Icons.edit_outlined,
                        tooltip: L.of(context).conversationEdit,
                        onPressed: onEdit,
                        // Sans « Booster », il n'y a que deux icônes : elles
                        // s'étalent plutôt que de laisser un vide à droite.
                        expanded: onBoost == null,
                      ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 4),
                        _CardIconAction(
                          icon: Icons.delete_outline,
                          tooltip: L.of(context).marketRemove,
                          onPressed: onDelete,
                          color: AppColors.semanticError,
                          expanded: onBoost == null,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketProductTile extends ConsumerWidget {
  const _MarketProductTile({required this.product, this.onEdit, this.onBoost});

  final MarketplaceProduct product;
  final VoidCallback? onEdit;
  final VoidCallback? onBoost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: AppRadius.card,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: product,
            heroTag: 'market-grid-${product.id}',
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: product.coverImage == null
                    ? ColoredBox(
                        color: AppColors.surfaceElevated,
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.accentPrimaryDark,
                          size: 30,
                        ),
                      )
                    : Hero(
                        tag: 'market-grid-${product.id}',
                        child: MediaImage.meta(
                          product.coverImage!,
                          decodeWidth: 176,
                          placeholder: ColoredBox(
                            color: AppColors.surfaceElevated,
                          ),
                        ),
                      ),
              ),
            ),
            if (product.isBoosted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 2,
                  horizontal: 10,
                ),
                color: AppColors.accentPrimaryDark.withOpacity(0.1),
                child: Text(
                  L.of(context).marketBoosted48h,
                  style: TextStyle(
                    color: AppColors.accentPrimaryDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  // Le prix en Outfit, en vert, la devise DÉTACHÉE et plus
                  // discrète. C'est l'information qu'on cherche en premier
                  // sur une carte : le montant doit se lire avant l'unité,
                  // pas se noyer dedans.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: product.price,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '  ${product.currency}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  _SellerTrustLine(product: product),
                  // Sur l'annonce de QUELQU'UN D'AUTRE, l'action utile
                  // n'est pas de booster — c'est de parler au vendeur.
                  //
                  // Cette grille ne portait que « Booster », c'est-à-dire
                  // une action de VENDEUR, payante, sur l'écran que
                  // parcourent surtout des acheteurs. « Négocier » ouvre la
                  // fiche produit, d'où part « Écrire au vendeur » avec le
                  // produit épinglé dans la conversation.
                  //
                  // `onEdit` est le signe qu'on est chez soi : les deux ne
                  // coexistent jamais, on ne négocie pas avec soi-même.
                  if (onEdit == null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: product,
                              heroTag: 'market-grid-${product.id}',
                            ),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          // L'encre foncée et non le bleu d'action : ce
                          // bouton porte un LIBELLÉ blanc (7,2:1 contre 2,96:1).
                          backgroundColor: AppColors.accentPrimaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.chip,
                          ),
                        ),
                        icon: const Icon(Icons.forum_outlined, size: 15),
                        label: Text(
                          L.of(context).marketNegotiate,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (onEdit != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onBoost != null)
                          TextButton(
                            onPressed: onBoost,
                            child: Text(
                              L.of(context).marketBoost,
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          visualDensity: VisualDensity.compact,

                          tooltip: L.of(context).conversationEdit,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerTrustLine extends StatelessWidget {
  const _SellerTrustLine({required this.product});

  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    final rating = product.sellerRating;
    return Row(
      children: [
        if (product.sellerIsCertified) ...[
          const VerifiedBadge(size: 13),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            product.sellerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        const SizedBox(width: 6),
        if (rating == null)
          Text(
            L.of(context).marketNoReviewYet,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          )
        else ...[
          Icon(Icons.star, size: 12, color: AppColors.accentPrimaryLight),
          const SizedBox(width: 2),
          Text(
            '${rating.toStringAsFixed(1)} (${product.sellerReviewCount})',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MarketplaceSearchField extends ConsumerStatefulWidget {
  const _MarketplaceSearchField();

  @override
  ConsumerState<_MarketplaceSearchField> createState() =>
      _MarketplaceSearchFieldState();
}

class _MarketplaceSearchFieldState
    extends ConsumerState<_MarketplaceSearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(marketplaceQueryProvider),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(marketplaceQueryProvider.notifier).state = value;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(marketplaceQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(marketplaceQueryProvider);
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: L.of(context).marketSearchHint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: query.isEmpty && _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.close, size: 18),

                tooltip: L.of(context).actionClose,
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

/// L'en-tête du Marché — la barre verte, avec ses actions.
///
/// Un `PreferredSizeWidget` dédié plutôt qu'un usage direct de
/// `PokouAppBar` : le Marché porte un menu et un bouton d'ajout, que la
/// barre générique ne connaît pas. Le reste — hauteur, couleur, ligne de
/// statut — vient d'elle.
class _MarketAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MarketAppBar({required this.actions});

  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return PokouAppBar(title: L.of(context).marketTitle, actions: actions);
  }
}
