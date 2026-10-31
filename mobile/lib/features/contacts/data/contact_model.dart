import '../../../core/media/media_repository.dart';

class PokouContact {
  const PokouContact({
    required this.id,
    required this.phone,
    required this.displayName,
    this.contactUserId,
    this.about,
    this.avatar,
    required this.isRegistered,
    this.priorityTag,
    this.isVerified = false,
  });

  final int id;
  final String phone;
  final String displayName;
  final int? contactUserId;
  final String? about;
  final MediaMeta? avatar;
  final bool isRegistered;

  /// Compte certifié par Pokou — « est-ce bien cette personne ? ».
  ///
  /// À ne pas confondre avec le badge VENDEUR du marché, qui répond à
  /// « puis-je lui acheter quelque chose ? » et se paie (voir
  /// api/app/utils/identity.py).
  final bool isVerified;
  final String?
  priorityTag; // BUSINESS | FOURNISSEUR | CLIENT | BOSS | AMI (Mode Bouclier)

  bool get isPriorityContact => priorityTag != null && priorityTag != 'AMI';

  factory PokouContact.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'] as Map<String, dynamic>?;
    return PokouContact(
      id: json['id'] as int,
      phone: json['phone'] as String,
      displayName: json['display_name'] as String,
      contactUserId: json['contact_user_id'] as int?,
      about: json['about'] as String?,
      avatar: avatarJson != null ? MediaMeta.fromJson(avatarJson) : null,
      isRegistered: json['is_registered'] as bool? ?? false,
      priorityTag: json['priority_tag'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

/// Résultat de la recherche d'un numéro — voir ContactsRepository.lookup.
///
/// `registered == false` n'est pas un échec : c'est le cas normal d'un
/// numéro qui n'a pas encore Pokou, et celui qui doit proposer une
/// invitation plutôt qu'une erreur.
class PhoneLookup {
  const PhoneLookup({
    required this.phone,
    required this.registered,
    this.userId,
    this.displayName,
  });

  /// Numéro NORMALISÉ par le serveur (format international). C'est celui-ci
  /// qu'il faut renvoyer comme laissez-passer, pas celui tapé à la main.
  final String phone;
  final bool registered;
  final int? userId;
  final String? displayName;

  factory PhoneLookup.fromJson(Map<String, dynamic> json) => PhoneLookup(
    phone: json['phone'] as String,
    registered: json['registered'] as bool? ?? false,
    userId: json['user_id'] as int?,
    displayName: json['display_name'] as String?,
  );
}
