import 'assime_extras.dart';
import 'assime_sheets.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' show IsoCode;

import '../../../core/country/country_config.dart';
import '../../auth/presentation/country_names.dart';
import '../../../core/widgets/pokou_back_button.dart';
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
import '../../../core/widgets/pokou_context_menu.dart';

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
              contextMenuBuilder: pokouContextMenuBuilder,
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
    final myUserId = ref.watch(authControllerProvider).user?.id;
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
                  MaterialPageRoute(
                    builder: (_) => const FavoritesAlertsScreen(),
                  ),
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
            const SizedBox(height: 12),
            // Accueil Assimé (p.15) : les catégories en tuiles ; dès qu'une
            // recherche ou un filtre est posé, la barre « Filtres · n »,
            // le nombre d'annonces et le tri (Assimé 1).
            if (_isBrowsing(ref))
              const _CategoryTiles()
            else
              const _FiltersRow(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    L.of(context).assimeNearYou,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isBrowsing(ref))
                  TextButton(
                    onPressed: () => showAssimeFilters(context),
                    child: Text(L.of(context).assimeFilters),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimaryDark,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyCatalogScreen()),
                  ),
                  child: Text(L.of(context).assimeMyListings),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildProductsList(productsState, myUserId, context, ref),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
        child: FloatingActionButton(
          // Une ANNONCE (Assimé 5 à 7), pas une publicité payante. Un « + »
          // seul : le libellé reste pour les lecteurs d'écran.
          onPressed: () => editProduct(context, ref),
          tooltip: L.of(context).assimePublishCta,
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  /// Sans recherche ni filtre : l'accueil, avec ses tuiles de catégories.
  bool _isBrowsing(WidgetRef ref) =>
      ref.watch(marketplaceQueryProvider).trim().isEmpty &&
      ref.watch(marketplaceCategoryProvider) == 'TOUT' &&
      !ref.watch(marketplaceCertifiedOnlyProvider) &&
      ref.watch(marketplaceFiltersProvider).isEmpty;

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
      final query = ref.watch(marketplaceQueryProvider).trim();
      if (query.isEmpty) {
        return Text(
          L.of(context).marketNoProduct,
          style: TextStyle(color: AppColors.textSecondary),
        );
      }
      return _NoResult(query: query);
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
        childAspectRatio: 0.66,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _MarketProductTile(
        product: products[index],
        isMine: products[index].sellerId == myUserId,
      ),
    );
  }
}

/// Une icône par catégorie connue ; les autres prennent l'étiquette.
IconData _categoryIcon(String slug) => switch (slug) {
  'MODE' => Icons.checkroom_outlined,
  'BEAUTE' => Icons.spa_outlined,
  'MAISON' => Icons.home_outlined,
  'ELECTRONIQUE' || 'TELEPHONES' => Icons.phone_android_outlined,
  'VEHICULES' => Icons.directions_car_outlined,
  'SERVICES' => Icons.handyman_outlined,
  _ => Icons.sell_outlined,
};

/// Accueil Assimé (p.15) : les catégories en tuiles, qui posent le filtre.
class _CategoryTiles extends ConsumerWidget {
  const _CategoryTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(marketplaceConfigProvider);
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: config.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = config.categories[index];
          return SizedBox(
            width: 78,
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    ref.read(marketplaceCategoryProvider.notifier).state =
                        category.slug,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _categoryIcon(category.slug),
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// « Bè · aujourd'hui » : le quartier et la date de publication.
String assimePlaceAndDate(L l, String locale, MarketplaceProduct product) {
  final created = product.createdAt?.toLocal();
  String? when;
  if (created != null) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(created.year, created.month, created.day);
    final diff = today.difference(day).inDays;
    when = diff == 0
        ? l.assimeToday
        : diff == 1
        ? l.assimeYesterday
        : DateFormat('dd/MM', locale).format(created);
  }
  return [
    if ((product.location ?? '').trim().isNotEmpty) product.location!.trim(),
    ?when,
  ].join(' · ');
}

/// Assimé 1 : une carte de résultat — la photo, avec « Sponsorisé » et le
/// cœur posés dessus ; le prix, le titre, « quartier · date », le vendeur.
class _MarketProductTile extends ConsumerStatefulWidget {
  const _MarketProductTile({required this.product, required this.isMine});

  final MarketplaceProduct product;
  final bool isMine;

  @override
  ConsumerState<_MarketProductTile> createState() => _MarketProductTileState();
}

class _MarketProductTileState extends ConsumerState<_MarketProductTile> {
  bool? _favorite;

