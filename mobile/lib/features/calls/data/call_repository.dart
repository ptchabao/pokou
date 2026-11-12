import '../../../core/api/api_client.dart';
import '../../../core/crypto/call_keys.dart';
import '../../../core/crypto/e2ee_outcome.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/time/server_time.dart';
import '../../groups/data/group_repository.dart';

class CallToken {
  const CallToken({
    required this.room,
    required this.token,
    required this.livekitUrl,
    this.participantIds = const [],
    this.joinedExisting = false,
    this.e2ee = false,
  });

  final String room;
  final String token;
  final String livekitUrl;

  /// Les autres participants de l'appel — sert à leur signaler `end` en
  /// raccrochant, y compris ceux ajoutés en cours d'appel.
  final List<int> participantIds;

  /// Vrai quand le serveur nous a fait rejoindre un appel déjà en cours dans
  /// ce groupe au lieu d'en ouvrir un second (voir _active_group_call côté
  /// API) — l'écran d'appel s'ouvre alors sans « sonner » chez personne.
  final bool joinedExisting;

  /// L'appel est chiffré de bout en bout — sa clé est dans [CallKeys].
  final bool e2ee;

  factory CallToken.fromJson(Map<String, dynamic> json) => CallToken(
    room: json['room'] as String,
    token: json['token'] as String,
    livekitUrl: json['livekit_url'] as String,
    participantIds: ((json['participant_ids'] as List?) ?? const [])
        .cast<int>(),
    joinedExisting: json['joined_existing'] as bool? ?? false,
    e2ee: json['e2ee'] as bool? ?? false,
  );
}

/// Appel de groupe en cours, pour le bandeau « Rejoindre » d'une conversation
/// de groupe. `null` quand il n'y a pas d'appel — l'absence est le cas normal.
class ActiveGroupCall {
  const ActiveGroupCall({
    required this.room,
    required this.isVideo,
    required this.callerId,
    required this.participantIds,
  });

  final String room;
  final bool isVideo;
  final int callerId;
  final List<int> participantIds;

  static ActiveGroupCall? fromJson(Map<String, dynamic> json) {
    if (json['active'] != true) return null;
    return ActiveGroupCall(
      room: json['room'] as String,
      isVideo: json['is_video'] as bool? ?? true,
      callerId: json['caller_id'] as int,
      participantIds: ((json['participant_ids'] as List?) ?? const [])
          .cast<int>(),
    );
  }
}

class CallLogOther {
  const CallLogOther({
    required this.id,
    required this.displayName,
    this.avatar,
    this.isVerified = false,
  });

  final int id;
  final String displayName;
  final MediaMeta? avatar;

  /// Le ✓ d'identité — le même que dans la liste des discussions.
  final bool isVerified;

  factory CallLogOther.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'] as Map<String, dynamic>?;
    return CallLogOther(
      id: json['id'] as int,
      displayName: json['display_name'] as String,
      avatar: avatarJson != null ? MediaMeta.fromJson(avatarJson) : null,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

/// Une entrée du journal d'appels — le statut reflète la perspective du
/// spectateur : pour un appel sortant c'est l'issue globale (ringing/
/// ongoing/ended/missed/declined) ; pour un appel entrant c'est la réponse
/// individuelle du spectateur (invited/accepted/declined/missed).
class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.direction,
    required this.callType,
    this.groupName,
    required this.isVideo,
    required this.status,
    required this.createdAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.others,
  });

  final String id;
  final String direction; // outgoing | incoming
  final String callType; // 1:1 | group

  /// Renseigné quand l'appel a été lancé depuis une conversation de groupe —
  /// intitulé plus parlant que la liste des participants.
  final String? groupName;
  final bool isVideo;
  final String status;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final List<CallLogOther> others;

  bool get isMissedOrDeclined => status == 'missed' || status == 'declined';

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    final othersJson = (json['others'] as List).cast<Map<String, dynamic>>();
    return CallLogEntry(
      id: json['id'] as String,
      direction: json['direction'] as String,
      callType: json['call_type'] as String,
      groupName: json['group_name'] as String?,
      isVideo: json['is_video'] as bool,
      status: json['status'] as String,
      createdAt: parseServerTime(json['created_at'] as String),
      endedAt: json['ended_at'] != null
          ? parseServerTime(json['ended_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      others: othersJson.map(CallLogOther.fromJson).toList(),
    );
  }
}

