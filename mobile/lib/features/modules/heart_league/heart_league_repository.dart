import '../../../core/api/api_client.dart';
import 'heart_league_model.dart';

class HeartLeagueRepository {
  HeartLeagueRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<LeagueStanding> standing() async {
    final response = await _api.get('/heart-league/me');
    return LeagueStanding.fromJson(response as Map<String, dynamic>);
  }

  Future<LeagueRanking> ranking() async {
    final response = await _api.get('/heart-league/leaderboard?limit=20');
    return LeagueRanking.fromJson(response as Map<String, dynamic>);
  }

  /// Renvoie l'URL de paiement Mobile Money, ou `null`.
  ///
  /// Rien n'est accordé ici : l'effet est posé à la CONFIRMATION du
  /// paiement, côté serveur. Abandonner sur la page de la passerelle ne
  /// donne donc rien — ce qui est le comportement attendu, et la raison
  /// pour laquelle l'écran ne doit pas se réjouir trop tôt.
  Future<String?> buyProtection() async {
    final response = await _api.post(
      '/heart-league/protection',
      body: const {},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }
}
