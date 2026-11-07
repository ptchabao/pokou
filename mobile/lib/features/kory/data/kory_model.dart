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
    this.myPledge,
    this.pledgeSummary,
    this.serverNow,
    this.isDue = false,
    this.closedAt,
    this.collectorId,
  });

  /// Mon engagement (KOR-12 à 14), `null` si je ne me suis pas engagé.
  final KoryPledge? myPledge;

  /// La vue du collecteur sur les engagements fermes (KOR-15).
  final KoryPledgeSummary? pledgeSummary;

  /// L'heure du serveur à la réponse : le délai de 8 h se compte sur elle,
  /// pas sur l'horloge du téléphone.
  final DateTime? serverNow;

  /// La date de fin est passée et la collecte est encore ouverte (KOR-15).
  final bool isDue;
  final DateTime? closedAt;
  final int? collectorId;

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
    myPledge: json['my_pledge'] is Map<String, dynamic>
        ? KoryPledge.fromJson(json['my_pledge'] as Map<String, dynamic>)
        : null,
    pledgeSummary: json['pledge_summary'] is Map<String, dynamic>
        ? KoryPledgeSummary.fromJson(
            json['pledge_summary'] as Map<String, dynamic>,
          )
        : null,
    serverNow: tryParseServerTime(json['server_now'] as String? ?? ''),
    isDue: json['is_due'] as bool? ?? false,
    closedAt: tryParseServerTime(json['closed_at'] as String? ?? ''),
    collectorId: json['collector_id'] as int?,
  );
}

/// Un engagement : un montant de départ, plus un montant par jour jusqu'à
/// la date de fin. Modifiable 8 h, ferme ensuite (KORY-13).
class KoryPledge {
  const KoryPledge({
    required this.base,
    required this.total,
    required this.pledgedAt,
    required this.firmAt,
    required this.isFirm,
    required this.confirmed,
    required this.remaining,
    this.daily,
    this.days = 0,
    this.nextDailyAdd,
  });

  final int base;
  final int? daily;
  final int days;
  final int total;
  final DateTime pledgedAt;
  final DateTime firmAt;
  final bool isFirm;
  final int confirmed;
  final int remaining;
  final DateTime? nextDailyAdd;

  factory KoryPledge.fromJson(Map<String, dynamic> json) => KoryPledge(
    base: json['base'] as int? ?? 0,
    daily: json['daily'] as int?,
    days: json['days'] as int? ?? 0,
    total: json['total'] as int? ?? 0,
    pledgedAt:
        tryParseServerTime(json['pledged_at'] as String? ?? '') ??
        DateTime.now(),
    firmAt:
        tryParseServerTime(json['firm_at'] as String? ?? '') ?? DateTime.now(),
    isFirm: json['is_firm'] as bool? ?? false,
    confirmed: json['confirmed'] as int? ?? 0,
    remaining: json['remaining'] as int? ?? 0,
    nextDailyAdd: DateTime.tryParse(json['next_daily_add'] as String? ?? ''),
  );
}

class KoryPledgeSummary {
  const KoryPledgeSummary({
    required this.engagedTotal,
    required this.engagedCount,
    required this.confirmedTotal,
    required this.toConfirmTotal,
    required this.toConfirmCount,
    required this.remainingTotal,
    required this.remainingCount,
  });

  final int engagedTotal;
  final int engagedCount;
  final int confirmedTotal;
  final int toConfirmTotal;
  final int toConfirmCount;
  final int remainingTotal;
  final int remainingCount;

  factory KoryPledgeSummary.fromJson(Map<String, dynamic> json) =>
      KoryPledgeSummary(
        engagedTotal: json['engaged_total'] as int? ?? 0,
        engagedCount: json['engaged_count'] as int? ?? 0,
        confirmedTotal: json['confirmed_total'] as int? ?? 0,
        toConfirmTotal: json['to_confirm_total'] as int? ?? 0,
        toConfirmCount: json['to_confirm_count'] as int? ?? 0,
        remainingTotal: json['remaining_total'] as int? ?? 0,
        remainingCount: json['remaining_count'] as int? ?? 0,
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
    this.reviewReason,
    this.proofMediaId,
  });

  /// Pourquoi le collecteur n'a pas constaté l'envoi (KOR-5).
  final String? reviewReason;
  final int? proofMediaId;

  bool get isContested => status == 'REJECTED';

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
    reviewReason: json['review_reason'] as String?,
    proofMediaId: json['proof_media_id'] as int?,
  );
}

class KorySummary {
  const KorySummary({
    required this.monthConfirmedTotal,
    required this.toReviewCount,
  });

  final int monthConfirmedTotal;
  final int toReviewCount;

  factory KorySummary.fromJson(Map<String, dynamic> json) => KorySummary(
    monthConfirmedTotal: json['month_confirmed_total'] as int? ?? 0,
    toReviewCount: json['to_review_count'] as int? ?? 0,
  );
}
