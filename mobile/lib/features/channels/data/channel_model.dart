import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../messaging/data/direct_message_model.dart' show PollData;
import '../../../core/time/server_time.dart';

class PokouChannel {
  const PokouChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.avatar,
    required this.createdBy,
    required this.isOwner,
    required this.isFollowing,
    required this.followerCount,
    required this.inviteCode,
    required this.isVerified,
    this.isAdmin = false,
    this.postCount = 0,
    this.isPrivate = false,
  });

  final int id;
  final String name;
  final String? description;
  final MediaMeta? avatar;
  final int createdBy;
  final bool isOwner;
  final bool isFollowing;
  final int followerCount;
  final String? inviteCode;
  final bool isVerified;

  /// Droit de PUBLIER et de modifier la chaîne — résolu par le serveur
  /// (créateur ou membre promu), jamais déduit du rôle côté client.
  final bool isAdmin;
  final int postCount;

  /// Chaîne privée : introuvable par la recherche, illisible sans
  /// abonnement, et accessible par le seul lien d'invitation.
  ///
  /// Le drapeau vient du SERVEUR, qui applique les trois règles. Il ne sert
  /// ici qu'à le dire — jamais à décider : un client qui filtrerait
  /// lui-même laisserait passer tout ce qu'il oublie.
  final bool isPrivate;

  /// L'état montré quand le geste attend le réseau — voir
  /// `ChannelRepository.setFollowing`. Le compteur bouge avec, sinon « Suivi »
  /// s'afficherait à côté d'un nombre d'abonnés qui ne m'inclut pas.
  PokouChannel withFollowing(bool following) => PokouChannel(
    id: id,
    name: name,
    description: description,
    avatar: avatar,
    createdBy: createdBy,
    isOwner: isOwner,
    isFollowing: following,
    followerCount: following == isFollowing
        ? followerCount
        : (followerCount + (following ? 1 : -1)).clamp(0, 1 << 31),
    inviteCode: inviteCode,
    isVerified: isVerified,
    isAdmin: isAdmin,
    postCount: postCount,
    isPrivate: isPrivate,
  );

  factory PokouChannel.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'] as Map<String, dynamic>?;
    return PokouChannel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      avatar: avatarJson == null ? null : MediaMeta.fromJson(avatarJson),
      createdBy: json['created_by'] as int,
      isOwner: json['is_owner'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
      followerCount: json['follower_count'] as int? ?? 0,
      inviteCode: json['invite_code'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? false,
      postCount: json['post_count'] as int? ?? 0,
      isPrivate: json['is_private'] as bool? ?? false,
    );
  }
}

String channelInviteLinkFor(String code) =>
    'https://pok.app/channel/$code';

String channelPostLinkFor(String code, Object postId) =>
    'https://pok.app/channel/$code/post/$postId';

/// Publication d'une chaîne — diffusion à sens unique : on lit et on réagit,
/// on ne répond pas (c'est ce qui distingue une chaîne d'un groupe).
class ChannelPost {
  const ChannelPost({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    required this.textContent,
    required this.media,
    required this.createdAt,
    required this.editedAt,
    required this.viewCount,
    required this.reactions,
    this.poll,
  });

  final String id;
  final int channelId;
  final int authorId;
  final String authorName;
  final String? textContent;
  final MediaMeta? media;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int viewCount;
  final List<ChannelPostReaction> reactions;

  /// Sondage porté par la publication, s'il y en a un. MÊME modèle que les
  /// sondages de conversation (PollData) : côté serveur c'est la même table
  /// et la même route de vote, il n'y a donc pas deux formes à connaître.
  final PollData? poll;

  bool get wasEdited => editedAt != null;

  /// La réaction que J'AI posée, s'il y en a une — `mine` est résolu par le
  /// serveur, l'écran n'a donc pas à comparer des listes d'identifiants.
  ChannelPostReaction? get myReaction {
    for (final reaction in reactions) {
      if (reaction.mine) return reaction;
    }
    return null;
  }

  /// Remplace le sondage par sa version à jour — le vote renvoie l'état
  /// complet du sondage, que l'écran fusionne dans la publication affichée
  /// sans recharger tout le fil.
  ChannelPost withPoll(PollData updated) =>
      _copy(reactions: reactions, poll: updated);

  /// Ma réaction posée (ou retirée, avec `null`) SANS attendre le serveur —
  /// l'état montré quand le geste attend le réseau. Mêmes règles que le
  /// serveur : une seule réaction par personne, et une pastille à zéro
  /// disparaît.
  ChannelPost withMyReaction(String? emoji) {
    final updated = <ChannelPostReaction>[];
    var placed = emoji == null;
    for (final reaction in reactions) {
      var count = reaction.count - (reaction.mine ? 1 : 0);
      final isNew = reaction.emoji == emoji;
      if (isNew) {
        count++;
        placed = true;
      }
      if (count > 0) {
        updated.add(
          ChannelPostReaction(emoji: reaction.emoji, count: count, mine: isNew),
        );
      }
    }
    if (!placed) {
      updated.add(ChannelPostReaction(emoji: emoji!, count: 1, mine: true));
    }
    return _copy(reactions: updated, poll: poll);
  }

  ChannelPost _copy({
    required List<ChannelPostReaction> reactions,
    required PollData? poll,
  }) => ChannelPost(
    id: id,
    channelId: channelId,
    authorId: authorId,
    authorName: authorName,
    textContent: textContent,
    media: media,
    createdAt: createdAt,
    editedAt: editedAt,
    viewCount: viewCount,
    reactions: reactions,
    poll: poll,
  );

  factory ChannelPost.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'] as Map<String, dynamic>?;
    final pollJson = json['poll'] as Map<String, dynamic>?;
    final editedAt = json['edited_at'] as String?;
    return ChannelPost(
      id: json['id'] as String,
      channelId: json['channel_id'] as int,
      authorId: json['author_id'] as int,
      authorName: json['author_name'] as String? ?? 'Chaîne',
      textContent: json['text_content'] as String?,
      media: mediaJson == null ? null : MediaMeta.fromJson(mediaJson),
      createdAt: parseServerTime(json['created_at'] as String),
      editedAt: editedAt == null ? null : tryParseServerTime(editedAt),
      viewCount: json['view_count'] as int? ?? 0,
      reactions: ((json['reactions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChannelPostReaction.fromJson)
          .toList(),
      poll: pollJson == null ? null : PollData.fromJson(pollJson),
    );
  }
}

class ChannelPostReaction {
  const ChannelPostReaction({
    required this.emoji,
    required this.count,
    required this.mine,
  });

  final String emoji;
  final int count;
  final bool mine;

  factory ChannelPostReaction.fromJson(Map<String, dynamic> json) =>
      ChannelPostReaction(
        emoji: json['emoji'] as String,
        count: json['count'] as int? ?? 0,
        mine: json['mine'] as bool? ?? false,
      );
}
