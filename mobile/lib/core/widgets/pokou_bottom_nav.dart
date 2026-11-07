import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/contacts/presentation/discussions_controller.dart';
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

/// Les onglets possibles. Kory et Honam sont désormais ouverts dans tous les
/// pays ; les autres modules restent pilotés par la configuration reçue.
/// Le mode allégé reste disponible si une configuration ne contient que la
/// messagerie.
///
/// Un ENUM et non un index : la liste des onglets dépend du pays (NAV-01),
/// et un index partagé entre la barre et la coquille ouvrait le mauvais
/// écran dès qu'un onglet apparaissait ou disparaissait.
enum PokouTab {
  home,
  discussions,
  statuses,
  calls,
  kory,
  honam,
  more,
  settings,
}

/// Les modules de service. Tant qu'aucun n'est ouvert dans le pays,
/// l'application se présente en lot 1.
const pokouServiceModules = {'kory', 'kory_plus', 'honam', 'assime'};

/// Vrai quand seule la messagerie est ouverte. Pokou certifié et le mode
/// preuve ne comptent pas : ils sont ouverts dès le lancement.
bool isLot1(Set<String> modules) => !modules.any(pokouServiceModules.contains);

/// Les onglets à montrer, selon les modules ouverts dans le pays.
List<PokouTab> pokouTabsFor(Set<String> modules) => isLot1(modules)
    ? const [
        PokouTab.discussions,
        PokouTab.statuses,
        PokouTab.calls,
        PokouTab.settings,
      ]
    : [
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
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          label: l.navChats,
        ),
        PokouTab.kory => PokouNavDestination(
          icon: Icons.savings_outlined,
          activeIcon: Icons.savings,
          label: l.navKory,
        ),
        PokouTab.honam => PokouNavDestination(
          icon: Icons.health_and_safety_outlined,
          activeIcon: Icons.health_and_safety,
          label: l.navHonam,
        ),
        PokouTab.more => PokouNavDestination(
          icon: Icons.grid_view_outlined,
          activeIcon: Icons.grid_view_rounded,
          label: l.navMore,
        ),
        PokouTab.statuses => PokouNavDestination(
          icon: Icons.donut_large_outlined,
          activeIcon: Icons.donut_large,
          label: l.navStatus,
        ),
        PokouTab.calls => PokouNavDestination(
          icon: Icons.call_outlined,
          activeIcon: Icons.call,
          label: l.navCalls,
        ),
        PokouTab.settings => PokouNavDestination(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: l.moreSectionSettings,
        ),
      },
  ];
}

/// Navigation basse simple, pleine largeur et sans conteneur arrondi.
class PokouBottomNav extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Pastille des non-lus sur Discussions (maquette Terre de Confiance).
    final unread = ref.watch(
      discussionsProvider.select(
        (async) => (async.valueOrNull ?? const [])
            .where((d) => !d.isArchived)
            .fold<int>(0, (sum, d) => sum + d.unreadCount),
      ),
    );
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
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          // AUCUNE élévation : le système de design supprime les ombres
          // diffuses pour tenir la fréquence d'images sur les appareils
          // d'entrée de gamme. La barre se détache par un trait d'un point,
          // posé par le `Container` ci-dessus.
          elevation: 0,
          items: [
            for (final (i, destination) in pokouNavDestinationsOf(
              context,
              tabs,
            ).indexed)
              BottomNavigationBarItem(
                icon: _Glyph(
                  icon: destination.icon,
                  active: false,
                  badge: tabs[i] == PokouTab.discussions ? unread : 0,
                ),
                activeIcon: _Glyph(
                  icon: destination.activeIcon,
                  active: true,
                  badge: tabs[i] == PokouTab.discussions ? unread : 0,
                ),
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
  const _Glyph({required this.icon, required this.active, this.badge = 0});

  final IconData icon;
  final bool active;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 32,
          height: 2,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.accentPrimary : Colors.transparent,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(3),
            ),
          ),
        ),
        // Maquette Figma : une pastille terre cuite claire sous l'icône
        // active (38 × 28).
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 44,
          height: 28,
          decoration: BoxDecoration(
            color: active ? AppColors.terracottaTint : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Badge(
            isLabelVisible: badge > 0,
            backgroundColor: AppColors.accentPrimary,
            label: Text(badge > 99 ? '99+' : '$badge'),
            child: Icon(icon),
          ),
        ),
      ],
    );
  }
}
