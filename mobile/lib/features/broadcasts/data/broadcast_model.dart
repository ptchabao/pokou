import '../../../core/time/server_time.dart';
/// Une liste de diffusion — le carnet de copie de son auteur.
///
/// Elle n'existe que pour lui : les destinataires ne savent pas qu'ils y
/// figurent, et n'ont aucun moyen de l'apprendre. C'est la différence de
/// fond avec un groupe, et c'est pour ça que ce modèle n'a pas de notion de
/// « membre qui consulte » — il n'y en a pas.
class BroadcastList {
  const BroadcastList({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.members,
  });

  final int id;
  final String name;
  final int memberCount;
  final List<BroadcastMember> members;

  factory BroadcastList.fromJson(Map<String, dynamic> json) => BroadcastList(
    id: json['id'] as int,
    name: json['name'] as String,
    memberCount: json['member_count'] as int? ?? 0,
    members: ((json['members'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(BroadcastMember.fromJson)
        .toList(),
  );
}

class BroadcastMember {
  const BroadcastMember({required this.userId, required this.displayName});

  final int userId;
  final String displayName;

  factory BroadcastMember.fromJson(Map<String, dynamic> json) =>
      BroadcastMember(
        userId: json['user_id'] as int,
        displayName: json['display_name'] as String? ?? 'Contact',
      );
}

/// Un envoi, vu par son auteur : ce qu'il a composé une fois, et à combien
/// de personnes c'est parti. Les destinataires n'ont pas d'équivalent —
/// chez eux, il n'y a qu'un message ordinaire.
class BroadcastSentMessage {
  const BroadcastSentMessage({
    required this.id,
    required this.content,
    required this.recipientCount,
    required this.createdAt,
  });

  final String id;
  final String? content;
  final int recipientCount;
  final DateTime createdAt;

  factory BroadcastSentMessage.fromJson(Map<String, dynamic> json) =>
      BroadcastSentMessage(
        id: json['id'] as String,
        content: json['content'] as String?,
        recipientCount: json['recipient_count'] as int? ?? 0,
        createdAt: parseServerTime(json['created_at'] as String),
      );
}
