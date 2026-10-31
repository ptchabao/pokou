import '../../../core/api/api_client.dart';
import '../../../core/sync/queued_mutation.dart';
import 'status_model.dart';

class StatusRepository {
  StatusRepository({required ApiClient apiClient, MutationQueue? mutations})
    : _api = apiClient,
      _mutations = mutations ?? MutationQueue(api: apiClient);

  final ApiClient _api;

  /// Les réglages qui supportent d'attendre le réseau — voir
  /// core/sync/queued_mutation.dart.
  final MutationQueue _mutations;

  /// Voir contacts_repository.dart::listRaw.
  Future<List<dynamic>> getFeedRaw() async {
    final response = await _api.get('/status/feed');
    return response['items'] as List;
  }

  Future<List<StatusFeedItem>> getFeed() async => (await getFeedRaw())
      .cast<Map<String, dynamic>>()
      .map(StatusFeedItem.fromJson)
      .toList();

  Future<PokouStatus> createText(String text) async {
    final response = await _api.post(
      '/status',
      body: {'content_type': 'TEXT', 'text_content': text},
    );
    return PokouStatus.fromJson(response as Map<String, dynamic>);
  }

  Future<PokouStatus> createMedia({
    required String contentType,
    required int mediaAssetId,
    String? caption,
  }) async {
    final response = await _api.post(
      '/status',
      body: {
        'content_type': contentType,
        'media_asset_id': mediaAssetId,
        if (caption != null && caption.trim().isNotEmpty)
          'text_content': caption,
      },
    );
    return PokouStatus.fromJson(response as Map<String, dynamic>);
  }

  /// Idempotent côté API : un statut vu hors ligne est compté à la
  /// reconnexion, et l'anneau de l'auteur ne se rallume pas entre-temps.
  Future<void> markViewed(String statusId) => _mutations.send(
    QueuedMutation(
      key: 'status:view:$statusId',
      method: 'POST',
      path: '/status/$statusId/view',
    ),
  );

  /// Retire mon statut avant les 24 h. Pas de file hors ligne : retirer
  /// une photo publiée par erreur doit réussir MAINTENANT ou le dire.
  Future<void> delete(String statusId) async {
    await _api.delete('/status/$statusId');
  }

  Future<Map<String, dynamic>> boost(String statusId) async {
    final response = await _api.post(
      '/marketplace/boost/status/$statusId',
      body: const {},
    );
    return (response as Map).cast<String, dynamic>();
  }

  /// Qui a vu MON statut, et quand. L'API renvoie 404 pour le statut d'un
  /// autre — pas 403 : répondre « interdit » confirmerait qu'un statut
  /// existe derrière cet identifiant.
  Future<List<StatusViewer>> viewers(String statusId) async {
    final response = await _api.get('/status/$statusId/views');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(StatusViewer.fromJson)
        .toList();
  }

  Future<StatusPrivacy> getPrivacy() async {
    final response = await _api.get('/status/privacy');
    return StatusPrivacy.fromJson(response as Map<String, dynamic>);
  }

  Future<StatusPrivacy> setPrivacy({
    required StatusAudience audience,
    List<int> userIds = const [],
  }) async {
    final response = await _api.put(
      '/status/privacy',
      body: {
        'mode': audience.wire,
        // Le serveur ignore la liste hors modes « sauf »/« uniquement », mais
        // ne pas l'envoyer évite de lui faire effacer/réécrire pour rien.
        'user_ids': audience.needsList ? userIds : const <int>[],
      },
    );
    return StatusPrivacy.fromJson(response as Map<String, dynamic>);
  }
}
