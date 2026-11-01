import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/time/server_time.dart';

/// Ce que je cherche aujourd'hui.
class SparkIntent {
  const SparkIntent({
    required this.kind,
    required this.label,
    required this.secondsLeft,
  });

  final String kind;
  final String label;

  /// Donné par le SERVEUR. L'expiration est la mécanique centrale du
  /// produit : la recalculer côté téléphone la ferait dépendre d'une horloge
  /// qu'on ne contrôle pas.
  final int secondsLeft;

  factory SparkIntent.fromJson(Map<String, dynamic> json) => SparkIntent(
    kind: json['kind'] as String? ?? '',
    label: json['label'] as String? ?? '',
    secondsLeft: json['seconds_left'] as int? ?? 0,
  );
}

class SparkIntentOption {
  const SparkIntentOption({required this.kind, required this.label});

  final String kind;
  final String label;

  factory SparkIntentOption.fromJson(Map<String, dynamic> json) =>
      SparkIntentOption(
        kind: json['kind'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

/// Ma fiche Spark — distincte de mon profil Pokou.
class SparkProfile {
  const SparkProfile({
    required this.displayName,
    required this.age,
    required this.gender,
    required this.karma,
    required this.canInvite,
    required this.likesLeft,
    required this.likesBalance,
    required this.viewsLeft,
    required this.hasPlus,
    required this.canSeeLikers,
    required this.isBoosted,
    required this.isVisible,
    required this.locationIsFresh,
    required this.photos,
    this.bio,
    this.birthDate,
  });

  final String displayName;
  final int age;
  final String gender;
  final int karma;
  final bool canInvite;

  /// `-1` signifie « sans limite ». Le serveur le dit ainsi, et l'écran doit
  /// l'afficher ainsi — montrer « -1 like » serait le seul endroit où
  /// l'application mentirait sur un compte.
  final int likesLeft;
  final int likesBalance;
  final int viewsLeft;

  final bool hasPlus;
  final bool canSeeLikers;
  final bool isBoosted;
  final bool isVisible;
  final bool locationIsFresh;
  final List<SparkPhoto> photos;
  final String? bio;
  final String? birthDate;

  bool get likesAreUnlimited => likesLeft < 0;

  factory SparkProfile.fromJson(Map<String, dynamic> json) => SparkProfile(
    displayName: json['display_name'] as String? ?? '',
    age: json['age'] as int? ?? 0,
    gender: json['gender'] as String? ?? 'AUTRE',
    karma: json['karma'] as int? ?? 0,
    canInvite: json['can_invite'] as bool? ?? true,
    likesLeft: json['likes_left'] as int? ?? 0,
    likesBalance: json['likes_balance'] as int? ?? 0,
    viewsLeft: json['views_left'] as int? ?? 0,
    hasPlus: json['has_plus'] as bool? ?? false,
    canSeeLikers: json['can_see_likers'] as bool? ?? false,
    isBoosted: json['is_boosted'] as bool? ?? false,
    isVisible: json['is_visible'] as bool? ?? true,
    locationIsFresh: json['location_is_fresh'] as bool? ?? false,
    bio: json['bio'] as String?,
    birthDate: json['birth_date'] as String?,
    photos: ((json['photos'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkPhoto.fromJson)
        .toList(),
  );
}

class SparkPhoto {
  const SparkPhoto({required this.id, this.media});

  final int id;
  final MediaMeta? media;

  factory SparkPhoto.fromJson(Map<String, dynamic> json) => SparkPhoto(
    id: json['id'] as int? ?? 0,
    media: json['media'] != null
        ? MediaMeta.fromJson(json['media'] as Map<String, dynamic>)
        : null,
  );
}

/// Une carte du flux.
///
/// Ne porte NI nom Pokou, NI numéro : ouvrir Spark n'expose pas le compte de
/// messagerie, et le modèle n'a donc aucun champ pour les recevoir.
class SparkCard {
  const SparkCard({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.karma,
    required this.photos,
    this.bio,
    this.distanceKm,
    this.intentLabel,
  });

  final int userId;
  final String displayName;
  final int age;
  final int karma;
  final List<SparkPhoto> photos;
  final String? bio;
  final double? distanceKm;
  final String? intentLabel;

  factory SparkCard.fromJson(Map<String, dynamic> json) => SparkCard(
    userId: json['user_id'] as int? ?? 0,
    displayName: json['display_name'] as String? ?? '',
    age: json['age'] as int? ?? 0,
    karma: json['karma'] as int? ?? 0,
    bio: json['bio'] as String?,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    intentLabel: json['intent_label'] as String?,
    photos: ((json['photos'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkPhoto.fromJson)
        .toList(),
  );
}

/// Le flux, et ce qui lui manque pour exister.
///
/// Les trois « manques » sont des états à part entière, pas des listes vides :
/// un écran vide laisse croire à une panne, alors que ce qu'il faut dire est
/// « choisissez une intention », « activez votre position » ou « vous avez vu
/// vos vingt profils ».
class SparkFeed {
  const SparkFeed({
    required this.items,
    required this.needsIntent,
    required this.needsLocation,
    required this.quotaReached,
    this.message,
    this.viewsLeft,
  });

  final List<SparkCard> items;
  final bool needsIntent;
  final bool needsLocation;
  final bool quotaReached;
  final String? message;
  final int? viewsLeft;

  factory SparkFeed.fromJson(Map<String, dynamic> json) => SparkFeed(
    items: ((json['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkCard.fromJson)
        .toList(),
    needsIntent: json['needs_intent'] as bool? ?? false,
    needsLocation: json['needs_location'] as bool? ?? false,
    quotaReached: json['quota_reached'] as bool? ?? false,
    message: json['message'] as String?,
    viewsLeft: json['views_left'] as int?,
  );
}

/// Un match et sa Salle d'Entrée.
class SparkMatch {
  const SparkMatch({
    required this.id,
    required this.status,
    required this.roomSecondsLeft,
    required this.extensions,
    required this.canExtend,
    required this.extensionPrice,
    required this.iContinued,
    this.peer,
    this.peerContinued,
    this.messages = const [],
  });

  final int id;

  /// `ROOM`, `CONTINUED`, `SAVED` ou `EXPIRED`.
  final String status;

  final int roomSecondsLeft;
  final int extensions;
  final bool canExtend;
  final int extensionPrice;
  final bool iContinued;
  final SparkCard? peer;

  /// `null` tant que la salle est ouverte, volontairement : savoir que
  /// l'autre a déjà appuyé transformerait « veux-tu continuer ? » en
  /// « oseras-tu refuser ? ».
  final bool? peerContinued;

  final List<SparkRoomMessage> messages;

  bool get isOpen => status == 'ROOM';
  bool get isLive =>
      status == 'ROOM' || status == 'CONTINUED' || status == 'SAVED';

  factory SparkMatch.fromJson(Map<String, dynamic> json) => SparkMatch(
    id: json['id'] as int? ?? 0,
    status: json['status'] as String? ?? 'ROOM',
    roomSecondsLeft: json['room_seconds_left'] as int? ?? 0,
    extensions: json['extensions'] as int? ?? 0,
    canExtend: json['can_extend'] as bool? ?? false,
    extensionPrice: json['extension_price'] as int? ?? 0,
    iContinued: json['i_continued'] as bool? ?? false,
    peerContinued: json['peer_continued'] as bool?,
    peer: json['peer'] != null
        ? SparkCard.fromJson(json['peer'] as Map<String, dynamic>)
        : null,
    messages: ((json['messages'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkRoomMessage.fromJson)
        .toList(),
  );
}

class SparkRoomMessage {
  const SparkRoomMessage({
    required this.id,
    required this.kind,
    required this.isMine,
    this.sticker,
    this.media,
  });

  final int id;

  /// `VOICE` ou `STICKER`. Jamais de texte — le serveur le refuse.
  final String kind;

  final bool isMine;
  final String? sticker;
  final MediaMeta? media;

  factory SparkRoomMessage.fromJson(Map<String, dynamic> json) =>
      SparkRoomMessage(
        id: json['id'] as int? ?? 0,
        kind: json['kind'] as String? ?? 'STICKER',
        isMine: json['is_mine'] as bool? ?? false,
        sticker: json['sticker'] as String?,
        media: json['media'] != null
            ? MediaMeta.fromJson(json['media'] as Map<String, dynamic>)
            : null,
      );
}

/// L'avis agrégé des amis. Jamais le détail.
class WingmanVerdict {
  const WingmanVerdict({
    required this.asked,
    required this.answered,
    this.verdict,
    this.label,
  });

  final int asked;
  final int answered;
  final String? verdict;
  final String? label;

  factory WingmanVerdict.fromJson(Map<String, dynamic> json) => WingmanVerdict(
    asked: json['asked'] as int? ?? 0,
    answered: json['answered'] as int? ?? 0,
    verdict: json['verdict'] as String?,
    label: json['label'] as String?,
  );
}

class WingmanRequest {
  const WingmanRequest({
    required this.id,
    required this.askedBy,
    required this.candidate,
  });

  final int id;
  final String askedBy;
  final SparkCard candidate;

  factory WingmanRequest.fromJson(Map<String, dynamic> json) => WingmanRequest(
    id: json['id'] as int? ?? 0,
    askedBy: json['asked_by'] as String? ?? 'Un ami',
    candidate: SparkCard.fromJson(
      (json['candidate'] as Map<String, dynamic>?) ?? const {},
    ),
  );
}

/// Une formule de rendez-vous.
class SparkPack {
  const SparkPack({
    required this.id,
    required this.title,
    required this.venueName,
    required this.price,
    this.description,
    this.venueAddress,
    this.media,
  });

  final int id;
  final String title;
  final String venueName;
  final int price;
  final String? description;
  final String? venueAddress;
  final MediaMeta? media;

  factory SparkPack.fromJson(Map<String, dynamic> json) => SparkPack(
    id: json['id'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    venueName: json['venue_name'] as String? ?? '',
    price: json['price'] as int? ?? 0,
    description: json['description'] as String?,
    venueAddress: json['venue_address'] as String?,
    media: json['media'] != null
        ? MediaMeta.fromJson(json['media'] as Map<String, dynamic>)
        : null,
  );
}

/// Un rendez-vous, et l'argent qui l'accompagne.
class SparkDate {
  const SparkDate({
    required this.id,
    required this.matchId,
    required this.status,
    required this.amount,
    required this.scheduledAt,
    required this.isPayer,
    required this.iValidated,
    required this.canValidate,
    required this.canCancelFree,
    required this.peerId,
    this.peerName,
    this.pack,
    this.voucherCode,
    this.settlement,
  });

  final int id;
  final int matchId;

  /// `PENDING`, `HELD`, `RELEASED`, `REFUNDED`, `PENALIZED` ou `CANCELLED`.
  final String status;

  final int amount;
  final DateTime scheduledAt;
  final bool isPayer;
  final bool iValidated;
  final bool canValidate;
  final bool canCancelFree;

  /// L'identifiant de l'autre. Nécessaire pour signaler SON absence — le
  /// serveur exige un identifiant, précisément pour qu'on ne puisse pas se
  /// désigner soi-même absent et récupérer la moitié de sa propre mise.
  final int peerId;

  final String? peerName;
  final SparkPack? pack;

  /// Le bon. N'existe qu'une fois l'argent encaissé — un code émis avant
  /// paiement serait un repas gratuit.
  final String? voucherCode;

  final SparkSettlement? settlement;

  bool get isHeld => status == 'HELD';
  bool get isSettled => settlement != null;

  factory SparkDate.fromJson(Map<String, dynamic> json) => SparkDate(
    id: json['id'] as int? ?? 0,
    matchId: json['match_id'] as int? ?? 0,
    status: json['status'] as String? ?? 'PENDING',
    amount: json['amount'] as int? ?? 0,
    scheduledAt:
        tryParseServerTime(json['scheduled_at'] as String? ?? '') ??
        DateTime.now(),
    isPayer: json['is_payer'] as bool? ?? false,
    iValidated: json['i_validated'] as bool? ?? false,
    canValidate: json['can_validate'] as bool? ?? false,
    canCancelFree: json['can_cancel_free'] as bool? ?? false,
    peerId: json['peer_id'] as int? ?? 0,
    peerName: json['peer_name'] as String?,
    voucherCode: json['voucher_code'] as String?,
    pack: json['pack'] != null
        ? SparkPack.fromJson(json['pack'] as Map<String, dynamic>)
        : null,
    settlement: json['settlement'] != null
        ? SparkSettlement.fromJson(json['settlement'] as Map<String, dynamic>)
        : null,
  );
}

/// Le dénouement d'une séquestre. « Dû », jamais « versé ».
class SparkSettlement {
  const SparkSettlement({
    required this.penaltyToMe,
    this.merchantDue,
    this.platformFee,
    this.penaltyAmount,
  });

  final bool penaltyToMe;
  final int? merchantDue;
  final int? platformFee;
  final int? penaltyAmount;

  factory SparkSettlement.fromJson(Map<String, dynamic> json) =>
      SparkSettlement(
        penaltyToMe: json['penalty_to_me'] as bool? ?? false,
        merchantDue: json['merchant_due'] as int?,
        platformFee: json['platform_fee'] as int?,
        penaltyAmount: json['penalty_amount'] as int?,
      );
}

/// Les prix, dits par le serveur une seule fois.
class SparkShop {
  const SparkShop({
    required this.likePacks,
    required this.superSpark,
    required this.roomExtension,
    required this.plusMonthly,
    required this.seeLikersWeekly,
    required this.boostHour,
  });

  final List<({int size, int price})> likePacks;
  final int superSpark;
  final int roomExtension;
  final int plusMonthly;
  final int seeLikersWeekly;
  final int boostHour;

  factory SparkShop.fromJson(Map<String, dynamic> json) => SparkShop(
    likePacks: ((json['like_packs'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (pack) => (
            size: pack['size'] as int? ?? 0,
            price: pack['price'] as int? ?? 0,
          ),
        )
        .toList(),
    superSpark: json['super_spark'] as int? ?? 0,
    roomExtension: json['room_extension'] as int? ?? 0,
    plusMonthly: json['plus_monthly'] as int? ?? 0,
    seeLikersWeekly: json['see_likers_weekly'] as int? ?? 0,
    boostHour: json['boost_hour'] as int? ?? 0,
  );
}

/// Une vérification « tout va bien ? ».
class SparkCheckin {
  const SparkCheckin({required this.id, required this.dueAt, this.dateId});

  final int id;
  final DateTime dueAt;
  final int? dateId;

  factory SparkCheckin.fromJson(Map<String, dynamic> json) => SparkCheckin(
    id: json['id'] as int? ?? 0,
    dueAt: tryParseServerTime(json['due_at'] as String? ?? '') ?? DateTime.now(),
    dateId: json['date_id'] as int?,
  );
}

class SparkSafetyContact {
  const SparkSafetyContact({
    required this.id,
    required this.userId,
    required this.name,
  });

  final int id;
  final int userId;
  final String name;

  factory SparkSafetyContact.fromJson(Map<String, dynamic> json) =>
      SparkSafetyContact(
        id: json['id'] as int? ?? 0,
        userId: json['user_id'] as int? ?? 0,
        name: json['name'] as String? ?? 'Contact',
      );
}
