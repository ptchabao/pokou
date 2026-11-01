import '../../../core/crypto/media_cipher.dart';
import '../../../core/media/media_repository.dart' show MediaMeta;

enum DirectMessageStatus { sent, delivered, read }

/// Aperçu compact d'un message cité — WhatsApp affiche l'auteur et un
/// extrait au-dessus du texte, sans recharger le message d'origine à chaque
/// bulle. Même forme renvoyée par messages.py et groups.py (voir
/// `_serialize_reply_preview` dans chacun) : `senderName` n'est renseigné que
/// côté groupe, où l'auteur n'est pas évident du seul sens de la bulle.
class MessageReplyPreview {
  const MessageReplyPreview({
    required this.id,
    required this.senderId,
    required this.messageType,
    required this.content,
    this.senderName,
    this.senderCertifiedName,
  });

  final String id;
  final int senderId;
  final String messageType;
  final String? content;
  final String? senderName;

  /// Le nom d'un auteur CERTIFIÉ, qui l'emporte sur le carnet (voir
  /// api/app/utils/identity.py::nom_affiche). Nul sinon.
  final String? senderCertifiedName;

  factory MessageReplyPreview.fromJson(Map<String, dynamic> json) =>
      MessageReplyPreview(
        id: json['id'] as String,
        senderId: json['sender_id'] as int,
        messageType: json['message_type'] as String? ?? 'TEXT',
        content: json['content'] as String?,
        senderName: json['sender_name'] as String?,
        senderCertifiedName: json['sender_certified_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'message_type': messageType,
    'content': content,
    if (senderName != null) 'sender_name': senderName,
    if (senderCertifiedName != null)
      'sender_certified_name': senderCertifiedName,
  };
}

/// Réaction agrégée par emoji (« 👍 3 ») — voir
/// api/app/routes/messages.py::_serialize_reactions et son pendant côté
/// groupe. `mine` est absent de certains événements de groupe (diffusés sans
/// point de vue précis) ; `false` par défaut y est le choix sûr, une bulle ne
/// doit jamais prétendre à tort qu'on a déjà réagi.
class MessageReactionSummary {
  const MessageReactionSummary({
    required this.emoji,
    required this.count,
    required this.userIds,
    required this.mine,
  });

  final String emoji;
  final int count;
  final List<int> userIds;
  final bool mine;

  factory MessageReactionSummary.fromJson(Map<String, dynamic> json) =>
      MessageReactionSummary(
        emoji: json['emoji'] as String,
        count: json['count'] as int? ?? 0,
        userIds: (json['user_ids'] as List<dynamic>? ?? const []).cast<int>(),
        mine: json['mine'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'count': count,
    'user_ids': userIds,
    'mine': mine,
  };
}

/// Option d'un sondage, avec le compte de votes déjà agrégé côté serveur —
/// voir api/app/routes/polls.py::_serialize_poll.
class PollOptionData {
  const PollOptionData({
    required this.id,
    required this.text,
    required this.position,
    required this.voteCount,
    required this.voterIds,
    required this.mine,
  });

  final int id;
  final String text;
  final int position;
  final int voteCount;
  final List<int> voterIds;
  final bool mine;

  factory PollOptionData.fromJson(Map<String, dynamic> json) => PollOptionData(
    id: json['id'] as int,
    text: json['text'] as String,
    position: json['position'] as int? ?? 0,
    voteCount: json['vote_count'] as int? ?? 0,
    voterIds: (json['voters'] as List<dynamic>? ?? const []).cast<int>(),
    mine: json['mine'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'position': position,
    'vote_count': voteCount,
    'voters': voterIds,
    'mine': mine,
  };
}

/// Sondage attaché à un message de type POLL — même forme dupliquée à
/// l'identique dans messages.py, groups.py et polls.py (voir leurs
/// `_serialize_poll`) : l'historique rechargé doit porter la même forme que
/// l'événement WebSocket `poll:vote`, sinon les barres de vote clignoteraient
/// entre deux représentations au moindre rechargement.
class PollData {
  const PollData({
    required this.id,
    required this.question,
    required this.allowsMultiple,
    required this.options,
    required this.totalVoters,
    this.revealsVoters = true,
  });