/// Pokou — appels audio/vidéo/de groupe (LiveKit Cloud). Aucun état d'appel
/// n'est suivi côté client au-delà de la session en cours ; l'invitation et
/// les événements accept/decline/end passent par le WebSocket existant
/// (voir app/routes/calls.py côté API et WsClient côté app). Le journal
/// d'appels lui-même vit côté serveur (call_logs/call_participants) et se
/// lit via getLog().
class CallRepository {
  CallRepository({
    required ApiClient apiClient,
    E2EEService? e2ee,
    GroupRepository? groups,
    CallKeyVault? vault,
    int? Function()? myUserId,
  }) : _api = apiClient,
       _e2ee = e2ee,
       _groups = groups,
       _vault = vault,
       _myUserId = myUserId ?? (() => null);

  /// Garde la clé d'un appel de groupe tant qu'il reste joignable : on peut
  /// le quitter et y revenir, alors que son enveloppe ne s'ouvre qu'une
  /// fois. Absent dans les tests qui ne s'en occupent pas.
  final CallKeyVault? _vault;

  Future<void> _rememberGroupKey(String room, CallKey key) async {
    CallKeys.remember(room, key);
    await _vault?.keep(room, key);
  }

  /// Pour sceller et ouvrir la clé d'un appel de groupe avec les clés
  /// d'expéditeur du groupe (voir [startGroupCall]).
  final GroupRepository? _groups;

  final ApiClient _api;

  /// Absent dans les tests qui ne s'occupent pas du chiffrement : les
  /// appels se passent alors comme avant.
  final E2EEService? _e2ee;

  /// L'utilisateur connecté — la clé d'un appel est scellée POUR lui, et
  /// rien d'autre ne doit l'ouvrir.
  final int? Function() _myUserId;

  /// Un appel à deux est chiffré de bout en bout quand le correspondant sait
  /// le recevoir ET qu'une session chiffrée existe déjà avec l'identité
  /// qu'il publie ; sinon il part comme avant, en clair pour le serveur de
  /// média, et l'écran le dit. Les appels de groupe, eux, exigent une clé.
  Future<CallToken> startCall(
    List<int> contactIds, {
    bool isVideo = true,
  }) async {
    final me = _myUserId();
    final invitees = contactIds.toSet().toList();
    final peer = invitees.length == 1 ? invitees.single : null;
    final key = peer != null && me != null ? await _keyFor(peer) : null;
    final groupKeys = invitees.length > 1
        ? await _sealedGroupKeys(invitees, from: me)
        : null;
    final response = await _api.post(
      '/calls/token',
      body: {
        'contact_ids': invitees,
        'is_video': isVideo,
        if (key != null)
          'sealed_keys': {'$peer': await _seal(peer!, key, from: me!)},
        if (groupKeys != null) 'sealed_keys': groupKeys.sealedKeys,
      },
    );
    final token = CallToken.fromJson(response as Map<String, dynamic>);
    // Seulement si le SERVEUR confirme : une API pas encore à jour ignore
    // `sealed_keys` sans erreur, et l'invité rejoindrait alors sans clé.
    // Chiffrer de notre côté seulement ferait un appel où personne
    // n'entend personne.
    if (invitees.length > 1 && !token.e2ee) {
      throw const CallEncryptionException(
        'le serveur n’a pas confirmé le chiffrement de groupe',
      );
    }
    if (key != null && token.e2ee) CallKeys.remember(token.room, key);
    if (groupKeys != null && token.e2ee && !token.joinedExisting) {
      await _rememberGroupKey(token.room, groupKeys.key);
    } else if (groupKeys != null && token.joinedExisting) {
      await _rememberReturnedKey(response, token, inviter: null);
    }
    return token;
  }

  /// Une clé neuve si l'appel vers [peerUserId] peut être chiffré.
  ///
  /// Une session DÉJÀ ouverte est exigée, et pas seulement possible : la
  /// clé ne doit jamais être l'enveloppe qui ouvre une session. Elle n'est
  /// remise qu'à l'invité qui décroche ; un appel manqué laisserait sinon
  /// une session dont le préambule n'arrive jamais, et tous nos messages
  /// suivants deviendraient illisibles chez lui.
  ///
  /// La session doit aussi viser l'identité qu'il publie aujourd'hui : après
  /// une réinstallation chez lui, une clé scellée sur l'ancienne ne
  /// s'ouvrirait pas, et l'appel échouerait là où il passait en clair.
  Future<CallKey?> _keyFor(int peerUserId) async {
    if (!await _canEncryptFor(peerUserId)) return null;
    return CallKey.generate();
  }

