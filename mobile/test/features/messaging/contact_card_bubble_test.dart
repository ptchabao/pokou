import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_harness.dart';
import 'package:pokou/features/messaging/presentation/contact_card_bubble.dart';

Widget _wrap(Widget child) => localizedHarness(child);

/// `Text.rich` enveloppe le TextSpan fourni dans un TextSpan supplémentaire
/// (le style ambiant fusionné) avant de le passer à RichText — les vrais
/// runs de LinkifiedText vivent donc à une profondeur variable, jamais
/// directement dans `RichText.text.children`. On les cherche récursivement
/// plutôt que de supposer un niveau fixe.
Iterable<TextSpan> _allTextSpans(InlineSpan span) sync* {
  if (span is TextSpan) {
    yield span;
    for (final child in span.children ?? const <InlineSpan>[]) {
      yield* _allTextSpans(child);
    }
  }
}

void main() {
  group('extractFirstUrl', () {
    test('trouve un lien https dans une phrase', () {
      expect(
        extractFirstUrl('regarde ça https://exemple.com/article intéressant'),
        'https://exemple.com/article',
      );
    });

    test('normalise un lien www. sans schéma', () {
      expect(extractFirstUrl('voir www.exemple.com pour plus'), 'https://www.exemple.com');
    });

    test('renvoie null en l\'absence de lien', () {
      expect(extractFirstUrl('bonjour, comment vas-tu ?'), isNull);
    });

    test('ne retient que le PREMIER lien quand il y en a plusieurs', () {
      expect(
        extractFirstUrl('https://premier.com et https://second.com'),
        'https://premier.com',
      );
    });
  });

  group('findPhoneMatches', () {
    test('detects a plausible international number inside a sentence', () {
      final matches = findPhoneMatches('appelle-moi au +228 90 12 34 56 stp').toList();
      expect(matches, hasLength(1));
      expect(matches.single.group(0), '+228 90 12 34 56');
    });

    test('ignores sequences whose digit count is too short for a phone number', () {
      // "12-34-56" a la FORME du motif (assez de caractères avec les
      // séparateurs) mais ne compte que 6 chiffres utiles une fois les
      // tirets écartés — sous la borne basse de 7, donc écarté.
      expect(findPhoneMatches('le code de la porte est 12-34-56'), isEmpty);
    });

    test('ignores sequences longer than an E.164 number', () {
      expect(findPhoneMatches('référence 123456789012345678'), isEmpty);
    });

    test('finds multiple numbers in the same text', () {
      final matches = findPhoneMatches('joins-moi au +22890123456 ou au +22898765432').toList();
      expect(matches, hasLength(2));
    });
  });

  group('LinkifiedText', () {
    testWidgets('preserves the full text and renders without a phone number', (tester) async {
      await tester.pumpWidget(_wrap(const LinkifiedText(text: 'bonne journée à tous', style: TextStyle())));
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      expect(richText.text.toPlainText(), 'bonne journée à tous');
    });

    testWidgets('preserves the full text when it contains a tappable phone number', (tester) async {
      await tester.pumpWidget(_wrap(const LinkifiedText(
        text: 'contacte le fournisseur au +22890123456 avant midi',
        style: TextStyle(),
      )));
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      expect(richText.text.toPlainText(), 'contacte le fournisseur au +22890123456 avant midi');
    });

    testWidgets('*gras* devient un span en gras, sans les astérisques', (tester) async {
      await tester.pumpWidget(_wrap(const LinkifiedText(text: 'ceci est *important* pour tous', style: TextStyle())));
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final spans = _allTextSpans(richText.text).toList();
      expect(richText.text.toPlainText(), 'ceci est important pour tous');
      final bold = spans.firstWhere((s) => s.text == 'important');
      expect(bold.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('_italique_ devient un span en italique', (tester) async {
      await tester.pumpWidget(_wrap(const LinkifiedText(text: 'rendez-vous _demain_ matin', style: TextStyle())));
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final spans = _allTextSpans(richText.text).toList();
      expect(richText.text.toPlainText(), 'rendez-vous demain matin');
      final italic = spans.firstWhere((s) => s.text == 'demain');
      expect(italic.style!.fontStyle, FontStyle.italic);
    });

    testWidgets('~barré~ devient un span barré', (tester) async {
      await tester.pumpWidget(_wrap(const LinkifiedText(text: 'le prix est ~5000~ 4000 FCFA', style: TextStyle())));
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final spans = _allTextSpans(richText.text).toList();
      expect(richText.text.toPlainText(), 'le prix est 5000 4000 FCFA');
      final struck = spans.firstWhere((s) => s.text == '5000');
      expect(struck.style!.decoration, TextDecoration.lineThrough);
    });

    testWidgets('un numéro cité en gras reste tappable', (tester) async {
      await tester.pumpWidget(_wrap(const LinkifiedText(text: 'appelez *+22890123456* vite', style: TextStyle())));
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final spans = _allTextSpans(richText.text).toList();
      expect(richText.text.toPlainText(), 'appelez +22890123456 vite');
      final phone = spans.firstWhere((s) => s.text == '+22890123456');
      expect(phone.recognizer, isNotNull);
      // La mise en forme (gras) est conservée EN PLUS du soulignement du lien.
      expect(phone.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('des astérisques de multiplication espacées ne sont pas prises pour du gras', (tester) async {
      // Le délimiteur doit COLLER à son contenu (`* 3 = 6 *` a un espace
      // juste après l'ouvrant) — sans cette exigence, une expression comme
      // celle-ci deviendrait un span en gras à tort.
      await tester.pumpWidget(_wrap(const LinkifiedText(text: '2 * 3 = 6 * 7 pour vérifier', style: TextStyle())));
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final spans = _allTextSpans(richText.text).toList();
      expect(richText.text.toPlainText(), '2 * 3 = 6 * 7 pour vérifier');
      expect(spans.any((s) => s.style?.fontWeight == FontWeight.w700), isFalse);
    });
  });

  group('ContactCardBubble', () {
    testWidgets('affiche le nom et le numéro de chaque contact partagé', (tester) async {
      await tester.pumpWidget(_wrap(const ContactCardBubble(
        payload: {
          'contacts': [
            {'display_name': 'Fatou', 'phone': '+22890123456'},
            {'display_name': 'Koffi', 'phone': '+22898765432'},
          ],
        },
      )));

      expect(find.text('Fatou'), findsOneWidget);
      expect(find.text('+22890123456'), findsOneWidget);
      expect(find.text('Koffi'), findsOneWidget);
      expect(find.text('+22898765432'), findsOneWidget);
    });
  });
}
