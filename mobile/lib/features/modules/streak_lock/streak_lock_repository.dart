import '../../../core/api/api_client.dart';
import 'streak_lock_model.dart';

class StreakLockRepository {
  StreakLockRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<Streak>> streaks() async {
    final response = await _api.get('/streaks');
    final items =
        (response as Map<String, dynamic>)['items'] as List? ?? const [];
    return items.cast<Map<String, dynamic>>().map(Streak.fromJson).toList();
  }

  /// Renvoie l'URL de paiement Mobile Money, ou `null`.
  ///
  /// La chaîne n'est PAS restaurée ici : le serveur revérifie la fenêtre de
  /// grâce à la confirmation du paiement.
  Future<String?> restore(int peerId) async {
    final response = await _api.post(
      '/streaks/$peerId/restore',
      body: const {},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }
}
