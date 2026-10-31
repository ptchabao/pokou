import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/sync/offline_list.dart';
import '../data/ad_model.dart';
import '../data/marketplace_repository.dart';
import '../data/product_model.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>(
  (ref) => MarketplaceRepository(apiClient: ref.watch(apiClientProvider)),
);

class SellerCertificationStatus {
  const SellerCertificationStatus({
    required this.isCertifiedSeller,
    required this.isPending,
  });

  final bool isCertifiedSeller;
  final bool isPending;
}

final mySellerCertificationProvider =
    FutureProvider.autoDispose<SellerCertificationStatus>((ref) async {
      final profile = await ref
          .read(apiClientProvider)
          .get('/users/me/profile');
      final json = profile as Map<String, dynamic>;
      // `is_certified_seller`, et non `is_verified` : ce dernier est le ✓
      // d'identité, que l'approbation du dossier vendeur ne pose pas.
      return SellerCertificationStatus(
        isCertifiedSeller: json['is_certified_seller'] as bool? ?? false,
        isPending: json['is_certification_pending'] as bool? ?? false,
      );
    });

// Clés du cache hors ligne (voir core/sync/offline_list.dart).
const _catalogueScope = 'marketplace:catalogue';
const _configScope = 'marketplace:config';
const _mineScope = 'marketplace:mine';

/// Les catégories et les devises du marché, réglées depuis l'admin.
///
/// `Provider` et non `FutureProvider.autoDispose` : la configuration change
/// rarement, et on ne veut pas que quitter l'onglet Marché la fasse
/// redemander. Elle expose sa valeur de repli SYNCHRONEMENT — la barre de
/// filtres et le formulaire d'annonce ont besoin d'une liste dès la
/// première image de rendu, pas d'un `AsyncValue` à déballer.
final marketplaceConfigProvider =
    StateNotifierProvider<MarketplaceConfigNotifier, MarketplaceConfig>(
      (ref) => MarketplaceConfigNotifier(ref),
    );

class MarketplaceConfigNotifier extends StateNotifier<MarketplaceConfig> {
  MarketplaceConfigNotifier(this._ref) : super(MarketplaceConfig.fallback) {
    recharger();
  }

  final Ref _ref;

  Future<void> recharger() async {
    final store = _ref.read(pokouMessageStoreProvider);
    // D'abord la dernière configuration connue : hors ligne, les catégories
    // de l'administration valent mieux que la liste de repli codée en dur.
    try {
      final cached = await store.cachedConversations(_configScope);
      if (cached != null && cached.isNotEmpty && mounted) {
        state = MarketplaceConfig.fromJson(
          (cached.first as Map).cast<String, dynamic>(),
        );
      }
    } catch (_) {}
    try {
      final raw = await _ref.read(marketplaceRepositoryProvider).configRaw();
      if (!mounted) return;
      state = MarketplaceConfig.fromJson(raw);
      await store.saveConversations(_configScope, [raw]);
    } catch (_) {
      // Hors ligne, ou serveur trop ancien pour cette route : on garde ce
      // qu'on a. Un marché aux catégories un peu datées reste un marché ;
      // un marché sans catégories n'en est plus un.
    }
  }
}

final marketplaceQueryProvider = StateProvider<String>((ref) => '');
final marketplaceCategoryProvider = StateProvider<String>((ref) => 'TOUT');
final marketplaceLocationProvider = StateProvider<String>((ref) => '');

final marketplacePositionProvider = FutureProvider.autoDispose<Position?>((
  ref,
) async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied)
    permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever)
    return null;
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  );
});

class ProductsPaginationState {
  const ProductsPaginationState({
    required this.items,
    required this.hasMore,
    required this.isLoading,
    this.nextOffset,
    this.error,
  });

  final List<MarketplaceProduct> items;
  final bool hasMore;
  final bool isLoading;
  final int? nextOffset;
  final Object? error;

  factory ProductsPaginationState.initial() =>
      const ProductsPaginationState(items: [], hasMore: true, isLoading: false);