  final String id;
  final String question;
  final bool allowsMultiple;
  final List<PollOptionData> options;
  final int totalVoters;

  /// Faux pour un sondage de CHAÎNE : le serveur y renvoie `voters` vide
  /// exprès (une chaîne publique ne publie pas qui a voté quoi — voir
  /// polls.py::_serialize_poll). À lire AVANT de conclure quoi que ce soit
  /// d'un `voterIds` vide : « masqué » et « personne n'a voté » se
  /// ressemblent dans les données, pas dans ce qu'on peut en dire.
  /// Vrai par défaut, pour les charges utiles antérieures au champ.
  final bool revealsVoters;

  factory PollData.fromJson(Map<String, dynamic> json) => PollData(
    id: json['id'] as String,
    question: json['question'] as String,
    allowsMultiple: json['allows_multiple'] as bool? ?? false,
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((raw) => PollOptionData.fromJson(raw as Map<String, dynamic>))
        .toList(),
    totalVoters: json['total_voters'] as int? ?? 0,
    revealsVoters: json['reveals_voters'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'allows_multiple': allowsMultiple,
    'options': options.map((option) => option.toJson()).toList(),
    'total_voters': totalVoters,
  };
}

/// Un fichier composé sur l'appareil et qui n'est pas encore parti.
///
/// Le CHEMIN et non les octets : garder plusieurs méga-octets dans la base
/// locale à chaque photo la ferait grossir sans raison, alors que le fichier
/// est déjà sur l'appareil. Le prix à payer est qu'un fichier effacé entre
/// la composition et l'envoi rend la ligne inenvoyable — c'est pour ça que
/// la file la marque en échec plutôt que de réessayer indéfiniment.
class PendingMedia {
  const PendingMedia({
    required this.path,
    required this.filename,
    required this.mimeType,
    this.caption,
  });

  final String path;
  final String filename;
  final String mimeType;
  final String? caption;

  Map<String, dynamic> toJson() => {
    'path': path,
    'filename': filename,
    'mime_type': mimeType,
    'caption': caption,
  };

  factory PendingMedia.fromJson(Map<String, dynamic> json) => PendingMedia(
    path: json['path'] as String,
    filename: json['filename'] as String,
    mimeType: json['mime_type'] as String,
    caption: json['caption'] as String?,
  );
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.messageType,
    required this.content,
    this.encryption,
    this.ciphertext,
    this.envelope,
    required this.mediaAssetId,
    required this.media,
    required this.status,
    required this.createdAt,
    this.replyToId,
    this.replyTo,
    this.reactions = const [],
    this.editedAt,
    this.expiresAt,
    this.viewOnce = false,
    this.viewedAt,
    this.payload,
    this.poll,
    this.pendingMedia,
    this.mediaKey,
    this.proofMode = false,
    this.deletedAt,
    this.originalContent,
  });

  final String id;
  final int senderId;
  final int recipientId;
  final String messageType;

  /// Le fichier qui attend de partir — LOCAL à cet appareil.
  ///
  /// Jusqu'ici, envoyer une photo téléversait d'abord, envoyait ensuite, et
  /// n'écrivait rien entre les deux. Une coupure au mauvais moment effaçait
  /// le geste : ni bulle, ni fichier, ni trace. Sur un réseau mobile, « au
  /// mauvais moment » arrive souvent.
  ///
  /// La bulle est maintenant écrite AVANT le téléversement, avec ce champ.
  /// Elle survit donc à la coupure, à la fermeture de l'écran et au
  /// redémarrage de l'application — la file d'attente reprend le
  /// téléversement à la reconnexion (voir core/sync/outbox_service.dart).
  ///
  /// N'est JAMAIS envoyé au serveur : `toJson()` le sérialise pour le cache
  /// local, et le dépôt ne le transmet pas.
  final PendingMedia? pendingMedia;

