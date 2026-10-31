import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:pokou/features/contacts/data/device_contacts_service.dart';

/// Les numéros tels qu'on les enregistre vraiment, rapprochés du compte
/// Pokou quel que soit le format.
void main() {
  String? tg(String raw) => normalizeDevicePhone(raw, IsoCode.TG);

  test('numéro togolais sans indicatif', () {
    expect(tg('90123456'), '+22890123456');
    expect(tg('90 12 34 56'), '+22890123456');
  });

  test('indicatif écrit sans le +', () {
    expect(tg('228 90 12 34 56'), '+22890123456');
    expect(tg('0022890123456'), '+22890123456');
  });

  test('contact étranger enregistré sans le +', () {
    expect(tg('22901 97 12 34 56'), '+2290197123456');
  });

  test('zéro de tête en trop', () {
    expect(tg('090123456'), '+22890123456');
  });

  test('format international inchangé', () {
    expect(tg('+228 90-12-34-56'), '+22890123456');
    expect(tg('+229 01 97 12 34 56'), '+2290197123456');
  });

  test('rien de plausible : écarté', () {
    expect(tg('12'), isNull);
    expect(tg('abc'), isNull);
  });
}
