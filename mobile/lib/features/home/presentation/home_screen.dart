import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../honam/presentation/honam_controller.dart';
import '../../honam/presentation/honam_screen.dart';
import '../../honam/presentation/honam_send_screen.dart';
import '../../kory/presentation/kory_controller.dart';
import '../../kory/presentation/kory_create_screen.dart';
import '../../kory/presentation/kory_screen.dart';
import '../../modules/shared/module_ui.dart';
import 'global_search_screen.dart';

/// L'accueil après connexion (écran APP-1) : une carte par module ouvert
/// dans le pays (NAV-08), chacune menant à son module.
///
/// Une carte vide montre l'action de départ du module plutôt qu'un état
/// vide (NAV-09) : « Créer une cagnotte », pas « Aucune cagnotte ».
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<PokouTab> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final config = ref.watch(currentCountryConfigProvider);
    final user = ref.watch(authControllerProvider).user;
    final firstName = (user?.fullName ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discussionsProvider);
          ref.invalidate(countryConfigProvider);
          if (config.has('kory')) refreshKory(ref);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            PokouAppBar(
              title: firstName.isEmpty ? l.navHome : l.homeGreeting(firstName),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _SearchEntry(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                ),
              ),
            ),
            _DiscussionsCard(onSeeAll: () => onOpenTab(PokouTab.discussions)),
            if (config.has('kory'))
              _KoryCard(onSeeAll: () => onOpenTab(PokouTab.kory)),
            if (config.has('honam'))
              _HonamCard(onSeeAll: () => onOpenTab(PokouTab.honam)),
          ],
        ),
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.search, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text(
                L.of(context).homeSearchHint,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.icon,
    required this.title,
    required this.onSeeAll,
    required this.child,
  });

  final IconData icon;
  final String title;
  final VoidCallback onSeeAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.accentPrimaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: Text(L.of(context).homeSeeAll),
              ),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _DiscussionsCard extends ConsumerWidget {
  const _DiscussionsCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final discussions = ref.watch(discussionsProvider).valueOrNull ?? const [];
    final recent = discussions.take(2).toList();

    return _HomeSection(
      icon: Icons.forum_outlined,
      title: l.navChats,
      onSeeAll: onSeeAll,
      child: ModuleCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: recent.isEmpty
            ? ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(l.homeNoChats),
                onTap: onSeeAll,
              )
            : Column(
                children: [
                  for (final d in recent)
                    ListTile(
                      onTap: onSeeAll,
                      leading: ContactAvatar(
                        avatar: d.avatar,
                        displayName: d.displayName,
                        size: 44,
                      ),
                      title: Text(
                        d.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: d.lastMessage == null
                          ? null
                          : Text(
                              d.lastMessage!.displayTextOf(l),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: d.unreadCount > 0
                          ? Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentPrimary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${d.unreadCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
      ),
    );
  }
}

class _KoryCard extends ConsumerWidget {
  const _KoryCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final pots = ref.watch(koryPotsProvider).valueOrNull ?? const [];
    final open = pots.where((p) => p.isOpen).toList();

    return _HomeSection(
      icon: Icons.savings_outlined,
      title: l.korySubtitle,
      onSeeAll: onSeeAll,
      child: open.isEmpty
          ? ModuleCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.koryNoMoney,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ModuleActionButton(
                    label: l.koryCreate,
                    icon: Icons.add,
                    expanded: false,
                    onPressed: () => openKoryCreate(context, ref),
                  ),
                ],
              ),
            )
          : KoryPotCard(pot: open.first),
    );
  }
}

/// La carte Honam : la commande en cours, ou l'action de départ (NAV-09).
/// Jamais un nom de médicament (HON-04).
class _HonamCard extends ConsumerWidget {
  const _HonamCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final orders = ref.watch(honamOrdersProvider).valueOrNull ?? const [];
    final current = orders.where((o) => !o.isFinished).toList();
    return _HomeSection(
      icon: Icons.local_pharmacy_outlined,
      title: l.honamSubtitle,
      onSeeAll: onSeeAll,
      child: current.isEmpty
          ? ModuleCard(
              child: ModuleActionButton(
                label: l.honamSend,
                icon: Icons.photo_camera_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HonamSendScreen()),
                ),
              ),
            )
          : HonamOrderCard(order: current.first),
    );
  }
}
