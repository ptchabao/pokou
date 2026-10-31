import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Papier peint des conversations — le motif griffonné derrière les bulles.
///
/// Un fond de conversation n'est pas un vide : c'est lui qui rend une
/// discussion chargée chaleureuse plutôt qu'administrative, et c'est contre
/// lui que les bulles se détachent. D'où un motif, et non un aplat.
///
/// Trois précautions, chacune pour une raison précise :
///
/// - **Fondu multiplicatif** (`BlendMode.multiply`). L'image source a un fond
///   BLANC ; posée telle quelle sur le crème, elle l'effacerait. Multipliée
///   par la couleur de fond, ses zones blanches prennent exactement la teinte
///   du canevas et seules les lignes du motif subsistent. Un simple réglage
///   d'opacité aurait délavé le crème au lieu de le conserver.
/// - **Opacité basse.** Le motif doit se deviner, pas se lire : il passe
///   derrière du texte, et tout ce qu'il gagne en présence, la conversation
///   le perd en lisibilité.
/// - **Échelle 3.** L'image fait 1024 pixels de côté ; à cette échelle chaque
///   griffonnage mesure une trentaine de points logiques et le motif se
///   répète plusieurs fois par écran. Rendue à l'échelle 1, une seule tuile
///   couvrirait tout l'écran et le motif se lirait comme un dessin.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child});

  final Widget child;

  /// Publique pour que les tests puissent viser exactement cette ressource
  /// sans recopier le chemin.
  static const assetPath = 'assets/chat_wallpaper.webp';

  static const _tileScale = 3.0;
  static const _patternOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.chatBackground,
        image: DecorationImage(
          image: ExactAssetImage(assetPath, scale: _tileScale),
          repeat: ImageRepeat.repeat,
          colorFilter: ColorFilter.mode(AppColors.chatBackground, BlendMode.multiply),
          opacity: _patternOpacity,
        ),
      ),
      child: child,
    );
  }
}
