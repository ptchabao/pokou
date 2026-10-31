import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_background.dart';
import 'auth_controller.dart';

/// L'écran d'attente entre le lancement et le premier vrai écran.
///
/// Il existe pour résoudre `AuthStatus.unknown` — lire le jeton stocké est
/// asynchrone — avant d'envoyer vers `/inbox` ou `/phone`, ce qui évite de
/// faire clignoter l'écran de connexion à chaque démarrage de quelqu'un qui
/// est déjà connecté.
///
/// Ce qu'il montre compte autant que ce qu'il fait. Depuis que le profil en
/// cache suffit à ouvrir l'application (voir AuthController._restoreSession),
/// cette attente dure le plus souvent quelques dizaines de millisecondes.
/// Un rond qui tourne apparaissant puis disparaissant en un clin d'œil se
/// lit comme un défaut d'affichage, pas comme un chargement — alors on ne
/// l'affiche qu'au bout d'un moment, quand l'attente devient réelle
/// (premier lancement après installation, ou réseau en panne). Avant ça,
/// l'écran reste exactement de la même couleur que la fenêtre peinte par
/// Android avant Flutter : de l'extérieur, il ne se passe rien, puis
/// l'application est là.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _spinnerDelay = Duration(milliseconds: 450);

  /// Créé une seule fois, et non dans `build` : un `Future.delayed` posé
  /// dans la méthode de construction repart à zéro à chaque reconstruction,
  /// et le délai ne s'écoulerait jamais si l'écran se reconstruit souvent.
  final Future<void> _spinnerDue = Future<void>.delayed(_spinnerDelay);

  @override
  void initState() {
    super.initState();
    // L'état peut ÊTRE DÉJÀ résolu au moment où cet écran se construit —
    // rien ne garantit l'ordre entre la restauration de session et le
    // premier rendu. `ref.listen` seul ne verrait alors jamais passer de
    // changement, et on resterait bloqué ici pour toujours.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _route(ref.read(authControllerProvider).status);
    });
  }

  void _route(AuthStatus status) {
    if (!mounted) return;
    if (status == AuthStatus.authenticated) {
      context.go('/inbox');
    } else if (status == AuthStatus.unauthenticated) {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) => _route(next.status));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PokouBackground(
        child: Center(
          child: FutureBuilder<void>(
            future: _spinnerDue,
            builder: (context, snapshot) => AnimatedOpacity(
              opacity: snapshot.connectionState == ConnectionState.done ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: CircularProgressIndicator(
                color: AppColors.accentPrimaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
