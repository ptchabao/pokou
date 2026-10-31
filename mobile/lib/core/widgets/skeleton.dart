import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Les formes grises qui tiennent la place d'un contenu pendant son
/// chargement.
///
/// Elles remplacent les ronds qui tournent, et ce n'est pas une question de
/// goût. Un indicateur de progression dit « attendez » sans rien dire de
/// plus : l'écran reste vide, sa hauteur change d'un coup à l'arrivée des
/// données, et tout ce qui était en dessous saute. Un squelette dit « il y
/// aura ici une liste de chaînes, avec une image ronde et deux lignes de
/// texte » — la mise en page est déjà en place, l'arrivée du vrai contenu ne
/// déplace plus rien, et l'attente paraît plus courte parce qu'on a déjà
/// quelque chose à regarder.
///
/// D'où la règle qui suit ces classes : un squelette doit avoir la FORME de
/// ce qu'il remplace. Un rectangle générique ne vaut pas mieux qu'un rond
/// qui tourne.

/// Anime tout un groupe de formes d'une seule pulsation.
///
/// Un `AnimationController` par forme donnerait une dizaine de tickers pour
/// une liste, et — pire — des pulsations désynchronisées : l'écran
/// scintillerait au lieu de respirer. Un seul contrôleur ici, et les formes
/// en dessous restent de simples widgets sans état.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quelqu'un qui a demandé moins d'animations dans les réglages
    // d'accessibilité ne doit pas voir l'écran palpiter : les formes
    // restent alors immobiles, et disent la même chose.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.45).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// Un bloc gris — une ligne de texte, une vignette, un bouton.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  /// `double.infinity` pour occuper toute la largeur disponible.
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeletonFill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Un rond gris — une photo de profil, une image de chaîne, un statut.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.skeletonFill,
        shape: BoxShape.circle,
      ),
    );
  }
}
