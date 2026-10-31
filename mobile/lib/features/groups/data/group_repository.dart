import '../../../core/api/api_client.dart';
import '../../messaging/data/direct_message_model.dart'
    show MessageReactionSummary, PollData;
import 'group_invitation_model.dart';
import 'group_model.dart';

/// Pendant de MessagingRepository pour les conversations de groupe : simple
/// enveloppe HTTP, aucune persistance locale (même choix qu'en 1:1, l'historique
/// est refetché à l'ouverture de l'écran).
class GroupRepository {
  GroupRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Voir contacts_repository.dart::listRaw — même raison : c'est ce JSON
  /// qu'on garde pour rouvrir l'app sans réseau.
  Future<List<dynamic>> listMyGroupsRaw() async {
    final response = await _api.get('/groups');
    return response['items'] as List;
  }

  Future<List<Group>> listMyGroups() async => (await listMyGroupsRaw())
      .cast<Map<String, dynamic>>()
      .map(Group.fromJson)
      .toList();

  Future<Group> getGroup(int groupId) async {
    final response = await _api.get('/groups/$groupId');
    return Group.fromJson(response as Map<String, dynamic>);
  }

  /// Supprimer pour tous. Renvoie le message conservé en mode preuve, ou
  /// `null` quand il a été effacé.
  Future<GroupMessage?> deleteMessage(int groupId, String messageId) async {
    final response =
        await _api.delete('/groups/$groupId/messages/$messageId')
            as Map<String, dynamic>;
    final kept = response['message'] as Map<String, dynamic>?;
    return response['kept_as_proof'] == true && kept != null
        ? GroupMessage.fromJson(kept)
        : null;
  }

  Future<Group> setProofMode(int groupId, {required bool enabled}) async {
    final response = await _api.post(
      '/groups/$groupId/proof-mode',
      body: {'enabled': enabled},
    );
    return Group.fromJson(response as Map<String, dynamic>);
  }

  Future<Group> createGroup({
    required String name,
    required List<int> memberUserIds,
  }) async {
    final response = await _api.post(
      '/groups',
      body: {'name': name, 'member_user_ids': memberUserIds},
    );
    return Group.fromJson(response as Map<String, dynamic>);
  }

  /// INVITE des gens — ne les ajoute plus.
  ///
  /// La réponse porte désormais `{group, invitations}` : ajouter quelqu'un le
  /// rendait membre sur-le-champ, il reçoit maintenant une invitation qu'il
  /// accepte ou refuse. Le groupe rendu ici est donc inchangé tant que
  /// personne n'a accepté — c'est normal, et c'est tout l'objet.
  Future<({Group group, int invited})> inviteMembers({
    required int groupId,
    required List<int> userIds,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/members',
      body: {'user_ids': userIds},
    );
    final corps = response as Map<String, dynamic>;
    return (
      group: Group.fromJson(corps['group'] as Map<String, dynamic>),
      invited: (corps['invitations'] as List? ?? const []).length,
    );
  }

