/// Le classement d'un joueur, tel que le serveur le calcule.
///
/// Toute la règle — seuils, décompte, laissez-passer — vit côté SERVEUR. Ce
/// modèle ne recalcule rien : une règle appliquée des deux côtés finit
/// toujours par diverger, et c'est alors l'écran qui ment.
class LeagueStanding {
  const LeagueStanding({
    required this.points,
    required this.bestPoints,
    required this.leagueCode,
    required this.leagueLabel,
    required this.leagueRank,
    required this.progress,
    required this.isProtected,
    required this.daysUntilDecay,
    this.nextLabel,
    this.pointsNeeded,
  });

  final int points;
  final int bestPoints;
  final String leagueCode;
  final String leagueLabel;
  final int leagueRank;

  /// Avancement vers la ligue suivante, entre 0 et 1. Vaut 1 au sommet —
  /// une barre vide y donnerait l'impression de n'avoir rien accompli.
  final double progress;

  final bool isProtected;

  /// Jours avant le prochain décompte. Affiché pour qu'on le SACHE, au lieu
  /// de découvrir la perte après coup.
  final int daysUntilDecay;

  final String? nextLabel;
  final int? pointsNeeded;

  bool get isTop => nextLabel == null;

  factory LeagueStanding.fromJson(Map<String, dynamic> json) {
    final league = (json['league'] as Map<String, dynamic>?) ?? const {};
    final next = json['next_league'] as Map<String, dynamic>?;
    return LeagueStanding(
      points: json['points'] as int? ?? 0,
      bestPoints: json['best_points'] as int? ?? 0,
      leagueCode: league['code'] as String? ?? 'BRONZE',
      leagueLabel: league['label'] as String? ?? 'Bronze',
      leagueRank: league['rank'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      isProtected: json['is_protected'] as bool? ?? false,
      daysUntilDecay: json['days_until_decay'] as int? ?? 7,
      nextLabel: next?['label'] as String?,
      pointsNeeded: next?['points_needed'] as int?,
    );
  }
}

class LeagueRanking {
  const LeagueRanking({
    required this.items,
    required this.myRank,
    required this.myPoints,
  });

  final List<LeagueEntry> items;

  /// Ma place, même hors du tableau affiché : un classement où l'on ne se
  /// voit pas ne dit rien à celui qui le consulte.
  final int myRank;
  final int myPoints;

  factory LeagueRanking.fromJson(Map<String, dynamic> json) => LeagueRanking(
    items: ((json['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LeagueEntry.fromJson)
        .toList(),
    myRank: json['my_rank'] as int? ?? 0,
    myPoints: json['my_points'] as int? ?? 0,
  );
}

class LeagueEntry {
  const LeagueEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.points,
    required this.leagueCode,
    required this.isMe,
  });

  final int rank;
  final int userId;
  final String displayName;
  final int points;
  final String leagueCode;
  final bool isMe;

  factory LeagueEntry.fromJson(Map<String, dynamic> json) => LeagueEntry(
    rank: json['rank'] as int? ?? 0,
    userId: json['user_id'] as int? ?? 0,
    displayName: json['display_name'] as String? ?? 'Joueur',
    points: json['points'] as int? ?? 0,
    leagueCode: json['league'] as String? ?? 'BRONZE',
    isMe: json['is_me'] as bool? ?? false,
  );
}
