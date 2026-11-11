import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../l10n/app_localizations.dart';
import '../../../core/time/server_time.dart';
import 'status_text_style.dart';

class PokouStatus {
  const PokouStatus({
    required this.id,
    required this.userId,
    required this.contentType,
    required this.textContent,
    required this.media,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedByMe,
    required this.viewCount,
    this.contentUnavailable = false,
    this.textStyle = StatusTextStyle.plain,
  });

  final String id;
  final int userId;
  final String contentType; // TEXT | IMAGE | VIDEO
  final String? textContent;
  final MediaMeta? media;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewedByMe;
  final int viewCount;
  final bool contentUnavailable;

  /// Le fond et la police d'un statut en texte (voir [StatusTextStyle]).
  final StatusTextStyle textStyle;

  factory PokouStatus.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'] as Map<String, dynamic>?;
    // Le style voyage devant le texte, en caractères invisibles : on le
    // sépare ici, une fois, pour que `textContent` soit partout le texte
    // que l'auteur a écrit.
    final rawText = json['text_content'] as String?;
    final (style, text) = rawText == null
        ? (StatusTextStyle.plain, null)
        : StatusTextStyle.decode(rawText);
    return PokouStatus(
      id: json['id'] as String,
      userId: json['user_id'] as int,
      contentType: json['content_type'] as String,
      textContent: text,
      textStyle: style,
      media: mediaJson != null ? MediaMeta.fromJson(mediaJson) : null,
      createdAt: parseServerTime(json['created_at'] as String),
      expiresAt: parseServerTime(json['expires_at'] as String),
      viewedByMe: json['viewed_by_me'] as bool? ?? false,
      viewCount: json['view_count'] as int? ?? 0,
      contentUnavailable: json['status_unavailable'] as bool? ?? false,
    );
  }
}

class StatusFeedItem {
  const StatusFeedItem({
    required this.userId,
    required this.displayName,
    required this.statuses,
    this.avatar,
    this.isVerified = false,
  });

  final int userId;
  final String displayName;
  final List<PokouStatus> statuses;
  final MediaMeta? avatar;

  /// Compte certifié — voir api/app/utils/identity.py.
  final bool isVerified;

  /// Au moins un statut que JE n'ai pas vu.
  ///
  /// C'est ce qui allume l'anneau autour de la photo, partout dans
  /// l'application. « Non vu », et non « existe » : un anneau permanent
  /// autour de quelqu'un qui publie tous les jours ne dirait plus rien.
  bool get hasUnseen => statuses.any((s) => !s.viewedByMe);

  bool get allViewed => statuses.every((s) => s.viewedByMe);

  factory StatusFeedItem.fromJson(Map<String, dynamic> json) {
    final items = (json['statuses'] as List).cast<Map<String, dynamic>>();
    return StatusFeedItem(
      userId: json['user_id'] as int,
      displayName: json['display_name'] as String,
      avatar: json['avatar'] == null
          ? null
          : MediaMeta.fromJson(json['avatar'] as Map<String, dynamic>),
      statuses: items.map(PokouStatus.fromJson).toList(),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

/// Qui peut voir MES statuts. L'audience est décidée par l'auteur, pas par le
/// spectateur : ajouter quelqu'un à son carnet ne donne pas accès à ses
/// statuts (voir api/app/services/status_privacy_service.py).
enum StatusAudience {
  /// Mes contacts — le défaut.
  contacts('CONTACTS'),

  /// Personne : les statuts ne restent visibles que pour moi.
  nobody('NOBODY'),

  /// Mes contacts SAUF les personnes listées.
  except('EXCEPT'),

  /// Uniquement les personnes listées — aucune relation de contact requise.
  only('ONLY');

  const StatusAudience(this.wire);

  /// Valeur envoyée à l'API. Séparée du nom Dart : `except` est un mot
  /// réservé côté serveur… et un nom d'énumération acceptable côté Dart.
  final String wire;

  static StatusAudience fromWire(String? raw) =>
      StatusAudience.values.firstWhere(
        (value) => value.wire == raw,
        orElse: () => StatusAudience.contacts,
      );

  /// Les deux modes qui s'appuient sur une liste de personnes.
  bool get needsList =>
      this == StatusAudience.except || this == StatusAudience.only;

  String labelOf(L l) => switch (this) {
    StatusAudience.contacts => l.audienceContacts,
    StatusAudience.nobody => l.audienceNobody,
    StatusAudience.except => l.audienceExcept,
    StatusAudience.only => l.audienceOnly,
  };

  String descriptionOf(L l) => switch (this) {
    StatusAudience.contacts => l.audienceContactsDesc,
    StatusAudience.nobody => l.audienceNobodyDesc,
    StatusAudience.except => l.audienceExceptDesc,
    StatusAudience.only => l.audienceOnlyDesc,
  };
}

class StatusPrivacy {
  const StatusPrivacy({required this.audience, required this.userIds});

  final StatusAudience audience;

  /// Exclusions en mode « sauf », autorisations en mode « uniquement ».
  final List<int> userIds;

  factory StatusPrivacy.fromJson(Map<String, dynamic> json) => StatusPrivacy(
    audience: StatusAudience.fromWire(json['mode'] as String?),
    userIds: ((json['user_ids'] as List?) ?? const []).cast<int>(),
  );
}

/// Une vue d'un statut : QUI l'a vu et QUAND. Réservé à l'auteur du statut
/// côté API (savoir qui regarde le statut d'un autre n'est le droit de
/// personne), d'où l'absence de ce modèle dans le fil public.
class StatusViewer {
  const StatusViewer({
    required this.viewerId,
    required this.displayName,
    required this.avatar,
    required this.viewedAt,
  });

  final int viewerId;

  /// Résolu côté serveur : le nom du carnet d'adresses de l'AUTEUR l'emporte
  /// sur celui que le spectateur s'est choisi — c'est sous ce nom que
  /// l'auteur le reconnaît.
  final String displayName;
  final MediaMeta? avatar;
  final DateTime viewedAt;

  factory StatusViewer.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'] as Map<String, dynamic>?;
    return StatusViewer(
      viewerId: json['viewer_id'] as int,
      // Repli défensif : le serveur fournit toujours un nom.
      displayName: json['display_name'] as String? ?? '',
      avatar: avatarJson == null ? null : MediaMeta.fromJson(avatarJson),
      viewedAt: parseServerTime(json['viewed_at'] as String),
    );
  }
}