  Future<({CallKey key, Map<String, dynamic> sealedKeys})> _sealedGroupKeys(
    List<int> inviteeIds, {
    required int? from,
  }) async {
    if (from == null) {
      throw const CallEncryptionException('session expirée, reconnecte-toi');
    }
    // Moi-même n'est jamais un invité : on l'écarte au lieu d'échouer.
    final targets = inviteeIds.where((id) => id != from).toSet();
    final key = CallKey.generate();
    final sealedKeys = <String, dynamic>{};
    // Un membre qui ne peut pas recevoir la clé (application trop ancienne,
    // aucune session chiffrée encore) ne bloque plus l'appel de TOUS : il
    // n'est simplement pas appelé. Le serveur ne fait sonner que ceux pour
    // qui une clé a été scellée.
    for (final inviteeId in targets) {
      try {
        if (!await _canEncryptFor(inviteeId)) continue;
        sealedKeys['$inviteeId'] = await _seal(inviteeId, key, from: from);
      } catch (_) {
        continue;
      }
    }
    if (sealedKeys.isEmpty) {
      throw const CallEncryptionException(
        'aucun membre ne peut encore recevoir un appel chiffré',
      );
    }
    return (key: key, sealedKeys: sealedKeys);
  }

  /// La clé d'un appel de GROUPE, scellée UNE fois avec ma clé
  /// d'expéditeur du groupe, la même que pour mes messages de groupe.
  ///
  /// Scellée par session à deux (ci-dessus), elle exigeait d'avoir déjà
  /// échangé en privé avec chaque membre : dans un groupe neuf, ou après une
  /// remise à zéro, personne ne l'avait fait, et l'appel échouait sur
  /// « aucun membre ne peut encore recevoir un appel chiffré ». La clé
  /// d'expéditeur, elle, est remise à chaque membre par le groupe lui-même,
  /// et chacun la récupère en rejoignant ([_open]). Aucune session à deux
  /// n'est touchée.
  Future<({CallKey key, Map<String, dynamic> sealedKeys})> _groupCallKeys(
    int groupId,
    List<int> inviteeIds, {
    required int? from,
  }) async {
    final groups = _groups;
    if (groups == null) return _sealedGroupKeys(inviteeIds, from: from);
    if (from == null) {
      throw const CallEncryptionException('session expirée, reconnecte-toi');
    }
    final key = CallKey.generate();
    final ({int epoch, String ciphertext}) sealed;
    try {
      sealed = await groups.sealWithMySenderKey(
        groupId: groupId,
        senderId: from,
        plaintext: key.sealForGroup(from: from, groupId: groupId),
      );
    } catch (_) {
      throw const CallEncryptionException(
        'aucun membre ne peut encore recevoir un appel chiffré',
      );
    }
    final entry = {
      'encryption': groupCallKeyEncryption,
      'ciphertext': sealed.ciphertext,
      'envelope': {'group_id': groupId, 'epoch': sealed.epoch},
    };
    return (
      key: key,
      sealedKeys: {
        for (final id in inviteeIds.toSet())
          if (id != from) '$id': entry,
      },
    );
  }

  static const groupCallKeyEncryption = 'sender-key-v1';

  Future<bool> _canEncryptFor(int peerUserId) async {
    final e2ee = _e2ee;
    if (e2ee == null) return false;
    final peer = await e2ee.peerCrypto(peerUserId);
    if (!peer.capabilities.contains(E2EEService.callCapability)) return false;
    final state = await e2ee.sessionState(
      peerUserId,
      publishedIdentityKey: peer.identityKey,
    );
    return state == PeerSessionState.established;
  }

  /// Scelle [key] pour [peerUserId] — ou lève. On ne bascule pas en clair à
  /// ce stade : l'appelant croit appeler chiffré.
  Future<Map<String, dynamic>> _seal(
    int peerUserId,
    CallKey key, {
    required int from,
  }) async {
    final outcome = await _e2ee!.seal(
      peerUserId: peerUserId,
      plaintext: key.seal(from: from, to: peerUserId),
    );
    return switch (outcome) {
      SealEncrypted(:final encryption, :final ciphertext, :final envelope) => {
        'encryption': encryption,
        'ciphertext': ciphertext,
        'envelope': envelope,
      },
      SealRefused(:final reason) => throw EncryptionUnavailableException(
        reason,
      ),
      SealPeerHasNoKeys() => throw const CallEncryptionException(
        'le correspondant n\'a plus de clé de chiffrement',
      ),
    };
  }

