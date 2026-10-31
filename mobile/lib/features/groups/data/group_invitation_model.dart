/// Une invitation à rejoindre un groupe — reçue, pas encore tranchée.
///
/// Ajouter quelqu'un à un groupe le rendait membre sur-le-champ : on se
/// retrouvait dans une conversation sans l'avoir demandé, avec ses
/// notifications et son historique, et la seule sortie était de partir —
/// c'est-à-dire d'annoncer publiquement qu'on était parti.
///
/// Ce que porte cette charge utile est exactement ce qu'il faut pour
/// DÉCIDER : le nom du groupe, combien ils sont, qui invite, et jusqu'à
/// quand. Pas les messages — on ne lit pas une conversation qu'on n'a pas
/// rejointe, et l'invitation ne doit pas devenir une porte dérobée vers son
/// contenu.
class GroupInvitation {
  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.invitedByName,
    required this.expiresAt,
    this.groupAvatarMediaId,
  });

  final String id;
  final int groupId;
  final String groupName;
  final int memberCount;

  /// « Kodjo vous invite » se décide autrement que « quelqu'un vous
  /// invite ». Nul si le compte a été supprimé entre-temps : l'invitation
  /// reste lisible, elle perd seulement son auteur.
  final String? invitedByName;

  final DateTime expiresAt;
  final int? groupAvatarMediaId;

  /// Combien de temps reste-t-il ? Négatif si c'est fini.
  Duration get restant => expiresAt.difference(DateTime.now());

  /// Périmée du point de vue de l'APPAREIL.
  ///
  /// Le serveur reste juge — il refusera l'acceptation avec un 409 — mais
  /// l'écran ne doit pas proposer un bouton qui ne peut plus rien faire. Une
  /// horloge décalée fera au pire disparaître l'invitation un peu tôt ;
  /// c'est préférable à un « Accepter » qui échoue sans raison visible.
  bool get expiree => restant.isNegative;

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    final groupe = json['group'] as Map<String, dynamic>? ?? const {};
    final invitant = json['invited_by'] as Map<String, dynamic>? ?? const {};
    return GroupInvitation(
      id: json['id'] as String,
      groupId: groupe['id'] as int,
      groupName: groupe['name'] as String? ?? '',
      memberCount: (groupe['member_count'] as num?)?.toInt() ?? 0,
      groupAvatarMediaId: groupe['avatar_media_id'] as int?,
      invitedByName: invitant['display_name'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
