import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/time/server_time.dart';

/// Une catégorie du marché, telle que l'administration l'a réglée.
class MarketCategory {
  const MarketCategory({required this.slug, required this.label});

  final String slug;
  final String label;

  factory MarketCategory.fromJson(Map<String, dynamic> json) => MarketCategory(
    slug: json['slug'] as String,
    label: json['label'] as String? ?? json['slug'] as String,
  );
}

/// Une devise ouverte sur le marché.
class MarketCurrency {
  const MarketCurrency({
    required this.code,
    required this.label,
    this.isDefault = false,
  });

  /// Le code enregistré avec le prix (« XOF »).
  final String code;

  /// Ce qui s'affiche à côté du montant (« FCFA »).
  final String label;

  final bool isDefault;

  factory MarketCurrency.fromJson(Map<String, dynamic> json) => MarketCurrency(
    code: json['code'] as String,
    label: json['label'] as String? ?? json['code'] as String,
    isDefault: json['default'] as bool? ?? false,
  );
}

/// Une formule de vérification de compte.
///
/// Le CODE part au serveur, jamais le montant — c'est lui qui facture. Le
/// prix affiché ici n'est qu'un reflet de ce que le serveur a annoncé.
class VerificationPlan {
  const VerificationPlan({
    required this.code,
    required this.label,
    required this.description,
    required this.amount,
    this.isDefault = false,
  });

  final String code;
  final String label;
  final String description;
  final int amount;
  final bool isDefault;

  factory VerificationPlan.fromJson(Map<String, dynamic> json) =>
      VerificationPlan(
        code: json['code'] as String,
        label: json['label'] as String? ?? json['code'] as String,
        description: json['description'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        isDefault: json['default'] as bool? ?? false,
      );
}

/// La configuration du marché — catégories, devises et formules.
///
/// Elle était écrite en dur dans l'application : ajouter une catégorie
/// demandait une publication Play Store, et la devise était un champ de
/// texte libre où « XOF », « FCFA » et « fcfa » cohabitaient sans jamais se
/// comparer. Elle vient maintenant de `GET /marketplace/config`.
///
/// [fallback] existe pour une raison précise : le marché doit rester
/// utilisable HORS LIGNE et pendant que la requête est en vol. Des filtres
/// vides seraient pires que des filtres figés, donc l'application garde sa
/// liste historique comme filet.
class MarketplaceConfig {
  const MarketplaceConfig({
    required this.categories,
    required this.currencies,
    required this.verificationPlans,
  });

  final List<MarketCategory> categories;
  final List<MarketCurrency> currencies;
  final List<VerificationPlan> verificationPlans;

  static final fallback = MarketplaceConfig(
    categories: const [
      MarketCategory(slug: 'TELEPHONES', label: 'Téléphones'),
      MarketCategory(slug: 'MODE', label: 'Mode'),
      MarketCategory(slug: 'MAISON', label: 'Maison'),
      MarketCategory(slug: 'SERVICES', label: 'Services'),
      MarketCategory(slug: 'AUTRE', label: 'Autre'),
    ],
    currencies: const [
      MarketCurrency(code: 'XOF', label: 'FCFA', isDefault: true),
    ],
    // La formule historique, au tarif qui est déjà le sien : 5 000 FCFA.
    // Aucun prix n'est inventé ici — si le serveur en propose d'autres,
    // ce sont les siens qui s'affichent.
    verificationPlans: const [
      VerificationPlan(
        code: 'ANNUAL',
        label: 'Vendeur vérifié',
        description: 'Badge vérifié sur toutes vos annonces.',
        amount: 5000,
        isDefault: true,
      ),
    ],
  );

  /// Les identifiants de catégorie, « TOUT » en tête — la forme qu'attend la
  /// barre de filtres.
  List<String> get filterSlugs => ['TOUT', ...categories.map((c) => c.slug)];

  String labelOf(String slug) {
    for (final c in categories) {
      if (c.slug == slug) return c.label;
    }
    // Une annonce publiée sous une catégorie depuis retirée garde la
    // sienne : on montre le code brut plutôt que rien.
    return slug;
  }

  VerificationPlan get defaultVerificationPlan => verificationPlans.firstWhere(
    (p) => p.isDefault,
    orElse: () => verificationPlans.isEmpty
        ? fallback.verificationPlans.first
        : verificationPlans.first,
  );

  MarketCurrency get defaultCurrency => currencies.firstWhere(
    (d) => d.isDefault,
    orElse: () => currencies.isEmpty
        ? const MarketCurrency(code: 'XOF', label: 'FCFA', isDefault: true)
        : currencies.first,
  );

