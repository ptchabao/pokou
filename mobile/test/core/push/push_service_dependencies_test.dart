import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PushService ne doit pas lire `authControllerProvider`.
///
/// `authControllerProvider` OBSERVE `pushServiceProvider` — il appelle
/// `registerCurrentToken()` à la connexion. Lire l'autre sens ferme le cycle,
/// et Riverpod lève `CircularDependencyError`.
///
/// Ce n'est pas une subtilité théorique : l'exception tombait dans le `catch`
/// de l'enregistrement du jeton, qui n'écrivait qu'un `debugPrint` invisible
/// en release. Le jeton FCM n'était donc JAMAIS envoyé, le serveur
/// journalisait « Aucun jeton FCM » à chaque message, et rien, nulle part,
/// ne reliait les deux.
///
/// Une vérification de TEXTE et non de comportement, faute de mieux : monter
/// le vrai service en test demanderait Firebase, et c'est précisément le
/// chemin qui échoue avant d'atteindre le cycle. Le sens de la dépendance,
/// lui, se lit dans le fichier.
void main() {
  test('PushService ne dépend pas de authControllerProvider', () {
    // Les commentaires sont retirés : celui qui explique POURQUOI ce cycle
    // est interdit nomme forcément le provider, et doit rester lisible.
    final code = File('lib/core/push/push_service.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      code.contains('authControllerProvider'),
      isFalse,
      reason: 'PushService lit authControllerProvider, qui l\'observe déjà : '
          'le cycle fait échouer l\'enregistrement du jeton FCM. La session '
          'se pousse par setSession(), depuis AuthController.',
    );
  });

  test('AuthController pousse la session vers PushService', () {
    // Le pendant du test précédent : rompre le cycle n'a de sens que si
    // quelqu'un alimente effectivement PushService. Sans cet appel, le
    // service croirait l'utilisateur déconnecté en permanence et
    // n'enverrait jamais le jeton — la même panne, par l'autre bout.
    final source =
        File('lib/features/auth/presentation/auth_controller.dart')
            .readAsStringSync();

    expect(source.contains('_push.setSession('), isTrue);
  });
}
