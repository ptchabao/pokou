import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

/// « Il y a 12 minutes », « Il y a 1 heure », « Hier, 21:40 » — l'âge d'un
/// statut, tel que la liste et la visionneuse l'écrivent. Un statut vit
/// 24 h : au-delà d'hier, il n'existe plus.
String statusAgo(L l, DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final elapsed = reference.difference(local);
  if (elapsed.inMinutes < 1) return l.statusJustNow;
  if (elapsed.inMinutes < 60) return l.statusMinutesAgo(elapsed.inMinutes);
  final today = DateTime(reference.year, reference.month, reference.day);
  if (local.isBefore(today)) {
    return l.statusYesterdayAt(DateFormat.Hm().format(local));
  }
  return l.statusHoursAgo(elapsed.inHours);
}
