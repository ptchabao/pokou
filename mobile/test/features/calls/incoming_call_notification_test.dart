import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/push/push_service.dart';

import 'dart:io';

/// Deux défauts constatés sur appareil réel le 23/09/2026, application
/// complètement fermée : DEUX notifications pour un seul appel, et répondre
/// ouvrait Pokou sur l'écran d'accueil au lieu de l'appel.
void main() {
  group('notification d\'appel en arrière-plan', () {
    test('Android ne double pas la notification native', () {
      // La couche native (PokouFirebaseMessagingService → CallManager →
      // RingtoneService) a déjà sonné et affiché SA notification avant même
      // que l'isolate Dart ne se réveille. Le laisser en poser une seconde
      // donnait deux appels à l'écran pour un seul appelant.
      expect(
        shouldBuildCallNotificationInBackground(TargetPlatform.android),
        isFalse,
      );
    });

    test('iOS garde le repli Flutter', () {
      // Il n'y a pas encore de couche native sur iOS : y couper ce chemin
      // supprimerait les appels entrants au lieu d'un doublon.
      expect(
        shouldBuildCallNotificationInBackground(TargetPlatform.iOS),
        isTrue,
      );
    });

    test('l\'identifiant de notification est CONSTANT', () {
      // Il valait `message.hashCode` : un identifiant différent par push,
      // donc une notification EMPILÉE par push au lieu d'une qui remplace.
      // Un appareil ayant laissé d'anciens jetons FCM derrière lui en
      // recevait autant de copies visibles.
      expect(kIncomingCallNotificationId, isA<int>());

      // Le CODE, pas les commentaires — qui expliquent justement pourquoi
      // `message.hashCode` a été retiré, et feraient échouer une recherche
      // naïve. Ce test a d'ailleurs trouvé un SECOND site qu'on avait
      // manqué : le chemin premier plan portait le même défaut.
      final code = File('lib/core/push/push_service.dart')
          .readAsLinesSync()
          .where((ligne) => !ligne.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code.contains('message.hashCode'),
        isFalse,
        reason:
            'aucune notification d\'appel ne doit être identifiée par '
            'le hash du message — ni en arrière-plan, ni au premier plan',
      );
    });
  });

  group('le pont natif est BRANCHÉ', () {
    test('main.dart observe nativeCallGateProvider', () {
      // LE défaut : `NativeCallBridge` était écrit, testé, complet — et
      // aucun fichier de l'application ne l'appelait. Ça ne se voit ni à la
      // compilation, ni à l'analyse, ni dans les tests du pont lui-même,
      // qui passaient tous. Seul un appel perdu sur un vrai téléphone l'a
      // révélé.
      final main = File('lib/main.dart').readAsStringSync();

      expect(
        main.contains('nativeCallGateProvider'),
        isTrue,
        reason:
            'sans cette observation, répondre depuis la notification '
            'ouvre Pokou sur l\'écran d\'accueil et perd l\'appel',
      );
    });
  });
}
