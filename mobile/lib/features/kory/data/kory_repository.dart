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
    String? beneficiaryName,
    bool amountsVisible = true,
    DateTime? endsAt,
    List<int>? memberIds,
    int? deputyId,
    String? drawMode,
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
        if (beneficiaryName != null && beneficiaryName.isNotEmpty)
          'beneficiary_name': beneficiaryName,
        'amounts_visible': amountsVisible,
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        'member_ids': ?memberIds,
        'deputy_id': ?deputyId,
        'draw_mode': ?drawMode,
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
    int? proofMediaId,
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
        'proof_media_id': ?proofMediaId,
      },
    );
  }

  /// KOR-10 : l'aperçu d'une cagnotte avant de la rejoindre.
  Future<KoryPreview> preview(String code) async {
    final response = await _api.get(
      '/kory/preview/${Uri.encodeComponent(code.trim().toUpperCase())}',
    );
    return KoryPreview.fromJson(response as Map<String, dynamic>);
  }

  Future<KoryPot> _action(
    int potId,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _api.post(
      '/kory/pots/$potId/$path',
      body: body ?? const {},
    );
    return KoryPot.fromJson(response as Map<String, dynamic>);
  }

  /// KOR-25 : accepter ou refuser l'invitation dans une tontine.
  Future<KoryPot> acceptTontine(int potId) => _action(potId, 'accept');
  Future<KoryPot> declineTontine(int potId) => _action(potId, 'decline');

  /// Kory Plus : ouvre le paiement Mobile Money des frais d'ouverture.
  /// Renvoie l'adresse de la passerelle ; la confirmation du paiement, côté
  /// serveur, vaut acceptation de l'invitation.
  Future<String?> payPlusFee(int potId) async {
    final response = await _api.post('/kory/pots/$potId/fee', body: const {});
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  /// L'administrateur démarre sans ceux qui ont refusé.
  Future<KoryPot> startTontine(int potId) => _action(potId, 'start');

  /// KOR-8 / 20 : relancer ceux qui n'ont pas répondu ou versé. Renvoie le
  /// nombre de personnes relancées.
  Future<int> remind(int potId) async {
    final response = await _api.post(
      '/kory/pots/$potId/remind',
      body: const {},
    );
    return (response as Map<String, dynamic>)['reminded'] as int? ?? 0;
  }

  /// KOR-28 : proposer, accepter, valider ou refuser un échange de mois.
  Future<KoryPot> requestSwap(int potId, int withUserId, {String? message}) =>
      _action(potId, 'swaps', {
        'with_user_id': withUserId,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      });
  Future<KoryPot> acceptSwap(int potId, int swapId) =>
      _action(potId, 'swaps/$swapId/accept');
  Future<KoryPot> approveSwap(int potId, int swapId) =>
      _action(potId, 'swaps/$swapId/approve');
  Future<KoryPot> refuseSwap(int potId, int swapId) =>
      _action(potId, 'swaps/$swapId/refuse');

  /// KOR-30 : dissoudre la tontine, avec un motif.
  Future<KoryPot> dissolve(int potId, String reason) =>
      _action(potId, 'dissolve', {'reason': reason});

  /// KOR-22 : AMOUNT (avec [amount]), PAUSE, STOP ou COLLECTOR (avec
  /// [collectorId]).
  Future<KoryPot> changeCotisation(
    int potId,
    String action, {
    int? amount,
    int? collectorId,
  }) => _action(potId, 'cotisation', {
    'action': action,
    'amount': ?amount,
    'collector_id': ?collectorId,
  });

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

  /// KOR-11 : ajouter des participants (Pokou, ou invités par SMS).
  Future<KoryPot> addParticipants(
    int potId, {
    List<int> userIds = const [],
    List<({String phone, String name})> phones = const [],
  }) async {
    final response = await _api.post(
      '/kory/pots/$potId/participants',
      body: {
        'user_ids': userIds,
        'phones': [
          for (final p in phones) {'phone': p.phone, 'name': p.name},
        ],
      },
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
