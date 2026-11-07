import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/crypto/media_cipher.dart' show MediaKey;
import '../../../core/time/server_time.dart';
import '../../../core/deeplink/invite_link_parser.dart' show pokouLinkBaseUrl;
import '../../messaging/data/direct_message_model.dart'
    show MessageReactionSummary, MessageReplyPreview, PendingMedia, PollData;

/// Personne citée par @ dans un message de groupe — voir
/// api/app/routes/groups.py::_serialize_mentions. Le nom est résolu côté
/// serveur (comme `sender_name`) : sans ça il faudrait retrouver chaque
/// membre cité pour surligner « @Nom » dans le texte.
class GroupMentionRef {
  const GroupMentionRef({required this.userId, required this.displayName});

  final int userId;
  final String displayName;

  factory GroupMentionRef.fromJson(Map<String, dynamic> json) =>
      GroupMentionRef(
        userId: json['user_id'] as int,
        displayName: json['display_name'] as String? ?? 'Inconnu',
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
  };
}

/// Membre d'un groupe. `displayName` est résolu côté serveur (voir
/// api/app/routes/groups.py::_serialize_member) : sans ça il faudrait un appel
/// par membre pour étiqueter l'auteur de chaque bulle.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.role,
    required this.displayName,
    this.joinedAt,
  });

  final int userId;
  final String role;
  final String displayName;

  /// Entrée dans le groupe : un membre ne peut se faire re-livrer que ce
  /// qui a été écrit APRÈS (voir e2ee_retry_service.dart).
  final DateTime? joinedAt;

  bool get isOwner => role == 'OWNER';
  bool get isAdmin => role == 'ADMIN';

  /// Peut administrer le groupe — créateur ou administrateur nommé.
  bool get canManage => role == 'OWNER' || role == 'ADMIN';

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    userId: json['user_id'] as int,
    role: json['role'] as String? ?? 'MEMBER',
    displayName: json['display_name'] as String? ?? 'Inconnu',
    joinedAt: _parseJoinedAt(json['joined_at']),
  );

  static DateTime? _parseJoinedAt(Object? raw) {
    if (raw is! String) return null;
    // Le serveur écrit l'UTC sans suffixe.
    return DateTime.tryParse(
      raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z',
    );
  }
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberCount,
    required this.members,
    this.communityName,
    this.avatarMediaId,
    this.avatar,
    this.myRole,
    this.canManage = false,
    this.inviteCode,
    this.communityId,
    this.isAnnouncement = false,
    this.proofMode = false,
    this.cryptoEpoch = 1,
    this.adminsOnlyMessages = false,
    this.disappearingSeconds,
    this.membersCanEditInfo = false,
    this.joinApproval = false,
    this.canEditInfo = false,
  });

  /// DIS-26 « Envoyer des messages » : réservé aux administrateurs.
  final bool adminsOnlyMessages;

  /// Messages éphémères du groupe (24 h, 7 j, 90 j) ou `null`.
  final int? disappearingSeconds;

  /// DIS-26 « Modifier le nom et la photo » ouvert à tous les membres.
  final bool membersCanEditInfo;

  /// DIS-26 « Approuver les nouveaux membres ».
  final bool joinApproval;

  /// Puis-je modifier le nom et la photo ? Calculé par le serveur.
  final bool canEditInfo;

  final int id;
  final String name;
  final int createdBy;
  final int memberCount;

  /// Mode preuve (Pokou certifié) : un message supprimé reste visible,
  /// barré, pour tous, et plus rien ne se modifie.
  final bool proofMode;
  final int cryptoEpoch;
  final String? communityName;
  final int? avatarMediaId;

  /// Métadonnée de la photo du groupe — nécessaire pour la mettre en cache
  /// localement (voir ContactAvatar), l'identifiant seul ne suffit pas.
  final MediaMeta? avatar;

  /// Rôle de l'utilisateur courant dans CE groupe — OWNER, ADMIN ou MEMBER.
  /// Nul sur la liste allégée (`GET /groups`).
  final String? myRole;

  /// Peut renommer, changer la photo, gérer le lien et retirer des membres.
  /// Calculé côté serveur : le client ne doit pas déduire les droits d'un
  /// nom de rôle qu'il pourrait mal interpréter.
  final bool canManage;

  /// Lien d'invitation — le serveur ne le renvoie qu'aux administrateurs,
  /// donc `null` signifie soit « pas de lien », soit « pas le droit ».
  final String? inviteCode;

  /// Communauté à laquelle ce groupe appartient, s'il y en a une.
  final int? communityId;

  /// Groupe d'annonces d'une communauté : seuls ses administrateurs y
  /// écrivent (voir api/app/routes/groups.py::_require_can_post).
  final bool isAnnouncement;

  bool get isOwner => myRole == 'OWNER';

  /// Puis-je écrire ici ? Faux uniquement dans les annonces quand je ne suis
  /// pas administrateur — l'app affiche alors une saisie désactivée plutôt
  /// que de laisser écrire un message qui serait refusé.
  bool get canPost => !(isAnnouncement || adminsOnlyMessages) || canManage;

  /// Vide sur la liste des groupes (`GET /groups`, charge utile allégée),
  /// peuplé sur le détail (`GET /groups/{id}`).
  final List<GroupMember> members;

  bool isOwnedBy(int userId) => createdBy == userId;

  String nameFor(int senderId) => members
      .firstWhere(
        (member) => member.userId == senderId,
        orElse: () => const GroupMember(
          userId: -1,
          role: 'MEMBER',
          displayName: 'Inconnu',
        ),
      )
      .displayName;

  factory Group.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>?;
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      createdBy: json['created_by'] as int,
      memberCount: json['member_count'] as int? ?? (membersJson?.length ?? 0),
      communityName: json['community_name'] as String?,
      avatarMediaId: json['avatar_media_id'] as int?,
      avatar: json['avatar'] != null
          ? MediaMeta.fromJson(json['avatar'] as Map<String, dynamic>)
          : null,
      myRole: json['my_role'] as String?,
      canManage: json['can_manage'] as bool? ?? false,
      inviteCode: json['invite_code'] as String?,
      communityId: json['community_id'] as int?,
      isAnnouncement: json['is_announcement'] as bool? ?? false,
      proofMode: json['proof_mode'] as bool? ?? false,
      cryptoEpoch: json['crypto_epoch'] as int? ?? 1,
      adminsOnlyMessages: json['admins_only_messages'] as bool? ?? false,
      disappearingSeconds: json['disappearing_seconds'] as int?,
      membersCanEditInfo: json['members_can_edit_info'] as bool? ?? false,
      joinApproval: json['join_approval'] as bool? ?? false,
      canEditInfo:
          json['can_edit_info'] as bool? ??
          (json['can_manage'] as bool? ?? false),
      members: membersJson == null
          ? const []
          : membersJson
                .map((raw) => GroupMember.fromJson(raw as Map<String, dynamic>))
                .toList(),
    );
  }
}

