import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Documents the exact normalization behavior DeviceContactsService relies
/// on — parsing the signed-in user's own E.164 number to infer a default
/// region, then using that region to interpret local-format device
/// contact numbers. Not testing the package itself, just pinning our
/// usage of it against representative inputs.
void main() {
  test('an already-international number parses without a region hint', () {
    final parsed = PhoneNumber.parse('+22890123456');
    expect(parsed.isoCode, IsoCode.TG);
    expect(parsed.international, '+22890123456');
  });

  test('a local-format number is completed using the caller region', () {
    final myIsoCode = PhoneNumber.parse('+22890123456').isoCode;
    final parsed = PhoneNumber.parse('90123457', callerCountry: myIsoCode);
    expect(parsed.international, '+22890123457');
  });

  test('garbage input throws rather than silently producing a bad number', () {
    expect(() => PhoneNumber.parse('not a phone number'), throwsException);
  });
}
