import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/stickers/presentation/trailing_emoji.dart';

void main() {
  group('trailingEmoji', () {
    test('rend l\'emoji quand le texte se termine par un emoji', () {
      expect(trailingEmoji('bravo 👏'), '👏');
    });

    test('ne rend rien pour du texte ordinaire', () {
      expect(trailingEmoji('bonjour'), isNull);
      expect(trailingEmoji(''), isNull);
    });

    test('ne se déclenche que sur la FIN', () {
      // Un 😂 écrit trois mots plus tôt ne doit plus rien proposer : la
      // suggestion répond à ce qu'on vient de taper.
      expect(trailingEmoji('😂 puis autre chose'), isNull);
    });

    test('un emoji à teint de peau reste ENTIER', () {
      // 👍🏿 occupe plusieurs unités de code. Couper au dernier caractère
      // Dart rendrait la moitié d'un modificateur, qui ne correspond à
      // aucun emoji.
      expect(trailingEmoji('super 👍🏿'), '👍🏿');
    });

    test('une séquence composée reste entière', () {
      // Famille : plusieurs emojis liés par des jointeurs de largeur nulle.
      const famille = '👨‍👩‍👧';
      expect(trailingEmoji('voici $famille'), famille);
    });

    test('les symboles anciens comptent aussi', () {
      // ❤ et ✅ sont antérieurs au bloc Emoji, et parmi les plus utilisés.
      expect(trailingEmoji('oui ✅'), '✅');
      expect(trailingEmoji('je t\'aime ❤'), '❤');
    });

    test('un chiffre n\'est pas un emoji', () {
      // 1 est la base de 1️⃣ : sans garde, tout nombre déclencherait une
      // recherche de stickers à chaque frappe.
      expect(trailingEmoji('rendez-vous à 9'), isNull);
    });
  });
}
