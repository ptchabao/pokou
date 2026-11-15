import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../country/country_config.dart';
import 'pokou_bottom_nav.dart';

/// L'onglet affiché par la coquille (`InboxScreen`), ou `null` pour l'onglet
/// de départ (Accueil, ou Discussions au Lot 1).
///
/// Un fournisseur et non un état local de la coquille : un écran ouvert PAR
/// DESSUS la coquille (Assimé, Centre de notifications) garde la barre du
/// bas, et un appui sur un onglet doit pouvoir changer l'onglet de la coquille
/// en dessous. `autoDispose` : la coquille le regarde tant qu'elle est montée,
/// un autre compte connecté plus tard repart de l'onglet de départ.
final pokouCurrentTabProvider = StateProvider.autoDispose<PokouTab?>(
  (ref) => null,
);

/// Le nom de la route de la coquille (go_router nomme la page par son
/// chemin).
const pokouShellRouteName = '/inbox';

/// Revient à la coquille et y montre [tab].
void openPokouTab(BuildContext context, WidgetRef ref, PokouTab tab) {
  ref.read(pokouCurrentTabProvider.notifier).state = tab;
  Navigator.of(context).popUntil(
    (route) => route.settings.name == pokouShellRouteName || route.isFirst,
  );
}

/// Un écran ouvert depuis un onglet, qui garde la barre du bas avec cet
/// onglet actif : Assimé avec « Plus » (maquette p.15), le Centre de
/// notifications avec « Accueil » (maquette p.109).
///
/// L'écran est poussé normalement sur la pile (le retour système et la
/// flèche retour le ferment comme avant) ; seule la barre est ajoutée. Un
/// appui sur un onglet referme l'écran et ouvre l'onglet dans la coquille.
/// Si l'onglet n'existe pas dans le pays (Lot 1), l'écran s'ouvre sans barre.
class PokouTabPage extends ConsumerWidget {
  const PokouTabPage({super.key, required this.tab, required this.child});

  final PokouTab tab;
  final Widget child;

  /// Le chemin habituel : pousse [child] avec la barre, [tab] actif.
  static Future<T?> push<T>(
    BuildContext context, {
    required PokouTab tab,
    required Widget child,
  }) => Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => PokouTabPage(tab: tab, child: child),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(
      currentCountryConfigProvider.select((config) => config.modules),
    );
    final tabs = pokouTabsFor(modules);
    final index = tabs.indexOf(tab);
    if (index < 0) return child;
    return Scaffold(
      body: child,
      bottomNavigationBar: PokouBottomNav(
        currentIndex: index,
        tabs: tabs,
        onTap: (i) => openPokouTab(context, ref, tabs[i]),
      ),
    );
  }
}
