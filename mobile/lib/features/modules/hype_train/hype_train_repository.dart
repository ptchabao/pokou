import '../../../core/api/api_client.dart';
import 'hype_train_model.dart';

class HypeTrainRepository {
  HypeTrainRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<HypeTrain>> live() => _list('/hype');

  Future<List<HypeTrain>> mine() => _list('/hype/mine');

  Future<List<HypeTrain>> _list(String path) async {
    final response = await _api.get(path);
    final items =
        (response as Map<String, dynamic>)['items'] as List? ?? const [];
    return items.cast<Map<String, dynamic>>().map(HypeTrain.fromJson).toList();
  }

  Future<HypeTrain> detail(int trainId) async {
    final response = await _api.get('/hype/$trainId');
    return HypeTrain.fromJson(response as Map<String, dynamic>);
  }

  Future<HypeTrain> create({
    required String title,
    required String promise,
    required int goalAmount,
    int hours = 24,
  }) async {
    final response = await _api.post(
      '/hype',
      body: {
        'title': title,
        'promise': promise,
        'goal_amount': goalAmount,
        'hours': hours,
      },
    );
    return HypeTrain.fromJson(response as Map<String, dynamic>);
  }

  Future<String?> contribute(int trainId, int amount) async {
    final response = await _api.post(
      '/hype/$trainId/contribute',
      body: {'amount': amount},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }
}
