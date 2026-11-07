import 'dart:convert';

import '../../../core/crypto/undecryptable.dart';
import '../../../core/api/api_client.dart';
import '../../../core/crypto/e2ee_outcome.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/crypto/group_sender_keys.dart';
import '../../../core/crypto/media_cipher.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../messaging/data/direct_message_model.dart'
    show MessageReactionSummary, PollData, MessageReplyPreview;
import 'group_invitation_model.dart';
import 'group_model.dart';
import '../../../core/time/server_time.dart';

/// Chiffrement et enveloppe HTTP pour les conversations de groupe. Cleartext
/// is returned only to the controller, which persists it in SQLCipher.
class GroupRepository {
  GroupRepository({
    required ApiClient apiClient,
    required E2EEService e2ee,
    required GroupSenderKeys senderKeys,
    required PokouMessageStore store,
  }) : _api = apiClient,
       _e2ee = e2ee,
       _senderKeys = senderKeys,
       _store = store;

  final ApiClient _api;
  final E2EEService _e2ee;
  final GroupSenderKeys _senderKeys;
  final PokouMessageStore _store;
  static final Set<String> _publishedEpochs = {};
  static final Map<String, Future<GroupMessage>> _incomingDecryptions = {};

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

  /// Opens only sender-key payloads pairwise-enveloped for this device.
  Future<void> prepareReceiverKeys(
    Group group,
    int myUserId, {
    int? epoch,
  }) async {
    final requestedEpoch = epoch ?? group.cryptoEpoch;
    if (requestedEpoch > group.cryptoEpoch) {
      throw StateError('Future group crypto epoch');
    }
    final response = await _api.get(
      '/groups/${group.id}/sender-key-distributions?epoch=$requestedEpoch',
    );
    if (response['epoch'] != requestedEpoch) {
      throw StateError('Stale group crypto epoch');
    }
    for (final raw in (response['items'] as List? ?? const [])) {
      final item = raw as Map<String, dynamic>;
      if (item['recipient_id'] != myUserId ||
          item['encryption'] != 'v1' ||
          item['epoch'] != null && item['epoch'] != requestedEpoch) {
        continue; // hors contexte : ignorée, sans bloquer les autres
      }
      final senderId = item['sender_id'] as int;
      // Déjà installée : ne JAMAIS rouvrir l'enveloppe (elle ne s'ouvre
      // qu'une fois). C'était la cause des bulles vides / « en attente »
      // sur tous les messages de groupe.
      if (await _senderKeys.hasDistribution(
        groupId: group.id,
        epoch: requestedEpoch,
        senderId: senderId,
      )) {
        continue;
      }
      try {
        final distribution = await _e2ee.open(
          peerUserId: senderId,
          envelope: item['envelope'] as Map<String, dynamic>,
          ciphertext: item['ciphertext'] as String,
        );
        await _senderKeys.acceptDistribution(
          groupId: group.id,
          epoch: requestedEpoch,
          senderId: senderId,
          distribution: distribution,
        );
      } catch (_) {
        // Une clé illisible ne bloque plus celles des autres membres : les
        // messages de CET expéditeur passeront par la re-livraison.
      }
    }
  }

  Future<void> _ensureSenderKeyDistributed(Group group, int senderId) async {
    final cacheKey = '${group.id}:${group.cryptoEpoch}:$senderId';
    if (_publishedEpochs.contains(cacheKey)) return;
    final recipients = group.members
        .map((member) => member.userId)
        .where((id) => id != senderId)
        .toSet();
    final distribution = await _senderKeys.createDistribution(
      groupId: group.id,
      epoch: group.cryptoEpoch,
      senderId: senderId,
    );
    final sealed = <Map<String, dynamic>>[];
    for (final recipientId in recipients) {
      final peer = await _e2ee.peerCrypto(recipientId);
      if (!peer.capabilities.contains(E2EEService.groupCapability)) {
        throw StateError('A current group member cannot receive Sender Keys');
      }
      if (peer.identityKey != null &&
          await _e2ee.sessionState(
                recipientId,
                publishedIdentityKey: peer.identityKey,
              ) ==
              PeerSessionState.changed) {
        throw StateError('Group member identity changed');
      }
      final envelope = await _e2ee.seal(
        peerUserId: recipientId,
        plaintext: distribution,
      );
      if (envelope is! SealEncrypted) {
        throw StateError('Unable to pairwise-encrypt sender-key distribution');
      }
      sealed.add({
        'recipient_id': recipientId,
        'encryption': envelope.encryption,
        'ciphertext': envelope.ciphertext,
        'envelope': envelope.envelope,
      });
    }
    await _api.post(
      '/groups/${group.id}/sender-key-distributions',
      body: {'epoch': group.cryptoEpoch, 'distributions': sealed},
    );
    _publishedEpochs.add(cacheKey);
  }

