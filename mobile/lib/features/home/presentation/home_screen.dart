import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contacts/data/conversation_summary.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../contacts/presentation/open_discussion.dart';
import '../../honam/data/honam_models.dart';
import '../../honam/presentation/honam_controller.dart';
import '../../honam/presentation/honam_order_screen.dart';
import '../../kory/data/kory_model.dart';
import '../../kory/presentation/kory_controller.dart';
import '../../kory/presentation/kory_pot_screen.dart';
import '../../../core/widgets/pokou_tab_page.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../../notifications/presentation/notifications_center_screen.dart';
import '../data/home_banner.dart';
import 'global_search_screen.dart';
import 'home_carousel.dart';
import '../../../core/widgets/pokou_icon.dart';

/// Pokou · 1. Accueil (maquette p.14) :
///
/// 1. la salutation, la recherche et les notifications ;
/// 2. une carte « Tout voir » par module ouvert dans le pays — Discussions
///    d'abord, puis Kory et Honam si lancés ;
/// 3. Assimé, en simple ligne d'entrée (il n'a pas encore son onglet) ;
/// 4. le rappel du chiffrement, dans le carrousel.
///
/// Chaque carte ne s'affiche que pour un module ouvert dans le pays — voir
/// `CountryConfig`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<PokouTab> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(currentCountryConfigProvider);
    final user = ref.watch(authControllerProvider).user;
    final firstName = (user?.fullName ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discussionsProvider);
          ref.invalidate(countryConfigProvider);
          ref.invalidate(serviceNotificationsProvider);
          ref.invalidate(homeBannersProvider);
          if (config.has('kory')) refreshKory(ref);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // ── En-tête (maquette p.14) : le logo, « Bonjour » et le
            // prénom à gauche, la loupe et la cloche à droite.
            _HomeHeader(firstName: firstName),
            // ── Le carrousel, en haut : les annonces de ma zone, puis le
            // rappel du chiffrement.
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: HomeCarousel(onOpenTab: onOpenTab),
            ),
            _DiscussionsCard(onSeeAll: () => onOpenTab(PokouTab.discussions)),
            if (config.has('kory'))
              _KoryCard(onSeeAll: () => onOpenTab(PokouTab.kory)),
            if (config.has('honam'))
              _HonamCard(onSeeAll: () => onOpenTab(PokouTab.honam)),
            if (config.has('assime'))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _AssimeRow(
                  onTap: () => PokouTabPage.push(
                    context,
                    tab: PokouTab.more,
                    child: const MarketplaceScreen(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// L'en-tête de l'Accueil (maquette p.14) : le logo Pokou, « Bonjour » en
/// petit au-dessus du prénom, puis la loupe et la cloche. Pas de photo de
/// profil ici : elle vit dans « Plus ».
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final unread =
        ref.watch(serviceNotificationsProvider).valueOrNull?.unread ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/brand/pokou_logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.homeHelloOverline,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (firstName.isNotEmpty)
                    Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l.homeSearchEverything,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
          ),
          IconButton(
            tooltip: l.notifCenterTitle,
            // La barre du bas reste, Accueil actif (maquette p.109).
            onPressed: () => PokouTabPage.push(
              context,
              tab: PokouTab.home,
              child: const NotificationsCenterScreen(),
            ),
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: AppColors.accentPrimary,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: const Icon(Icons.notifications_none_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

/// La ligne d'entrée d'Assimé (maquette p.14) : pas encore une carte pleine,
/// juste une porte vers le module — il n'a pas d'onglet avant le lot 3.
class _AssimeRow extends StatelessWidget {
  const _AssimeRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          const PokouModuleLogo(PokouModule.assime, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.homeAssimeTitle} · ${l.marketSubtitle}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  l.homeAssimeShort,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// L'en-tête d'une carte de module (maquette p.14) : l'icône, le titre, et
/// « Tout voir » souligné à droite — DANS la carte, sur sa couleur.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.leading,
    required this.title,
    required this.ink,
    required this.onSeeAll,
  });

  final Widget leading;
  final String title;
  final Color ink;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      leading,
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ),
      InkWell(
        onTap: onSeeAll,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Text(
            L.of(context).homeSeeAll,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ink,
              decoration: TextDecoration.underline,
              decorationColor: ink,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Le fond coloré d'une carte de module, cliquable en entier.
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.color,
    required this.child,
    this.border,
    this.onTap,
  });

  final Color color;
  final Color? border;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.card,
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 8, 12),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// La carte Discussions (maquette p.14) : terre cuite, « Tout voir », et les
/// deux dernières discussions — Baba compris si c'est la plus récente.
class _DiscussionsCard extends ConsumerWidget {
  const _DiscussionsCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final recent =
        (ref.watch(discussionsProvider).valueOrNull ??
                const <ConversationSummary>[])
            .where((d) => !d.isArchived)
            .take(2)
            .toList();
    const ink = Colors.white;
    return _ModuleCard(
      color: AppColors.accentPrimary,
      onTap: onSeeAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            leading: const Icon(
              Icons.chat_bubble_outline,
              size: 18,
              color: ink,
            ),
            title: l.navChats,
            ink: ink,
            onSeeAll: onSeeAll,
          ),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                l.homeNoChats,
                style: TextStyle(color: ink.withValues(alpha: 0.86)),
              ),
            )
          else
            for (final d in recent) _DiscussionRow(discussion: d),
        ],
      ),
    );
  }
}

