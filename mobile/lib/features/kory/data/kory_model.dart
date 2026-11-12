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
    this.createdAt,
    this.extendedAt,
    this.groupName,
    this.beneficiaryName,
    this.amountsVisible = true,
    this.deputyId,
    this.deputyName,
    this.isDeputy = false,
    this.isAdmin = false,
    this.endsAt,
    this.dissolvedAt,
    this.dissolveReason,
    this.remindedAt,
    this.participantsCount = 0,
    this.drawMode,
    this.drawSeal,
    this.drawnAt,
    this.members = const [],
    this.swaps = const [],
    this.plusFee,
    this.cotisation,
    this.organizerId,
  });

  final DateTime? createdAt;
  final DateTime? extendedAt;

  /// La discussion d'où vient la collecte (KOR-6 « Discussion liée »).
  final String? groupName;

  /// Pour qui l'on collecte (KOR-6) : un nom, pas un compte.
  final String? beneficiaryName;

  /// KOR-6 : les montants de chacun sont visibles de tous ; sinon, seuls
  /// l'auteur et celui qui confirme les voient.
  final bool amountsVisible;

  /// Co-organisateur d'une cotisation (KOR-18), suppléant de
  /// l'administrateur d'une tontine (KOR-24).
  final int? deputyId;
  final String? deputyName;
  final bool isDeputy;

  /// L'organisateur ou son suppléant.
  final bool isAdmin;
  final DateTime? endsAt;
  final DateTime? dissolvedAt;
  final String? dissolveReason;
  final DateTime? remindedAt;
  final int participantsCount;

  /// Tontine : DRAW (tirage au sort) ou FIXED (ordre fixé) — KOR-24 / 26.
  final String? drawMode;
  final String? drawSeal;
  final DateTime? drawnAt;
  final List<KoryMemberInfo> members;
  final List<KorySwap> swaps;

  /// Tontine Kory Plus : ses frais d'ouverture, `null` hors tontine.
  final KoryPlusFee? plusFee;
  final KoryCotisation? cotisation;
  final int? organizerId;

  /// Tontine en attente : les invités n'ont pas tous accepté (KOR-8).
  bool get isPending => status == 'PENDING';
  bool get isDissolved => dissolvedAt != null;

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
    createdAt: tryParseServerTime(json['created_at'] as String? ?? ''),
    extendedAt: tryParseServerTime(json['extended_at'] as String? ?? ''),
    groupName: json['group_name'] as String?,
    beneficiaryName: json['beneficiary_name'] as String?,
    amountsVisible: json['amounts_visible'] as bool? ?? true,
    deputyId: json['deputy_id'] as int?,
    deputyName: json['deputy_name'] as String?,
    isDeputy: json['is_deputy'] as bool? ?? false,
    isAdmin:
        json['is_admin'] as bool? ?? (json['is_organizer'] as bool? ?? false),
    endsAt: tryParseServerTime(json['ends_at'] as String? ?? ''),
    dissolvedAt: tryParseServerTime(json['dissolved_at'] as String? ?? ''),
    dissolveReason: json['dissolve_reason'] as String?,
    remindedAt: tryParseServerTime(json['reminded_at'] as String? ?? ''),
    participantsCount: json['participants_count'] as int? ?? 0,
    drawMode: json['draw_mode'] as String?,
    drawSeal: json['draw_seal'] as String?,
    drawnAt: tryParseServerTime(json['drawn_at'] as String? ?? ''),
    members: [
      for (final m in (json['members'] as List? ?? const []))
        KoryMemberInfo.fromJson(m as Map<String, dynamic>),
    ],
    swaps: [
      for (final w in (json['swaps'] as List? ?? const []))
        KorySwap.fromJson(w as Map<String, dynamic>),
    ],
    plusFee: KoryPlusFee.tryParse(json['plus_fee']),
    cotisation: json['cotisation'] is Map<String, dynamic>
        ? KoryCotisation.fromJson(json['cotisation'] as Map<String, dynamic>)
        : null,
    organizerId: json['organizer_id'] as int?,
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
    this.expectedCount = 0,
    this.confirmedCount = 0,
    this.declaredCount = 0,
    this.rejectedCount = 0,
    this.lateCount = 0,
    this.contributors = const [],
  });

  /// KOR-29 : combien de membres doivent miser, et où ils en sont.
  final int expectedCount;
  final int confirmedCount;
  final int declaredCount;
  final int rejectedCount;
  final int lateCount;

  /// KOR-7 : chacun, pour le tour en cours.
  final List<KoryContributorState> contributors;

  bool get isCurrent => status == 'CURRENT';
  bool get isDone => status == 'DONE';
  bool get isCancelled => status == 'CANCELLED';

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
    expectedCount: json['expected_count'] as int? ?? 0,
    confirmedCount: json['confirmed_count'] as int? ?? 0,
    declaredCount: json['declared_count'] as int? ?? 0,
    rejectedCount: json['rejected_count'] as int? ?? 0,
    lateCount: json['late_count'] as int? ?? 0,
    contributors: [
      for (final c in (json['contributors'] as List? ?? const []))
        KoryContributorState.fromJson(c as Map<String, dynamic>),
    ],
  );
}

