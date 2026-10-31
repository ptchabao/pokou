import '../../../core/api/api_client.dart';

/// L'indicateur « en train d'écrire ».
///
/// Diffusion pure : le serveur ne persiste rien et n'envoie aucune
/// notification push (voir api/app/routes/presence.py). L'état ne vaut que
/// quelques secondes, et c'est le client qui le renvoie tant que la frappe
/// continue.
class PresenceRepository {
  PresenceRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Prévient le correspondant. **N'échoue jamais bruyamment** : un
  /// indicateur perdu est sans conséquence, alors qu'une exception remontée
  /// depuis le champ de saisie interromprait la frappe.
  Future<void> setTyping({
    required String kind,
    required int id,
    required bool typing,
  }) async {
    try {
      await _api.post(
        '/presence/typing',
        body: {'kind': kind, 'id': id, 'typing': typing},
      );
    } catch (_) {
      // Silencieux, volontairement — voir docstring.
    }
  }
}