  Future<GroupMessage> _sendEncrypted({
    required Group group,
    required int senderId,
    required String messageType,
    required Map<String, dynamic> body,
    String? replyToId,
    int? mediaAssetId,
  }) async {
    await _ensureSenderKeyDistributed(group, senderId);
    final ciphertext = await _senderKeys.encrypt(
      groupId: group.id,
      epoch: group.cryptoEpoch,
      senderId: senderId,
      plaintext: jsonEncode(body),
    );
    final response = await _api.post(
      '/groups/${group.id}/messages',
      body: {
        'message_type': messageType,
        'media_asset_id': ?mediaAssetId,
        'reply_to_id': ?replyToId,
        'encryption': 'sender-key-v1',
        'ciphertext': ciphertext,
        'crypto_epoch': group.cryptoEpoch,
      },
    );
    final serverMessage = GroupMessage.fromJson(
      response as Map<String, dynamic>,
    );
    final rawReply = body['reply_to'];
    final reply = rawReply is Map<String, dynamic>
        ? MessageReplyPreview.fromJson(rawReply)
        : null;
    final mediaKey = MediaKey.tryFromJson(body['media_key']);
    if (mediaKey != null && mediaAssetId != null) {
      if (mediaKey.assetId != mediaAssetId ||
          !_encryptedMediaTypes.contains(messageType)) {
        throw const FormatException('Group media key context mismatch');
      }
      MediaKeyRing.remember(mediaAssetId, mediaKey);
    }
    return serverMessage.resolvedWith(
      content: body['content'] as String? ?? mediaKey?.caption ?? '',
      payload: body['payload'] as Map<String, dynamic>?,
      replyTo: reply,
      media: mediaKey?.toMeta(mediaAssetId!),
      mediaKey: mediaKey,
    );
  }

  static const _encryptedMediaTypes = {'IMAGE', 'VIDEO', 'AUDIO', 'DOCUMENT'};

  Future<List<GroupMessage>> decryptMessages(
    Group group,
    List<GroupMessage> messages,
    int myUserId,
  ) async {
    if (messages.any((message) => !message.isEncrypted)) {
      throw const FormatException('Plaintext group message rejected');
    }
    final result = <GroupMessage>[];
    final epochs = messages
        .where(
          (message) =>
              message.isEncrypted &&
              message.cryptoEpoch != null &&
              message.cryptoEpoch! <= group.cryptoEpoch,
        )
        .map((message) => message.cryptoEpoch!)
        .toSet();
    for (final epoch in epochs) {
      try {
        await prepareReceiverKeys(group, myUserId, epoch: epoch);
      } catch (_) {
        // Réseau ou époque périmée : on tente quand même chaque message.
      }
    }
    for (final message in messages) {
      if (!message.isEncrypted ||
          message.cryptoEpoch == null ||
          message.cryptoEpoch! > group.cryptoEpoch ||
          message.senderId == myUserId) {
        result.add(message);
        continue;
      }
      result.add(await decryptIncoming(group, message));
    }
    return result;
  }

  Future<GroupMessage> decryptIncoming(Group group, GroupMessage message) {
    final existing = _incomingDecryptions[message.id];
    if (existing != null) return existing;
    final future = _decryptIncomingOnce(group, message);
    _incomingDecryptions[message.id] = future;
    return future.whenComplete(() {
      if (identical(_incomingDecryptions[message.id], future)) {
        _incomingDecryptions.remove(message.id);
      }
    });
  }

  Future<GroupMessage> _decryptIncomingOnce(
    Group group,
    GroupMessage message,
  ) async {
    GroupMessage resolved;
    MediaKey? mediaKey;
    try {
      final clear = await _senderKeys.decrypt(
        groupId: group.id,
        epoch: message.cryptoEpoch!,
        senderId: message.senderId,
        ciphertext: message.ciphertext!,
      );
      resolved = resolveGroupBody(message, clear);
      mediaKey = resolved.mediaKey;
    } catch (_) {
      // Illisible ici : on demande à l'expéditeur de le re-livrer (voir
      // e2ee_retry_service.dart) plutôt que de laisser une bulle vide.
      reportUndecryptable('group', message.id);
      return message;
    }
    // The Signal receive chain has advanced. Persist cleartext into SQLCipher
    // before allowing another incoming message to consume the next key.
    await _store.saveGroup([resolved]);
    if (mediaKey != null && message.mediaAssetId != null) {
      MediaKeyRing.remember(message.mediaAssetId!, mediaKey);
    }
    return resolved;
  }

