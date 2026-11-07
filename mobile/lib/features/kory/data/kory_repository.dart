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
    List<int>? rotation,
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
        'rotation': ?rotation,
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

  Future<void> review(
    int potId,
    int entryId, {
    required bool confirm,
    String? reason,
  }) async {
    await _api.post(
      '/kory/pots/$potId/entries/$entryId/review',
      body: {
        'decision': confirm ? 'CONFIRM' : 'REJECT',
        if (!confirm && reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      },
    );
  }

  /// KOR-12 / 13 : s'engager, ou corriger son engagement dans les 8 h.
  Future<KoryPot> pledge(int potId, {required int base, int? daily}) async {
    final response = await _api.put(
      '/kory/pots/$potId/pledge',
      body: {'base': base, if (daily != null && daily > 0) 'daily': daily},
    );
    return KoryPot.fromJson(response as Map<String, dynamic>);
  }

  /// KOR-15 : prolonger la collecte jusqu'à [dueAt].
  Future<KoryPot> extend(int potId, DateTime dueAt) async {
    final response = await _api.post(
      '/kory/pots/$potId/extend',
      body: {'due_at': dueAt.toUtc().toIso8601String()},
    );
    return KoryPot.fromJson(response as Map<String, dynamic>);
  }

  /// KOR-5 : corriger la référence ou joindre la capture du SMS.
  Future<void> resubmit(
    int potId,
    int entryId, {
    String? walletReference,
    int? proofMediaId,
  }) async {
    await _api.post(
      '/kory/pots/$potId/entries/$entryId/resubmit',
      body: {
        'wallet_reference': ?walletReference,
        'proof_media_id': ?proofMediaId,
      },
    );
  }

  /// Tontine : l'organisateur passe au tour suivant.
  Future<void> nextRound(int potId) async {
    await _api.post('/kory/pots/$potId/next-round', body: const {});
  }

  Future<void> close(int potId) async {
    await _api.post('/kory/pots/$potId/close', body: const {});
  }
}
