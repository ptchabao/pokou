import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../l10n/app_localizations.dart';

/// Aperçu du dernier message d'une conversation — juste de quoi remplir une
/// ligne de la liste (voir GET /conversations, api/app/routes/conversations.py
/// ::_last_message_payload), pas le message complet.
class ConversationPreview {
  ConversationPreview({
    required this.messageId,
    required this.messageType,
    required this.content,
    required this.createdAt,
    required this.senderId,
    required this.senderName,
    required this.isMine,
    this.encrypted = false,
  });

  final String messageId;
  final String messageType;
  final String? content;
  final DateTime createdAt;
  final int senderId;
  final String? senderName;
  final bool isMine;

  /// Le dernier message est chiffré, donc `content` est vide — le serveur ne
  /// pouvait pas le lire. Le clair se retrouve dans le cache local, où il a
  /// déjà été déchiffré (voir localContent).
  final bool encrypted;

  /// Texte déchiffré retrouvé dans le cache local, posé après coup.
  ///
  /// Hors du constructeur à dessein : il ne vient pas du réseau, et le
  /// mélanger à `content` ferait perdre la trace de qui a produit quoi.
  String? localContent;

  factory ConversationPreview.fromJson(Map<String, dynamic> json) =>
      ConversationPreview(
        messageId: json['id'] as String,
        messageType: json['message_type'] as String? ?? 'TEXT',
        content: json['content'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        senderId: json['sender_id'] as int,
        senderName: json['sender_name'] as String?,
        isMine: json['is_mine'] as bool? ?? false,
        encrypted: json['encrypted'] as bool? ?? false,
      );

  /// Libellé affichable dans la liste — un média sans légende doit dire CE
  /// QUE C'EST (WhatsApp affiche « 📷 Photo », jamais une ligne vide).
  String displayTextOf(L l) {
    if (content != null && content!.trim().isNotEmpty) return content!;

    // Message chiffré : le serveur n'a rien pu envoyer, mais l'appareil a
    // déjà déchiffré ce message et le garde en clair dans son cache. Sans
    // ce rattrapage, la liste d'accueil afficherait une ligne blanche pour
    // chaque conversation chiffrée — visuellement, la fonctionnalité aurait
    // l'air cassée alors qu'elle marche.
    if (encrypted) {
      final local = localContent;
      if (local != null && local.trim().isNotEmpty) return local;
      // Pas encore en cache (message reçu pendant que l'app était fermée) :
      // on dit CE QUE C'EST plutôt que de laisser vide.
      if (messageType == 'TEXT')
        return content?.trim().isNotEmpty == true ? content! : l.mediaMessage;
    }

    return switch (messageType) {
      'IMAGE' => l.mediaPhoto,
      'VIDEO' => l.mediaVideo,
      'AUDIO' => l.mediaVoiceNote,
      'DOCUMENT' => l.mediaDocument,
      'LOCATION' => l.mediaLocation,
      'CONTACT' => l.mediaSharedContact,
      'POLL' => l.mediaPoll,
      // Un appel terminé est désormais un message du fil : sans cette
      // ligne, la dernière activité d'une conversation où l'on vient de se
      // parler s'afficherait VIDE dans la liste d'accueil.
      'CALL' => l.mediaCall,
      'STICKER' => l.mediaSticker,
      _ => '',
    };
  }
}

/// Une ligne de l'écran d'accueil — un contact (1:1) ou un groupe, mélangés
/// dans une seule liste déjà triée par le serveur (épinglées d'abord, puis
/// activité). Voir GET /conversations pour la forme exacte.
class ConversationSummary {
  const ConversationSummary({
    required this.kind,
    required this.id,
    required this.name,
    this.communityName,
    required this.avatar,
    required this.isPinned,
    required this.isMuted,
    required this.isArchived,
    required this.isUnknownContact,
    required this.contactUserId,
    required this.lastMessage,
    required this.unreadCount,
    this.groupCount = 0,
    this.isVerified = false,
    this.isBot = false,
  });

  final String kind; // contact | group | community
  /// Id du Contact/GroupMember réglable (pin/archive/mute), ou null pour un
  /// inconnu qui m'a écrit sans avoir de ligne Contact de mon côté — voir
  /// `is_unknown_contact`.
  final int? id;
  final String name;
  final String? communityName;
  final MediaMeta? avatar;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;

  /// Personne qui m'a écrit sans figurer dans mon carnet — façon WhatsApp,
  /// elle apparaît quand même. Le client ne doit pas proposer les actions
  /// habituelles (épingler/archiver/muter) tant que cette ligne n'existe pas.
  final bool isUnknownContact;

  /// Compte certifié — une propriété du COMPTE, servie par l'API sous un nom
  /// neutre (voir api/app/utils/identity.py). Toujours `false` pour un
  /// groupe ou une communauté : ce ne sont pas des personnes.
  final bool isVerified;

  /// Le bot d'une entreprise (Pokou Business) — ni « inconnu » à ajouter,
  /// ni conversation chiffrée.
  final bool isBot;
  final int? contactUserId; // uniquement kind == "contact"
  final ConversationPreview? lastMessage;
  final int unreadCount;

  /// Nombre de groupes, pour `kind == 'community'` uniquement.
  ///
  /// Les groupes d'une communauté ne figurent PAS séparément dans la liste :
  /// les afficher aux deux endroits montrerait la même conversation deux
  /// fois, et on n'ouvrirait jamais une communauté dont on voit déjà tous
  /// les groupes au-dessus. Ce compte est ce qui remplace leur absence.
  final int groupCount;

  bool get isCommunity => kind == 'community';

  String get displayName =>
      communityName == null ? name : '$communityName - $name';

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'] as Map<String, dynamic>?;
    final lastMessageJson = json['last_message'] as Map<String, dynamic>?;
    return ConversationSummary(
      kind: json['kind'] as String? ?? 'contact',
      id: json['id'] as int?,
      // Nom de repli : le serveur en fournit toujours un, cette branche ne
      // sert qu'à ne pas planter sur une charge utile abîmée.
      name: json['name'] as String? ?? '',
      communityName: json['community_name'] as String?,
      avatar: avatarJson != null ? MediaMeta.fromJson(avatarJson) : null,
      isPinned: json['is_pinned'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      isUnknownContact: json['is_unknown_contact'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      isBot: json['is_bot'] as bool? ?? false,
      contactUserId: json['contact_user_id'] as int?,
      lastMessage: lastMessageJson != null
          ? ConversationPreview.fromJson(lastMessageJson)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      groupCount: json['group_count'] as int? ?? 0,
    );
  }
}
