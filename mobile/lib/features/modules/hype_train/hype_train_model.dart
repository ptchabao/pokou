/// Un objectif collectif.
class HypeTrain {
  const HypeTrain({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.promise,
    required this.goalAmount,
    required this.collectedAmount,
    required this.progress,
    required this.isUnlocked,
    required this.secondsLeft,
    required this.isLive,
    required this.isOwner,
    this.ownerName,
    this.contributors = const [],
    this.due,
  });

  final int id;
  final int ownerId;
  final String title;

  /// Ce que le créateur s'engage à débloquer. Visible AVANT de payer —
  /// l'inverse serait vendre à l'aveugle.
  final String promise;

  final int goalAmount;
  final int collectedAmount;
  final double progress;
  final bool isUnlocked;
  final int secondsLeft;
  final bool isLive;
  final bool isOwner;
  final String? ownerName;
  final List<HypeContributor> contributors;

  /// Ce qui revient au créateur. Nul pour les autres.
  final int? due;

  factory HypeTrain.fromJson(Map<String, dynamic> json) {
    final earnings = json['earnings'] as Map<String, dynamic>?;
    return HypeTrain(
      id: json['id'] as int? ?? 0,
      ownerId: json['owner_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      promise: json['promise'] as String? ?? '',
      goalAmount: json['goal_amount'] as int? ?? 0,
      collectedAmount: json['collected_amount'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      secondsLeft: json['seconds_left'] as int? ?? 0,
      isLive: json['is_live'] as bool? ?? false,
      isOwner: json['is_owner'] as bool? ?? false,
      ownerName: json['owner_name'] as String?,
      contributors: ((json['contributors'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(HypeContributor.fromJson)
          .toList(),
      due: earnings?['due'] as int?,
    );
  }
}

class HypeContributor {
  const HypeContributor({
    required this.amount,
    required this.isMine,
    this.name,
  });

  final int amount;
  final bool isMine;
  final String? name;

  factory HypeContributor.fromJson(Map<String, dynamic> json) =>
      HypeContributor(
        amount: json['amount'] as int? ?? 0,
        isMine: json['is_mine'] as bool? ?? false,
        name: json['name'] as String?,
      );
}
