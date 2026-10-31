import '../../../core/api/api_client.dart';
import '../../../core/sync/queued_mutation.dart';
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
}
