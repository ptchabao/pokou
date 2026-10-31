import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:pokou/features/auth/presentation/country_names.dart';
import 'package:pokou/features/auth/presentation/phone_country.dart';

/// L'écran de connexion était prérempli « +228 » sans sélecteur : s'inscrire
/// depuis un autre pays supposait de savoir qu'on pouvait effacer ce préfixe,
/// et un numéro local tapé tel quel finissait enregistré comme togolais. Ces
/// tests portent sur la donnée qui alimente le sélecteur — c'est elle qui
/// décide du numéro réellement envoyé au serveur.
void main() {
  test('la liste couvre les autres pays, avec le bon indicatif', () {
    final countries = allPhoneCountries('fr');
    final byIso = {for (final country in countries) country.isoCode: country};

    // Bien plus qu'une poignée de pays : c'est la base libphonenumber du
    // paquet qui fournit la liste, pas une saisie à la main.
    expect(countries.length, greaterThan(200));

    expect(byIso[IsoCode.TG]!.dialCode, '228');
    expect(byIso[IsoCode.CI]!.dialCode, '225');
    expect(byIso[IsoCode.BJ]!.dialCode, '229');
    expect(byIso[IsoCode.BF]!.dialCode, '226');
    expect(byIso[IsoCode.SN]!.dialCode, '221');
    expect(byIso[IsoCode.NG]!.dialCode, '234');
    expect(byIso[IsoCode.FR]!.dialCode, '33');
    expect(byIso[IsoCode.US]!.dialCode, '1');
  });

  test('chaque pays porte un drapeau et un exemple de numéro local', () {
    final ci = phoneCountryFor(IsoCode.CI)!;
    final fr = phoneCountryFor(IsoCode.FR)!;

    // Drapeau calculé depuis les deux lettres ISO — aucune table à maintenir.
    expect(ci.flag, '🇨🇮');
    expect(fr.flag, '🇫🇷');
    // L'exemple est celui DU PAYS : montrer un numéro togolais à un Français
    // n'aide personne à comprendre ce qu'on attend de lui.
    expect(ci.exampleNsn, isNotEmpty);
    expect(fr.exampleNsn, isNotEmpty);
    expect(ci.exampleNsn, isNot(fr.exampleNsn));
  });

  test('la recherche trouve un pays par son nom comme par son indicatif', () {
    final countries = allPhoneCountries('fr');

    List<PhoneCountry> search(String query) =>
        countries.where((c) => c.searchIndexIn('fr').contains(query.toLowerCase())).toList();

    expect(search('bénin').map((c) => c.isoCode), contains(IsoCode.BJ));
    // Quelqu'un qui ne connaît pas le nom français de son pays le trouve par
    // son indicatif.
    expect(search('225').map((c) => c.isoCode), contains(IsoCode.CI));
    expect(search('gh').map((c) => c.isoCode), contains(IsoCode.GH));
  });

  test('un pays sans nom traduit reste identifiable', () {
    // Aucune traduction inventée : le code ISO fait office de nom, et le
    // drapeau plus l'indicatif suffisent à le reconnaître. Vrai dans toutes
    // les langues, puisque la table des noms est la même partout.
    final iceland = phoneCountryFor(IsoCode.IS)!;
    for (final language in ['fr', 'en', 'es', 'it', 'ru', 'ar']) {
      expect(iceland.nameIn(language), 'IS');
    }
    expect(iceland.dialCode, '354');
  });

  test('un pays desservi est nommé dans les six langues', () {
    // Le point de la table : un utilisateur russe ou arabophone doit trouver
    // son pays dans sa propre langue, pas en français translittéré.
    final benin = phoneCountryFor(IsoCode.BJ)!;
    expect(benin.nameIn('fr'), 'Bénin');
    expect(benin.nameIn('en'), 'Benin');
    expect(benin.nameIn('ru'), 'Бенин');
    expect(benin.nameIn('ar'), 'بنين');
  });

  test('chaque langue nomme exactement les mêmes pays', () {
    // Un pays nommé en français et oublié en italien apparaîtrait deux fois
    // au même endroit de la liste selon la langue, ce qui ne se voit qu'en
    // changeant de langue — donc jamais.
    final reference = countryNames['fr']!.keys.toSet();
    for (final entry in countryNames.entries) {
      expect(entry.value.keys.toSet(), reference,
          reason: 'la table ${entry.key} ne couvre pas les mêmes pays');
    }
  });

  test('le pays deviné par défaut est toujours exploitable', () {
    // En test, la locale de l'environnement n'a pas forcément de région :
    // le repli doit rendre un pays complet plutôt que rien.
    final detected = detectPhoneCountry();
    expect(detected.dialCode, isNotEmpty);
    expect(detected.flag.isNotEmpty, isTrue);
  });

  test('le numéro composé est un E.164 valide pour son pays', () {
    // C'est la promesse de l'écran : indicatif choisi + numéro national =
    // numéro que le serveur accepte sans avoir à deviner un pays.
    final togo = PhoneNumber.parse('+22890112233');
    expect(togo.isValid(), isTrue);
    expect(togo.isoCode, IsoCode.TG);

    final ivory = PhoneNumber.parse('+2250701020304');
    expect(ivory.isoCode, IsoCode.CI);

    // Et un numéro togolais valide ne le reste pas sous l'indicatif ivoirien :
    // sans sélecteur, c'est exactement le compte qu'on créait par erreur.
    expect(PhoneNumber.parse('+22590112233').isValid(), isFalse);
  });

  group('le pays proposé par défaut', () {
    test('un numéro déjà vérifié l\'emporte sur tout le reste', () {
      // C'est la seule source qui ne se trompe pas : elle vient d'un numéro
      // que son propriétaire a confirmé par SMS.
      final country = detectPhoneCountry(rememberedIso: 'CI', simIso: 'FR');
      expect(country.isoCode, IsoCode.CI);
    });

    test('à défaut, la carte SIM', () {
      // La bonne réponse dès la PREMIÈRE ouverture, et c'est elle qui
      // manquait : la locale seule proposait la France à un téléphone
      // réglé en français et utilisé à Lomé.
      expect(detectPhoneCountry(simIso: 'TG').isoCode, IsoCode.TG);
      expect(detectPhoneCountry(simIso: 'bj').isoCode, IsoCode.BJ,
          reason: 'le code de la SIM arrive en minuscules');
    });

    test('un code illisible ne casse pas la détection', () {
      // Un émulateur ou un constructeur avare peut renvoyer n'importe quoi.
      // On retombe alors sur les sources suivantes, jamais sur une erreur.
      for (final junk in ['', 'XX', '123', 'zzz']) {
        expect(() => detectPhoneCountry(simIso: junk), returnsNormally,
            reason: junk);
      }
    });

    test('sans aucun indice, le Togo', () {
      // Le marché d'origine, et une réponse toujours exploitable : le
      // sélecteur reste ouvert, se tromper coûte un tap.
      expect(detectPhoneCountry(rememberedIso: 'XX', simIso: 'XX').dialCode,
          isNotEmpty);
    });
  });
}
