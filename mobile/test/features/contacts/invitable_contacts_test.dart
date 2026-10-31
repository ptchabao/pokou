import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/contacts/data/device_contacts_service.dart';
import 'package:pokou/features/contacts/presentation/contacts_controller.dart';

/// Qui proposer d'inviter ? — le croisement entre le répertoire du téléphone
/// et le carnet Pokou.
///
/// Aucune de ces fautes ne se signale à l'écran : la liste s'affiche, elle
/// est simplement fausse. Proposer d'inviter quelqu'un qui utilise déjà
/// l'application est même pire qu'une absence de liste — ça donne l'air de
/// ne pas savoir qui sont ses propres utilisateurs.
void main() {
  DeviceContactEntry entry(String name, String phone) =>
      DeviceContactEntry(name: name, phone: phone);

  const me = '+22890000000';

  test('ceux qui sont déjà sur Pokou ne sont pas proposés à l\'invitation', () {
    final result = invitableFrom(
      deviceBook: [entry('Awa', '+22891111111'), entry('Kodjo', '+22892222222')],
      phonesOnPokou: {'+22891111111'},
      myPhone: me,
    );
    expect(result.map((e) => e.name), ['Kodjo']);
  });

  test('un contact à plusieurs numéros n\'apparaît pas plusieurs fois', () {
    // Le répertoire d'un commerçant en contient beaucoup : sans
    // dédoublonnage, la liste devient illisible sans qu'on comprenne
    // pourquoi le même nom revient.
    final result = invitableFrom(
      deviceBook: [
        entry('Kodjo', '+22892222222'),
        entry('Kodjo', '+22892222222'),
        entry('Kodjo (bureau)', '+22893333333'),
      ],
      phonesOnPokou: const {},
      myPhone: me,
    );
    expect(result.length, 2);
    expect(result.map((e) => e.phone), containsAll(['+22892222222', '+22893333333']));
  });

  test('on ne se propose pas de s\'inviter soi-même', () {
    // Son propre numéro figure dans son répertoire plus souvent qu'on ne
    // croit — et se voir proposé à l'invitation est le genre de détail qui
    // décrédibilise tout l'écran.
    final result = invitableFrom(
      deviceBook: [entry('Moi', me), entry('Awa', '+22891111111')],
      phonesOnPokou: const {},
      myPhone: me,
    );
    expect(result.map((e) => e.name), ['Awa']);
  });

  test('la liste est triée par nom, insensible à la casse', () {
    final result = invitableFrom(
      deviceBook: [entry('zoé', '+1'), entry('Awa', '+2'), entry('Bruno', '+3')],
      phonesOnPokou: const {},
      myPhone: me,
    );
    expect(result.map((e) => e.name), ['Awa', 'Bruno', 'zoé']);
  });

  test('un répertoire entièrement sur Pokou donne une liste vide, pas une erreur', () {
    final result = invitableFrom(
      deviceBook: [entry('Awa', '+22891111111')],
      phonesOnPokou: {'+22891111111'},
      myPhone: me,
    );
    expect(result, isEmpty);
  });
}