  factory MarketplaceConfig.fromJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MarketCategory.fromJson)
        .toList();
    final currencies = (json['currencies'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MarketCurrency.fromJson)
        .toList();
    final plans = (json['verification_plans'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VerificationPlan.fromJson)
        .toList();
    // Un serveur qui renvoie des listes vides ne doit pas vider l'écran.
    return MarketplaceConfig(
      categories: categories.isEmpty ? fallback.categories : categories,
      currencies: currencies.isEmpty ? fallback.currencies : currencies,
      verificationPlans: plans.isEmpty ? fallback.verificationPlans : plans,
    );
  }
}

/// Produit d'un catalogue vendeur. `image` est la vignette principale (celle
/// des listes), `gallery` les images secondaires dans l'ordre voulu par le
/// vendeur — voir api/app/routes/marketplace.py.
///
/// La note et le badge de certification décrivent le VENDEUR, pas ce produit :
/// la marketplace ne fait que mettre en relation (aucun paiement encaissé),
/// donc la confiance se juge sur la personne et vaut pour tout son catalogue.
class MarketplaceProduct {
  const MarketplaceProduct({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.description,
    this.category = 'AUTRE',
    this.location,
    this.latitude,
    this.longitude,
    required this.price,
    required this.currency,
    this.image,
    this.gallery = const [],
    this.sellerIsCertified = false,
    this.sellerIsPro = false,
    this.sellerRating,
    this.sellerReviewCount = 0,
    this.isActive = true,
    this.isBoosted = false,
  });

  final int id;
  final int sellerId;
  final String sellerName;
  final String name;
  final String? description;
  final String category;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String price;
  final String currency;
  final MediaMeta? image;
  final List<MediaMeta> gallery;
  final bool sellerIsCertified;
  final bool sellerIsPro;

  /// `null` tant que personne n'a noté ce vendeur — à distinguer de 0, qui
  /// serait une très mauvaise note et non une absence d'avis.
  final double? sellerRating;
  final int sellerReviewCount;
  final bool isActive;
  final bool isBoosted;

  /// Toutes les images dans l'ordre d'affichage, la principale d'abord —
  /// ce dont une visionneuse a besoin, sans que chaque écran ait à
  /// recombiner `image` et `gallery` lui-même.
  List<MediaMeta> get allImages => [if (image != null) image!, ...gallery];

  /// L'image à montrer sur la fiche — la principale, ou à défaut la
  /// première de la galerie.
  ///
  /// Le formulaire propose DEUX zones séparées, « Photo principale » et
  /// « Autres photos ». Un vendeur qui ne remplit que la seconde publiait
  /// une annonce avec des photos et une fiche SANS aucune image : la liste
  /// ne lisait que `image`, et n'a jamais regardé la galerie.
  ///
  /// Le repli est ici, et pas dans chaque écran qui affiche une fiche : il
  /// y en a déjà deux, et le troisième aurait oublié la règle.
  MediaMeta? get coverImage =>
      image ?? (gallery.isEmpty ? null : gallery.first);

  factory MarketplaceProduct.fromJson(Map<String, dynamic> json) {
    final imageJson =
        (json['image'] ?? json['image_media']) as Map<String, dynamic>?;
    final galleryJson = json['gallery'] as List<dynamic>?;
    final rating = json['seller_rating'];
    return MarketplaceProduct(
      id: json['id'] as int,
      sellerId: json['seller_id'] as int,
      sellerName: json['seller_name'] as String? ?? 'Vendeur',
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'AUTRE',
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      price: json['price'].toString(),
      currency: json['currency'] as String? ?? 'XOF',
      image: imageJson == null ? null : MediaMeta.fromJson(imageJson),
      gallery: galleryJson == null
          ? const []
          : galleryJson
                .whereType<Map<String, dynamic>>()
                .map(MediaMeta.fromJson)
                .toList(),
      sellerIsCertified: json['seller_is_certified'] as bool? ?? false,
      sellerIsPro: json['seller_is_pro'] as bool? ?? false,
      // Le serveur renvoie un nombre JSON (int ou double selon la moyenne) —
      // `as double?` casserait sur une note ronde comme 4.
      sellerRating: rating == null ? null : (rating as num).toDouble(),
      sellerReviewCount: json['seller_review_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isBoosted: json['is_boosted'] as bool? ?? false,
    );
  }
}

/// Fiche de confiance d'un vendeur — en-tête de son catalogue.
class SellerProfile {
  const SellerProfile({
    required this.sellerId,
    required this.sellerName,
    required this.isCertified,
    this.isPro = false,
    required this.rating,
    required this.reviewCount,
    required this.productCount,
  });

  final int sellerId;
  final String sellerName;
  final bool isCertified;
  final bool isPro;
  final double? rating;
  final int reviewCount;
  final int productCount;

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'];
    return SellerProfile(
      sellerId: json['seller_id'] as int,
      sellerName: json['seller_name'] as String? ?? 'Vendeur',
      isCertified: json['is_certified'] as bool? ?? false,
      isPro: json['is_pro'] as bool? ?? false,
      rating: rating == null ? null : (rating as num).toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      productCount: json['product_count'] as int? ?? 0,
    );
  }
}

/// Avis laissé sur un vendeur. `isMine` est résolu côté serveur : c'est lui
/// qui sait quel avis appartient au lecteur, sans que le client compare des
/// identifiants.
class SellerReview {
  const SellerReview({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.isMine,
  });

  final int id;
  final int authorId;
  final String authorName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final bool isMine;

  factory SellerReview.fromJson(Map<String, dynamic> json) => SellerReview(
    id: json['id'] as int,
    authorId: json['author_id'] as int,
    authorName: json['author_name'] as String? ?? 'Utilisateur',
    rating: json['rating'] as int,
    comment: json['comment'] as String?,
    createdAt: parseServerTime(json['created_at'] as String),
    isMine: json['is_mine'] as bool? ?? false,
  );
}
