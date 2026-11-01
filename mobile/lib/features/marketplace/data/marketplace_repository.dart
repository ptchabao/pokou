import '../../../core/api/api_client.dart';
import '../../messaging/data/direct_message_model.dart';
import 'ad_model.dart';
import 'product_model.dart';
import '../../../core/time/server_time.dart';

class PaginatedProducts {
  const PaginatedProducts({
    required this.items,
    required this.hasMore,
    this.nextOffset,
  });

  final List<MarketplaceProduct> items;
  final bool hasMore;
  final int? nextOffset;

  factory PaginatedProducts.fromJson(Map<String, dynamic> json) =>
      PaginatedProducts(
        items: (json['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(MarketplaceProduct.fromJson)
            .toList(),
        hasMore: json['has_more'] as bool? ?? false,
        nextOffset: json['next_offset'] as int?,
      );
}

class MarketplaceRepository {
  MarketplaceRepository({required ApiClient apiClient}) : _api = apiClient;
  final ApiClient _api;

  /// Recherche par nom/description, combinable avec un filtre vendeur —
  /// `query` vide revient à lister tout le catalogue.
  Future<PaginatedProducts> list({
    int? sellerId,
    String? query,
    String? category,
    String? location,
    double? latitude,
    double? longitude,
    int limit = 20,
    int offset = 0,
  }) async => PaginatedProducts.fromJson(
    await listRaw(
      sellerId: sellerId,
      query: query,
      category: category,
      location: location,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
      offset: offset,
    ),
  );

  /// La page TELLE QUE le serveur l'envoie — c'est elle que le cache hors
  /// ligne garde (voir contacts_repository.dart::listRaw).
  Future<Map<String, dynamic>> listRaw({
    int? sellerId,
    String? query,
    String? category,
    String? location,
    double? latitude,
    double? longitude,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String>[
      if (sellerId != null) 'seller_id=$sellerId',
      if (query != null && query.trim().isNotEmpty)
        'q=${Uri.encodeQueryComponent(query.trim())}',
      if (category != null && category != 'TOUT')
        'category=${Uri.encodeQueryComponent(category)}',
      if (location != null && location.trim().isNotEmpty)
        'location=${Uri.encodeQueryComponent(location.trim())}',
      if (latitude != null) 'latitude=$latitude',
      if (longitude != null) 'longitude=$longitude',
      'limit=$limit',
      'offset=$offset',
    ];
    final response = await _api.get(
      '/marketplace${params.isEmpty ? '' : '?${params.join('&')}'}',
    );
    return response as Map<String, dynamic>;
  }

  Future<List<MarketplaceProduct>> listLegacy({int? sellerId}) async {
    final response = await _api.get(
      '/marketplace${sellerId == null ? '' : '?seller_id=$sellerId'}',
    );
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(MarketplaceProduct.fromJson)
        .toList();
  }

  /// Les catégories et les devises réglées par l'administration.
  Future<MarketplaceConfig> config() async =>
      MarketplaceConfig.fromJson(await configRaw());

  Future<Map<String, dynamic>> configRaw() async =>
      await _api.get('/marketplace/config') as Map<String, dynamic>;

  Future<List<MarketplaceProduct>> mine() async => (await mineRaw())
      .cast<Map<String, dynamic>>()
      .map(MarketplaceProduct.fromJson)
      .toList();

  Future<List<dynamic>> mineRaw() async {
    final response = await _api.get('/marketplace/mine');
    return response['items'] as List;
  }

  Future<MarketplaceProduct> create({
    required String name,
    required String description,
    String category = 'AUTRE',
    String? location,
    double? latitude,
    double? longitude,
    required String price,
    required String currency,
    int? imageMediaId,
    List<int>? galleryMediaIds,
  }) async {
    final response = await _api.post(
      '/marketplace',
      body: {
        'name': name,
        'description': description,
        'category': category,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'price': price,
        'currency': currency,
        if (imageMediaId != null) 'image_media_id': imageMediaId,
        if (galleryMediaIds != null) 'gallery_media_ids': galleryMediaIds,
      },
    );
    return MarketplaceProduct.fromJson(response as Map<String, dynamic>);
  }

  /// `galleryMediaIds` à `null` laisse la galerie inchangée, une liste vide la
  /// vide — la distinction est portée par l'API (voir ProductPayload), donc
  /// on n'envoie la clé que si l'appelant a vraiment une intention dessus.
  ///
  /// `imageMediaId`, lui, part TOUJOURS, `null` compris : l'API traite
  /// désormais un champ absent comme « inchangé », donc l'omettre rendrait
  /// impossible de RETIRER la photo principale. Cet écran connaît toujours
  /// son intention sur cette photo — elle est à l'écran devant le vendeur.
  Future<MarketplaceProduct> update({
    required int id,
    required String name,
    required String description,
    String category = 'AUTRE',
    String? location,
    double? latitude,
    double? longitude,
    required String price,
    required String currency,
    int? imageMediaId,
    List<int>? galleryMediaIds,
  }) async {
    final response = await _api.patch(
      '/marketplace/$id',
      body: {
        'name': name,
        'description': description,
        'category': category,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'price': price,
        'currency': currency,
        'image_media_id': imageMediaId,
        if (galleryMediaIds != null) 'gallery_media_ids': galleryMediaIds,
      },
    );
    return MarketplaceProduct.fromJson(response as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/marketplace/$id');

  /// Mise en avant de 3 ou 7 jours (600 ou 1 300 FCFA TTC).
  Future<Map<String, dynamic>> boostProduct(int id, {int days = 7}) async {
    final response = await _api.post('/marketplace/$id/boost', body: {'days': days});
    return (response as Map).cast<String, dynamic>();
  }

  Future<String> marketplacePaymentStatus(int paymentId) async {
    final response = await _api.get('/marketplace/payments/$paymentId');
    return (response as Map)['status'] as String;
  }

  /// Les publicités en diffusion pour un emplacement. Elles étaient
  /// vendues sans qu'aucun écran ne les montre.
  Future<List<MarketplaceAdItem>> adFeed({String placement = 'MARKET'}) async {
    final response =
        await _api.get('/marketplace/ads/feed?placement=$placement')
            as Map<String, dynamic>;
    return ((response['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MarketplaceAdItem.fromJson)
        .toList();
  }

  /// Ouvre la conversation avec l'annonceur : le serveur crée le premier
  /// message, comme « Écrire au vendeur ».
  Future<({int advertiserId, String advertiserName})> contactAdvertiser(
    int adId,
  ) async {
    final response =
        await _api.post('/marketplace/ads/$adId/contact')
            as Map<String, dynamic>;
    return (
      advertiserId: response['advertiser_id'] as int,
      advertiserName: response['advertiser_name'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>> createAd({
    required String title,
    required String body,
    int amount = 10000,
    int durationDays = 7,
    String placement = 'MARKET',
    int? mediaAssetId,
  }) async {
    final response = await _api.post(
      '/marketplace/ads',
      body: {
        'title': title,
        'body': body,
        'amount': amount,
        'duration_days': durationDays,
        'placement': placement,
        if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
      },
    );
    return (response as Map).cast<String, dynamic>();
  }

  /// [plan] est le CODE d'une formule, jamais un montant : c'est le serveur
  /// qui facture. Absent, il applique la formule par défaut.
  Future<Map<String, dynamic>> requestVerification({
    required int identityMediaId,
    String? plan,
  }) async {
    final response = await _api.post(
      '/marketplace/verification',
      body: {
        'identity_media_id': identityMediaId,
        if (plan != null) 'plan': plan,
      },
    );
    return (response as Map).cast<String, dynamic>();
  }

  // ─── Confiance : fiche vendeur, avis, note ─────────────────────────────────

  Future<SellerProfile> sellerProfile(int sellerId) async {
    final response = await _api.get('/marketplace/sellers/$sellerId');
    return SellerProfile.fromJson(response as Map<String, dynamic>);
  }

  Future<List<SellerReview>> sellerReviews(int sellerId) async {
    final response = await _api.get('/marketplace/sellers/$sellerId/reviews');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(SellerReview.fromJson)
        .toList();
  }

  /// Pose OU remplace mon avis (PUT côté API : un seul avis par personne).
  Future<SellerReview> reviewSeller({
    required int sellerId,
    required int rating,
    String? comment,
  }) async {
    final response = await _api.put(
      '/marketplace/sellers/$sellerId/review',
      body: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
    return SellerReview.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteMyReview(int sellerId) =>
      _api.delete('/marketplace/sellers/$sellerId/review');

  /// Épingle la fiche produit dans une conversation et renvoie le message
  /// créé. Sans `recipientId`, la fiche part au VENDEUR — c'est
  /// « Écrire au vendeur », qui ouvre une discussion où l'article est déjà
  /// sous les yeux. L'API n'exige pas d'avoir le vendeur dans son carnet :
  /// mettre en relation des inconnus est tout l'objet d'une marketplace.
  Future<DirectMessage> shareProduct({
    required int productId,
    int? recipientId,
    String? message,
  }) async {
    final response = await _api.post(
      '/marketplace/$productId/share',
      body: {
        if (recipientId != null) 'recipient_id': recipientId,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
    return DirectMessage.fromJson(response as Map<String, dynamic>);
  }

  // ── Assimé : favoris, alertes, statut sponsorisé, bilan ─────────────────

  Future<List<AssimeSnapshot>> favorites() async {
    final json = await _api.get('/marketplace/favorites') as Map<String, dynamic>;
    return [
      for (final item in (json['items'] as List? ?? const []))
        AssimeSnapshot.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> setFavorite(int productId, bool favorite) => favorite
      ? _api.put('/marketplace/$productId/favorite')
      : _api.delete('/marketplace/$productId/favorite');

  Future<List<AssimeAlert>> alerts() async {
    final json = await _api.get('/marketplace/alerts') as Map<String, dynamic>;
    return [
      for (final item in (json['items'] as List? ?? const []))
        AssimeAlert.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> createAlert({String? query, String? category, int? maxPrice}) =>
      _api.post('/marketplace/alerts', body: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        'category': ?category,
        'max_price': ?maxPrice,
      });

  Future<void> deleteAlert(int id) => _api.delete('/marketplace/alerts/$id');

  /// La seule place sponsorisée de la bande des statuts, ou `null`.
  Future<SponsoredStatus?> sponsoredStatus({String? city}) async {
    final query = city != null && city.trim().isNotEmpty ? '?city=${Uri.encodeQueryComponent(city.trim())}' : '';
    final json = await _api.get('/marketplace/sponsored-status$query') as Map<String, dynamic>;
    final item = json['item'] as Map<String, dynamic>?;
    return item == null ? null : SponsoredStatus.fromJson(item, every: json['every'] as int? ?? 5);
  }

  Future<void> countSponsoredContact(int boostId) => _api.post('/marketplace/boosts/$boostId/contact');

  /// « Pourquoi je vois ça » : `null` si l'annonce n'est plus sponsorisée.
  Future<String?> whySponsored(int productId) async {
    final json = await _api.get('/marketplace/$productId/why') as Map<String, dynamic>;
    return json['sponsored'] == true ? json['text'] as String? : null;
  }

  Future<List<BoostReport>> boostReport(int productId) async {
    final json = await _api.get('/marketplace/$productId/boost/report') as Map<String, dynamic>;
    return [
      for (final item in (json['items'] as List? ?? const []))
        BoostReport.fromJson(item as Map<String, dynamic>),
    ];
  }
}

/// Une annonce réduite à ce qu'une carte affiche (favoris, statut
/// sponsorisé).
class AssimeSnapshot {
  const AssimeSnapshot({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.sellerId,
    required this.sellerName,
    this.location,
    this.imageMediaId,
  });

  final int id;
  final String name;
  final String price;
  final String currency;
  final int sellerId;
  final String sellerName;
  final String? location;
  final int? imageMediaId;

  factory AssimeSnapshot.fromJson(Map<String, dynamic> json) => AssimeSnapshot(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    price: '${json['price'] ?? ''}',
    currency: json['currency'] as String? ?? 'XOF',
    sellerId: json['seller_id'] as int,
    sellerName: json['seller_name'] as String? ?? '',
    location: json['location'] as String?,
    imageMediaId: json['image_media_id'] as int?,
  );
}

class AssimeAlert {
  const AssimeAlert({required this.id, this.query, this.category, this.maxPrice, this.matchesCount = 0});

  final int id;
  final String? query;
  final String? category;
  final int? maxPrice;
  final int matchesCount;

  factory AssimeAlert.fromJson(Map<String, dynamic> json) => AssimeAlert(
    id: json['id'] as int,
    query: json['query'] as String?,
    category: json['category'] as String?,
    maxPrice: json['max_price'] as int?,
    matchesCount: json['matches_count'] as int? ?? 0,
  );
}

class SponsoredStatus {
  const SponsoredStatus({required this.boostId, required this.product, required this.why, this.every = 5});

  final int boostId;
  final AssimeSnapshot product;
  final String why;

  /// Au plus un statut sponsorisé tous les [every] statuts.
  final int every;

  factory SponsoredStatus.fromJson(Map<String, dynamic> json, {int every = 5}) => SponsoredStatus(
    boostId: json['boost_id'] as int,
    product: AssimeSnapshot.fromJson(json['product'] as Map<String, dynamic>),
    why: (json['why'] as Map?)?['text'] as String? ?? '',
    every: every,
  );
}

class BoostReport {
  const BoostReport({
    required this.days,
    required this.startsAt,
    required this.expiresAt,
    required this.active,
    required this.impressions,
    required this.statusViews,
    required this.contacts,
    this.statusModeration,
  });

  final int? days;
  final DateTime startsAt;
  final DateTime expiresAt;
  final bool active;
  final int impressions;
  final int statusViews;
  final int contacts;
  final String? statusModeration;

  factory BoostReport.fromJson(Map<String, dynamic> json) => BoostReport(
    days: json['days'] as int?,
    startsAt: parseServerTime(json['starts_at'] as String),
    expiresAt: parseServerTime(json['expires_at'] as String),
    active: json['active'] as bool? ?? false,
    impressions: json['impressions'] as int? ?? 0,
    statusViews: json['status_views'] as int? ?? 0,
    contacts: json['contacts'] as int? ?? 0,
    statusModeration: json['status_moderation'] as String?,
  );
}
