import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Libellé de jour façon WhatsApp : « Aujourd'hui », « Hier », puis le nom du
/// jour dans la semaine écoulée, et une date pleine au-delà.
///
/// Motifs numériques uniquement pour la date pleine : l'app ne charge pas les
/// données de locale (pas d'`initializeDateFormatting`), donc un motif à mois
/// nommé lèverait une LocaleDataException à l'exécution. Les noms de jours
/// viennent donc des traductions de l'app, et non d'`intl`.
List<String> _weekdays(L l) => [
  l.weekdayMonday,
  l.weekdayTuesday,
  l.weekdayWednesday,
  l.weekdayThursday,
  l.weekdayFriday,
  l.weekdaySaturday,
  l.weekdaySunday,
];

String dayLabel(L l, DateTime instant, {DateTime? now}) {
  final local = instant.toLocal();
  final today = now?.toLocal() ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final reference = DateTime(today.year, today.month, today.day);
  final difference = reference.difference(day).inDays;

  if (difference == 0) return l.dayToday;
  if (difference == 1) return l.dayYesterday;
  // Au-delà d'une semaine, le nom du jour redevient ambigu (« mardi », mais
  // lequel ?) — on passe donc à la date.
  if (difference > 1 && difference < 7) return _weekdays(l)[local.weekday - 1];
  return DateFormat('d/M/y').format(local);
}

/// Vrai si ces deux instants ne tombent pas le même jour — sert à décider où
/// insérer un séparateur dans un fil de messages.
bool isDifferentDay(DateTime first, DateTime second) {
  final a = first.toLocal();
  final b = second.toLocal();
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

/// Pastille de date insérée dans le fil, entre deux journées de messages.
class DaySeparator extends StatelessWidget {
  const DaySeparator({super.key, required this.instant});

  final DateTime instant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            // PILULE, et non un rectangle à coins doux : le système réserve
            // l'arrondi complet aux éléments qui ne sont pas des surfaces —
            // puces, pastilles, séparateurs. Une date n'est pas une carte.
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            // EN CAPITALES, avec de l'interlettrage : la date n'est pas du
            // contenu, c'est un repère. La mettre en capitales espacées la
            // fait lire comme une étiquette et cesser de concurrencer les
            // messages autour.
            dayLabel(L.of(context), instant).toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// En tête du fil pendant que la page précédente arrive : remonter dans
/// l'historique doit se voir, sinon le geste semble ne rien faire.
class OlderMessagesLoader extends StatelessWidget {
  const OlderMessagesLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
