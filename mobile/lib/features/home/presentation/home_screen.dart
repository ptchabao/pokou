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
import 'pokou_page_header.dart';
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
    final l = L.of(context);
    final config = ref.watch(currentCountryConfigProvider);
    final user = ref.watch(authControllerProvider).user;
    final firstName = (user?.fullName ?? '').split(' ').first;
    final unreadMessages = ref.watch(
      discussionsProvider.select(
        (async) => (async.valueOrNull ?? const <ConversationSummary>[])
            .where((d) => !d.isArchived)
            .fold<int>(0, (sum, d) => sum + d.unreadCount),
      ),
    );

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
            // ── En-tête : la salutation à gauche, la loupe et la cloche à
            // droite (maquette p.14 : pas de barre de recherche pleine
            // largeur ici, elle vit sur sa propre icône).
            PokouPageHeader(
              title: firstName.isEmpty
                  ? l.homeHelloOverline
                  : l.homeGreeting(firstName),
              subtitle: unreadMessages > 0
                  ? l.homeUnreadSummary(unreadMessages)
                  : l.homeTagline,
              emphasized: unreadMessages > 0,
              actions: [
                IconButton(
                  tooltip: l.homeSearchEverything,
                  icon: const Icon(Icons.search),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GlobalSearchScreen(),
                    ),
                  ),
                ),
              ],
            ),
            _DiscussionsCard(onSeeAll: () => onOpenTab(PokouTab.discussions)),
            if (config.has('kory'))
              _KoryCard(onSeeAll: () => onOpenTab(PokouTab.kory)),
            if (config.has('honam'))
              _HonamCard(onSeeAll: () => onOpenTab(PokouTab.honam)),
            if (config.has('assime'))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _AssimeRow(
                  onTap: () => PokouTabPage.push(
                    context,
                    tab: PokouTab.more,
                    child: const MarketplaceScreen(),
                  ),
                ),
              ),
            // ── Le carrousel : les annonces de ma zone, puis le rappel du
            // chiffrement.
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: HomeCarousel(onOpenTab: onOpenTab),
            ),
          ],
        ),
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
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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

/// La carte Discussions (maquette p.14) : titre, « Tout voir », et les deux
/// dernières discussions — Baba compris si c'est la plus récente.
class _DiscussionsCard extends ConsumerWidget {
  const _DiscussionsCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final discussions =
        (ref.watch(discussionsProvider).valueOrNull ??
                const <ConversationSummary>[])
            .where((d) => !d.isArchived)
            .toList();
    final unread = discussions.fold<int>(0, (s, d) => s + d.unreadCount);
    final recent = discussions.take(2).toList();
    return Column(
      children: [
        _SectionHeader(
          title: l.navChats,
          trailing: TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(unread > 0 ? l.homeSeeAllUnread('$unread') : l.homeSeeAll),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Card(
            padding: const EdgeInsets.symmetric(vertical: 4),
            onTap: recent.isEmpty ? onSeeAll : null,
            child: recent.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      l.homeNoChats,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: [
                      for (final (i, d) in recent.indexed) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: AppColors.border,
                          ),
                        _DiscussionRow(discussion: d),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// La carte Kory (maquette p.14) : « Kory · Cagnottes », « Tout voir », et
/// la cagnotte ouverte la plus proche de son échéance, s'il y en a une.
class _KoryCard extends ConsumerWidget {
  const _KoryCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final pots = ref.watch(koryPotsProvider).valueOrNull ?? const <KoryPot>[];
    final pot = pots.where((p) => p.isOpen).firstOrNull;
    return Column(
      children: [
        _SectionHeader(
          title: '${l.navKory} · ${l.homeKoryCardSubtitle}',
          trailing: TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l.homeSeeAll),
          ),
        ),
        if (pot != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _KoryInProgress(pot: pot),
          ),
      ],
    );
  }
}

/// La carte Honam (maquette p.14) : « Honam · Pharmacies », « Tout voir »,
/// et la commande en cours, s'il y en a une.
class _HonamCard extends ConsumerWidget {
  const _HonamCard({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final orders =
        ref.watch(honamOrdersProvider).valueOrNull ?? const <HonamOrder>[];
    final order = orders.where((o) => !o.isFinished).firstOrNull;
    return Column(
      children: [
        _SectionHeader(
          title: '${l.navHonam} · ${l.homeHonamCardSubtitle}',
          trailing: TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l.homeSeeAll),
          ),
        ),
        if (order != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HonamInProgress(order: order),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 12, 10),
    // Le titre à gauche, le lien à droite, sur la MÊME ligne médiane : le
    // lien flottait au-dessus du titre.
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              height: 1.3,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) trailing! else const SizedBox(width: 8),
      ],
    ),
  );
}

