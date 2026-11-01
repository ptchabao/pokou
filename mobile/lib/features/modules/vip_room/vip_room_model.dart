import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/time/server_time.dart';

/// Un salon d'abonnés.
class VipRoom {
  const VipRoom({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.pitch,
    required this.monthlyPrice,
    required this.isOpen,
    required this.isOwner,
    required this.isSubscribed,
    this.ownerName,
    this.expiresAt,
  });

  final int id;
  final int ownerId;
  final String title;

  /// Toujours visible, même sans abonnement : sans lui, personne n'a de
  /// raison de payer.
  final String pitch;

  final int monthlyPrice;
  final bool isOpen;
  final bool isOwner;
  final bool isSubscribed;
  final String? ownerName;
  final DateTime? expiresAt;

  factory VipRoom.fromJson(Map<String, dynamic> json) => VipRoom(
    id: json['id'] as int? ?? 0,
    ownerId: json['owner_id'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    pitch: json['pitch'] as String? ?? '',
    monthlyPrice: json['monthly_price'] as int? ?? 0,
    isOpen: json['is_open'] as bool? ?? true,
    isOwner: json['is_owner'] as bool? ?? false,
    isSubscribed: json['is_subscribed'] as bool? ?? false,
    ownerName: json['owner_name'] as String?,
    expiresAt: json['expires_at'] != null
        ? tryParseServerTime(json['expires_at'] as String)
        : null,
  );
}

class VipPost {
  const VipPost({required this.id, this.textContent, this.media});

  final int id;
  final String? textContent;

  /// Le média passe par la route authentifiée, comme partout ailleurs dans
  /// Pokou. Une URL publique contournerait l'abonnement.
  final MediaMeta? media;

  factory VipPost.fromJson(Map<String, dynamic> json) => VipPost(
    id: json['id'] as int? ?? 0,
    textContent: json['text_content'] as String?,
    media: json['media'] != null
        ? MediaMeta.fromJson(json['media'] as Map<String, dynamic>)
        : null,
  );
}

/// Le contenu d'un salon — ou son verrou.
///
/// `locked` vient du SERVEUR. C'est ce qui garantit que le contenu n'est pas
/// simplement caché à l'écran : il n'est jamais envoyé.
class VipRoomFeed {
  const VipRoomFeed({
    required this.room,
    required this.locked,
    required this.posts,
  });

  final VipRoom room;
  final bool locked;
  final List<VipPost> posts;

  factory VipRoomFeed.fromJson(Map<String, dynamic> json) => VipRoomFeed(
    room: VipRoom.fromJson((json['room'] as Map<String, dynamic>?) ?? const {}),
    locked: json['locked'] as bool? ?? true,
    posts: ((json['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(VipPost.fromJson)
        .toList(),
  );
}

/// Ce que mon salon a rapporté. « Dû », jamais « versé ».
class VipEarnings {
  const VipEarnings({
    required this.gross,
    required this.due,
    required this.subscriptions,
  });

  final int gross;
  final int due;
  final int subscriptions;

  factory VipEarnings.fromJson(Map<String, dynamic> json) => VipEarnings(
    gross: json['gross'] as int? ?? 0,
    due: json['due'] as int? ?? 0,
    subscriptions: json['subscriptions'] as int? ?? 0,
  );
}