  /// Les invitations que j'ai à trancher.
  Future<List<GroupInvitation>> myInvitations() async {
    final response = await _api.get('/groups/invitations');
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GroupInvitation.fromJson)
        .toList();
  }

  Future<Group> acceptInvitation(String invitationId) async {
    final response = await _api.post(
      '/groups/invitations/$invitationId/accept',
      body: const {},
    );
    return Group.fromJson(response as Map<String, dynamic>);
  }

  Future<void> rejectInvitation(String invitationId) =>
      _api.post('/groups/invitations/$invitationId/reject', body: const {});

  /// Sert aussi à quitter le groupe (en passant son propre userId) — c'est le
  /// même endpoint côté serveur, l'autorisation diffère seulement.
  Future<void> removeMember({required int groupId, required int userId}) =>
      _api.delete('/groups/$groupId/members/$userId');

  /// Renommage et/ou photo. `clearAvatar` est distinct d'un
  /// `avatarMediaId` nul : « retirer la photo » et « ne pas y toucher » ne
  /// peuvent pas se dire avec la même valeur.
  Future<Group> updateGroup({
    required int groupId,
    String? name,
    int? avatarMediaId,
    bool clearAvatar = false,
  }) async {
    final response = await _api.patch(
      '/groups/$groupId',
      body: {
        'name': ?name,
        'avatar_media_id': ?avatarMediaId,
        if (clearAvatar) 'clear_avatar': true,
      },
    );
    return Group.fromJson(response as Map<String, dynamic>);
  }

  Future<GroupMember> setMemberRole({
    required int groupId,
    required int userId,
    required String role,
  }) async {
    final response = await _api.put(
      '/groups/$groupId/members/$userId/role',
      body: {'role': role},
    );
    return GroupMember.fromJson(response as Map<String, dynamic>);
  }

  /// Crée le lien, ou le REMPLACE s'il en existait un — régénérer est le
  /// seul moyen de révoquer un lien déjà diffusé.
  Future<String> createInviteLink(int groupId) async {
    final response = await _api.post(
      '/groups/$groupId/invite-link',
      body: const {},
    );
    return response['invite_code'] as String;
  }

  Future<void> revokeInviteLink(int groupId) =>
      _api.delete('/groups/$groupId/invite-link');

  Future<GroupInvitePreview> previewInvite(String code) async {
    final response = await _api.get('/groups/invite/$code');
    return GroupInvitePreview.fromJson(response as Map<String, dynamic>);
  }

  Future<Group> joinByInvite(String code) async {
    final response = await _api.post(
      '/groups/invite/$code/join',
      body: const {},
    );
    return Group.fromJson(response as Map<String, dynamic>);
  }

  Future<List<GroupMessage>> getMessages(int groupId) async =>
      (await getMessagesPage(groupId)).items;

  /// Une page d'historique : la plus récente sans `before`, sinon les
  /// messages strictement antérieurs à cet instant.
  Future<({List<GroupMessage> items, bool hasMore})> getMessagesPage(
    int groupId, {
    DateTime? before,
    int limit = 100,
  }) async {
    final cursor = before == null
        ? ''
        : '&before=${Uri.encodeQueryComponent(before.toIso8601String())}';
    final response = await _api.get(
      '/groups/$groupId/messages?limit=$limit$cursor',
    );
    final items = (response['items'] as List).cast<Map<String, dynamic>>();
    return (
      items: items.map(GroupMessage.fromJson).toList(),
      hasMore: response['has_more'] as bool? ?? false,
    );
  }

  Future<GroupMessage> send({
    required int groupId,
    required String content,
    String? replyToId,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/messages',
      body: {'content': content, 'reply_to_id': replyToId},
    );
    return GroupMessage.fromJson(response as Map<String, dynamic>);
  }

  Future<GroupMessage> createPoll({
    required int groupId,
    required String question,
    required List<String> options,
    required bool allowsMultiple,
  }) async {
    final response = await _api.post(
      '/polls',
      body: {
        'kind': 'group',
        'target_id': groupId,
        'question': question,
        'options': options,
        'allows_multiple': allowsMultiple,
      },
    );
    return GroupMessage.fromJson(response as Map<String, dynamic>);
  }

  Future<GroupMessage> sendMedia({
    required int groupId,
    required String messageType,
    required int mediaAssetId,
    String? caption,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/messages',
      body: {
        'message_type': messageType,
        'media_asset_id': mediaAssetId,
        if (caption != null && caption.trim().isNotEmpty) 'content': caption,
      },
    );
    return GroupMessage.fromJson(response as Map<String, dynamic>);
  }

  /// Pose OU remplace sa réaction sur un message de groupe (une seule par
  /// personne et par message — voir
  /// api/app/routes/groups.py::set_group_message_reaction). La réponse ne
  /// porte QUE les réactions à jour, pas le message entier : c'est ce que
  /// renvoie cette route, contrairement à son équivalent 1:1.
  Future<List<MessageReactionSummary>> setReaction({
    required int groupId,
    required String messageId,
    required String emoji,
  }) async {
    final response = await _api.put(
      '/groups/$groupId/messages/$messageId/reaction',
      body: {'emoji': emoji},
    );
    final reactions =
        (response as Map<String, dynamic>)['reactions'] as List<dynamic>? ??
        const [];
    return reactions
        .map(
          (raw) => MessageReactionSummary.fromJson(raw as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<MessageReactionSummary>> removeReaction({
    required int groupId,
    required String messageId,
  }) async {
    final response = await _api.delete(
      '/groups/$groupId/messages/$messageId/reaction',
    );
    final reactions =
        (response as Map<String, dynamic>)['reactions'] as List<dynamic>? ??
        const [];
    return reactions
        .map(
          (raw) => MessageReactionSummary.fromJson(raw as Map<String, dynamic>),
        )
        .toList();
  }

  /// Vote sur un sondage — même route que côté 1:1 (voir
  /// MessagingRepository.votePoll), dupliquée ici pour que l'écran de groupe
  /// n'ait pas à dépendre d'un repository d'une autre fonctionnalité.
  Future<PollData> votePoll({
    required String pollId,
    required List<int> optionIds,
  }) async {
    final response = await _api.post(
      '/polls/$pollId/vote',
      body: {'option_ids': optionIds},
    );
    return PollData.fromJson(response as Map<String, dynamic>);
  }
}
