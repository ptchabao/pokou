/// Une chaîne d'échanges avec quelqu'un.
///
/// Rien n'est recalculé ici — ni le décompte des jours, ni la fenêtre de
/// rachat. Une règle appliquée des deux côtés finit toujours par diverger,
/// et c'est alors l'écran qui ment à propos de l'argent.
class Streak {
  const Streak({
    required this.peerId,
    required this.displayName,
    required this.currentDays,
    required this.bestDays,
    required this.isBroken,
    required this.brokenDays,
    required this.canRestore,
    required this.secondsLeft,
    required this.restoreAmount,
  });

  final int peerId;
  final String displayName;
  final int currentDays;
  final int bestDays;
  final bool isBroken;

  /// Ce que la chaîne valait au moment où elle s'est rompue — c'est ce
  /// nombre-là qu'on rachète, pas la valeur actuelle (qui est zéro).
  final int brokenDays;

  final bool canRestore;

  /// Secondes restantes pour sauver la chaîne. Donné par le SERVEUR, à
  /// décompter localement pour l'affichage seulement.
  final int secondsLeft;

  final int restoreAmount;

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
    peerId: json['peer_id'] as int? ?? 0,
    displayName: json['display_name'] as String? ?? 'Contact',
    currentDays: json['current_days'] as int? ?? 0,
    bestDays: json['best_days'] as int? ?? 0,
    isBroken: json['is_broken'] as bool? ?? false,
    brokenDays: json['broken_days'] as int? ?? 0,
    canRestore: json['can_restore'] as bool? ?? false,
    secondsLeft: json['seconds_left'] as int? ?? 0,
    restoreAmount: json['restore_amount'] as int? ?? 0,
  );
}
