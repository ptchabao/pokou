/// Une question payée, vue par celui qui l'a posée ou par celui qui la reçoit.
///
/// `askerName` est nul quand on est le DESTINATAIRE, et ce n'est pas une
/// donnée manquante : l'anonymat de l'acheteur est ce qui rend la question
/// posable. Le modèle ne cherche donc jamais à le combler.
class TruthQuestion {
  const TruthQuestion({
    required this.id,
    required this.question,
    required this.amount,
    required this.status,
    required this.isMine,
    this.askerName,
    this.targetName,
    this.answer,
  });

  final int id;
  final String question;
  final int amount;

  /// `PENDING`, `ANSWERED` ou `DECLINED`.
  final String status;

  final bool isMine;
  final String? askerName;
  final String? targetName;
  final String? answer;

  bool get isAnswered => status == 'ANSWERED';
  bool get isDeclined => status == 'DECLINED';

  factory TruthQuestion.fromJson(Map<String, dynamic> json) => TruthQuestion(
    id: json['id'] as int? ?? 0,
    question: json['question'] as String? ?? '',
    amount: json['amount'] as int? ?? 0,
    status: json['status'] as String? ?? 'PENDING',
    isMine: json['is_mine'] as bool? ?? false,
    askerName: json['asker_name'] as String?,
    targetName: json['target_name'] as String?,
    answer: json['answer'] as String?,
  );
}
