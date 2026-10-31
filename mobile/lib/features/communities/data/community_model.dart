import '../../../core/media/media_repository.dart' show MediaMeta;

/// Un groupe vu depuis sa communauté — juste ce qu'il faut pour le lister et
/// l'ouvrir. Le détail complet reste `Group` (features/groups).
class CommunityGroup {
  const CommunityGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.isAnnouncement,
    this.avatar,
  });

  final int id;
  final String name;
  final int memberCount;

  /// Groupe d'annonces de la communauté : tout le monde y lit, seuls les
  /// administrateurs y écrivent.
  final bool isAnnouncement;

  final MediaMeta? avatar;

  factory CommunityGroup.fromJson(Map<String, dynamic> json) => CommunityGroup(
    id: json['id'] as int,
    name: json['name'] as String,
    memberCount: json['member_count'] as int? ?? 0,
    isAnnouncement: json['is_announcement'] as bool? ?? false,
    avatar: json['avatar'] != null
        ? MediaMeta.fromJson(json['avatar'] as Map<String, dynamic>)
        : null,
  );
}

/// Communauté — un contenant qui regroupe plusieurs groupes autour d'un même
/// ensemble de personnes. Elle n'a pas de conversation propre : son groupe
/// d'annonces joue ce rôle (voir api/app/routes/communities.py).
class Community {
  const Community({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.groupCount,
    required this.groups,
    this.description,
    this.avatar,
    this.myRole,
    this.canManage = false,
    this.inviteCode,
  });

  final int id;
  final String name;
  final String? description;
  final int memberCount;
  final int groupCount;

  /// Vide sur la liste (`GET /communities`), peuplé sur le détail.
  final List<CommunityGroup> groups;

  final MediaMeta? avatar;
  final String? myRole;

  /// Décidé par le serveur : le client ne déduit pas les droits d'un nom de
  /// rôle qu'il pourrait mal interpréter.
  final bool canManage;

  /// Renvoyé aux seuls administrateurs — `null` signifie « pas de lien » ou
  /// « pas le droit de le voir ».
  final String? inviteCode;

  bool get isOwner => myRole == 'OWNER';

  /// Le groupe d'annonces, s'il est connu (détail seulement).
  CommunityGroup? get announcements =>
      groups.where((group) => group.isAnnouncement).firstOrNull;

  factory Community.fromJson(Map<String, dynamic> json) {
    final groupsJson = json['groups'] as List<dynamic>?;
    return Community(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      memberCount: json['member_count'] as int? ?? 0,
      groupCount: json['group_count'] as int? ?? (groupsJson?.length ?? 0),
      groups: groupsJson == null
          ? const []
          : groupsJson
                .map(
                  (raw) => CommunityGroup.fromJson(raw as Map<String, dynamic>),
                )
                .toList(),
      avatar: json['avatar'] != null
          ? MediaMeta.fromJson(json['avatar'] as Map<String, dynamic>)
          : null,
      myRole: json['my_role'] as String?,
      canManage: json['can_manage'] as bool? ?? false,
      inviteCode: json['invite_code'] as String?,
    );
  }
}

/// Ce qu'on voit avant d'accepter une invitation. Sans les membres ni les
/// groupes : on ne révèle pas la composition d'une communauté à quelqu'un qui
/// n'y est pas encore.
class CommunityInvitePreview {
  const CommunityInvitePreview({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.groupCount,
    required this.alreadyMember,
    this.description,
  });

  final int id;
  final String name;
  final String? description;
  final int memberCount;
  final int groupCount;
  final bool alreadyMember;

  factory CommunityInvitePreview.fromJson(Map<String, dynamic> json) =>
      CommunityInvitePreview(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        memberCount: json['member_count'] as int? ?? 0,
        groupCount: json['group_count'] as int? ?? 0,
        alreadyMember: json['already_member'] as bool? ?? false,
      );
}

/// Même forme que pour les groupes — le lien ne s'ouvre pas encore d'un clic
/// (App Links non configurés), il se colle dans « Rejoindre ».
String communityInviteLinkFor(String code) =>
    'https://pok.app/c/$code';

String communityInviteCodeFrom(String input) {
  final trimmed = input.trim();
  const marker = '/c/';
  final index = trimmed.indexOf(marker);
  if (index == -1) return trimmed;
  return trimmed.substring(index + marker.length).split(RegExp(r'[/?#]')).first;
}
