import '../../../core/api/api_client.dart';
import 'monitor_model.dart';

class InboxRepository {
  InboxRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<SmartContact>> listSmartContacts() async {
    final response = await _api.get('/mahizu/monitors?limit=100');
    final items = (response['items'] as List).cast<Map<String, dynamic>>();
    return items.map(SmartContact.fromJson).toList();
  }
}
