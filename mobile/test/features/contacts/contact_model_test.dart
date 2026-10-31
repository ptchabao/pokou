import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/contacts/data/contact_model.dart';

void main() {
  test('a contact matched to a registered Pokou user carries contact_user_id', () {
    final contact = PokouContact.fromJson({
      'id': 1,
      'phone': '+22890000000',
      'display_name': 'Bob',
      'contact_user_id': 42,
      'about': 'Toujours en ligne',
      'is_registered': true,
    });

    expect(contact.isRegistered, isTrue);
    expect(contact.contactUserId, 42);
  });

  test('an unregistered phone number has no contact_user_id', () {
    final contact = PokouContact.fromJson({
      'id': 2,
      'phone': '+22899999999',
      'display_name': 'Not on Pokou',
      'contact_user_id': null,
      'about': null,
      'is_registered': false,
    });

    expect(contact.isRegistered, isFalse);
    expect(contact.contactUserId, isNull);
  });
}