/// Où en est un membre pour une échéance ou un tour : CONFIRMED, DECLARED,
/// REJECTED, LATE (échéance passée, rien de déclaré) ou DUE (à venir).
class KoryContributorState {
  const KoryContributorState({
    required this.userId,
    required this.status,
    this.name,
  });

  final int userId;
  final String? name;
  final String status;

  factory KoryContributorState.fromJson(Map<String, dynamic> json) =>
      KoryContributorState(
        userId: json['user_id'] as int,
        name: json['name'] as String?,
        status: json['status'] as String? ?? 'DUE',
      );
}

/// Un membre d'une tontine : invité, accepté ou non, administrateur ou
/// suppléant (KOR-8, 24, 25).
class KoryMemberInfo {
  const KoryMemberInfo({
    required this.userId,
    this.name,
    this.accepted = false,
    this.declined = false,
    this.isAdmin = false,
    this.isDeputy = false,
    this.feePaid = false,
  });

  /// Kory Plus : a réglé ses frais d'ouverture (payer vaut accepter).
  final bool feePaid;

  final int userId;
  final String? name;
  final bool accepted;
  final bool declined;
  final bool isAdmin;
  final bool isDeputy;

  factory KoryMemberInfo.fromJson(Map<String, dynamic> json) => KoryMemberInfo(
    userId: json['user_id'] as int,
    name: json['name'] as String?,
    accepted: json['accepted'] as bool? ?? false,
    declined: json['declined'] as bool? ?? false,
    isAdmin: json['is_admin'] as bool? ?? false,
    isDeputy: json['is_deputy'] as bool? ?? false,
    feePaid: json['fee_paid'] as bool? ?? false,
  );
}

/// Kory Plus : les frais d'ouverture d'une tontine (KOR-8 / 25), fixés par le
/// serveur selon le pays de l'administrateur. `amountHt == 0` : gratuite.
class KoryPlusFee {
  const KoryPlusFee({
    required this.amountHt,
    required this.amountTtc,
    this.paidCount = 0,
    this.memberCount = 0,
    this.iPaid = false,
  });

  final int amountHt;
  final int amountTtc;
  final int paidCount;
  final int memberCount;
  final bool iPaid;

  bool get isDue => amountHt > 0;

  static KoryPlusFee? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return KoryPlusFee(
      amountHt: json['amount_ht'] as int? ?? 0,
      amountTtc: json['amount_ttc'] as int? ?? 0,
      paidCount: json['paid_count'] as int? ?? 0,
      memberCount: json['member_count'] as int? ?? 0,
      iPaid: json['i_paid'] as bool? ?? false,
    );
  }
}

/// KOR-28 : un échange de mois. PENDING (attend l'autre membre), ACCEPTED
/// (attend l'administrateur), DONE ou REFUSED.
class KorySwap {
  const KorySwap({
    required this.id,
    required this.requesterId,
    required this.targetId,
    required this.requesterRound,
    required this.targetRound,
    required this.status,
    required this.createdAt,
    this.requesterName,
    this.targetName,
    this.message,
    this.decidedAt,
  });

  final int id;
  final int requesterId;
  final String? requesterName;
  final int targetId;
  final String? targetName;
  final int requesterRound;
  final int targetRound;
  final String? message;
  final String status;
  final DateTime createdAt;
  final DateTime? decidedAt;

  bool get isOpen => status == 'PENDING' || status == 'ACCEPTED';

