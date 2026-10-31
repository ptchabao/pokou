import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/modules/presentation/module_routes.dart';

/// Où mène un module activé.
///
/// C'est le chaînon qui manquait : les modules étaient activables et ne
/// conduisaient nulle part. Un interrupteur qui n'allume rien est pire
/// qu'une absence de fonctionnalité — il donne l'impression que
/// l'application est cassée.
void main() {
  test('les sept modules du catalogue ont un écran', () {
    for (final slug in [
      'heart_league', 'streak_lock', 'truth_market',
      'social_tax', 'vip_room', 'hype_train', 'spark',
    ]) {
      expect(
        moduleHasScreen(slug),
        isTrue,
        reason: "$slug est activable mais ne mène nulle part",
      );
      expect(moduleScreenFor(slug), isNotNull);
    }
  });

  test('un slug inconnu ne fait pas planter la résolution', () {
    // Le serveur peut nommer un module que cette version de l'application
    // ne connaît pas : le catalogue vit en base, et une version ancienne
    // reste installée longtemps. C'est cette valeur nulle qui permet à
    // l'écran d'accueil de l'annoncer plutôt que d'ouvrir du vide.
    expect(moduleScreenFor('module_du_futur'), isNull);
    expect(moduleHasScreen(''), isFalse);
  });
}
