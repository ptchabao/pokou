import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/messaging/presentation/day_separator.dart';
import 'package:pokou/l10n/app_localizations_fr.dart';

void main() {
  // Les libellés viennent des traductions depuis que « lundi » n'est plus
  // écrit en dur : on prend le français, la langue de ces assertions.
  final l = LFr();
  // Référence fixe : un test qui dépend de « maintenant » réel changerait de
  // résultat selon l'heure à laquelle la suite tourne.
  final now = DateTime(2026, 9, 7, 14, 30); // lundi 7 septembre 2026

  group('dayLabel', () {
    test("aujourd'hui", () {
      expect(dayLabel(l, DateTime(2026, 9, 7, 8, 0), now: now), "Aujourd'hui");
      // Encore aujourd'hui juste après minuit — c'est le JOUR qui compte,
      // pas l'écart en heures.
      expect(dayLabel(l, DateTime(2026, 9, 7, 0, 5), now: now), "Aujourd'hui");
    });

    test('hier', () {
      expect(dayLabel(l, DateTime(2026, 9, 6, 23, 55), now: now), 'Hier');
    });

    test('dans la semaine écoulée : le nom du jour', () {
      expect(dayLabel(l, DateTime(2026, 9, 5), now: now), 'samedi');
      expect(dayLabel(l, DateTime(2026, 9, 2), now: now), 'mercredi');
    });

    test('au-delà d\'une semaine : la date, car « mardi » redevient ambigu', () {
      expect(dayLabel(l, DateTime(2026, 8, 28), now: now), '28/8/2026');
      expect(dayLabel(l, DateTime(2025, 12, 24), now: now), '24/12/2025');
    });
  });

  group('isDifferentDay', () {
    test('deux instants du même jour', () {
      expect(
        isDifferentDay(DateTime(2026, 9, 7, 1, 0), DateTime(2026, 9, 7, 23, 0)),
        isFalse,
      );
    });

    test('minuit sépare deux journées même à quelques minutes d\'écart', () {
      expect(
        isDifferentDay(DateTime(2026, 9, 6, 23, 58), DateTime(2026, 9, 7, 0, 2)),
        isTrue,
      );
    });

    test('même jour et mois, année différente', () {
      expect(
        isDifferentDay(DateTime(2025, 9, 7), DateTime(2026, 9, 7)),
        isTrue,
      );
    });
  });
}
