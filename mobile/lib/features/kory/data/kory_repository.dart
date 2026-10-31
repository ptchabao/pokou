import '../../../core/api/api_client.dart';
import 'kory_model.dart';

class KoryRepository {
  KoryRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<KoryPot>> pots({int? groupId}) async {
    final response = await _api.get(
      groupId == null ? '/kory/pots' : '/kory/pots?group_id=$groupId',
    );
    final items =
        (response as Map<String, dynamic>)['items'] as List? ?? const [];
    return items.cast<Map<String, dynamic>>().map(KoryPot.fromJson).toList();
  }

  Future<KorySummary> summary() async {
    final response = await _api.get('/kory/summary');
    return KorySummary.fromJson(response as Map<String, dynamic>);
  }

  Future<KoryPot> pot(int id) async {
    final response = await _api.get('/kory/pots/$id');
    return KoryPot.fromJson(response as Map<String, dynamic>);
  }

  Future<KoryPot> create({
    required String kind,
    required String title,
    String? description,
    int? groupId,
    int? goalAmount,
    int? amountPerMember,
    String? period,
    DateTime? dueAt,
  }) async {
    final response = await _api.post(
      '/kory/pots',
      body: {
        'kind': kind,
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'group_id': ?groupId,
        'goal_amount': ?goalAmount,
        'amount_per_member': ?amountPerMember,
        'period': ?period,
        if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
      },
    );
    return KoryPot.fromJson(response as Map<String, dynamic>);
  }

  Future<KoryPot> join(String code) async {
    final response = await _api.post('/kory/join', body: {'code': code});
    return KoryPot.fromJson(response as Map<String, dynamic>);
  }

  Future<void> declare(
    int potId, {
    required int amount,
    String? walletReference,
    String? periodLabel,
    String? note,
  }) async {
    await _api.post(
      '/kory/pots/$potId/entries',
      body: {
        'amount': amount,
        if (walletReference != null && walletReference.isNotEmpty)
          'wallet_reference': walletReference,
        if (periodLabel != null && periodLabel.isNotEmpty)
          'period_label': periodLabel,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<void> review(int potId, int entryId, {required bool confirm}) async {
    await _api.post(
      '/kory/pots/$potId/entries/$entryId/review',
      body: {'decision': confirm ? 'CONFIRM' : 'REJECT'},
    );
  }

  Future<void> close(int potId) async {
    await _api.post('/kory/pots/$potId/close', body: const {});
  }
}
