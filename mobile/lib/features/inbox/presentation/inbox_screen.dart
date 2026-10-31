import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country/country_config.dart';
import '../../../core/widgets/pokou_background.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../home/presentation/more_screen.dart';
import '../../kory/presentation/kory_screen.dart';

/// Coquille persistante de l'app — Accueil | Discussions | Kory | Plus
/// (cahier des charges, section 6.1).
///
/// Les onglets suivent les modules ouverts dans le pays (NAV-01) : Kory
/// n'apparaît pas là où il n'est pas lancé. L'onglet courant est retenu par
/// son identité (`PokouTab`), pas par sa position, pour qu'un onglet qui
/// apparaît au chargement de la configuration ne décale pas la sélection.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  PokouTab _current = PokouTab.home;

  /// Les onglets déjà ouverts au moins une fois.
  ///
  /// `IndexedStack` construit TOUS ses enfants. On ne construit donc un
  /// onglet qu'à sa première visite, et on le garde monté ensuite : la
  /// position de défilement de chaque onglet est conservée (NAV-02), sans
  /// faire démarrer tous les écrans — et toutes leurs requêtes — d'un coup.
  final Set<PokouTab> _visited = {PokouTab.home};

  void _open(PokouTab tab) => setState(() {
    _current = tab;
    _visited.add(tab);
  });

  Widget _build(PokouTab tab) => switch (tab) {
    PokouTab.home => HomeScreen(onOpenTab: _open),
    PokouTab.discussions => const ContactsScreen(),
    PokouTab.kory => const KoryScreen(),
    PokouTab.more => const MoreScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(
      currentCountryConfigProvider.select((config) => config.modules),
    );
    final tabs = pokouTabsFor(modules);
    final current = tabs.contains(_current) ? _current : PokouTab.home;
    final index = tabs.indexOf(current);

    return PokouBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: index,
            children: [
              for (final tab in tabs)
                if (_visited.contains(tab))
                  KeyedSubtree(key: ValueKey(tab), child: _build(tab))
                else
                  SizedBox.shrink(key: ValueKey(tab)),
            ],
          ),
        ),
        bottomNavigationBar: PokouBottomNav(
          currentIndex: index,
          tabs: tabs,
          onTap: (i) => _open(tabs[i]),
        ),
      ),
    );
  }
}
