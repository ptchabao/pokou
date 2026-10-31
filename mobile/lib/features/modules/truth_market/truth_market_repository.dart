import '../../../core/api/api_client.dart';
import 'truth_market_model.dart';

class TruthMarketRepository {
  TruthMarketRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<TruthQuestion>> received() => _list('/truth/received');

  Future<List<TruthQuestion>> sent() => _list('/truth/sent');

  Future<List<TruthQuestion>> _list(String path) async {
    final response = await _api.get(path);
    final items =
        (response as Map<String, dynamic>)['items'] as List? ?? const [];
    return items
        .cast<Map<String, dynamic>>()
        .map(TruthQuestion.fromJson)
        .toList();
  }

  /// Ouvre le paiement d'une question. Elle n'arrive chez l'autre qu'une
  /// fois l'argent confirmé, côté serveur.
  Future<String?> ask({
    required int targetId,
    required String question,
    required int amount,
  }) async {
    final response = await _api.post(
      '/truth',
      body: {'target_id': targetId, 'question': question, 'amount': amount},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  Future<void> answer(int questionId, String answer) async {
    await _api.post('/truth/$questionId/answer', body: {'answer': answer});
  }

  Future<void> decline(int questionId) async {
    await _api.post('/truth/$questionId/decline', body: const {});
  }
}
