import '../../../core/media/media_repository.dart' show MediaMeta;

class PokouUser {
  const PokouUser({
    required this.id,
    this.email,
    this.phone,
    this.fullName,
    this.about,
    required this.plan,
    this.avatarMediaId,
    this.avatar,
    this.products = const [],
    this.sharedMedia = const [],
    this.sharedLinks = const [],
    this.isVerified = false,
    this.isCertificationPending = false,
    this.isCertifiedSeller = false,
    this.certifiedSellerUntil,
  });

  final int id;
  final String? email;
  final String? phone;
  final String? fullName;
  final String? about;
  final String plan;
  final int? avatarMediaId;
  final MediaMeta? avatar;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> sharedMedia;
  final List<String> sharedLinks;
  final bool isVerified;
  final bool isCertificationPending;

  /// Vendeur vérifié du Marché — distinct de [isVerified], le ✓ d'identité.
  /// C'est ce statut que pose l'approbation du dossier ouvert depuis
  /// « Vérifier mon compte ».
  final bool isCertifiedSeller;
  final DateTime? certifiedSellerUntil;

  factory PokouUser.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'] as Map<String, dynamic>?;
    return PokouUser(
      id: json['id'] as int,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String?,
      about: json['about'] as String?,
      plan: json['plan'] as String? ?? 'free',
      avatarMediaId: json['avatar_media_id'] as int?,
      avatar: avatarJson != null ? MediaMeta.fromJson(avatarJson) : null,
      products: ((json['products'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
      sharedMedia: ((json['shared_media'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
      sharedLinks: ((json['shared_links'] as List?) ?? const []).cast<String>(),
      isVerified: json['is_verified'] as bool? ?? false,
      isCertificationPending:
          json['is_certification_pending'] as bool? ?? false,
      isCertifiedSeller: json['is_certified_seller'] as bool? ?? false,
      certifiedSellerUntil: DateTime.tryParse(
        json['certified_seller_until'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'full_name': fullName,
    'about': about,
    'plan': plan,
    'avatar_media_id': avatarMediaId,
    'is_verified': isVerified,
    'is_certification_pending': isCertificationPending,
    'is_certified_seller': isCertifiedSeller,
    'certified_seller_until': certifiedSellerUntil?.toIso8601String(),
  };

  PokouUser copyWith({
    int? id,
    String? email,
    String? phone,
    String? fullName,
    String? about,
    String? plan,
    int? avatarMediaId,
    MediaMeta? avatar,
    List<Map<String, dynamic>>? products,
    List<Map<String, dynamic>>? sharedMedia,
    List<String>? sharedLinks,
    bool? isVerified,
    bool? isCertificationPending,
    bool? isCertifiedSeller,
    DateTime? certifiedSellerUntil,
  }) {
    return PokouUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      about: about ?? this.about,
      plan: plan ?? this.plan,
      avatarMediaId: avatarMediaId ?? this.avatarMediaId,
      avatar: avatar ?? this.avatar,
      products: products ?? this.products,
      sharedMedia: sharedMedia ?? this.sharedMedia,
      sharedLinks: sharedLinks ?? this.sharedLinks,
      isVerified: isVerified ?? this.isVerified,
      isCertificationPending:
          isCertificationPending ?? this.isCertificationPending,
      isCertifiedSeller: isCertifiedSeller ?? this.isCertifiedSeller,
      certifiedSellerUntil: certifiedSellerUntil ?? this.certifiedSellerUntil,
    );
  }

  String get displayName => fullName ?? phone ?? email ?? 'Utilisateur';
}