  factory KorySwap.fromJson(Map<String, dynamic> json) => KorySwap(
    id: json['id'] as int,
    requesterId: json['requester_id'] as int,
    requesterName: json['requester_name'] as String?,
    targetId: json['target_id'] as int,
    targetName: json['target_name'] as String?,
    requesterRound: json['requester_round'] as int,
    targetRound: json['target_round'] as int,
    message: json['message'] as String?,
    status: json['status'] as String? ?? 'PENDING',
    createdAt:
        tryParseServerTime(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    decidedAt: tryParseServerTime(json['decided_at'] as String? ?? ''),
  );
}

/// Le calendrier d'une cotisation (KOR-19 à 21), tel que le serveur le
/// recalcule à partir du journal.
class KoryCotisation {
  const KoryCotisation({
    required this.membersCount,
    required this.isMember,
    this.members = const [],
    this.current,
    this.history = const [],
    this.myPeriods = const [],
    this.myNext,
    this.schedule = const [],
    this.nextPeriodDue,
  });

  final int membersCount;
  final bool isMember;
  final List<KoryContributorState> members;
  final KoryDuePeriod? current;
  final List<KoryPastPeriod> history;
  final List<KoryMyPeriod> myPeriods;
  final KoryMyPeriod? myNext;
  final List<KoryScheduledDue> schedule;

  /// L'échéance qui suit celle en cours (KOR-22 « à partir du … »).
  final DateTime? nextPeriodDue;

  factory KoryCotisation.fromJson(Map<String, dynamic> json) {
    final next = json['next_period'];
    return KoryCotisation(
      membersCount: json['members_count'] as int? ?? 0,
      isMember: json['is_member'] as bool? ?? false,
      members: [
        for (final m in (json['members'] as List? ?? const []))
          KoryContributorState.fromJson({
            ...(m as Map<String, dynamic>),
            'status': 'DUE',
          }),
      ],
      current: json['current'] is Map<String, dynamic>
          ? KoryDuePeriod.fromJson(json['current'] as Map<String, dynamic>)
          : null,
      history: [
        for (final h in (json['history'] as List? ?? const []))
          KoryPastPeriod.fromJson(h as Map<String, dynamic>),
      ],
      myPeriods: [
        for (final p in (json['my_periods'] as List? ?? const []))
          KoryMyPeriod.fromJson(p as Map<String, dynamic>),
      ],
      myNext: json['my_next'] is Map<String, dynamic>
          ? KoryMyPeriod.fromJson(json['my_next'] as Map<String, dynamic>)
          : null,
      schedule: [
        for (final s in (json['schedule'] as List? ?? const []))
          KoryScheduledDue.fromJson(s as Map<String, dynamic>),
      ],
      nextPeriodDue: next is Map<String, dynamic>
          ? tryParseServerTime(next['due_at'] as String? ?? '')
          : null,
    );
  }
}

/// L'échéance en cours, vue de l'organisateur (KOR-20).
class KoryDuePeriod {
  const KoryDuePeriod({
    required this.label,
    required this.dueAt,
    required this.amount,
    required this.expectedTotal,
    required this.confirmedTotal,
    required this.upToDateCount,
    required this.toConfirmCount,
    required this.lateCount,
    this.late = const [],
  });

  final String label;
  final DateTime dueAt;
  final int amount;
  final int expectedTotal;
  final int confirmedTotal;
  final int upToDateCount;
  final int toConfirmCount;
  final int lateCount;
  final List<KoryContributorState> late;

  factory KoryDuePeriod.fromJson(Map<String, dynamic> json) => KoryDuePeriod(
    label: json['label'] as String? ?? '',
    dueAt:
        tryParseServerTime(json['due_at'] as String? ?? '') ?? DateTime.now(),
    amount: json['amount'] as int? ?? 0,
    expectedTotal: json['expected_total'] as int? ?? 0,
    confirmedTotal: json['confirmed_total'] as int? ?? 0,
    upToDateCount: json['up_to_date_count'] as int? ?? 0,
    toConfirmCount: json['to_confirm_count'] as int? ?? 0,
    lateCount: json['late_count'] as int? ?? 0,
    late: [
      for (final m in (json['late'] as List? ?? const []))
        KoryContributorState.fromJson({
          ...(m as Map<String, dynamic>),
          'status': 'LATE',
        }),
    ],
  );
}

/// Une échéance passée : combien l'ont réglée (KOR-20 « Mois précédents »).
class KoryPastPeriod {
  const KoryPastPeriod({
    required this.label,
    required this.dueAt,
    required this.paidCount,
    required this.membersCount,
    required this.contestedCount,
  });

  final String label;
  final DateTime dueAt;
  final int paidCount;
  final int membersCount;
  final int contestedCount;

