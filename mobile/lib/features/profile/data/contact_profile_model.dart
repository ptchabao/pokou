import '../../../core/crypto/media_cipher.dart';
import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/time/server_time.dart';

/// Fiche d'un contact, façon WhatsApp Business : ce qui a été échangé avec
/// lui (médias, documents, liens), ce qu'on a en commun (groupes), et les
/// actions qui le concernent (bloquer).
///
/// Modèle DÉDIÉ et non `PokouUser` : celui-là décrit la session (mon compte,
/// mon plan, mes jetons) ; y greffer des sections propres à la consultation
/// d'un tiers ferait grossir le modèle de session pour un écran, et forcerait
/// des champs vides partout ailleurs.
class ContactProfile {
  const ContactProfile({
    required this.userId,
    required this.displayName,
    required this.phone,
    required this.about,
    required this.avatar,
    required this.isBlocked,
    this.isContact = true,
    this.isVerified = false,
    this.sharedMedia = const [],
    this.sharedDocuments = const [],
    this.sharedLinks = const [],
    this.commonGroups = const [],
    this.products = const [],
  });

  final int userId;

  /// Le nom du carnet d'adresses l'emporte sur celui que la personne s'est
  /// choisi — c'est celui sous lequel on la reconnaît (résolu par l'API,
  /// voir `contact_display_name`).
  final String displayName;
  final String? phone;
  final String? about;
  final MediaMeta? avatar;
  final bool isBlocked;

  /// Dans MON carnet. Faux pour quelqu'un qui m'a écrit sans que j'aie son
  /// numéro : la fiche propose alors de l'enregistrer.
  final bool isContact;
  final bool isVerified;

  /// Photos et vidéos, du plus récent au plus ancien.
  final List<SharedAttachment> sharedMedia;

  /// Documents (PDF, notes vocales, fichiers) — séparés des visuels parce
  /// qu'ils se lisent en liste et non en grille.
  final List<SharedAttachment> sharedDocuments;
  final List<SharedLink> sharedLinks;
  final List<CommonGroup> commonGroups;
  final List<ContactProduct> products;

  bool get hasSharedContent =>
      sharedMedia.isNotEmpty ||
      sharedDocuments.isNotEmpty ||
      sharedLinks.isNotEmpty;

  factory ContactProfile.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'] as Map<String, dynamic>?;
    final contactName = (json['contact_display_name'] as String?)?.trim();
    final profileName = (json['full_name'] as String?)?.trim();
    // Un compte CERTIFIÉ garde son nom, même chez qui l'a enregistré
    // autrement — voir api/app/utils/identity.py::nom_affiche.
    final certified =
        (json['is_verified'] as bool? ?? false) &&
        profileName != null &&
        profileName.isNotEmpty;
    return ContactProfile(
      userId: json['id'] as int,
      displayName: certified
          ? profileName
          : (contactName != null && contactName.isNotEmpty)
          ? contactName
          : (profileName != null && profileName.isNotEmpty)
          ? profileName
          : (json['phone'] as String? ?? 'Contact'),
      phone: json['phone'] as String?,
      about: json['about'] as String?,
      avatar: avatarJson == null ? null : MediaMeta.fromJson(avatarJson),
      isBlocked: json['is_blocked'] as bool? ?? false,
      // Absent d'une ancienne API, qui n'ouvrait la fiche qu'aux contacts.
      isContact: json['is_contact'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      sharedMedia: _attachments(json['shared_media']),
      sharedDocuments: _attachments(json['shared_documents']),
      sharedLinks: ((json['shared_links'] as List?) ?? const [])
          .whereType<Object>()
          .map(SharedLink.fromAny)
          .toList(),
      commonGroups: ((json['common_groups'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CommonGroup.fromJson)
          .toList(),
      products: ((json['products'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ContactProduct.fromJson)
          .toList(),
    );
  }

  static List<SharedAttachment> _attachments(Object? raw) {
    return ((raw as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SharedAttachment.fromJson)
        // Une pièce jointe chiffrée dont la clé n'a pas encore été lue sur
        // cet appareil n'est, pour le serveur comme pour nous, qu'un bloc
        // opaque : on ne la montre pas plutôt que d'afficher une vignette
        // cassée. Elle apparaît dès que la conversation a été ouverte.
        .where((attachment) => !attachment.isOpaque)
        .toList();
  }
}

class SharedAttachment {
  const SharedAttachment({
    required this.media,
    required this.messageType,
    required this.sentAt,
  });

  final MediaMeta media;
  final String messageType;
  final DateTime sentAt;

  /// Bloc chiffré de bout en bout dont la clé est inconnue ici.
  bool get isOpaque =>
      media.mimeType == MediaCipher.uploadMimeType &&
      media.originalFilename == MediaCipher.uploadFilename;

  factory SharedAttachment.fromJson(Map<String, dynamic> json) {
    final media = MediaMeta.fromJson(json['media'] as Map<String, dynamic>);
    // Chiffrée et déjà ouverte : sa vraie description vient de sa clé.
    final key = MediaKeyRing.of(media.id);
    return SharedAttachment(
      media: key?.toMeta(media.id) ?? media,
      messageType: json['message_type'] as String? ?? 'DOCUMENT',
      sentAt: parseServerTime(json['created_at'] as String),
    );
  }
}

class SharedLink {
  const SharedLink({required this.url, this.sentAt});

  final String url;
  final DateTime? sentAt;

  /// Accepte les deux formes : l'objet `{url, created_at}` renvoyé
  /// aujourd'hui, et la simple chaîne que renvoyait la version précédente de
  /// l'API — un client à jour ne doit pas casser face à un serveur qui ne
  /// l'est pas encore (et inversement).
  factory SharedLink.fromAny(Object raw) {
    if (raw is String) return SharedLink(url: raw);
    final json = raw as Map<String, dynamic>;
    final sentAt = json['created_at'] as String?;
    return SharedLink(
      url: json['url'] as String,
      sentAt: sentAt == null ? null : tryParseServerTime(sentAt),
    );
  }

  String get host => Uri.tryParse(url)?.host ?? url;
}

class CommonGroup {
  const CommonGroup({
    required this.id,
    required this.name,
    required this.memberCount,
  });

  final int id;
  final String name;
  final int memberCount;

  factory CommonGroup.fromJson(Map<String, dynamic> json) => CommonGroup(
    id: json['id'] as int,
    name: json['name'] as String? ?? 'Groupe',
    memberCount: json['member_count'] as int? ?? 0,
  );
}

class ContactProduct {
  const ContactProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.image,
  });

  final int id;
  final String name;
  final String price;
  final String currency;
  final MediaMeta? image;

  factory ContactProduct.fromJson(Map<String, dynamic> json) {
    final imageJson = json['image'] as Map<String, dynamic>?;
    return ContactProduct(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Produit',
      price: json['price']?.toString() ?? '',
      currency: json['currency'] as String? ?? 'XOF',
      image: imageJson == null ? null : MediaMeta.fromJson(imageJson),
    );
  }
}
