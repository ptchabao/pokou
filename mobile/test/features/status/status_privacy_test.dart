import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/l10n/app_localizations.dart';
import 'package:pokou/features/status/data/status_model.dart';

void main() {
  group('StatusAudience', () {
    test('la valeur réseau est stable, indépendamment du nom Dart', () {
      expect(StatusAudience.contacts.wire, 'CONTACTS');
      expect(StatusAudience.nobody.wire, 'NOBODY');
      expect(StatusAudience.except.wire, 'EXCEPT');
      expect(StatusAudience.only.wire, 'ONLY');
    });

    test('un mode inconnu retombe sur « mes contacts »', () {
      // Un mode ajouté côté serveur ne doit pas planter le client, et le
      // repli doit être le comportement par défaut, pas le plus permissif.
      expect(StatusAudience.fromWire('QUELQUE_CHOSE'), StatusAudience.contacts);
      expect(StatusAudience.fromWire(null), StatusAudience.contacts);
    });

    test('seuls « sauf » et « uniquement » ont besoin d\'une liste', () {
      expect(StatusAudience.contacts.needsList, isFalse);
      expect(StatusAudience.nobody.needsList, isFalse);
      expect(StatusAudience.except.needsList, isTrue);
      expect(StatusAudience.only.needsList, isTrue);
    });

    test('chaque mode a un libellé et une explication, dans chaque langue', () {
      // La version forte de l'ancienne vérification : depuis que ces textes
      // viennent des traductions, une langue oubliée est le vrai risque —
      // pas un libellé vide en français.
      for (final locale in L.supportedLocales) {
        final l = lookupL(locale);
        for (final audience in StatusAudience.values) {
          expect(audience.labelOf(l), isNotEmpty,
              reason: 'libellé manquant en ${locale.languageCode}');
          expect(audience.descriptionOf(l), isNotEmpty,
              reason: 'explication manquante en ${locale.languageCode}');
        }
      }
    });
  });

  group('StatusPrivacy.fromJson', () {
    test('lit le réglage et sa liste', () {
      final parsed = StatusPrivacy.fromJson({'mode': 'EXCEPT', 'user_ids': [4, 7]});
      expect(parsed.audience, StatusAudience.except);
      expect(parsed.userIds, [4, 7]);
    });

    test('une réponse sans liste donne une liste vide, pas null', () {
      final parsed = StatusPrivacy.fromJson({'mode': 'NOBODY'});
      expect(parsed.audience, StatusAudience.nobody);
      expect(parsed.userIds, isEmpty);
    });
  });
}