  /// Texte du message — DÉCHIFFRÉ quand il l'a été.
  ///
  /// Le reste de l'application ne connaît que ce champ : le chiffrement
  /// s'arrête au dépôt (voir messaging_repository.dart). Un écran, un cache
  /// ou une recherche n'a donc jamais à savoir qu'il existe.
  final String? content;

  // ── Chiffrement de bout en bout ───────────────────────────────────────
  /// `null` = message en clair (correspondant sans version qui chiffre).
  /// Sinon `content` arrive vide du réseau et n'est rempli qu'après
  /// déchiffrement local.
  final String? encryption;
  final String? ciphertext;
  final Map<String, dynamic>? envelope;

  bool get isEncrypted => encryption != null;

  /// La clé de la pièce jointe, quand elle a voyagé chiffrée de bout en bout
  /// (voir core/crypto/media_cipher.dart). Sans elle, le fichier téléchargé
  /// n'est qu'un bloc opaque : tout affichage passe donc par
  /// `MediaRepository.resolveLocalFile(mediaKey: …)`.
  ///
  /// Gardée dans le cache LOCAL, qui est chiffré (SQLCipher) : c'est le seul
  /// endroit où elle existe une fois le message ouvert — la redemander au
  /// réseau est impossible, le cliquet a avancé.
  final MediaKey? mediaKey;

  final int? mediaAssetId;
  final MediaMeta? media;
  final DirectMessageStatus status;
  final DateTime createdAt;

  /// Message cité, s'il y en a un — `replyToId` seul suffit à savoir QU'il y
  /// a une citation, `replyTo` porte de quoi la dessiner sans second appel.
  final String? replyToId;
  final MessageReplyPreview? replyTo;

  final List<MessageReactionSummary> reactions;

  /// Renseigné à la première modification — voir
  /// api/app/routes/messages.py::edit_message.
  final DateTime? editedAt;

  /// Échéance d'un message éphémère. Le client n'a pas à agir dessus (le
  /// serveur filtre déjà les messages expirés de l'historique), mais la
  /// porter évite de la redemander pour un futur compte à rebours.
  final DateTime? expiresAt;

  final bool viewOnce;
  final DateTime? viewedAt;

  /// Charge utile des contenus riches sans pièce jointe (position, carte de
  /// visite) — voir api/app/models/orm.py::DirectMessage.payload. Sa forme
  /// dépend de `messageType`, lue par les widgets dédiés (poll_bubble.dart,
  /// location_bubble.dart, contact_card_bubble.dart).
  final Map<String, dynamic>? payload;

  final PollData? poll;

  // ── Mode preuve à deux ────────────────────────────────────────────────
  /// Envoyé pendant que la discussion était en mode preuve.
  final bool proofMode;

  /// « Supprimé pour tous » en mode preuve : le message reste, barré.
  final DateTime? deletedAt;

  /// Version d'origine d'un message modifié en mode preuve. Pour un
  /// message chiffré, le serveur ne l'a jamais eue : c'est CET appareil qui
  /// l'a gardée, au moment où la modification est arrivée (voir
  /// PokouMessageStore._keepProofTrace).
  final String? originalContent;

  bool get isMedia => mediaAssetId != null;
  bool get isEdited => editedAt != null;

  /// Vue unique déjà consommée par SON DESTINATAIRE — l'expéditeur voit aussi
  /// ce booléen passer à vrai (même message sérialisé des deux côtés), mais
  /// seul le destinataire perd l'accès au fichier (voir media.py::_can_access
  /// côté serveur).
  bool get isViewed => viewedAt != null;

