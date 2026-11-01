import '../../../core/time/server_time.dart';
/// Kory — une cagnotte ou une cotisation, telle que le serveur la décrit.
///
/// Aucun champ ne s'appelle « solde » : Pokou ne détient rien (BM-01).
/// `confirmedTotal` est la somme de ce que le collecteur a confirmé avoir
/// reçu sur son propre wallet.
class KoryPot {
  const KoryPot({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.confirmedTotal,
    required this.myConfirmedTotal,
    required this.isOrganizer,
    required this.isCollector,
    required this.joinCode,
    this.description,
    this.groupId,
    this.organizerName,
    this.collectorName,
    this.collectorPhone,
    this.goalAmount,
    this.amountPerMember,
    this.period,
    this.dueAt,
    this.pendingCount,
    this.declaredTotal = 0,
    this.remainingToCollect,
    this.entries = const [],
    this.rounds = const [],
    this.currentRound,
  });

  /// Tontine (Kory Plus) : les tours, dans l'ordre fixé à l'ouverture.
  final List<KoryRound> rounds;
  final int? currentRound;

  bool get isTontine => kind == 'TONTINE';

  /// « Total déclaré » : ce que les membres disent avoir envoyé.
  final int declaredTotal;

  /// « Reste à collecter » vers l'objectif, depuis le confirmé.
  final int? remainingToCollect;

  final int id;
  final String kind; // CAGNOTTE | COTISATION | TONTINE
  final String title;
  final String? description;
  final int? groupId;
  final String? organizerName;
  final String? collectorName;
  final String? collectorPhone;
  final int? goalAmount;
  final int? amountPerMember;
  final String? period; // WEEKLY | MONTHLY
  final DateTime? dueAt;
  final String status; // OPEN | CLOSED
  final int confirmedTotal;
  final int myConfirmedTotal;
  final int? pendingCount;
  final bool isOrganizer;
  final bool isCollector;
  final String joinCode;
  final List<KoryEntry> entries;

  bool get isOpen => status == 'OPEN';
  bool get isCotisation => kind == 'COTISATION';

  /// Avancement vers l'objectif, borné à 1 : une cagnotte peut le dépasser.
  double? get progress {
    final goal = goalAmount;
    if (goal == null || goal <= 0) return null;
    return (confirmedTotal / goal).clamp(0, 1).toDouble();
  }

  factory KoryPot.fromJson(Map<String, dynamic> json) => KoryPot(
    id: json['id'] as int,
    kind: json['kind'] as String? ?? 'CAGNOTTE',
    title: json['title'] as String,
    description: json['description'] as String?,
    groupId: json['group_id'] as int?,
    organizerName: json['organizer_name'] as String?,
    collectorName: json['collector_name'] as String?,
    collectorPhone: json['collector_phone'] as String?,
    goalAmount: json['goal_amount'] as int?,
    amountPerMember: json['amount_per_member'] as int?,
    period: json['period'] as String?,
    dueAt: tryParseServerTime(json['due_at'] as String? ?? ''),
    status: json['status'] as String? ?? 'OPEN',
    confirmedTotal: json['confirmed_total'] as int? ?? 0,
    myConfirmedTotal: json['my_confirmed_total'] as int? ?? 0,
    pendingCount: json['pending_count'] as int?,
    declaredTotal: json['declared_total'] as int? ?? 0,
    remainingToCollect: json['remaining_to_collect'] as int?,
    isOrganizer: json['is_organizer'] as bool? ?? false,
    isCollector: json['is_collector'] as bool? ?? false,
    joinCode: json['join_code'] as String? ?? '',
    entries: [
      for (final e in (json['entries'] as List? ?? const []))
        KoryEntry.fromJson(e as Map<String, dynamic>),
    ],
    rounds: [
      for (final r in (json['rounds'] as List? ?? const []))
        KoryRound.fromJson(r as Map<String, dynamic>),
    ],
    currentRound: json['current_round'] as int?,
  );
}

/// Un tour de tontine : son bénéficiaire reçoit les mises de tous les
/// autres sur son wallet, et confirme seul ce qu'il a reçu.
class KoryRound {
  const KoryRound({
    required this.number,
    required this.beneficiaryId,
    required this.status,
    required this.confirmedTotal,
    required this.expectedTotal,
    this.beneficiaryName,
    this.dueAt,
  });

  final int number;
  final int beneficiaryId;
  final String? beneficiaryName;
  final DateTime? dueAt;
  final String status; // UPCOMING | CURRENT | DONE
  final int confirmedTotal;
  final int expectedTotal;

  factory KoryRound.fromJson(Map<String, dynamic> json) => KoryRound(
    number: json['number'] as int,
    beneficiaryId: json['beneficiary_id'] as int,
    beneficiaryName: json['beneficiary_name'] as String?,
    dueAt: tryParseServerTime(json['due_at'] as String? ?? ''),
    status: json['status'] as String? ?? 'UPCOMING',
    confirmedTotal: json['confirmed_total'] as int? ?? 0,
    expectedTotal: json['expected_total'] as int? ?? 0,
  );
}

/// Une contribution déclarée. Jamais supprimée : refusée, elle reste au
/// journal avec son statut.
class KoryEntry {
  const KoryEntry({
    required this.id,
    required this.contributorId,
    required this.amount,
    required this.status,
    required this.declaredAt,
    required this.isMine,
    this.contributorName,
    this.walletReference,
    this.periodLabel,
    this.note,
    this.roundNumber,
    this.canReview = false,
  });

  final int? roundNumber;

  /// Le collecteur — ou, dans une tontine, le bénéficiaire DU TOUR de la
  /// contribution — peut la confirmer ou la contester.
  final bool canReview;

  final int id;
  final int contributorId;
  final String? contributorName;
  final int amount;
  final String? walletReference;
  final String? periodLabel;
  final String? note;
  final String status; // DECLARED | CONFIRMED | REJECTED
  final DateTime declaredAt;
  final bool isMine;

  bool get isPending => status == 'DECLARED';

  factory KoryEntry.fromJson(Map<String, dynamic> json) => KoryEntry(
    id: json['id'] as int,
    contributorId: json['contributor_id'] as int,
    contributorName: json['contributor_name'] as String?,
    amount: json['amount'] as int,
    walletReference: json['wallet_reference'] as String?,
    periodLabel: json['period_label'] as String?,
    note: json['note'] as String?,
    status: json['status'] as String? ?? 'DECLARED',
    declaredAt:
        tryParseServerTime(json['declared_at'] as String? ?? '') ??
        DateTime.now(),
    isMine: json['is_mine'] as bool? ?? false,
    roundNumber: json['round_number'] as int?,
    canReview: json['can_review'] as bool? ?? false,
  );
}

class KorySummary {
  const KorySummary({required this.monthConfirmedTotal, required this.toReviewCount});

  final int monthConfirmedTotal;
  final int toReviewCount;

  factory KorySummary.fromJson(Map<String, dynamic> json) => KorySummary(
    monthConfirmedTotal: json['month_confirmed_total'] as int? ?? 0,
    toReviewCount: json['to_review_count'] as int? ?? 0,
  );
}