  /// Le corps en clair d'un message de groupe — `{content, payload,
  /// reply_to, media_key}` — appliqué à [message]. Sert au déchiffrement
  /// normal ET à la re-livraison par l'expéditeur. Lève si le corps est
  /// invalide ou ne correspond pas au message.
  GroupMessage resolveGroupBody(GroupMessage message, String clear) {
    final decoded = jsonDecode(clear);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid encrypted group payload');
    }
    final mediaKey = MediaKey.tryFromJson(decoded['media_key']);
    if (mediaKey != null) {
      if (message.mediaAssetId == null ||
          mediaKey.assetId != message.mediaAssetId ||
          !_encryptedMediaTypes.contains(message.messageType)) {
        throw const FormatException('Group media key context mismatch');
      }
    }
    final replyJson = decoded['reply_to'] as Map<String, dynamic>?;
    return message.resolvedWith(
      content: decoded['content'] as String? ?? mediaKey?.caption ?? '',
      payload: decoded['payload'] as Map<String, dynamic>?,
      replyTo: replyJson == null ? null : MessageReplyPreview.fromJson(replyJson),
      media: mediaKey?.toMeta(message.mediaAssetId!),
      mediaKey: mediaKey,
    );
  }

  /// Le corps en clair d'un message de groupe que J'AI envoyé, pour le
  /// re-livrer à un membre qui n'a pas pu l'ouvrir.
  static String groupBodyOf(GroupMessage message) => jsonEncode({
    'content': message.content,
    'payload': ?message.payload,
    if (message.replyTo != null) 'reply_to': message.replyTo!.toJson(),
    if (message.mediaKey != null && message.mediaAssetId != null)
      'media_key': message.mediaKey!.withAssetId(message.mediaAssetId!).toJson(),
  });

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

  /// Supprime le groupe pour tous — réservé au créateur côté serveur.
  Future<void> deleteGroup(int groupId) => _api.delete('/groups/$groupId');

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

  /// DIS-26 : les réglages du groupe (administrateurs).
  Future<Group> updateSettings({
    required int groupId,
    bool? adminsOnlyMessages,
    bool? membersCanEditInfo,
    bool? joinApproval,
    bool setDisappearing = false,
    int? disappearingSeconds,
  }) async {
    final response = await _api.patch(
      '/groups/$groupId',
      body: {
        'admins_only_messages': ?adminsOnlyMessages,
        'members_can_edit_info': ?membersCanEditInfo,
        'join_approval': ?joinApproval,
        if (setDisappearing) 'disappearing_seconds': disappearingSeconds,
      },
    );
    return Group.fromJson(response as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> joinRequests(int groupId) async {
    final response = await _api.get('/groups/$groupId/join-requests');
    return ((response['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> decideJoinRequest({
    required int groupId,
    required String requestId,
    required bool approve,
  }) => _api.post(
    '/groups/$groupId/join-requests/$requestId',
    body: {'approve': approve},
  );

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

  /// Lève [GroupJoinPending] quand le groupe exige l'approbation d'un
  /// administrateur (DIS-26) : la demande est déposée, l'entrée viendra.
  Future<Group> joinByInvite(String code) async {
    final response = await _api.post(
      '/groups/invite/$code/join',
      body: const {},
    ) as Map<String, dynamic>;
    if (response['pending_approval'] == true) {
      throw GroupJoinPending(response['name'] as String? ?? '');
    }
    return Group.fromJson(response);
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
        : '&before=${Uri.encodeQueryComponent(toServerTime(before))}';
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
    required Group group,
    required int senderId,
    required String content,
    required String messageType,
    String? replyToId,
    MessageReplyPreview? replyTo,
  }) async {
    return _sendEncrypted(
      group: group,
      senderId: senderId,
      messageType: messageType,
      replyToId: replyToId,
      body: {
        'content': content,
        if (replyTo != null) 'reply_to': replyTo.toJson(),
      },
    );
  }

  Future<GroupMessage> createPoll({
    required int groupId,
    required String question,
    required List<String> options,
    required bool allowsMultiple,
  }) async {
    throw UnsupportedError(
      'Group polls are disabled until their schema is end-to-end encrypted.',
    );
  }

  Future<GroupMessage> sendMedia({
    required Group group,
    required int senderId,
    required String messageType,
    required int mediaAssetId,
    MediaKey? mediaKey,
    String? caption,
  }) async {
    return _sendEncrypted(
      group: group,
      senderId: senderId,
      messageType: messageType,
      mediaAssetId: mediaAssetId,
      body: {
        'content': caption,
        if (mediaKey != null)
          'media_key': mediaKey.withAssetId(mediaAssetId).toJson(),
      },
    );
  }

  Future<GroupMessage> edit({
    required Group group,
    required int senderId,
    required GroupMessage original,
    required String content,
  }) async {
    await _ensureSenderKeyDistributed(group, senderId);
    final ciphertext = await _senderKeys.encrypt(
      groupId: group.id,
      epoch: group.cryptoEpoch,
      senderId: senderId,
      plaintext: jsonEncode({'content': content}),
    );
    final response = await _api.patch(
      '/groups/${group.id}/messages/${original.id}',
      body: {
        'encryption': 'sender-key-v1',
        'ciphertext': ciphertext,
        'crypto_epoch': group.cryptoEpoch,
      },
    );
    return GroupMessage.fromJson(
      response as Map<String, dynamic>,
    ).resolvedWith(content: content, payload: null, replyTo: original.replyTo);
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

/// L'entrée par lien attend la validation d'un administrateur.
class GroupJoinPending implements Exception {
  const GroupJoinPending(this.groupName);

  final String groupName;
}