/// La carte Kory (maquette p.14) : ébène, « Kory · Cagnottes », « Tout
/// voir », et la cagnotte ouverte la plus proche de son échéance.
class _KoryCard extends ConsumerWidget {
  const _KoryCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final pots = ref.watch(koryPotsProvider).valueOrNull ?? const <KoryPot>[];
    final pot = pots.where((p) => p.isOpen).firstOrNull;
    const ink = Color(0xFFFFF9E5);
    return _ModuleCard(
      color: AppColors.brandEbene,
      onTap: pot == null
          ? onSeeAll
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            leading: const PokouIcon(
              PokouModuleIcon.kory,
              size: 18,
              color: AppColors.brandOr,
            ),
            title: '${l.navKory} · ${l.homeKoryCardSubtitle}',
            ink: ink,
            onSeeAll: onSeeAll,
          ),
          if (pot == null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                l.homeKoryEmpty,
                style: TextStyle(color: ink.withValues(alpha: 0.8)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _KoryInProgress(pot: pot, ink: ink),
            ),
        ],
      ),
    );
  }
}

/// La carte Honam (maquette p.14) : blanche, « Honam · Pharmacies », « Tout
/// voir », la commande en cours s'il y en a une, et « Envoyer une
/// ordonnance ».
class _HonamCard extends ConsumerWidget {
  const _HonamCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final orders =
        ref.watch(honamOrdersProvider).valueOrNull ?? const <HonamOrder>[];
    final order = orders.where((o) => !o.isFinished).firstOrNull;
    return _ModuleCard(
      color: AppColors.surface,
      border: AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            leading: const PokouModuleLogo(PokouModule.honam, size: 24),
            title: '${l.navHonam} · ${l.homeHonamCardSubtitle}',
            ink: AppColors.textPrimary,
            onSeeAll: onSeeAll,
          ),
          if (order != null)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 10),
              child: _HonamInProgress(order: order),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OutlinedButton.icon(
              onPressed: onSeeAll,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(l.honamSend),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentPrimaryDark,
                side: const BorderSide(color: AppColors.accentPrimary),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte blanche « Terre de Confiance » : 18 pt et un filet — à plat, sans
/// ombre. Les cartes ne flottent plus au-dessus du fond : elles y sont
/// posées, comme les cartes de services.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

class _KoryInProgress extends StatelessWidget {
  const _KoryInProgress({required this.pot, required this.ink});

  final KoryPot pot;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final progress = pot.progress;
    final due = pot.dueAt;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String? dueLabel;
    if (due != null) {
      try {
        dueLabel = l.koryDue(DateFormat('d MMM', locale).format(due));
      } catch (_) {
        dueLabel = l.koryDue(DateFormat('d/M').format(due));
      }
    }
    final soft = ink.withValues(alpha: 0.78);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pot.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 2),
        // L'échéance, ou le rappel que l'argent ne passe pas par Pokou.
        Text(
          [?pot.groupName, dueLabel ?? l.homeKoryNoMoney].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: soft),
        ),
        if (progress != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: ink.withValues(alpha: 0.16),
              color: AppColors.brandOr,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 13, color: soft),
            children: [
              TextSpan(text: '${l.koryTotalConfirmed} : '),
              TextSpan(
                text: formatFcfa(pot.confirmedTotal),
                style: TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              if (pot.goalAmount != null)
                TextSpan(text: ' ${l.koryOnGoal(formatFcfa(pot.goalAmount!))}'),
            ],
          ),
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

class _HonamInProgress extends StatelessWidget {
  const _HonamInProgress({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      color: AppColors.isDark
          ? AppColors.warning.withValues(alpha: 0.16)
          : const Color(0xFFFBF0D3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HonamOrderScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Jamais un nom de médicament (HON-04) : la pharmacie et
              // l'étape.
              Text(
                order.pharmacy?.name ?? l.navHonam,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                honamStatusLabel(l, order.status),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.isDark
                      ? AppColors.textSecondary
                      : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscussionRow extends ConsumerWidget {
  const _DiscussionRow({required this.discussion});

  final ConversationSummary discussion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final d = discussion;
    final last = d.lastMessage;
    final unread = d.unreadCount > 0;
    const ink = Colors.white;
    final soft = ink.withValues(alpha: 0.82);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openDiscussion(context, ref, d),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
        child: Row(
          children: [
            ContactAvatar(avatar: d.avatar, displayName: d.name, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  if (last != null)
                    Text(
                      last.displayTextOf(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: soft),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (last != null)
                  Text(
                    DateFormat.Hm().format(last.createdAt.toLocal()),
                    style: TextStyle(fontSize: 11.5, color: soft),
                  ),
                if (unread) ...[
                  const SizedBox(height: 3),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(9),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
