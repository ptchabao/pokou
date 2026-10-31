import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

class PokouNavDestination {
  const PokouNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

}

/// Les onglets possibles, dans l'ordre du cahier des charges (section 6.1) :
/// Accueil | Discussions | Kory | Honam | Plus.
///
/// Un ENUM et non un index : la liste des onglets dépend du pays (NAV-01),
/// et un index partagé entre la barre et la coquille ouvrait le mauvais
/// écran dès qu'un onglet apparaissait ou disparaissait.
enum PokouTab { home, discussions, kory, honam, more }

/// Les onglets à montrer, selon les modules ouverts dans le pays.
List<PokouTab> pokouTabsFor(Set<String> modules) => [
  PokouTab.home,
  PokouTab.discussions,
  if (modules.contains('kory')) PokouTab.kory,
  if (modules.contains('honam')) PokouTab.honam,
  PokouTab.more,
];

/// Les destinations, construites AVEC un contexte.
///
/// Une fonction et non une liste `const` : un libellé traduit ne peut pas
/// être constant, il dépend de la langue courante.
List<PokouNavDestination> pokouNavDestinationsOf(
  BuildContext context, [
  List<PokouTab> tabs = PokouTab.values,
]) {
  final l = L.of(context);
  return [
    for (final tab in tabs)
      switch (tab) {
        PokouTab.home => PokouNavDestination(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: l.navHome,
        ),
        PokouTab.discussions => PokouNavDestination(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum,
          label: l.navChats,
        ),
        PokouTab.kory => PokouNavDestination(
          icon: Icons.savings_outlined,
          activeIcon: Icons.savings,
          label: l.navKory,
        ),
        PokouTab.honam => PokouNavDestination(
          icon: Icons.local_pharmacy_outlined,
          activeIcon: Icons.local_pharmacy,
          label: l.navHonam,
        ),
        PokouTab.more => PokouNavDestination(
          icon: Icons.menu,
          activeIcon: Icons.menu_open,
          label: l.navMore,
        ),
      },
  ];
}

/// Navigation basse simple, pleine largeur et sans conteneur arrondi.
class PokouBottomNav extends StatelessWidget {
  const PokouBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabs = PokouTab.values,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PokouTab> tabs;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        // Un trait d'un point au lieu d'une ombre — voir `elevation: 0`.
        decoration: BoxDecoration(
          color: AppColors.navBackground,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.navBackground,
        selectedItemColor: AppColors.accentPrimaryDark,
        unselectedItemColor: AppColors.navIconInactive,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        // AUCUNE élévation : le système de design supprime les ombres
        // diffuses pour tenir la fréquence d'images sur les appareils
        // d'entrée de gamme. La barre se détache par un trait d'un point,
        // posé par le `Container` ci-dessus.
        elevation: 0,
        items: [
          for (final destination in pokouNavDestinationsOf(context, tabs))
            BottomNavigationBarItem(
              icon: _Glyph(icon: destination.icon, active: false),
              activeIcon: _Glyph(icon: destination.activeIcon, active: true),
              label: destination.label,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un glyphe d'onglet, avec son trait d'activité.
///
/// Le système demande un trait de 2 points AU-DESSUS de l'onglet actif. Ce
/// n'est pas une redondance avec la couleur : un trait se voit de plus loin
/// et survit au soleil, là où la différence entre un vert et un gris
/// s'estompe sur une dalle bon marché.
///
/// Le trait est présent dans LES DEUX états, transparent quand l'onglet est
/// inactif. Sans cela, chaque changement d'onglet décalerait les glyphes de
/// deux points vers le bas — un tressautement visible à chaque navigation.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 22,
          height: 2,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.accentPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        Icon(icon),
      ],
    );
  }
}