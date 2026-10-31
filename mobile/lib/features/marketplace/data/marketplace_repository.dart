import '../../../core/api/api_client.dart';
import '../../messaging/data/direct_message_model.dart';
import 'ad_model.dart';
import 'product_model.dart';

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

  Future<Map<String, dynamic>> boostProduct(int id) async {
    final response = await _api.post('/marketplace/$id/boost', body: const {});
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
}
