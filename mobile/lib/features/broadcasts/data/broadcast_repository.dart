import '../../../core/api/api_client.dart';
import 'broadcast_model.dart';

class BroadcastRepository {
  BroadcastRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<BroadcastList>> list() async {
    final response = await _api.get('/broadcasts');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(BroadcastList.fromJson)
        .toList();
  }

  Future<BroadcastList> create({
    required String name,
    required List<int> memberUserIds,
  }) async {
    final response = await _api.post(
      '/broadcasts',
      body: {'name': name, 'member_user_ids': memberUserIds},
    );
    return BroadcastList.fromJson(response as Map<String, dynamic>);
  }

  /// La sélection est renvoyée ENTIÈRE, pas en ajout/retrait : l'écran
  /// présente une case à cocher par contact, et un différentiel côté client
  /// serait une source d'écarts pour zéro gain.
  Future<BroadcastList> update({
    required int listId,
    String? name,
    List<int>? memberUserIds,
  }) async {
    final response = await _api.patch(
      '/broadcasts/$listId',
      body: {'name': ?name, 'member_user_ids': ?memberUserIds},
    );
    return BroadcastList.fromJson(response as Map<String, dynamic>);
  }

  Future<void> delete(int listId) => _api.delete('/broadcasts/$listId');

  Future<List<BroadcastSentMessage>> messages(int listId) async {
    final response = await _api.get('/broadcasts/$listId/messages');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(BroadcastSentMessage.fromJson)
        .toList();
  }

  /// Renvoie le nombre de destinataires SERVIS et le nombre sautés parce
  /// qu'ils ont bloqué l'expéditeur — les deux comptent pour l'écran, qui
  /// doit pouvoir dire « parti à 39 sur 40 » plutôt que de mentir.
  Future<({int recipientCount, int skippedBlocked})> send({
    required int listId,
    required String content,
  }) async {
    final response = await _api.post(
      '/broadcasts/$listId/messages',
      body: {'content': content},
    );
    final json = response as Map<String, dynamic>;
    return (
      recipientCount: json['recipient_count'] as int? ?? 0,
      skippedBlocked: json['skipped_blocked'] as int? ?? 0,
    );
  }
}
