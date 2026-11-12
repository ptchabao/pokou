import '../../groups/data/group_model.dart';

/// Une collecte en cours de création, d'une étape à l'autre (KOR-6, 11,
/// 17 à 19, 23, 24, 8). Rien n'est envoyé au serveur avant la dernière
/// étape : revenir en arrière ne laisse pas de collecte à moitié créée.
class KoryDraft {
  KoryDraft({required this.kind});

  String kind; // CAGNOTTE | COTISATION | TONTINE
  String title = '';
  String? description;
  String? beneficiary;

  /// Objectif (cagnotte), montant par membre (cotisation), mise (tontine).
  int? amount;
  String period = 'MONTHLY';

  /// Clôture (cagnotte), première échéance (cotisation), premier tour
  /// (tontine).
  DateTime? dueAt;

  /// Dernière échéance d'une cotisation ; `null` : sans fin.
  DateTime? endsAt;
  bool amountsVisible = true;
  Group? group;

  /// Les membres concernés (cotisation) ou l'ordre des tours (tontine).
  List<int> memberIds = const [];
  int? deputyId;

  /// Tontine : DRAW (tirage au sort au démarrage) ou FIXED.
  String drawMode = 'DRAW';

  String nameOf(int userId) =>
      group?.members
          .where((m) => m.userId == userId)
          .firstOrNull
          ?.displayName ??
      '—';
}

/// La `steps`-ième échéance après [start] — le même calcul que le serveur
/// (services/kory/cotisation.py) : un mois sans 31 garde son dernier jour.
DateTime koryAddPeriod(DateTime start, String period, int steps) {
  switch (period) {
    case 'WEEKLY':
      return start.add(Duration(days: 7 * steps));
    case 'BIWEEKLY':
      return start.add(Duration(days: 14 * steps));
  }
  final months = steps * (period == 'QUARTERLY' ? 3 : 1);
  final index = start.month - 1 + months;
  final year = start.year + index ~/ 12;
  final month = index % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    start.day > lastDay ? lastDay : start.day,
    start.hour,
    start.minute,
  );
}