  /// Les ouvertures en cours, par salon : deux chemins (notification et
  /// écran d'appel entrant) peuvent rejoindre au même instant, et une
  /// enveloppe ne s'ouvre qu'une fois.
  static final Map<String, Future<CallToken>> _joining = {};

  /// Rejoindre un salon. S'il est chiffré, sa clé doit être connue — tirée
  /// par nous, ou scellée pour nous par [inviter], celui qui nous a invités.
  /// Sinon on lève plutôt que d'entrer : on ne verrait et n'entendrait que
  /// du bruit.
  Future<CallToken> joinCall(String room, {int? inviter}) =>
      _joining[room] ??= _join(room, inviter).whenComplete(() {
        _joining.remove(room);
      });

  Future<CallToken> _join(String room, int? inviter) async {
    final response = await _api.post('/calls/token', body: {'room': room});
    final json = response as Map<String, dynamic>;
    final token = CallToken.fromJson(json);
    if (token.e2ee && CallKeys.of(token.room) == null) {
      await _rememberReturnedKey(json, token, inviter: inviter);
    }
    return token;
  }

  Future<void> _rememberReturnedKey(
    Object? response,
    CallToken token, {
    required int? inviter,
  }) async {
    final json = response as Map<String, dynamic>;
    if (!token.e2ee || CallKeys.of(token.room) != null) return;
    // Un appel de groupe que l'on a quitté, et où l'on revient : sa clé est
    // restée dans le coffre. Rouvrir l'enveloppe échouerait (elle ne
    // s'ouvre qu'une fois), et l'appelant n'en a même pas.
    final kept = await _vault?.restore(token.room);
    if (kept != null) {
      CallKeys.remember(token.room, kept);
      return;
    }
    final sealed = json['sealed_key'];
    final sender =
        inviter ??
        (sealed is Map<String, dynamic>
            ? sealed['from_user_id'] as int?
            : null);
    final key = await _open(sealed, inviter: sender);
    final isGroup =
        token.participantIds.length > 1 ||
        (sealed is Map<String, dynamic> &&
            sealed['encryption'] == groupCallKeyEncryption);
    if (isGroup) {
      await _rememberGroupKey(token.room, key);
    } else {
      CallKeys.remember(token.room, key);
    }
  }

  Future<CallKey> _open(Object? sealed, {required int? inviter}) async {
    final e2ee = _e2ee;
    final me = _myUserId();
    if (e2ee == null || me == null || inviter == null) {
      throw const CallEncryptionException('appel chiffré sans invitant connu');
    }
    if (sealed is! Map<String, dynamic>) {
      throw const CallEncryptionException('aucune clé pour cet appel');
    }
    final envelope = sealed['envelope'];
    final ciphertext = sealed['ciphertext'];
    if (envelope is! Map<String, dynamic> || ciphertext is! String) {
      throw const CallEncryptionException('clé d\'appel illisible');
    }
    // La clé vient de CELUI qui nous a sonnés, et de personne d'autre — le
    // serveur ne choisit pas qui nous la remet.
    if (sealed['from_user_id'] != inviter) {
      throw const CallEncryptionException(
        'clé d\'appel d\'un autre expéditeur',
      );
    }
    // Appel de groupe : un chiffré fait avec la clé d'expéditeur de
    // l'appelant dans ce groupe (voir _groupCallKeys).
    if (sealed['encryption'] == groupCallKeyEncryption) {
      final groups = _groups;
      final groupId = envelope['group_id'];
      final epoch = envelope['epoch'];
      if (groups == null || groupId is! int || epoch is! int) {
        throw const CallEncryptionException('clé d\'appel illisible');
      }
      final String clear;
      try {
        clear = await groups.openWithSenderKey(
          groupId: groupId,
          epoch: epoch,
          senderId: inviter,
          myUserId: me,
          ciphertext: ciphertext,
        );
      } catch (_) {
        throw const CallEncryptionException('clé d\'appel impossible à ouvrir');
      }
      final groupKey = CallKey.tryParseGroup(
        clear,
        from: inviter,
        groupId: groupId,
      );
      if (groupKey == null) {
        throw const CallEncryptionException('clé d\'appel illisible');
      }
      return groupKey;
    }
    // Jamais par une enveloppe qui OUVRE une session (préambule) : une clé
    // d'appel n'est scellée que sur une session existante (voir _keyFor).
    // En accepter une ici laisserait n'importe qui — le serveur compris —
    // se présenter sous une identité neuve.
    if (envelope.containsKey('ik') || envelope.containsKey('ek')) {
      throw const CallEncryptionException('clé d\'appel hors session établie');
    }
    final String plaintext;
    try {
      plaintext = await e2ee.open(
        peerUserId: inviter,
        envelope: envelope,
        ciphertext: ciphertext,
      );
    } catch (_) {
      throw const CallEncryptionException('clé d\'appel impossible à ouvrir');
    }
    final key = CallKey.tryParse(plaintext, from: inviter, to: me);
    if (key == null) {
      throw const CallEncryptionException('clé d\'appel illisible');
    }
    return key;
  }