  ProductsPaginationState copyWith({
    List<MarketplaceProduct>? items,
    bool? hasMore,
    bool? isLoading,
    int? nextOffset,
    Object? error,
    bool clearError = false,
  }) {
    return ProductsPaginationState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      nextOffset: nextOffset ?? this.nextOffset,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ProductsPaginationNotifier
    extends StateNotifier<ProductsPaginationState> {
  ProductsPaginationNotifier(this.ref)
    : super(ProductsPaginationState.initial()) {
    _init();
  }

  final Ref ref;
  static const _pageSize = 20;

  Future<void> _init() async {
    ref.onDispose(() {});
    _watchFilters();
    await loadInitial();
  }

  void _watchFilters() {
    ref.listen<String>(marketplaceQueryProvider, (_, __) => _resetAndLoad());
    ref.listen<String>(marketplaceCategoryProvider, (_, __) => _resetAndLoad());
    ref.listen<String>(marketplaceLocationProvider, (_, __) => _resetAndLoad());
    ref.listen<AsyncValue<Position?>>(
      marketplacePositionProvider,
      (_, __) => _resetAndLoad(),
    );
  }

  Future<void> _resetAndLoad() {
    state = ProductsPaginationState.initial();
    return loadInitial();
  }

  /// Le catalogue SANS filtre — le seul qu'on garde sur l'appareil. Une
  /// recherche ou une catégorie hors ligne n'a rien de fiable à montrer :
  /// filtrer localement une seule page donnerait un résultat faux, présenté
  /// comme s'il était complet.
  bool get _isDefaultView =>
      ref.read(marketplaceQueryProvider).trim().isEmpty &&
      ref.read(marketplaceCategoryProvider) == 'TOUT' &&
      ref.read(marketplaceLocationProvider).trim().isEmpty;

  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    final store = ref.read(pokouMessageStoreProvider);
    final cacheable = _isDefaultView;
    var showingCache = false;
    if (cacheable) {
      // Avant la position GPS, qui peut prendre plusieurs secondes : le
      // catalogue connu s'affiche pendant qu'on la cherche.
      final cached = await store.cachedConversations(_catalogueScope);
      if (cached != null && mounted) {
        state = state.copyWith(
          items: cached
              .cast<Map<String, dynamic>>()
              .map(MarketplaceProduct.fromJson)
              .toList(),
          // Pas de page suivante à demander tant que le serveur n'a pas
          // répondu : elle partirait d'une liste peut-être périmée.
          hasMore: false,
        );
        showingCache = true;
      }
    }
    try {
      final position = await ref.read(marketplacePositionProvider.future);
      final raw = await ref
          .read(marketplaceRepositoryProvider)
          .listRaw(
            query: ref.read(marketplaceQueryProvider),
            category: ref.read(marketplaceCategoryProvider),
            location: ref.read(marketplaceLocationProvider),
            latitude: position?.latitude,
            longitude: position?.longitude,
            limit: _pageSize,
            offset: 0,
          );
      final result = PaginatedProducts.fromJson(raw);
      if (cacheable) {
        await store.saveConversations(_catalogueScope, raw['items'] as List);
      }
      if (!mounted) return;
      state = state.copyWith(
        items: result.items,
        hasMore: result.hasMore,
        nextOffset: result.nextOffset,
        isLoading: false,
      );
    } on NetworkException catch (e) {
      if (!mounted) return;
      state = showingCache
          ? state.copyWith(isLoading: false)
          : state.copyWith(isLoading: false, error: e);
    } on ApiException catch (e) {
      // Même règle que les autres listes : une panne serveur laisse le
      // catalogue connu visible, un refus (session expirée…) remonte.
      if (!mounted) return;
      state = showingCache && e.statusCode >= 500
          ? state.copyWith(isLoading: false)
          : state.copyWith(isLoading: false, error: e);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final position = ref.read(marketplacePositionProvider).valueOrNull;
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .list(
            query: ref.read(marketplaceQueryProvider),
            category: ref.read(marketplaceCategoryProvider),
            location: ref.read(marketplaceLocationProvider),
            latitude: position?.latitude,
            longitude: position?.longitude,
            limit: _pageSize,
            offset: state.nextOffset ?? state.items.length,
          );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        nextOffset: result.nextOffset,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void invalidate() {
    _resetAndLoad();
  }
}

/// Les publicités en diffusion, par emplacement (MARKET ou STATUS).
///
/// Une erreur donne une liste vide plutôt qu'un écran d'erreur : une
/// publicité absente ne doit jamais empêcher de voir le marché ou les
/// actualités.
final adFeedProvider = FutureProvider.autoDispose
    .family<List<MarketplaceAdItem>, String>((ref, placement) async {
      try {
        return await ref
            .watch(marketplaceRepositoryProvider)
            .adFeed(placement: placement);
      } catch (_) {
        return const [];
      }
    });

final marketplaceProductsProvider =
    StateNotifierProvider.autoDispose<
      ProductsPaginationNotifier,
      ProductsPaginationState
    >((ref) => ProductsPaginationNotifier(ref));

/// Mes annonces — gardées sur l'appareil : on veut pouvoir montrer son
/// catalogue à un client en face de soi, même sans réseau.
final myProductsProvider = StreamProvider.autoDispose<List<MarketplaceProduct>>(
  (ref) => offlineList(
    store: ref.watch(pokouMessageStoreProvider),
    scope: _mineScope,
    fetch: ref.watch(marketplaceRepositoryProvider).mineRaw,
    parse: MarketplaceProduct.fromJson,
  ),
);
