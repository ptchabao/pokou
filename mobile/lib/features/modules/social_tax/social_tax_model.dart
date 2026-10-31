/// Une cagnotte de cérémonie.
class CeremonyFund {
  const CeremonyFund({
    required this.id,
    required this.title,
    required this.kind,
    required this.collectedAmount,
    required this.isClosed,
    required this.isOrganizer,
    this.description,
    this.goalAmount,
    this.organizerName,
    this.dueToOrganizer,
    this.contributors = const [],
    this.contributorCount = 0,
  });

  final int id;
  final String title;

  /// `MARIAGE`, `BAPTEME`, `DEUIL` ou `AUTRE`.
  final String kind;

  final int collectedAmount;
  final bool isClosed;
  final bool isOrganizer;
  final String? description;

  /// Objectif INDICATIF : une cagnotte n'a jamais refusé une contribution
  /// parce que l'objectif était atteint, et l'écran ne doit pas le suggérer.
  final int? goalAmount;

  final String? organizerName;

  /// Ce qui revient à l'organisateur, commission déduite. Nul pour les
  /// autres : ce chiffre ne regarde que lui.
  final int? dueToOrganizer;

  final List<Contribution> contributors;
  final int contributorCount;

  double get progress {
    final goal = goalAmount;
    if (goal == null || goal <= 0) return 0;
    return (collectedAmount / goal).clamp(0, 1).toDouble();
  }

  factory CeremonyFund.fromJson(Map<String, dynamic> json) {
    final payout = json['payout'] as Map<String, dynamic>?;
    return CeremonyFund(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      kind: json['kind'] as String? ?? 'AUTRE',
      collectedAmount: json['collected_amount'] as int? ?? 0,
      isClosed: json['is_closed'] as bool? ?? false,
      isOrganizer: json['is_organizer'] as bool? ?? false,
      description: json['description'] as String?,
      goalAmount: json['goal_amount'] as int?,
      organizerName: json['organizer_name'] as String?,
      dueToOrganizer: payout?['due_to_organizer'] as int?,
      contributors: ((json['contributors'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Contribution.fromJson)
          .toList(),
      contributorCount: json['contributor_count'] as int? ?? 0,
    );
  }
}

/// Une participation. `name` est nul quand la personne a donné anonymement :
/// c'est le NOM qui est masqué, jamais le montant — sinon le total ne
/// prouverait plus rien à l'organisateur.
class Contribution {
  const Contribution({
    required this.amount,
    required this.isAnonymous,
    required this.isMine,
    this.name,
    this.message,
  });

  final int amount;
  final bool isAnonymous;
  final bool isMine;
  final String? name;
  final String? message;

  factory Contribution.fromJson(Map<String, dynamic> json) => Contribution(
    amount: json['amount'] as int? ?? 0,
    isAnonymous: json['is_anonymous'] as bool? ?? false,
    isMine: json['is_mine'] as bool? ?? false,
    name: json['name'] as String?,
    message: json['message'] as String?,
  );
}