  factory KoryPastPeriod.fromJson(Map<String, dynamic> json) => KoryPastPeriod(
    label: json['label'] as String? ?? '',
    dueAt:
        tryParseServerTime(json['due_at'] as String? ?? '') ?? DateTime.now(),
    paidCount: json['paid_count'] as int? ?? 0,
    membersCount: json['members_count'] as int? ?? 0,
    contestedCount: json['contested_count'] as int? ?? 0,
  );
}

/// Une de MES échéances (KOR-21) : réglée, déclarée, contestée, en retard
/// ou à venir.
class KoryMyPeriod {
  const KoryMyPeriod({
    required this.label,
    required this.dueAt,
    required this.amount,
    required this.status,
    this.walletReference,
    this.declaredAt,
    this.wasContested = false,
  });

  final String label;
  final DateTime dueAt;
  final int amount;
  final String status;
  final String? walletReference;
  final DateTime? declaredAt;
  final bool wasContested;

  factory KoryMyPeriod.fromJson(Map<String, dynamic> json) => KoryMyPeriod(
    label: json['label'] as String? ?? '',
    dueAt:
        tryParseServerTime(json['due_at'] as String? ?? '') ?? DateTime.now(),
    amount: json['amount'] as int? ?? 0,
    status: json['status'] as String? ?? 'DUE',
    walletReference: json['wallet_reference'] as String?,
    declaredAt: tryParseServerTime(json['declared_at'] as String? ?? ''),
    wasContested: json['was_contested'] as bool? ?? false,
  );
}

class KoryScheduledDue {
  const KoryScheduledDue({
    required this.label,
    required this.dueAt,
    required this.amount,
  });

  final String label;
  final DateTime dueAt;
  final int amount;

  factory KoryScheduledDue.fromJson(Map<String, dynamic> json) =>
      KoryScheduledDue(
        label: json['label'] as String? ?? '',
        dueAt:
            tryParseServerTime(json['due_at'] as String? ?? '') ??
            DateTime.now(),
        amount: json['amount'] as int? ?? 0,
      );
}

/// KOR-10 : ce qu'on voit d'une cagnotte avant de la rejoindre.
class KoryPreview {
  const KoryPreview({
    required this.id,
    required this.kind,
    required this.title,
    required this.joinCode,
    this.description,
    this.beneficiaryName,
    this.goalAmount,
    this.amountPerMember,
    this.period,
    this.dueAt,
    this.groupName,
    this.organizerName,
    this.collectorName,
    this.collectorPhoneMasked,
    this.participantsCount = 0,
    this.amountsVisible = true,
    this.alreadyMember = false,
  });

  final int id;
  final String kind;
  final String title;
  final String joinCode;
  final String? description;
  final String? beneficiaryName;
  final int? goalAmount;
  final int? amountPerMember;
  final String? period;
  final DateTime? dueAt;
  final String? groupName;
  final String? organizerName;
  final String? collectorName;
  final String? collectorPhoneMasked;
  final int participantsCount;
  final bool amountsVisible;
  final bool alreadyMember;

  factory KoryPreview.fromJson(Map<String, dynamic> json) => KoryPreview(
    id: json['id'] as int,
    kind: json['kind'] as String? ?? 'CAGNOTTE',
    title: json['title'] as String? ?? '',
    joinCode: json['join_code'] as String? ?? '',
    description: json['description'] as String?,
    beneficiaryName: json['beneficiary_name'] as String?,
    goalAmount: json['goal_amount'] as int?,
    amountPerMember: json['amount_per_member'] as int?,
    period: json['period'] as String?,
    dueAt: tryParseServerTime(json['due_at'] as String? ?? ''),
    groupName: json['group_name'] as String?,
    organizerName: json['organizer_name'] as String?,
    collectorName: json['collector_name'] as String?,
    collectorPhoneMasked: json['collector_phone_masked'] as String?,
    participantsCount: json['participants_count'] as int? ?? 0,
    amountsVisible: json['amounts_visible'] as bool? ?? true,
    alreadyMember: json['already_member'] as bool? ?? false,
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
    this.amountHidden = false,
    this.reviewerName,
    this.reviewedAt,
  });

  /// KOR-6 : montant masqué aux autres membres ([amount] vaut alors 0).
  final bool amountHidden;

  /// Qui confirme : le collecteur, ou le bénéficiaire du tour.
  final String? reviewerName;
  final DateTime? reviewedAt;

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
    amount: json['amount'] as int? ?? 0,
    amountHidden: json['amount_hidden'] as bool? ?? false,
    reviewerName: json['reviewer_name'] as String?,
    reviewedAt: tryParseServerTime(json['reviewed_at'] as String? ?? ''),
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