  /// Appelle tous les membres d'un groupe. Si un appel est déjà en cours dans
  /// ce groupe, le serveur renvoie SON salon (`joinedExisting`) plutôt que
  /// d'ouvrir un appel parallèle.
  Future<CallToken> startGroupCall(
    int groupId, {
    required List<int> memberUserIds,
    bool isVideo = true,
  }) async {
    final active = await activeGroupCall(groupId);
    if (active != null) {
      return joinCall(active.room);
    }
    // La liste vient du SERVEUR, pas de l'écran : celui-ci pouvait n'avoir
    // pas encore chargé les membres, et l'appel partait sans personne.
    var invitees = memberUserIds.toSet().toList();
    try {
      final detail = await _api.get('/groups/$groupId') as Map<String, dynamic>;
      invitees = [
        for (final m in (detail['members'] as List? ?? const []))
          (m as Map<String, dynamic>)['user_id'] as int,
      ];
    } catch (_) {
      // Hors ligne : on garde la liste de l'écran.
    }
    final keys = await _groupCallKeys(groupId, invitees, from: _myUserId());
    final response = await _api.post(
      '/calls/token',
      body: {
        'group_id': groupId,
        'is_video': isVideo,
        'sealed_keys': keys.sealedKeys,
      },
    );
    final json = response as Map<String, dynamic>;
    final token = CallToken.fromJson(json);
    if (!token.e2ee) {
      throw const CallEncryptionException(
        'le serveur n’a pas confirmé le chiffrement de groupe',
      );
    }
    if (token.joinedExisting) {
      await _rememberReturnedKey(json, token, inviter: null);
    } else {
      await _rememberGroupKey(token.room, keys.key);
    }
    return token;
  }

  Future<ActiveGroupCall?> activeGroupCall(int groupId) async {
    final response = await _api.get('/calls/active?group_id=$groupId');
    return ActiveGroupCall.fromJson(response as Map<String, dynamic>);
  }

  /// Ajoute des participants à un appel en cours — le salon ne change pas,
  /// ceux qui y sont déjà n'ont rien à refaire. Renvoie la liste à jour des
  /// autres participants (pour le signal `end`).
  /// Dans un appel chiffré, chaque nouvel invité reçoit la clé, scellée
  /// pour lui. Si l'un d'eux ne peut pas la recevoir, personne n'est
  /// invité : il entrerait dans un appel qu'il ne pourrait pas suivre.
  Future<List<int>> inviteToCall({
    required String room,
    required List<int> userIds,
  }) async {
    final key = CallKeys.of(room);
    if (key == null) {
      throw const CallEncryptionException(
        'les invitations exigent un appel chiffré',
      );
    }
    final me = _myUserId();
    for (final userId in userIds) {
      if (me == null || !await _canEncryptFor(userId)) {
        throw const CallEncryptionException(
          'cette personne ne peut pas rejoindre un appel chiffré',
        );
      }
    }
    final sealedKeys = {
      for (final userId in userIds)
        '$userId': await _seal(userId, key, from: me!),
    };
    final response = await _api.post(
      '/calls/invite',
      body: {'room': room, 'user_ids': userIds, 'sealed_keys': sealedKeys},
    );
    return ((response['participant_ids'] as List?) ?? const []).cast<int>();
  }

  Future<void> signal({
    required String room,
    required int targetUserId,
    required String event,
  }) {
    return _api.post(
      '/calls/signal',
      body: {'room': room, 'target_user_id': targetUserId, 'event': event},
    );
  }

  Future<List<CallLogEntry>> getLog() async {
    return (await getLogRaw())
        .cast<Map<String, dynamic>>()
        .map(CallLogEntry.fromJson)
        .toList();
  }

  Future<List<dynamic>> getLogRaw() async {
    final response = await _api.get('/calls/log');
    return response['items'] as List;
  }
}
