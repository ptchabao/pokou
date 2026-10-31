import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pokou/core/country/country_config.dart';
import 'package:pokou/features/kory/data/kory_model.dart';
import 'package:pokou/features/kory/presentation/kory_controller.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('une cagnotte se lit sans solde, avec un total confirmé', () {
    final pot = KoryPot.fromJson({
      'id': 1,
      'kind': 'CAGNOTTE',
      'title': "Mariage d'Afi",
      'status': 'OPEN',
      'goal_amount': 100000,
      'confirmed_total': 150000,
      'my_confirmed_total': 5000,
      'is_organizer': true,
      'is_collector': true,
      'join_code': 'ABCD2345',
      'entries': [
        {
          'id': 3,
          'contributor_id': 9,
          'amount': 5000,
          'status': 'DECLARED',
          'declared_at': '2026-10-31T08:00:00',
          'is_mine': false,
        },
      ],
    });
    // Une cagnotte peut dépasser son objectif : la barre s'arrête à 100 %.
    expect(pot.progress, 1);
    expect(pot.entries.single.isPending, isTrue);
  });

  test('montants au format français, espace fine insécable', () {
    expect(formatFcfa(25000), '25 000 FCFA');
  });

  test('hors ligne, les modules se déduisent de l\'indicatif', () {
    expect(CountryConfig.guessFromPhone('+22890112233').has('kory'), isTrue);
    expect(CountryConfig.guessFromPhone('+2250700112233').has('kory'), isFalse);
    expect(CountryConfig.guessFromPhone(null).modules, {'discussions'});
  });
}
