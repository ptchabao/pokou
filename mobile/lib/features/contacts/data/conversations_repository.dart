import '../../../core/api/api_client.dart';
import '../../../core/media/media_repository.dart' show MediaMeta;
import '../../../core/sync/queued_mutation.dart';
import '../../../core/time/server_time.dart';
import 'conversation_summary.dart';

/// Écran d'accueil — liste unifiée des contacts et groupes, triée par le
/// serveur (épinglées d'abord, puis activité). Voir GET /conversations,
/// api/app/routes/conversations.py.
class ConversationsRepository {
  ConversationsRepository({
    required ApiClient apiClient,
    MutationQueue? mutations,
  }) : _api = apiClient,
       _mutations = mutations ?? MutationQueue(api: apiClient);

  final ApiClient _api;

  /// Les réglages qui supportent d'attendre le réseau — voir
  /// core/sync/queued_mutation.dart.
  final MutationQueue _mutations;

  Future<List<ConversationSummary>> list({bool archived = false}) async {
    final items = await listRaw(archived: archived);
    return items
        .cast<Map<String, dynamic>>()
        .map(ConversationSummary.fromJson)
        .toList();
  }

  /// La liste TELLE QUE le serveur l'envoie.
  ///
  /// Exposée parce que le cache hors ligne garde ce JSON brut : c'est le
  /// serveur qui compose et trie cette liste, et la redécouper pour la
  /// stocker reviendrait à recopier sa logique de tri sur l'appareil.
  Future<List<dynamic>> listRaw({bool archived = false}) async {
    final response = await _api.get('/conversations?archived=$archived');
    return response['items'] as List;
  }

  // Épingler, archiver, mettre en sourdine : des réglages sur SA liste, que
  // le serveur applique tels quels (PUT d'un état). Ils attendent donc le
  // réseau sans risque, et renvoient `true` quand c'est le cas.
  //
  // Bloquer, non : c'est une protection, et laisser croire qu'elle est en
  // place alors qu'elle attend une reconnexion serait pire que de dire
  // qu'elle a échoué.

  Future<bool> setPinned({
    required String kind,
    required int id,
    required bool pinned,
  }) => _setting('pin', kind, id, {'pinned': pinned});

  Future<bool> setArchived({
    required String kind,
    required int id,
    required bool archived,
  }) => _setting('archive', kind, id, {'archived': archived});

  /// Favori : seulement MA liste, comme l'épingle (filtre « Favoris »).
  Future<bool> setFavorite({
    required String kind,
    required int id,
    required bool favorite,
  }) => _setting('favorite', kind, id, {'favorite': favorite});

  Future<bool> mute({
    required String kind,
    required int id,
    required int? durationSeconds,
  }) => _setting('mute', kind, id, {'duration_seconds': durationSeconds});

  Future<bool> _setting(
    String setting,
    String kind,
    int id,
    Map<String, dynamic> value,
  ) async => (await _mutations.send(
    QueuedMutation(
      key: 'conversation:$setting:$kind:$id',
      method: 'PUT',
      path: '/conversations/$setting',
      body: {'kind': kind, 'id': id, ...value},
    ),
  )).queued;

  Future<void> setBlocked({required int contactUserId, required bool blocked}) {
    return _api.put(
      '/conversations/block',
      body: {'contact_user_id': contactUserId, 'blocked': blocked},
    );
  }

  /// Les personnes que j'ai bloquées — écran « Contacts bloqués ».
  Future<List<BlockedContact>> listBlocked() async {
    final response = await _api.get('/conversations/blocked');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(BlockedContact.fromJson)
        .toList();
  }

  /// Signale une personne ([contactUserId]) ou un groupe ([groupId]).
  ///
  /// [recentMessages] : les 5 derniers messages de la discussion, tels que
  /// CET appareil les a déchiffrés — envoyés seulement avec [consent]. Le
  /// serveur les chiffre au repos (REPORTS_ENCRYPTION_KEY).
  Future<void> report({
    int? contactUserId,
    int? groupId,
    required String reason,
    bool alsoBlock = false,
    List<ReportedMessage> recentMessages = const [],
    bool consent = false,
  }) {
    return _api.post(
      '/conversations/report',
      body: {
        'contact_user_id': ?contactUserId,
        'group_id': ?groupId,
        'reason': reason,
        if (alsoBlock) 'also_block': true,
        // Les messages ne partent qu'avec le consentement explicite.
        if (consent && recentMessages.isNotEmpty) ...{
          'consent': true,
          'recent_messages': [
            for (final message in recentMessages.take(5)) message.toJson(),
          ],
        },
      },
    );
  }
}

/// Une ligne de « Contacts bloqués ». Un inconnu n'a pas de nom de carnet :
/// le serveur envoie alors son numéro MASQUÉ (« +228 9• •• •• 41 »), jamais
/// le numéro en clair.
class BlockedContact {
  const BlockedContact({
    required this.contactUserId,
    required this.displayName,
    required this.isUnknownContact,
    required this.blockedAt,
    required this.afterReport,
    this.avatar,
  });

  final int contactUserId;
  final String displayName;
  final bool isUnknownContact;
  final DateTime? blockedAt;
  final bool afterReport;
  final MediaMeta? avatar;

  factory BlockedContact.fromJson(Map<String, dynamic> json) {
    final avatarJson = json['avatar'] as Map<String, dynamic>?;
    return BlockedContact(
      contactUserId: json['contact_user_id'] as int,
      displayName: json['display_name'] as String? ?? '',
      isUnknownContact: json['is_unknown_contact'] as bool? ?? false,
      blockedAt: json['blocked_at'] != null
          ? parseServerTime(json['blocked_at'] as String)
          : null,
      afterReport: json['after_report'] as bool? ?? false,
      avatar: avatarJson != null ? MediaMeta.fromJson(avatarJson) : null,
    );
  }
}

/// Un message joint à un signalement.
class ReportedMessage {
  const ReportedMessage({
    required this.sender,
    required this.text,
    required this.sentAt,
  });

  final String sender;
  final String text;
  final DateTime sentAt;

  Map<String, dynamic> toJson() => {
    'sender': sender.length > 120 ? sender.substring(0, 120) : sender,
    'text': text.length > 1000 ? text.substring(0, 1000) : text,
    'sent_at': sentAt.toUtc().toIso8601String(),
  };
}