  /// [fromCache] : la ligne vient du cache local de CET appareil, seul
  /// endroit d'où une clé de pièce jointe (`media_key`) peut être relue. Une
  /// charge venue du réseau n'en porte jamais de légitime — le serveur n'a
  /// jamais eu la clé — et celle qu'il glisserait serait la sienne.
  factory DirectMessage.fromJson(
    Map<String, dynamic> json, {
    bool fromCache = false,
  }) {
    final mediaJson = json['media'] as Map<String, dynamic>?;
    final replyToJson = json['reply_to'] as Map<String, dynamic>?;
    final pollJson = json['poll'] as Map<String, dynamic>?;
    // Présent uniquement quand la ligne vient du cache local : le serveur
    // n'a jamais entendu parler de ce champ.
    final enAttente = json['pending_media'] as Map<String, dynamic>?;
    return DirectMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as int,
      recipientId: json['recipient_id'] as int,
      messageType: json['message_type'] as String? ?? 'TEXT',
      content: json['content'] as String?,
      encryption: json['encryption'] as String?,
      ciphertext: json['ciphertext'] as String?,
      envelope: json['envelope'] as Map<String, dynamic>?,
      mediaAssetId: json['media_asset_id'] as int?,
      media: mediaJson != null ? MediaMeta.fromJson(mediaJson) : null,
      status: _statusFrom(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      replyToId: json['reply_to_id'] as String?,
      replyTo: replyToJson != null
          ? MessageReplyPreview.fromJson(replyToJson)
          : null,
      reactions: (json['reactions'] as List<dynamic>? ?? const [])
          .map(
            (raw) =>
                MessageReactionSummary.fromJson(raw as Map<String, dynamic>),
          )
          .toList(),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      viewOnce: json['view_once'] as bool? ?? false,
      viewedAt: json['viewed_at'] != null
          ? DateTime.parse(json['viewed_at'] as String)
          : null,
      payload: json['payload'] as Map<String, dynamic>?,
      poll: pollJson != null ? PollData.fromJson(pollJson) : null,
      pendingMedia: enAttente == null ? null : PendingMedia.fromJson(enAttente),
      proofMode: json['proof_mode'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      originalContent: json['original_content'] as String?,
      mediaKey: fromCache && json['encryption'] == null
          ? _remember(
              json['media_asset_id'] as int?,
              MediaKey.tryFromJson(json['media_key']),
            )
          : null,
    );
  }

  /// Dépose la clé dans le trousseau de session dès que le message est lu —
  /// voir MediaKeyRing.
  ///
  /// Une clé qui annonce un AUTRE fichier que celui du message est écartée :
  /// le serveur, maître de `media_asset_id`, ne doit pas pouvoir rattacher
  /// la clé d'une photo authentique à un autre fichier.
  static MediaKey? _remember(int? mediaAssetId, MediaKey? key) {
    if (key == null || mediaAssetId == null) return null;
    if (key.assetId != null && key.assetId != mediaAssetId) return null;
    MediaKeyRing.remember(mediaAssetId, key);
    return key;
  }

  /// Réciproque de `fromJson`, pour le cache local hors ligne (voir
  /// core/storage/pokou_message_store.dart). On garde exactement la forme de
  /// l'API : un seul format à maintenir, et le cache se relit avec le même
  /// `fromJson` que la réponse réseau.
  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'recipient_id': recipientId,
    'message_type': messageType,
    'content': content,
    // Conservés au tour de disque, et ce n'est pas un détail : c'est ce
    // qui distingue, au rechargement, un message RÉSOLU (chiffré ouvert,
    // `encryption` retiré) d'un message qui a ÉCHOUÉ (chiffré gardé,
    // `content` portant le texte d'erreur). Sans eux, les deux se
    // ressemblent une fois relus, et un échec passager devient définitif
    // — voir PokouMessageStore.plaintextFor.
    'encryption': encryption,
    'ciphertext': ciphertext,
    'envelope': envelope,
    'media_asset_id': mediaAssetId,
    'media': media?.toJson(),
    'status': _statusTo(status),
    'created_at': createdAt.toIso8601String(),
    'reply_to_id': replyToId,
    'reply_to': replyTo?.toJson(),
    'reactions': reactions.map((reaction) => reaction.toJson()).toList(),
    'edited_at': editedAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'view_once': viewOnce,
    'viewed_at': viewedAt?.toIso8601String(),
    'payload': payload,
    'poll': poll?.toJson(),
    'proof_mode': proofMode,
    'deleted_at': deletedAt?.toIso8601String(),
    'original_content': originalContent,
    // Cache LOCAL seulement — voir `pendingMedia`.
    if (pendingMedia != null) 'pending_media': pendingMedia!.toJson(),
    // Cache LOCAL seulement — voir `mediaKey`.
    if (mediaKey != null) 'media_key': mediaKey!.toJson(),
  };

