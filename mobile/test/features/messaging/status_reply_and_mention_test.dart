import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/groups/presentation/mention_picker.dart';
import 'package:pokou/features/messaging/presentation/status_reply.dart';
import 'package:pokou/features/messaging/presentation/unknown_sender_card.dart';
import 'package:pokou/l10n/app_localizations_fr.dart';

void main() {
  final l = LFr();

  group('réponse à un statut', () {
    test('la citation et la réponse font l’aller-retour', () {
      final sent = encodeStatusReply(
        caption: 'Vue sur le mont\nAgou',
        text: 'Superbe vue !',
      );
      final decoded = decodeStatusReply(sent, l);
      expect(decoded?.caption, 'Vue sur le mont Agou');
      expect(decoded?.text, 'Superbe vue !');
    });

    test('l’ancien format reste reconnu, un message ordinaire non', () {
      expect(
        decodeStatusReply('${l.statusReplyQuote}\nCoucou', l)?.text,
        'Coucou',
      );
      expect(decodeStatusReply('↩ pas une réponse\nà un statut', l), isNull);
      expect(decodeStatusReply('Bonjour', l), isNull);
    });
  });

  group('mentions', () {
    TextEditingValue at(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    test('le mot en cours après @ ouvre le sélecteur', () {
      expect(mentionQueryAt(at('Oui, je m’en occupe @Ka')), 'Ka');
      expect(mentionQueryAt(at('@')), '');
      expect(mentionQueryAt(at('mail@exemple.com')), isNull);
      expect(mentionQueryAt(at('fini @Kafui ')), isNull);
    });

    test('choisir remplace le début tapé par le nom', () {
      final value = insertMention(at('Merci @Ka'), 'Kafui K.');
      expect(value.text, 'Merci @Kafui K. ');
      expect(value.selection.baseOffset, value.text.length);
    });
  });

  test('une demande de code secret est repérée sur le téléphone', () {
    expect(
      asksForSecretCode('Envoyez votre code secret pour le réactiver.'),
      isTrue,
    );
    expect(asksForSecretCode('Donne-moi le code PIN'), isTrue);
    expect(asksForSecretCode('On se voit samedi ?'), isFalse);
  });
}
