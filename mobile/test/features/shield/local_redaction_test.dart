import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/shield/data/local_redaction.dart';

void main() {
  group('redactForShield', () {
    test('replaces amounts with [MONTANT]', () {
      expect(redactForShield('les 5000 FCFA sont prêts'), 'les [MONTANT] sont prêts');
    });

    test('replaces capitalized words with [NOM]', () {
      expect(redactForShield('Jean a confirmé'), '[NOM] a confirmé');
    });

    test('leaves lowercase words untouched', () {
      expect(redactForShield('salut, ça va ?'), 'salut, ça va ?');
    });

    test('is an approximation, not full NER — does not tag objects or places', () {
      // Contrairement à l'exemple du cahier des charges, "camion"/"Abidjan"
      // ne sont volontairement pas remplacés par [OBJET]/[LIEU] — seule une
      // vraie NER (non intégrée dans cette phase) pourrait le faire de façon fiable.
      final result = redactForShield('le camion pour Abidjan');
      expect(result, contains('camion'));
      expect(result, contains('[NOM]')); // "Abidjan" est capitalisé, tagué comme [NOM] par approximation
    });
  });
}
