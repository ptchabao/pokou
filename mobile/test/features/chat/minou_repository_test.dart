import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/chat/data/minou_repository.dart';

/// Le fil Minou mélange deux natures de lignes : des messages de conversation
/// et des alertes de moniteur. Ce sont ces deux traductions-là qui sont
/// vérifiées ici — se tromper de sens de lecture afficherait mes propres
/// messages comme ceux de Minou.
void main() {
  group('MinouThreadItem', () {
    test('« out » est ce que J\'AI écrit, « in » ce que Minou répond', () {
      final mine = MinouThreadItem.fromJson({
        'id': 'minou:1',
        'direction': 'out',
        'kind': 'message',
        'body': "J'ai vendu 3 sacs",
        'created_at': '2026-09-08T10:00:00',
      });
      final theirs = MinouThreadItem.fromJson({
        'id': 'minou:2',
        'direction': 'in',
        'kind': 'message',
        'body': "C'est noté 👍",
        'created_at': '2026-09-08T10:00:05',
      });

      expect(mine.isMine, isTrue);
      expect(theirs.isMine, isFalse);
      // Un message de conversation s'affiche tel quel, sans décoration.
      expect(mine.displayBody, "J'ai vendu 3 sacs");
    });

    test('une alerte se lit comme celle qui part par WhatsApp', () {
      final alert = MinouThreadItem.fromJson({
        'id': 'signal:7',
        'direction': 'in',
        'kind': 'alert',
        'title': 'Stock bas',
        'body': 'Le ciment passe sous le seuil.',
        'severity': 'HIGH',
        'monitor_name': 'Dépôt Agoè',
        'created_at': '2026-09-08T09:00:00',
      });

      expect(alert.isAlert, isTrue);
      // Jamais sortante : une alerte vient toujours du service vers moi.
      expect(alert.isMine, isFalse);
      // Même mise en forme que NotificationService.build_message côté API :
      // une même alerte ne doit pas se lire différemment selon le canal.
      expect(
        alert.displayBody,
        '🧠 Dépôt Agoè — Stock bas\n\nLe ciment passe sous le seuil.',
      );
    });

    test("l'alerte porte son explication, et son sujet est rendu lisible", () {
      // Le fond du reproche « la plupart des alertes ne veulent rien dire » :
      // un intitulé technique et une description vague. L'explication vient
      // du serveur, calculée sur les chiffres du signal.
      final alert = MinouThreadItem.fromJson({
        'id': 'signal:9',
        'direction': 'in',
        'kind': 'alert',
        'title': 'Alerte ventes_jour',
        'body': 'Vos ventes ont baissé.',
        'explanation':
            'Ce qui a été observé : « ventes jour » est à 43 200, '
            'contre 68 500 d\'habitude — en baisse de 37 %.\nNiveau : important.',
        'severity_label': 'important',
        'monitor_name': 'Dépôt Agoè',
        'created_at': '2026-09-08T09:00:00',
      });

      expect(alert.severityLabel, 'important');
      // Le souligné du nom de colonne disparaît de l'intitulé.
      expect(alert.displayBody, contains('Dépôt Agoè — Alerte ventes jour'));
      expect(alert.displayBody, isNot(contains('ventes_jour')));
      // La description du moteur ET l'explication, dans cet ordre.
      expect(alert.displayBody, contains('Vos ventes ont baissé.'));
      expect(alert.displayBody, contains('en baisse de 37 %'));
      expect(
        alert.displayBody.indexOf('Vos ventes'),
        lessThan(alert.displayBody.indexOf('Ce qui a été observé')),
      );
    });

    test('une alerte sans description reste lisible', () {
      final alert = MinouThreadItem.fromJson({
        'id': 'signal:8',
        'direction': 'in',
        'kind': 'alert',
        'title': 'Marge en baisse',
        'body': '',
        'monitor_name': 'Dépôt Agoè',
        'created_at': '2026-09-08T09:00:00',
      });

      expect(alert.displayBody, '🧠 Dépôt Agoè — Marge en baisse');
    });
  });

  group('MinouStatus', () {
    test(
      'le mode inconnu retombe sur la messagerie, jamais sur les alertes',
      () {
        // Prudence volontaire : afficher un fil d'alertes vide ferait croire
        // qu'un moniteur ne signale rien, alors qu'on n'a simplement pas
        // compris la réponse du serveur.
        final status = MinouStatus.fromJson({
          'mode': 'quelque_chose_de_neuf',
          'monitors': [],
        });

        expect(status.mode, MinouMode.messaging);
        expect(status.monitors, isEmpty);
        expect(status.hasMinouHistory, isFalse);
      },
    );

    test(
      'les moniteurs rattachés au numéro sont exposés avec leur intention',
      () {
        final status = MinouStatus.fromJson({
          'mode': 'alerts',
          'phone': '+22890111002',
          'has_minou_history': true,
          'monitors': [
            {
              'id': 3,
              'name': 'Dépôt Agoè',
              'intention': 'Surveiller les ventes',
            },
          ],
        });

        expect(status.mode, MinouMode.alerts);
        expect(status.phone, '+22890111002');
        expect(status.hasMinouHistory, isTrue);
        expect(status.monitors.single.name, 'Dépôt Agoè');
        expect(status.monitors.single.intention, 'Surveiller les ventes');
      },
    );
  });
}
