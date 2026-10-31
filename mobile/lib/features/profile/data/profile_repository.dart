import '../../../core/api/api_client.dart';
import '../../auth/data/user_model.dart';
import 'contact_profile_model.dart';

class ProfileRepository {
  ProfileRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<PokouUser> getMine() async {
    final response = await _api.get('/users/me/profile');
    return PokouUser.fromJson(response as Map<String, dynamic>);
  }

  /// Profil d'un contact — l'API renvoie 403 si `userId` n'est pas dans le
  /// carnet d'adresses de l'appelant (voir GET /users/{id}/profile).
  Future<PokouUser> getUser(int userId) async {
    final response = await _api.get('/users/$userId/profile');
    return PokouUser.fromJson(response as Map<String, dynamic>);
  }

  /// Même endpoint, lu comme une FICHE CONTACT (médias échangés, documents,
  /// liens, groupes en commun, blocage) plutôt que comme un compte — voir
  /// ContactProfile pour le pourquoi des deux modèles.
  Future<ContactProfile> getContactProfile(int userId) async {
    final response = await _api.get('/users/$userId/profile');
    return ContactProfile.fromJson(response as Map<String, dynamic>);
  }

  Future<PokouUser> updateMine({
    String? fullName,
    String? about,
    int? avatarMediaId,
  }) async {
    final response = await _api.put(
      '/users/me/profile',
      body: {
        'full_name': fullName,
        'about': about,
        if (avatarMediaId != null) 'avatar_media_id': avatarMediaId,
      },
    );
    return PokouUser.fromJson(response as Map<String, dynamic>);
  }
}