/// Carte blanche « Terre de Confiance » : 18 pt et un filet — à plat, sans
/// ombre. Les cartes ne flottent plus au-dessus du fond : elles y sont
/// posées, comme les cartes de services.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

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
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

/// Pastille de statut (« 65 % », « En livraison »).
class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.background, required this.ink});

  final String label;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.isDark ? ink.withValues(alpha: 0.2) : background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.isDark ? AppColors.textPrimary : ink,
      ),
    ),
  );
}

/// Surtitre coloré + icône teintée, en tête des cartes de module.
class _Overline extends StatelessWidget {
  const _Overline({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.overline,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String overline;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.isDark ? ink.withValues(alpha: 0.2) : tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: ink),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              overline,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class _KoryInProgress extends StatelessWidget {
  const _KoryInProgress({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final progress = pot.progress;
    final due = pot.dueAt;
    final daysLeft = due?.difference(DateTime.now()).inDays;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String? dueLabel;
    if (due != null) {
      try {
        dueLabel = l.koryDue(DateFormat('d MMM', locale).format(due));
      } catch (_) {
        dueLabel = l.koryDue(DateFormat('d/M').format(due));
      }
    }
    return _Card(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne du haut : le titre, et le temps qui reste en pastille.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.homeKoryInProgress,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (daysLeft != null && daysLeft >= 0) ...[
                const SizedBox(width: 8),
                _Chip(
                  l.homeDaysLeft(daysLeft),
                  background: AppColors.terracottaTint,
                  ink: AppColors.accentPrimaryDark,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Ligne du milieu : ce qui est réuni, et l'anneau de progression.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatFcfa(pot.confirmedTotal),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (pot.goalAmount != null)
                      Text(
                        l.koryOnGoal(formatFcfa(pot.goalAmount!)),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (progress != null) _ProgressRing(value: progress),
            ],
          ),
          const SizedBox(height: 12),
          // Ligne du bas : l'échéance, ou le rappel que l'argent ne passe
          // pas par Pokou.
          Row(
            children: [
              Icon(
                dueLabel != null
                    ? Icons.schedule
                    : Icons.verified_user_outlined,
                size: 16,
                color: dueLabel != null
                    ? AppColors.textMuted
                    : AppColors.feedbackSuccess,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dueLabel ?? l.homeKoryNoMoney,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// L'avancement en anneau, le pourcentage au centre.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final percent = (value.clamp(0, 1) * 100).round();
    return Semantics(
      label: '$percent %',
      child: SizedBox(
        width: 58,
        height: 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: value.clamp(0, 1).toDouble(),
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.surfaceElevated,
                color: AppColors.accentPrimary,
              ),
            ),
            ExcludeSemantics(
              child: Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HonamInProgress extends StatelessWidget {
  const _HonamInProgress({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _Card(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HonamOrderScreen(orderId: order.id)),
      ),
      child: _Overline(
        icon: Icons.delivery_dining_outlined,
        tint: const Color(0xFFDCFCE7),
        ink: AppColors.feedbackSuccess,
        overline: l.homeHonamInProgress,
        // Jamais un nom de médicament (HON-04) : la pharmacie et l'étape.
        title: order.pharmacy?.name ?? l.navHonam,
        trailing: _Chip(
          honamStatusLabel(l, order.status),
          background: const Color(0xFFFEF3C7),
          ink: AppColors.warning,
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
    return InkWell(
      onTap: () => openDiscussion(context, ref, d),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            ContactAvatar(avatar: d.avatar, displayName: d.name, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (last != null)
                    Text(
                      last.displayTextOf(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: unread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread
                          ? AppColors.accentPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                if (unread) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${d.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
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
