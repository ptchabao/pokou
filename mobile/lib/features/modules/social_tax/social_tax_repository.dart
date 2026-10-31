import '../../../core/api/api_client.dart';
import 'social_tax_model.dart';

class SocialTaxRepository {
  SocialTaxRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<CeremonyFund>> funds() async {
    final response = await _api.get('/ceremonies');
    final items =
        (response as Map<String, dynamic>)['items'] as List? ?? const [];
    return items
        .cast<Map<String, dynamic>>()
        .map(CeremonyFund.fromJson)
        .toList();
  }

  Future<CeremonyFund> fund(int id) async {
    final response = await _api.get('/ceremonies/$id');
    return CeremonyFund.fromJson(response as Map<String, dynamic>);
  }

  Future<CeremonyFund> create({
    required String title,
    required String kind,
    String? description,
    int? goalAmount,
    int daysOpen = 30,
  }) async {
    final response = await _api.post(
      '/ceremonies',
      body: {
        'title': title,
        'kind': kind,
        if (description != null && description.isNotEmpty)
          'description': description,
        'goal_amount': ?goalAmount,
        'days_open': daysOpen,
      },
    );
    return CeremonyFund.fromJson(response as Map<String, dynamic>);
  }

  Future<String?> contribute(
    int fundId, {
    required int amount,
    String? message,
    bool isAnonymous = false,
  }) async {
    final response = await _api.post(
      '/ceremonies/$fundId/contribute',
      body: {
        'amount': amount,
        if (message != null && message.isNotEmpty) 'message': message,
        'is_anonymous': isAnonymous,
      },
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  Future<void> close(int fundId) async {
    await _api.post('/ceremonies/$fundId/close', body: const {});
  }
}