/// Forme canonique d'un lien d'invitation de groupe (Android App Links / iOS Universal Links).
/// Lien COURT d'invitation : /g/{code}. Les anciens liens /invite/group/
/// restent reconnus.
String inviteLinkFor(String code) => '$pokouLinkBaseUrl/g/$code';

/// Extrait le code d'un lien collé (format canonique `/invite/group/CODE` ou
/// historique `/invite/CODE`), ou rend l'entrée telle quelle si c'est déjà un code.
String inviteCodeFrom(String input) {
  final trimmed = input.trim();
  final canonicalMarker = '/invite/group/';
  final canIdx = trimmed.indexOf(canonicalMarker);
  if (canIdx != -1) {
    return trimmed
        .substring(canIdx + canonicalMarker.length)
        .split(RegExp(r'[/?#]'))
        .first;
  }
  final marker = '/invite/';
  final index = trimmed.indexOf(marker);
  if (index == -1) return trimmed;
  return trimmed.substring(index + marker.length).split(RegExp(r'[/?#]')).first;
}

/// Ce qu'on voit AVANT d'accepter une invitation par lien. Sans la liste des
/// membres : on ne révèle pas qui est dans un groupe à quelqu'un qui n'y est
/// pas encore.
class GroupInvitePreview {
  const GroupInvitePreview({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.alreadyMember,
    this.avatarMediaId,
  });

  final int id;
  final String name;
  final int memberCount;
  final bool alreadyMember;
  final int? avatarMediaId;

  factory GroupInvitePreview.fromJson(Map<String, dynamic> json) =>
      GroupInvitePreview(
        id: json['id'] as int,
        name: json['name'] as String,
        memberCount: json['member_count'] as int? ?? 0,
        alreadyMember: json['already_member'] as bool? ?? false,
        avatarMediaId: json['avatar_media_id'] as int?,
      );
}

