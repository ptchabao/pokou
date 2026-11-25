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
    this.total,
  });

  final List<MarketplaceProduct> items;
  final bool hasMore;
  final int? nextOffset;

  /// Assimé 1 : « 48 annonces » — `null` sur un serveur plus ancien.
  final int? total;

  factory PaginatedProducts.fromJson(Map<String, dynamic> json) =>
      PaginatedProducts(
        items: (json['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(MarketplaceProduct.fromJson)
            .toList(),
        hasMore: json['has_more'] as bool? ?? false,
        nextOffset: json['next_offset'] as int?,
        total: json['total'] as int?,
      );
}

/// Les critères de la feuille « Filtres » (Assimé 2). La catégorie et
/// « Vendeurs certifiés » gardent leurs propres providers, partagés avec
/// la barre de puces.
class MarketFilters {
  const MarketFilters({
    this.minPrice,
    this.maxPrice,
    this.conditions = const {},
    this.publishedDays,
    this.sort = 'recent',
  });

  final int? minPrice;
  final int? maxPrice;
  final Set<String> conditions;
  final int? publishedDays;

  /// recent | price_asc | price_desc
  final String sort;

  /// Le nombre de critères posés, pour la puce « Filtres · 2 ».
  int get count =>
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (conditions.isEmpty ? 0 : 1) +
      (publishedDays != null ? 1 : 0);

  bool get isEmpty => count == 0 && sort == 'recent';

  MarketFilters copyWith({String? sort}) => MarketFilters(
    minPrice: minPrice,
    maxPrice: maxPrice,
    conditions: conditions,
    publishedDays: publishedDays,
    sort: sort ?? this.sort,
  );

  List<String> get queryParams => [
    if (minPrice != null) 'min_price=$minPrice',
    if (maxPrice != null) 'max_price=$maxPrice',
    if (conditions.isNotEmpty) 'condition=${conditions.join(',')}',
    if (publishedDays != null) 'published_days=$publishedDays',
    if (sort != 'recent') 'sort=$sort',
  ];
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
    bool certifiedOnly = false,
    MarketFilters filters = const MarketFilters(),
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
      certifiedOnly: certifiedOnly,
      filters: filters,
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
    bool certifiedOnly = false,
    MarketFilters filters = const MarketFilters(),
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String>[
      ...filters.queryParams,
      if (sellerId != null) 'seller_id=$sellerId',
      if (query != null && query.trim().isNotEmpty)
        'q=${Uri.encodeQueryComponent(query.trim())}',
      if (category != null && category != 'TOUT')
        'category=${Uri.encodeQueryComponent(category)}',
      if (location != null && location.trim().isNotEmpty)
        'location=${Uri.encodeQueryComponent(location.trim())}',
      if (latitude != null) 'latitude=$latitude',
      if (longitude != null) 'longitude=$longitude',
      if (certifiedOnly) 'certified_only=true',
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
    String? condition,
    bool negotiable = false,
  }) async {
    final response = await _api.post(
      '/marketplace',
      body: {
        'condition': ?condition,
        'negotiable': negotiable,
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
    String? condition,
    bool negotiable = false,
  }) async {
    final response = await _api.patch(
      '/marketplace/$id',
      body: {
        'condition': ?condition,
        'negotiable': negotiable,
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
    final response = await _api.post(
      '/marketplace/$id/boost',
      body: {'days': days},
    );
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

  /// Les avis et leur résumé : histogramme, points forts (Assimé 21).
  Future<SellerReviews> sellerReviewsFull(int sellerId) async =>
      SellerReviews.fromJson(
        await _api.get('/marketplace/sellers/$sellerId/reviews')
            as Map<String, dynamic>,
      );

  /// Le vendeur répond à un avis sur lui.
  Future<void> replyToReview(int reviewId, String reply) =>
      _api.put('/marketplace/reviews/$reviewId/reply', body: {'reply': reply});

  /// « Signaler un avis » (Assimé 21).
  Future<void> reportReview(int reviewId) =>
      _api.post('/marketplace/reviews/$reviewId/report');

  /// La fiche d'une annonce (compte une vue si elle n'est pas à moi).
  Future<MarketplaceProduct> product(int productId) async =>
      MarketplaceProduct.fromJson(
        await _api.get('/marketplace/$productId') as Map<String, dynamic>,
      );

  /// « Signaler » sur le profil d'un vendeur (Assimé 22) : la file de
  /// signalements de la messagerie, sans blocage.
  Future<void> reportSeller(int sellerId) => _api.post(
    '/conversations/report',
    body: {
      'contact_user_id': sellerId,
      'reason': 'Assimé · vendeur signalé depuis son profil',
    },
  );

  /// « Renouveler » (Assimé 9) : 30 jours de plus en ligne.
  Future<void> renew(int productId) =>
      _api.post('/marketplace/$productId/renew');

  /// « Masquer cette annonce » (Assimé 16), pour moi seul.
  Future<void> hideProduct(int productId) =>
      _api.post('/marketplace/$productId/hide');

  /// « Ne plus voir les annonces de ce vendeur » (Assimé 16).
  Future<void> hideSeller(int sellerId) =>
      _api.post('/marketplace/sellers/$sellerId/hide');

  /// Les annonces d'un vendeur, vendues comprises (Assimé 22).
  Future<List<MarketplaceProduct>> sellerProducts(int sellerId) async {
    final json =
        await _api.get('/marketplace/sellers/$sellerId/products')
            as Map<String, dynamic>;
    return (json['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MarketplaceProduct.fromJson)
        .toList();
  }

  /// Couper ou rallumer une alerte (Assimé 12).
  Future<void> setAlertPaused(int alertId, bool paused) =>
      _api.patch('/marketplace/alerts/$alertId', body: {'paused': paused});

  /// « Voir l'annonce » depuis le statut sponsorisé, compté pour le bilan.
  Future<void> countSponsoredOpen(int boostId) =>
      _api.post('/marketplace/boosts/$boostId/open');

  /// Signaler une annonce (Assimé 11) : scam, forbidden, counterfeit,
  /// misleading ou other.
  Future<void> reportProduct(int productId, String reason) =>
      _api.post('/marketplace/$productId/report', body: {'reason': reason});

  /// Pose OU remplace mon avis (PUT côté API : un seul avis par personne).
  Future<SellerReview> reviewSeller({
    required int sellerId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    final response = await _api.put(
      '/marketplace/sellers/$sellerId/review',
      body: {
        'rating': rating,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
    return SellerReview.fromJson(response as Map<String, dynamic>);
  }

  /// ANN-18 : les personnes avec qui j'ai échangé depuis la publication.
  Future<List<Map<String, dynamic>>> buyerCandidates(int productId) async {
    final response =
        await _api.get('/marketplace/$productId/buyer-candidates')
            as Map<String, dynamic>;
    return (response['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  /// ANN-18 : clore la vente. [buyerId] `null` : vendue hors de Pokou.
  Future<void> markSold(int productId, {int? buyerId, int? finalPrice}) =>
      _api.post(
        '/marketplace/$productId/sold',
        body: {'buyer_id': buyerId, 'final_price': ?finalPrice},
      );

  /// Vente en main propre — le vendeur, en face de l'acheteur : « Commande
  /// validée et livrée ». Le serveur envoie un code à l'ACHETEUR seulement.
  Future<Map<String, dynamic>> startHandover(
    int productId, {
    required int buyerId,
    int? finalPrice,
  }) async =>
      await _api.post(
            '/marketplace/$productId/handover',
            body: {'buyer_id': buyerId, 'final_price': ?finalPrice},
          )
          as Map<String, dynamic>;

  /// La remise en cours (ou la dernière). Pour l'acheteur, avec le `code`.
  Future<Map<String, dynamic>> handover(int productId) async =>
      await _api.get('/marketplace/$productId/handover')
          as Map<String, dynamic>;

  /// « Clôturer la vente » avec le code que l'acheteur a donné.
  Future<Map<String, dynamic>> confirmHandover(
    int productId,
    String code,
  ) async =>
      await _api.post(
            '/marketplace/$productId/handover/confirm',
            body: {'code': code},
          )
          as Map<String, dynamic>;

  Future<void> cancelHandover(int productId) =>
      _api.delete('/marketplace/$productId/handover');

  /// ANN-19 : la vente que l'acheteur va noter.
  Future<Map<String, dynamic>> sale(int productId) async =>
      await _api.get('/marketplace/$productId/sale') as Map<String, dynamic>;

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
    final json =
        await _api.get('/marketplace/favorites') as Map<String, dynamic>;
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
      _api.post(
        '/marketplace/alerts',
        body: {
          if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
          'category': ?category,
          'max_price': ?maxPrice,
        },
      );

  Future<void> deleteAlert(int id) => _api.delete('/marketplace/alerts/$id');

  /// La seule place sponsorisée de la bande des statuts, ou `null`.
  Future<SponsoredStatus?> sponsoredStatus({String? city}) async {
    final query = city != null && city.trim().isNotEmpty
        ? '?city=${Uri.encodeQueryComponent(city.trim())}'
        : '';
    final json =
        await _api.get('/marketplace/sponsored-status$query')
            as Map<String, dynamic>;
    final item = json['item'] as Map<String, dynamic>?;
    return item == null
        ? null
        : SponsoredStatus.fromJson(item, every: json['every'] as int? ?? 5);
  }

  Future<void> countSponsoredContact(int boostId) =>
      _api.post('/marketplace/boosts/$boostId/contact');

  /// « Pourquoi je vois ça » : `null` si l'annonce n'est plus sponsorisée.
  Future<String?> whySponsored(int productId) async {
    final json =
        await _api.get('/marketplace/$productId/why') as Map<String, dynamic>;
    return json['sponsored'] == true ? json['text'] as String? : null;
  }

  Future<List<BoostReport>> boostReport(int productId) async {
    final json =
        await _api.get('/marketplace/$productId/boost/report')
            as Map<String, dynamic>;
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
    this.sold = false,
    this.createdAt,
  });

  final int id;
  final String name;
  final String price;
  final String currency;
  final int sellerId;
  final String sellerName;
  final String? location;
  final int? imageMediaId;

  /// Assimé 12 : un favori vendu reste, barré.
  final bool sold;
  final DateTime? createdAt;

  factory AssimeSnapshot.fromJson(Map<String, dynamic> json) => AssimeSnapshot(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    price: '${json['price'] ?? ''}',
    currency: json['currency'] as String? ?? 'XOF',
    sellerId: json['seller_id'] as int,
    sellerName: json['seller_name'] as String? ?? '',
    location: json['location'] as String?,
    imageMediaId: json['image_media_id'] as int?,
    sold: json['sold'] as bool? ?? false,
    createdAt: json['created_at'] is String
        ? parseServerTime(json['created_at'] as String)
        : null,
  );
}

class AssimeAlert {
  const AssimeAlert({
    required this.id,
    this.query,
    this.category,
    this.maxPrice,
    this.matchesCount = 0,
    this.location,
    this.paused = false,
  });

  final int id;
  final String? query;
  final String? category;
  final int? maxPrice;
  final int matchesCount;
  final String? location;

  /// « Alerte coupée » (Assimé 12).
  final bool paused;

  factory AssimeAlert.fromJson(Map<String, dynamic> json) => AssimeAlert(
    id: json['id'] as int,
    query: json['query'] as String?,
    category: json['category'] as String?,
    maxPrice: json['max_price'] as int?,
    matchesCount: json['matches_count'] as int? ?? 0,
    location: json['location'] as String?,
    paused: json['paused'] as bool? ?? false,
  );
}

class SponsoredStatus {
  const SponsoredStatus({
    required this.boostId,
    required this.product,
    required this.why,
    this.every = 5,
  });

  final int boostId;
  final AssimeSnapshot product;
  final String why;

  /// Au plus un statut sponsorisé tous les [every] statuts.
  final int every;

  factory SponsoredStatus.fromJson(
    Map<String, dynamic> json, {
    int every = 5,
  }) => SponsoredStatus(
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
    this.opens = 0,
    this.messages = 0,
    this.messagesBefore = 0,
    this.daily = const [],
  });

  /// « Voir l'annonce » touché depuis le statut sponsorisé.
  final int opens;

  /// Messages reçus pendant la mise en avant, et avant elle.
  final int messages;
  final int messagesBefore;

  /// Vues par jour : (jour, résultats, statuts).
  final List<({DateTime day, int results, int status})> daily;

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
    opens: json['opens'] as int? ?? 0,
    messages: json['messages'] as int? ?? 0,
    messagesBefore: json['messages_before'] as int? ?? 0,
    daily: [
      for (final d in (json['daily'] as List? ?? const []))
        if (d is Map && DateTime.tryParse('${d['day']}') != null)
          (
            day: DateTime.parse('${d['day']}'),
            results: (d['results'] as num?)?.toInt() ?? 0,
            status: (d['status'] as num?)?.toInt() ?? 0,
          ),
    ],
  );
}