  Future<void> _toggle(bool current) async {
    setState(() => _favorite = !current);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .setFavorite(widget.product.id, !current);
      ref.invalidate(favoritesProvider);
    } catch (_) {
      if (mounted) setState(() => _favorite = current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final product = widget.product;
    final favorites = ref.watch(favoritesProvider).valueOrNull;
    final favorite =
        _favorite ?? (favorites?.any((f) => f.id == product.id) ?? false);
    final image = product.coverImage;
    final muted = TextStyle(fontSize: 11, color: AppColors.textSecondary);
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
            builder: (_) => ProductDetailScreen(
              product: product,
              heroTag: 'market-grid-${product.id}',
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image == null
                      ? ColoredBox(
                          color: AppColors.surfaceElevated,
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.textMuted,
                          ),
                        )
                      : Hero(
                          tag: 'market-grid-${product.id}',
                          child: MediaImage.meta(
                            image,
                            decodeWidth: 176,
                            placeholder: ColoredBox(
                              color: AppColors.surfaceElevated,
                            ),
                          ),
                        ),
                  if (product.isBoosted)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '☆ ${l.assimeSponsored}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (!widget.isMine)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: favorite
                            ? l.assimeRemoveFavorite
                            : l.assimeAddFavorite,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                        ),
                        onPressed: () => _toggle(favorite),
                        icon: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: favorite
                              ? AppColors.feedbackDanger
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${product.price} ${product.currency}',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  Text(
                    assimePlaceAndDate(l, locale, product),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ),
                      if (product.sellerIsCertified || product.sellerIsPro) ...[
                        const SizedBox(width: 3),
                        const VerifiedBadge(size: 12),
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
      contextMenuBuilder: pokouContextMenuBuilder,
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

/// Assimé 1 : « Filtres · 2 » (ouvre la feuille Assimé 2), « 48 annonces »
/// et le tri « Plus récentes ».
class _FiltersRow extends ConsumerWidget {
  const _FiltersRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final filters = ref.watch(marketplaceFiltersProvider);
    final total = ref.watch(marketplaceTotalProvider);
    final count =
        filters.count +
        (ref.watch(marketplaceCategoryProvider) == 'TOUT' ? 0 : 1) +
        (ref.watch(marketplaceCertifiedOnlyProvider) ? 1 : 0);
    final sorts = {
      'recent': l.assimeSortRecent,
      'price_asc': l.assimeSortPriceAsc,
      'price_desc': l.assimeSortPriceDesc,
    };
    return Row(
      children: [
        ActionChip(
          avatar: Icon(
            Icons.tune,
            size: 16,
            color: count > 0 ? Colors.white : AppColors.textSecondary,
          ),
          label: Text(
            count > 0 ? l.assimeFiltersCount(count) : l.assimeFilters,
          ),
          backgroundColor: count > 0
              ? AppColors.accentPrimary
              : AppColors.surfaceElevated,
          side: BorderSide(
            color: count > 0 ? AppColors.accentPrimary : AppColors.border,
          ),
          shape: const StadiumBorder(),
          labelStyle: TextStyle(
            color: count > 0 ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          onPressed: () => showAssimeFilters(context),
        ),
        const SizedBox(width: 10),
        if (total != null)
          Expanded(
            child: Text(
              l.assimeResultsCount(total),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          )
        else
          const Spacer(),
        PopupMenuButton<String>(
          initialValue: filters.sort,
          onSelected: (value) =>
              ref.read(marketplaceFiltersProvider.notifier).state = filters
                  .copyWith(sort: value),
          itemBuilder: (_) => [
            for (final entry in sorts.entries)
              PopupMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert, size: 16, color: AppColors.accentPrimary),
              const SizedBox(width: 2),
              Text(
                sorts[filters.sort]!,
                style: TextStyle(
                  color: AppColors.accentPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
    // Ouvert depuis l'Accueil ou Plus : un retour. En onglet : aucun.
    return PokouAppBar(
      title: L.of(context).marketTitle,
      // Maquette p.15 : « Petites annonces » sous le titre, à la place du
      // « En ligne », qui parle de la messagerie.
      subtitle: L.of(context).marketSubtitle,
      showStatus: false,
      leading: Navigator.of(context).canPop() ? const PokouBackButton() : null,
      actions: actions,
    );
  }
}

/// États vides · 4. Assimé, aucun résultat (maquette p.111) : ce qui n'a pas
/// été trouvé, et où ; créer une alerte sur cette recherche, ou élargir à
/// tout le pays.
class _NoResult extends ConsumerStatefulWidget {
  const _NoResult({required this.query});

  final String query;

  @override
  ConsumerState<_NoResult> createState() => _NoResultState();
}

class _NoResultState extends ConsumerState<_NoResult> {
  bool _saving = false;

  Future<void> _createAlert() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .createAlert(query: widget.query);
      messenger.showSnackBar(SnackBar(content: Text(l.emptyAssimeAlertDone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorNetwork)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final city = ref.watch(marketplaceLocationProvider).trim();
    final iso = ref.watch(currentCountryConfigProvider).country;
    final isoCode = IsoCode.values.where((c) => c.name == iso).firstOrNull;
    final countryName = isoCode == null
        ? null
        : countryNameFor(Localizations.localeOf(context).languageCode, isoCode);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            city.isEmpty ? l.emptyAssimeTitle : l.emptyAssimeTitleIn(city),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            l.emptyAssimeBody(widget.query),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _createAlert,
            icon: const Icon(Icons.notifications_none, size: 18),
            label: Text(l.emptyAssimeAlert),
          ),
          if (city.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(marketplaceLocationProvider.notifier).state = '';
                ref.read(marketplaceProductsProvider.notifier).invalidate();
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(
                countryName == null
                    ? l.emptyAssimeEverywhere
                    : l.emptyAssimeWholeCountry(countryName),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            l.emptyAssimeAlertNote,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