/// Message de groupe — même forme qu'un DirectMessage moins le statut
/// (pas d'accusé de réception/lecture par membre en v1, voir la docstring de
/// GroupMessage dans api/app/models/orm.py), plus `senderName` pour étiqueter
/// l'auteur au-dessus des bulles reçues.
class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderCertifiedName,
    this.senderIsVerified = false,
    required this.messageType,
    required this.content,
    this.encryption,
    this.ciphertext,
    this.cryptoEpoch,
    required this.mediaAssetId,
    required this.media,
    this.mediaKey,
    required this.createdAt,
    this.replyToId,
    this.replyTo,
    this.reactions = const [],
    this.editedAt,
    this.expiresAt,
    this.mentions = const [],
    this.payload,
    this.poll,
    this.pendingMedia,
    this.deletedAt,
    this.originalContent,
  });

  /// La première version d'un message modifié en mode preuve : elle reste
  /// visible de tous.
  final String? originalContent;

  /// Renseigné seulement en mode preuve : le message a été supprimé mais
  /// reste affiché, barré.
  final DateTime? deletedAt;

  final String id;
  final int groupId;

  /// Le fichier qui attend de partir — LOCAL à cet appareil.
  ///
  /// Même champ, même raison et même modèle qu'en tête-à-tête (voir
  /// `direct_message_model.dart::PendingMedia`) : la bulle est écrite avant
  /// le téléversement, elle survit à la coupure et au redémarrage, et la
  /// file d'attente reprend. Les deux conversations ne doivent pas se
  /// comporter différemment pour une photo — c'est le genre d'écart qui
  /// fait dire qu'une application a été faite en plusieurs fois.
  ///
  /// N'est JAMAIS envoyé au serveur.
  final PendingMedia? pendingMedia;
  final int senderId;
  final String senderName;

  /// Le nom d'un auteur CERTIFIÉ, qui l'emporte sur tous les carnets (voir
  /// api/app/utils/identity.py::nom_affiche). Nul sinon : c'est alors au
  /// carnet de CET appareil de nommer l'auteur.
  final String? senderCertifiedName;
  final bool senderIsVerified;
  final String messageType;
  final String? content;
  final String? encryption;
  final String? ciphertext;
  final int? cryptoEpoch;
  final int? mediaAssetId;
  final MediaMeta? media;
  final MediaKey? mediaKey;
  final DateTime createdAt;

  /// Message cité — même forme qu'en 1:1 (voir direct_message_model.dart),
  /// `senderName` en plus puisque l'auteur n'est pas évident du sens de la
  /// bulle dans un groupe.
  final String? replyToId;
  final MessageReplyPreview? replyTo;

  final List<MessageReactionSummary> reactions;

  /// Renseigné à la première modification — voir
  /// api/app/routes/groups.py::edit_group_message.
  final DateTime? editedAt;
  final DateTime? expiresAt;

  /// Personnes citées par @ dans `content` — voir
  /// api/app/routes/groups.py::_serialize_mentions.
  final List<GroupMentionRef> mentions;

  /// Charge utile des contenus riches sans pièce jointe — même forme qu'en
  /// 1:1 (voir direct_message_model.dart::DirectMessage.payload).
  final Map<String, dynamic>? payload;

  final PollData? poll;

  bool get isMedia => mediaAssetId != null;
  bool get isEdited => editedAt != null;
  bool get isEncrypted => encryption == 'sender-key-v1' && ciphertext != null;

  /// Réciproque de `fromJson`, pour le cache local hors ligne — même forme
  /// que l'API (voir core/storage/pokou_message_store.dart).
  Map<String, dynamic> toJson() => {
    'id': id,
    'group_id': groupId,
    'sender_id': senderId,
    'sender_name': senderName,
    'sender_certified_name': senderCertifiedName,
    'sender_is_verified': senderIsVerified,
    'message_type': messageType,
    'content': content,
    if (encryption != null) 'encryption': encryption,
    if (ciphertext != null) 'ciphertext': ciphertext,
    if (cryptoEpoch != null) 'crypto_epoch': cryptoEpoch,
    'media_asset_id': mediaAssetId,
    'media': media?.toJson(),
    if (mediaKey != null) 'media_key': mediaKey!.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'reply_to_id': replyToId,
    'reply_to': replyTo?.toJson(),
    'reactions': reactions.map((reaction) => reaction.toJson()).toList(),
    'edited_at': editedAt?.toUtc().toIso8601String(),
    'expires_at': expiresAt?.toUtc().toIso8601String(),
    'mentions': mentions.map((mention) => mention.toJson()).toList(),
    // Cache LOCAL seulement — voir `pendingMedia`.
    if (pendingMedia != null) 'pending_media': pendingMedia!.toJson(),
    'payload': payload,
    'poll': poll?.toJson(),
  };

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'] as Map<String, dynamic>?;
    final replyToJson = json['reply_to'] as Map<String, dynamic>?;
    final pollJson = json['poll'] as Map<String, dynamic>?;
    // Présent uniquement quand la ligne vient du cache local : le serveur
    // n'a jamais entendu parler de ce champ.
    final enAttente = json['pending_media'] as Map<String, dynamic>?;
    return GroupMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as int,
      senderId: json['sender_id'] as int,
      senderName: json['sender_name'] as String? ?? 'Inconnu',
      senderCertifiedName: json['sender_certified_name'] as String?,
      senderIsVerified: json['sender_is_verified'] as bool? ?? false,
      messageType: json['message_type'] as String? ?? 'TEXT',
      content: json['content'] as String?,
      encryption: json['encryption'] as String?,
      ciphertext: json['ciphertext'] as String?,
      cryptoEpoch: json['crypto_epoch'] as int?,
      mediaAssetId: json['media_asset_id'] as int?,
      media: mediaJson != null ? MediaMeta.fromJson(mediaJson) : null,
      mediaKey: MediaKey.tryFromJson(json['media_key']),
      createdAt: parseServerTime(json['created_at'] as String),
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
          ? parseServerTime(json['edited_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? parseServerTime(json['deleted_at'] as String)
          : null,
      originalContent: json['original_content'] as String?,
      expiresAt: json['expires_at'] != null
          ? parseServerTime(json['expires_at'] as String)
          : null,
      mentions: (json['mentions'] as List<dynamic>? ?? const [])
          .map((raw) => GroupMentionRef.fromJson(raw as Map<String, dynamic>))
          .toList(),
      payload: json['payload'] as Map<String, dynamic>?,
      poll: pollJson != null ? PollData.fromJson(pollJson) : null,
      pendingMedia: enAttente == null ? null : PendingMedia.fromJson(enAttente),
    );
  }

  /// Superposition d'une mise à jour ponctuelle reçue par WebSocket (réaction,
  /// vote, modification) sans recharger toute la conversation — voir
  /// group_conversation_screen.dart::_onRichContentEvent.
  GroupMessage copyWith({
    List<MessageReactionSummary>? reactions,
    DateTime? editedAt,
    String? content,
    PollData? poll,
    DateTime? deletedAt,
    String? encryption,
    String? ciphertext,
    int? cryptoEpoch,
    bool clearCiphertext = false,
    MessageReplyPreview? replyTo,
    Map<String, dynamic>? payload,
    MediaMeta? media,
    MediaKey? mediaKey,
  }) {
    return GroupMessage(
      id: id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      senderCertifiedName: senderCertifiedName,
      senderIsVerified: senderIsVerified,
      messageType: messageType,
      content: content ?? this.content,
      encryption: clearCiphertext ? null : encryption ?? this.encryption,
      ciphertext: clearCiphertext ? null : ciphertext ?? this.ciphertext,
      cryptoEpoch: cryptoEpoch ?? this.cryptoEpoch,
      mediaAssetId: mediaAssetId,
      media: media ?? this.media,
      mediaKey: mediaKey ?? this.mediaKey,
      createdAt: createdAt,
      replyToId: replyToId,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      editedAt: editedAt ?? this.editedAt,
      expiresAt: expiresAt,
      mentions: mentions,
      payload: payload ?? this.payload,
      poll: poll ?? this.poll,
      deletedAt: deletedAt ?? this.deletedAt,
      originalContent: originalContent,
    );
  }

  GroupMessage resolvedWith({
    required String content,
    required Map<String, dynamic>? payload,
    required MessageReplyPreview? replyTo,
    MediaMeta? media,
    MediaKey? mediaKey,
  }) => copyWith(
    content: content,
    payload: payload,
    replyTo: replyTo,
    media: media,
    mediaKey: mediaKey,
    clearCiphertext: true,
  );
}
