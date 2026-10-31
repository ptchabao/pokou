import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/notifications/active_conversation.dart';
import 'package:pokou/core/notifications/notification_policy.dart';
import 'package:pokou/core/settings/app_settings.dart';

/// La décision de PRÉSENTATION — ce que le serveur ne peut pas trancher.
///
/// Il sait qu'une socket est ouverte ; il ne sait pas ce que l'écran
/// affiche, ni ce que l'utilisateur a coché dans ses réglages. Ces deux
/// informations ne vivent que sur l'appareil, et ce sont elles qui décident
/// de la règle la plus visible d'une messagerie.
void main() {
  const settings = AppSettings();

  NotificationPresentation decide({
    String? type = 'message',
    NotificationPriority priority = NotificationPriority.normal,
    bool muted = false,
    int? contactUserId = 8,
    int? groupId,
    ActiveConversation? active,
    AppSettings withSettings = settings,
  }) {
    return decidePresentation(
      type: type,
      priority: priority,
      muted: muted,
      contactUserId: contactUserId,
      groupId: groupId,
      active: active,
      settings: withSettings,
    );
  }

  group('la conversation ouverte', () {
    test('un message de la conversation affichée ne notifie pas', () {
      // Se notifier soi-même pendant qu'on lit est le défaut le plus visible
      // qu'une messagerie puisse avoir.
      expect(
        decide(active: const ActiveConversation.direct(8)),
        NotificationPresentation.suppressed,
      );
    });

    test('un message d\'une AUTRE conversation notifie normalement', () {
      expect(
        decide(active: const ActiveConversation.direct(99)),
        NotificationPresentation.standard,
      );
    });

    test('le groupe affiché ne notifie pas, un autre groupe si', () {
      expect(
        decide(
          type: 'group_message',
          contactUserId: null,
          groupId: 3,
          active: const ActiveConversation.group(3),
        ),
        NotificationPresentation.suppressed,
      );
      expect(
        decide(
          type: 'group_message',
          contactUserId: null,
          groupId: 4,
          active: const ActiveConversation.group(3),
        ),
        NotificationPresentation.standard,
      );
    });

    test('un groupe ouvert ne fait pas taire un tête-à-tête', () {
      // Les deux espaces d'identifiants sont distincts : le groupe 8 et le
      // contact 8 n'ont rien à voir. Les confondre ferait disparaître des
      // notifications au hasard des identifiants.
      expect(
        decide(contactUserId: 8, active: const ActiveConversation.group(8)),
        NotificationPresentation.standard,
      );
    });
  });

  group('un appel', () {
    test('prend l\'écran même si la conversation est ouverte', () {
      // Un appel manqué ne se rattrape pas. Il passe avant la règle de la
      // conversation affichée, contrairement à tout le reste.
      expect(
        decide(type: 'call', active: const ActiveConversation.direct(8)),
        NotificationPresentation.fullScreen,
      );
    });

    test('prend l\'écran même en sourdine', () {
      expect(
        decide(type: 'call', muted: true),
        NotificationPresentation.fullScreen,
      );
    });

    test('se tait si l\'utilisateur a coupé les appels', () {
      expect(
        decide(
          type: 'call',
          withSettings: const AppSettings(callNotifications: false),
        ),
        NotificationPresentation.suppressed,
      );
    });
  });

  group('la sourdine et la priorité', () {
    test('une conversation en sourdine notifie sans bruit', () {
      expect(decide(muted: true), NotificationPresentation.silent);
    });

    test('la sourdine l\'emporte sur une priorité haute', () {
      // Le serveur envoie déjà une mention en sourdine avec la priorité
      // abaissée, mais la règle est répétée ici : le silence demandé par
      // l'utilisateur ne doit dépendre d'aucune valeur venue du réseau.
      expect(
        decide(muted: true, priority: NotificationPriority.high),
        NotificationPresentation.silent,
      );
    });

    test('une mention s\'impose en bandeau', () {
      expect(
        decide(type: 'group_mention', priority: NotificationPriority.high),
        NotificationPresentation.heads_up,
      );
    });

    test('une réaction reste discrète', () {
      expect(
        decide(priority: NotificationPriority.low),
        NotificationPresentation.silent,
      );
    });
  });

  group('les réglages de l\'utilisateur', () {
    test('couper les messages tait les tête-à-tête', () {
      expect(
        decide(withSettings: const AppSettings(messageNotifications: false)),
        NotificationPresentation.suppressed,
      );
    });

    test('couper les groupes tait aussi les mentions', () {
      for (final type in ['group_message', 'group_mention']) {
        expect(
          decide(
            type: type,
            contactUserId: null,
            groupId: 3,
            withSettings: const AppSettings(groupNotifications: false),
          ),
          NotificationPresentation.suppressed,
          reason: type,
        );
      }
    });

    test('couper les groupes ne tait pas les tête-à-tête', () {
      expect(
        decide(withSettings: const AppSettings(groupNotifications: false)),
        NotificationPresentation.standard,
      );
    });
  });

  group('la priorité venue du serveur', () {
    test('se lit, et retombe sur « normale » pour une valeur inconnue', () {
      expect(parsePriority('urgent'), NotificationPriority.urgent);
      expect(parsePriority('high'), NotificationPriority.high);
      expect(parsePriority('low'), NotificationPriority.low);
      expect(parsePriority('normal'), NotificationPriority.normal);
      // Une version du serveur plus récente que l'application ne doit pas
      // faire disparaître la notification.
      expect(parsePriority('cataclysmique'), NotificationPriority.normal);
      expect(parsePriority(null), NotificationPriority.normal);
    });
  });

  group('le regroupement', () {
    test('une conversation garde le même identifiant', () {
      // C'est tout l'intérêt : trois messages de la même personne remplacent
      // la même notification au lieu d'en empiler trois.
      expect(
        conversationNotificationId(contactUserId: 8),
        conversationNotificationId(contactUserId: 8),
      );
    });

    test('deux conversations ne partagent pas le leur', () {
      expect(
        conversationNotificationId(contactUserId: 8),
        isNot(conversationNotificationId(contactUserId: 9)),
      );
      // Le contact 8 et le groupe 8 sont deux conversations différentes :
      // les confondre ferait écraser l'une par l'autre.
      expect(
        conversationNotificationId(contactUserId: 8),
        isNot(conversationNotificationId(groupId: 8)),
      );
    });

    test('l\'identifiant tient dans un entier positif 32 bits', () {
      // Android refuse les autres. Un hashCode Dart, lui, peut être négatif.
      for (final id in [1, 42, 999999, 2147483647]) {
        final value = conversationNotificationId(contactUserId: id);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThanOrEqualTo(0x7fffffff));
      }
    });
  });
}
