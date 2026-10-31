import '../../../core/api/api_client.dart';
import 'module_model.dart';

class ModuleRepository {
  ModuleRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<ModuleCatalogue> catalogue() async {
    final response = await _api.get('/modules');
    return ModuleCatalogue.fromJson(response as Map<String, dynamic>);
  }

  /// Idempotent des deux côtés : le serveur accepte une activation déjà
  /// acquise, ce qui rend un double appui inoffensif.
  Future<void> activate(String slug) =>
      _api.post('/modules/$slug/activate', body: const {});

  Future<void> deactivate(String slug) =>
      _api.delete('/modules/$slug/activate');
}