  /// Utilisé pour superposer une mise à jour ponctuelle (réaction, vote,
  /// vue) reçue par WebSocket SANS recharger toute la conversation — voir
  /// conversation_screen.dart::_onRichContentEvent.
  DirectMessage copyWith({
    List<MessageReactionSummary>? reactions,
    DateTime? editedAt,
    DateTime? viewedAt,
    PollData? poll,
    String? content,
    bool clearCiphertext = false,
    MediaKey? mediaKey,
    MediaMeta? media,
    DirectMessageStatus? status,
    DateTime? deletedAt,
    String? originalContent,
  }) {
    return DirectMessage(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      messageType: messageType,
      content: content ?? this.content,
      // Après déchiffrement, le chiffré n'a plus lieu d'être transporté :
      // le garder le ferait écrire tel quel dans le cache local, où il ne
      // servirait qu'à occuper de la place et à semer le doute sur lequel
      // des deux champs fait foi.
      encryption: clearCiphertext ? null : encryption,
      ciphertext: clearCiphertext ? null : ciphertext,
      envelope: clearCiphertext ? null : envelope,
      mediaAssetId: mediaAssetId,
      media: media ?? this.media,
      status: status ?? this.status,
      createdAt: createdAt,
      replyToId: replyToId,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      editedAt: editedAt ?? this.editedAt,
      expiresAt: expiresAt,
      viewOnce: viewOnce,
      viewedAt: viewedAt ?? this.viewedAt,
      payload: payload,
      poll: poll ?? this.poll,
      mediaKey: _remember(mediaAssetId, mediaKey ?? this.mediaKey),
      proofMode: proofMode,
      deletedAt: deletedAt ?? this.deletedAt,
      originalContent: originalContent ?? this.originalContent,
    );
  }

  /// Ce message, ouvert : le clair déjà obtenu une fois ([opened], relu du
  /// cache local) remplace le chiffré venu du réseau — texte, et pour une
  /// pièce jointe sa clé et sa description.
  ///
  /// Refusé (le message est rendu tel quel) si le serveur annonce un autre
  /// fichier que celui de la copie ouverte : ce serait rattacher une clé
  /// authentique au fichier de quelqu'un d'autre.
  DirectMessage resolvedWith(DirectMessage opened) =>
      opened.mediaAssetId != mediaAssetId ? this : _resolvedWith(opened);

  DirectMessage _resolvedWith(DirectMessage opened) => copyWith(
    content: opened.content,
    mediaKey: opened.mediaKey,
    media: opened.mediaKey != null ? opened.media : null,
    clearCiphertext: true,
  );

  static String _statusTo(DirectMessageStatus status) => switch (status) {
    DirectMessageStatus.read => 'READ',
    DirectMessageStatus.delivered => 'DELIVERED',
    DirectMessageStatus.sent => 'SENT',
  };

  static DirectMessageStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'DELIVERED':
        return DirectMessageStatus.delivered;
      case 'READ':
        return DirectMessageStatus.read;
      default:
        return DirectMessageStatus.sent;
    }
  }
}


/// Le mode preuve d'une discussion à deux : le même pour les deux côtés.
class DirectProofMode {
  const DirectProofMode({required this.enabled, this.since, this.canDisable = false});

  final bool enabled;
  final DateTime? since;

  /// Seule la personne qui l'a activé peut le couper (maquette 10).
  final bool canDisable;

  static const off = DirectProofMode(enabled: false);

  factory DirectProofMode.fromJson(Map<String, dynamic> json) => DirectProofMode(
    enabled: json['enabled'] as bool? ?? false,
    since: json['since'] != null ? DateTime.parse(json['since'] as String) : null,
    canDisable: json['can_disable'] as bool? ?? false,
  );
}
