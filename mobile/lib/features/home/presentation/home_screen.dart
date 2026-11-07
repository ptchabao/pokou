import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../contacts/presentation/open_discussion.dart';
import '../../honam/presentation/honam_controller.dart';
import '../../honam/presentation/honam_screen.dart';
import '../../honam/presentation/honam_send_screen.dart';
import '../../kory/presentation/kory_controller.dart';
import '../../kory/presentation/kory_create_screen.dart';
import '../../kory/presentation/kory_screen.dart';
import '../../modules/shared/module_ui.dart';
import '../../settings/presentation/notifications_settings_screen.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../../profile/presentation/profile_screen.dart';
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
              title: l.navHome,
              showStatus: false,
              leading: Image.asset(
                'assets/brand/pokou_logo.png',
                width: 36,
                height: 36,
                semanticLabel: 'Pokou',
              ),
              actions: [
                // La photo mène au PROFIL (cible de 44 pt).
                if (user != null)
                  Semantics(
                    button: true,
                    label: l.navProfile,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: ContactAvatar(
                            avatar: user.avatar,
                            displayName: user.fullName ?? '',
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Maquette Figma : la salutation est une carte au dégradé
            // pêche, un anneau discret en coin, la date en pastille.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _GreetingCard(
                firstName: firstName.isEmpty ? l.navHome : firstName,
                onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                ),
                onNotifications: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsSettingsScreen(),
                  ),
                ),
              ),
            ),
            _DiscussionsCard(onSeeAll: () => onOpenTab(PokouTab.discussions)),
            if (config.has('kory'))
              _KoryCard(onSeeAll: () => onOpenTab(PokouTab.kory)),
            if (config.has('honam'))
              _HonamCard(onSeeAll: () => onOpenTab(PokouTab.honam)),
            if (config.has('assime')) const _AssimeEntry(),
          ],
        ),
      ),
    );
  }
}

/// Carte de salutation (maquette Figma `.greeting`).
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.firstName,
    required this.onSearch,
    required this.onNotifications,
  });

  final String firstName;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String today;
    try {
      today = DateFormat('EEE d MMM', locale).format(DateTime.now());
    } catch (_) {
      today = DateFormat('d/M').format(DateTime.now());
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.greeting,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          // L'anneau décoratif en bas à droite.
          Positioned(
            right: -34,
            bottom: -48,
            child: IgnorePointer(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 24,
                    color: AppColors.accentPrimary.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l.homeHelloOverline.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        today.toUpperCase(),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentPrimaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 32,
                              height: 1.1,
                              letterSpacing: -0.7,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.homeTagline,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundAction(
                      icon: Icons.search,
                      tooltip: l.homeSearchHint,
                      onTap: onSearch,
                    ),
                    const SizedBox(width: 8),
                    _RoundAction(
                      icon: Icons.notifications_none_outlined,
                      tooltip: l.profileNotifications,
                      onTap: onNotifications,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une section de l'Accueil : UNE carte qui porte son propre en-tête
/// (maquette APP-1) — rond teinté, titre, « Tout voir ». La carte des
/// Discussions est terracotta, les autres blanches.
class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.icon,
    required this.title,
    required this.onSeeAll,
    required this.child,
    this.subtitle,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onSeeAll;
  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ink = accent ? AppColors.neutralCreme : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: accent ? null : AppColors.surface,
          gradient: accent ? AppGradients.brand : null,
          borderRadius: AppRadius.card,
          boxShadow: accent ? AppElevation.brand : AppElevation.card,
        ),
        child: Stack(
          children: [
            if (accent)
              // Anneau clair en haut à droite (maquette `.discussion-card`).
              Positioned(
                top: -90,
                right: -90,
                child: IgnorePointer(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 30,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent
                              ? Colors.white.withValues(alpha: 0.16)
                              : AppColors.terracottaTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: accent
                              ? Colors.white
                              : AppColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                              if (subtitle != null)
                                TextSpan(
                                  text: ' · $subtitle',
                                  style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 0.2,
                                    color: accent
                                        ? AppColors.neutralCreme.withValues(
                                            alpha: 0.8,
                                          )
                                        : AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: accent
                              ? AppColors.neutralCreme
                              : AppColors.accentPrimary,
                        ),
                        onPressed: onSeeAll,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(L.of(context).homeSeeAll),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rond beige de 44 pt (recherche, notifications) — maquette APP-1.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.isDark
            ? AppColors.surfaceElevated
            : Colors.white.withValues(alpha: 0.82),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Tuile intérieure d'une section (maquette : `rounded-lg`, fond beige).
class _InnerTile extends StatelessWidget {
  const _InnerTile({required this.child, this.onDark = false, this.onTap});

  final Widget child;
  final bool onDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onDark
          ? const Color(
              0x33301508,
            ) // rgba(48,21,10,.2) — maquette `.mini-thread`
          : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadius.inner),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.inner),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

class _AssimeEntry extends StatelessWidget {
  const _AssimeEntry();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ModuleCard(
        // APP-1 → APP-5 : l'entrée d'Assimé ouvre les petites annonces.
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.feedbackInfo.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: AppColors.feedbackInfo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Assimé',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' · Petites annonces',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Achète et vends près de chez toi',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.terracottaTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                size: 18,
                color: AppColors.accentPrimary,
              ),
            ),
          ],
        ),
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
      accent: true,
      onSeeAll: onSeeAll,
      child: recent.isEmpty
          ? _InnerTile(
              onDark: true,
              onTap: onSeeAll,
              child: Text(
                l.homeNoChats,
                style: const TextStyle(color: AppColors.neutralCreme),
              ),
            )
          : Column(
              children: [
                for (final d in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _InnerTile(
                      onDark: true,
                      // Toucher une bulle ouvre LA discussion, directement.
                      onTap: () => openDiscussion(context, ref, d),
                      child: Row(
                        children: [
                          ContactAvatar(
                            avatar: d.avatar,
                            displayName: d.displayName,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.neutralCreme,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (d.lastMessage != null)
                                  Text(
                                    d.lastMessage!.displayTextOf(l),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.neutralCreme.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (d.unreadCount > 0)
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.neutralCreme,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${d.unreadCount}',
                                style: const TextStyle(
                                  color: AppColors.accentPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
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
      title: l.navKory,
      subtitle: l.korySubtitle,
      onSeeAll: onSeeAll,
      child: open.isEmpty
          ? _InnerTile(
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
      title: l.navHonam,
      subtitle: l.honamSubtitle,
      onSeeAll: onSeeAll,
      child: current.isEmpty
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(l.honamSend),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HonamSendScreen()),
                ),
              ),
            )
          : HonamOrderCard(order: current.first),
    );
  }
}
