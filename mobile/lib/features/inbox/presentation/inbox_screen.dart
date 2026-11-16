import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/country/country_config.dart';
import '../../../core/providers.dart';
import '../../settings/presentation/backup_screens.dart';
import '../../../core/widgets/pokou_background.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../core/widgets/pokou_tab_page.dart';
import '../../calls/presentation/call_log_screen.dart';
import '../../calls/presentation/missed_calls_badge.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../honam/presentation/honam_screen.dart';
import '../../home/presentation/more_screen.dart';
import '../../kory/presentation/kory_screen.dart';
import '../../status/presentation/status_list_screen.dart';

/// Coquille persistante de l'app — Accueil | Discussions | Kory | Honam |
/// Plus dans l'application complète (section 6.1), Discussions | Statuts |
/// Appels | Réglages au lot 1 (section 6.3).
///
/// Les onglets suivent les modules ouverts dans le pays (NAV-01) : Kory
/// n'apparaît pas là où il n'est pas lancé. L'onglet courant est retenu par
/// son identité (`PokouTab`), pas par sa position, pour qu'un onglet qui
/// apparaît au chargement de la configuration ne décale pas la sélection.
/// Il vit dans `pokouCurrentTabProvider`, pour qu'un écran ouvert par-dessus
/// avec la barre du bas (`PokouTabPage`) puisse changer d'onglet.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// Les onglets déjà ouverts au moins une fois.
  ///
  /// `IndexedStack` construit TOUS ses enfants. On ne construit donc un
  /// onglet qu'à sa première visite, et on le garde monté ensuite : la
  /// position de défilement de chaque onglet est conservée (NAV-02), sans
  /// faire démarrer tous les écrans — et toutes leurs requêtes — d'un coup.
  final Set<PokouTab> _visited = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _offerRestoreOrBackup(),
    );
  }

  /// CNX-2 : sur un téléphone VIDE, avec une sauvegarde au compte, la
  /// restauration est proposée une fois. Sinon, la sauvegarde quotidienne
  /// part en silence (MSG-12).
  Future<void> _offerRestoreOrBackup() async {
    final service = ref.read(backupServiceProvider);
    try {
      final empty =
          await ref.read(pokouMessageStoreProvider).messageCount() == 0;
      if (empty &&
          !await service.hasPassword() &&
          await service.takeRestoreOffer()) {
        // Une sauvegarde chez Pokou, ou sur le compte Google déjà connecté.
        // Sinon, sur Android, on propose quand même de la chercher sur
        // Google Drive (comme WhatsApp).
        final backup = await service.serverInfo() ?? await service.driveInfo();
        if ((backup != null || Platform.isAndroid) && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WelcomeBackScreen(backup: backup),
            ),
          );
          return;
        }
      }
      await service.backupIfDue();
    } catch (_) {
      // Hors ligne : rien à proposer maintenant.
    }
  }

  void _open(PokouTab tab) {
    ref.read(pokouCurrentTabProvider.notifier).state = tab;
  }

  Widget _build(PokouTab tab) => switch (tab) {
    PokouTab.home => HomeScreen(onOpenTab: _open),
    PokouTab.discussions => const ContactsScreen(),
    PokouTab.kory => const KoryScreen(),
    PokouTab.honam => const HonamScreen(),
    PokouTab.more => const MoreScreen(),
    // Lot 1 (NAV-10) : les mêmes écrans que dans l'application complète,
    // portés en onglets — aucun écran n'est dupliqué (NAV-11).
    PokouTab.statuses => const StatusListScreen(),
    PokouTab.calls => const CallLogScreen(),
    PokouTab.settings => const MoreScreen(lot1: true),
  };

  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(
      currentCountryConfigProvider.select((config) => config.modules),
    );
    final tabs = pokouShellTabsFor(modules);
    // L'onglet de départ : l'Accueil dans l'application complète, les
    // Discussions au lot 1, qui n'a pas d'Accueil.
    final requested = ref.watch(pokouCurrentTabProvider);
    final current = tabs.contains(requested) ? requested! : tabs.first;
    _visited.add(current);
    final index = tabs.indexOf(current);
    // La barre change avec la vue : celle de la messagerie dès qu'on ouvre
    // les Discussions, celle des modules ailleurs.
    final bar = pokouBarFor(modules, current);
    // Dans l'espace messagerie de l'application complète, le retour système
    // ramène à l'Accueil au lieu de quitter l'application.
    final backToHome = !isLot1(modules) && bar.contains(PokouTab.statuses);
    // Ouvrir le journal d'appels éteint la pastille des appels manqués ; le
    // quitter aussi, pour les appels arrivés pendant qu'il était affiché.
    ref.listen(pokouCurrentTabProvider, (previous, tab) {
      if (tab == PokouTab.calls || previous == PokouTab.calls) {
        ref.read(callsSeenAtProvider.notifier).markSeen();
      }
    });

    return PopScope(
      canPop: !backToHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(PokouTab.home);
      },
      child: PokouBackground(
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
            currentIndex: bar.indexOf(current),
            tabs: bar,
            onTap: (i) => _open(bar[i]),
          ),
        ),
      ),
    );
  }
}
