// Import explicite : les versions récentes de Flutter ne réexportent plus
// CupertinoPageTransitionsBuilder depuis material.dart.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// La transition entre deux écrans de Pokou.
///
/// ── Ce qu'elle remplace ────────────────────────────────────────────────
///
/// Le défaut de Flutter sur Android est un zoom : l'écran suivant grossit
/// depuis le centre pendant que le précédent grossit en s'effaçant. Sur un
/// téléphone d'entrée de gamme, c'est la transition qui se voit le plus —
/// deux écrans entiers redimensionnés à chaque image — et le passage d'un
/// fond à l'autre (le gris du Marché au blanc d'une conversation) se fait
/// d'un bloc au milieu du mouvement.
///
/// ── Ce qu'elle fait ────────────────────────────────────────────────────
///
/// L'écran qui arrive glisse sur une courte distance (un dixième de la
/// largeur) en apparaissant en fondu ; celui qu'il recouvre recule à peine.
/// Rapide au départ pour répondre au doigt, lent à l'arrivée pour se poser
/// (`fastOutSlowIn`, la courbe de Material). Le fondu adoucit le changement
/// de couleur de fond.
///
/// Deux transformations simples par image, sans ombre ni flou : c'est ce
/// qui tient 60 images par seconde sur 2 Go de mémoire.
///
/// Pas la transition iOS (`CupertinoPageTransitionsBuilder`) sur Android :
/// elle ajoute une ombre et un décalage de l'écran du dessous, plus coûteux,
/// et son retour par glissement depuis le bord gauche entre en conflit avec
/// le geste retour du système.
class PokouPageTransitionsBuilder extends PageTransitionsBuilder {
  const PokouPageTransitionsBuilder();

  static final _enterSlide = Tween<Offset>(
    begin: const Offset(0.1, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.fastOutSlowIn));

  static final _enterFade = CurveTween(curve: const Interval(0, 0.7, curve: Curves.easeOut));

  static final _exitSlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.04, 0),
  ).chain(CurveTween(curve: Curves.fastOutSlowIn));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: secondaryAnimation.drive(_exitSlide),
      child: SlideTransition(
        position: animation.drive(_enterSlide),
        child: FadeTransition(
          opacity: animation.drive(_enterFade),
          child: child,
        ),
      ),
    );
  }
}

/// Le thème de transition de l'application : le nôtre sur Android, celui du
/// système sur iOS (où le retour par glissement est le geste attendu).
const pokouPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: PokouPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);
