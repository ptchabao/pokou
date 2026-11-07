import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../chat/presentation/chat_controller.dart';
import '../../contacts/data/conversation_summary.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../../contacts/presentation/open_discussion.dart';
import '../../honam/data/honam_models.dart';
import '../../honam/presentation/honam_controller.dart';
import '../../honam/presentation/honam_order_screen.dart';
import '../../honam/presentation/honam_send_screen.dart';
import '../../kory/data/kory_model.dart';
import '../../kory/presentation/kory_controller.dart';
import '../../kory/presentation/kory_create_screen.dart';
import '../../kory/presentation/kory_pot_screen.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../../notifications/presentation/notifications_center_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'global_search_screen.dart';

/// APP-1 · Accueil — maquette « Terre de Confiance » (Stitch) :
///
/// 1. la salutation, avec la recherche ;
/// 2. Baba, en un geste ;
/// 3. « En cours » : la cagnotte ouverte et la commande qui avance ;
/// 4. les dernières discussions ;
/// 5. « Que veux-tu faire ? » : une carte par service, action directe ;
/// 6. le rappel du chiffrement.
///
/// Les cartes ne s'affichent que pour les modules ouverts dans le pays.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<PokouTab> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final config = ref.watch(currentCountryConfigProvider);
    final user = ref.watch(authControllerProvider).user;
    final firstName = (user?.fullName ?? '').split(' ').first;
    final unreadNotifications =
        ref.watch(serviceNotificationsProvider).valueOrNull?.unread ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discussionsProvider);
          ref.invalidate(countryConfigProvider);
          ref.invalidate(serviceNotificationsProvider);
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
                // NOT-1 : la cloche ouvre le centre de notifications.
                _Bell(
                  unread: unreadNotifications,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsCenterScreen(),
                    ),
                  ),
                ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _GreetingCard(
                firstName: firstName.isEmpty ? l.navHome : firstName,
                onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _BabaBanner(
                onTap: () => context.push(
                  '/chat/$kNoMonitor',
                  extra: l.navBaba,
                ),
              ),
            ),
            _InProgress(
              kory: config.has('kory'),
              honam: config.has('honam'),
            ),
            _RecentDiscussions(
              onSeeAll: () => onOpenTab(PokouTab.discussions),
            ),
            _SectionHeader(
              title: l.homeWhatToDo,
              subtitle: l.homeServicesSub,
            ),
            if (config.has('kory'))
              _ServiceCard(
                icon: Icons.savings_outlined,
                tint: AppColors.terracottaTint,
                ink: AppColors.accentPrimaryDark,
                overline: l.homeKoryOverline,
                title: l.navKory,
                pitch: l.homeKoryPitch,
                cta: _ServiceCta.primary(
                  label: l.koryCreate,
                  icon: Icons.add_circle_outline,
                  onPressed: () => openKoryCreate(context, ref),
                ),
                onTap: () => onOpenTab(PokouTab.kory),
              ),
            if (config.has('honam'))
              _ServiceCard(
                icon: Icons.health_and_safety_outlined,
                tint: const Color(0xFFDCFCE7),
                ink: AppColors.feedbackSuccess,
                overline: l.homeHonamOverline,
                title: l.navHonam,
                pitch: l.homeHonamPitch,
                cta: _ServiceCta.secondary(
                  label: l.honamSend,
                  icon: Icons.document_scanner_outlined,
                  iconColor: AppColors.feedbackSuccess,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HonamSendScreen()),
                  ),
                ),
                onTap: () => onOpenTab(PokouTab.honam),
              ),
            if (config.has('assime'))
              _ServiceCard(
                icon: Icons.storefront_outlined,
                tint: const Color(0xFFFEF3C7),
                ink: AppColors.warning,
                overline: l.homeAssimeOverline,
                title: l.homeAssimeTitle,
                pitch: l.homeAssimePitch,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: _TrustCard(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cloche avec pastille de non-lues (NOT-1).
class _Bell extends StatelessWidget {
  const _Bell({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: L.of(context).notifCenterTitle,
    onPressed: onTap,
    icon: Badge(
      isLabelVisible: unread > 0,
      backgroundColor: AppColors.accentPrimary,
      label: Text(unread > 9 ? '9+' : '$unread'),
      child: const Icon(Icons.notifications_none_outlined),
    ),
  );
}

/// La salutation : surtitre avec la date, le prénom, l'accroche, puis la
/// recherche — en pastille blanche dans la carte.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.firstName, required this.onSearch});

  final String firstName;
  final VoidCallback onSearch;

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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: AppGradients.greeting,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l.homeHelloOverline.toUpperCase()} • ${today.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            firstName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 32,
              height: 1.15,
              letterSpacing: -0.6,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.homeTagline,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.surface,
            shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onSearch,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.homeSearchEverything,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Besoin d'un coup de main ? » — Baba en un geste (ambre, jamais violet).
class _BabaBanner extends StatelessWidget {
  const _BabaBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      color: AppColors.isDark
          ? AppColors.brandOr.withValues(alpha: 0.16)
          : const Color(0xFFFEF3C7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppColors.isDark
              ? AppColors.brandOr.withValues(alpha: 0.4)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.brandOr,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF3B2A00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.homeBabaTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      l.homeBabaSub,
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
        ),
      ),
    );
  }
}

/// Un titre de section, avec un sous-titre ou une action à droite.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.dot = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool dot;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (dot) ...[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(bottom: 7),
            decoration: const BoxDecoration(
              color: AppColors.accentPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Carte blanche « Terre de Confiance » : 18 pt, filet, ombre double.
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
      boxShadow: AppElevation.card,
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

/// « En cours » : la cagnotte ouverte et la commande Honam qui avance.
/// Rien quand il n'y a rien à suivre — l'Accueil ne montre pas de vide.
class _InProgress extends ConsumerWidget {
  const _InProgress({required this.kory, required this.honam});

  final bool kory;
  final bool honam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final pots = kory
        ? (ref.watch(koryPotsProvider).valueOrNull ?? const <KoryPot>[])
        : const <KoryPot>[];
    final orders = honam
        ? (ref.watch(honamOrdersProvider).valueOrNull ?? const <HonamOrder>[])
        : const <HonamOrder>[];
    final pot = pots.where((p) => p.isOpen).firstOrNull;
    final order = orders.where((o) => !o.isFinished).firstOrNull;
    final count = (pot == null ? 0 : 1) + (order == null ? 0 : 1);
    if (count == 0) return const SizedBox.shrink();
    return Column(
      children: [
        _SectionHeader(
          title: l.homeInProgress,
          dot: true,
          trailing: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              l.homeAlertsActive(count),
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ),
        if (pot != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _KoryInProgress(pot: pot),
          ),
        if (order != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _HonamInProgress(order: order),
          ),
      ],
    );
  }
}

class _KoryInProgress extends StatelessWidget {
  const _KoryInProgress({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final progress = pot.progress;
    return _Card(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Overline(
            icon: Icons.savings_outlined,
            tint: AppColors.terracottaTint,
            ink: AppColors.accentPrimaryDark,
            overline: l.homeKoryInProgress,
            title: pot.title,
            trailing: progress == null
                ? null
                : _Chip(
                    '${(progress * 100).round()} %',
                    background: AppColors.terracottaTint,
                    ink: AppColors.accentPrimaryDark,
                  ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppColors.surfaceElevated,
                color: AppColors.accentPrimary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                formatFcfa(pot.confirmedTotal),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (pot.goalAmount != null)
                Text(
                  l.koryOnGoal(formatFcfa(pot.goalAmount!)),
                  style: TextStyle(color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppColors.feedbackSuccess,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.homeKoryNoMoney,
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

/// Les dernières discussions, dans une carte blanche ; toucher ouvre la
/// discussion directement.
class _RecentDiscussions extends ConsumerWidget {
  const _RecentDiscussions({required this.onSeeAll});

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
    final recent = discussions.take(3).toList();
    return Column(
      children: [
        _SectionHeader(
          title: l.navChats,
          trailing: TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  unread > 0 ? l.homeSeeAllUnread('$unread') : l.homeSeeAll,
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
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

/// L'action d'une carte de service : pleine (Kory) ou beige (Honam).
class _ServiceCta {
  const _ServiceCta.primary({
    required this.label,
    required this.icon,
    required this.onPressed,
  }) : primary = true,
       iconColor = null;

  const _ServiceCta.secondary({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconColor,
  }) : primary = false;

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final Color? iconColor;
}

/// Carte de service : icône teintée, surtitre, nom en grand, promesse, et
/// une action directe en pleine largeur — sans écran intermédiaire.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.overline,
    required this.title,
    required this.pitch,
    required this.onTap,
    this.cta,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String overline;
  final String title;
  final String pitch;
  final VoidCallback onTap;
  final _ServiceCta? cta;

  @override
  Widget build(BuildContext context) {
    final action = cta;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: _Card(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.isDark ? ink.withValues(alpha: 0.2) : tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 26, color: ink),
                ),
                const Spacer(),
                if (action == null)
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 12),
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
              style: TextStyle(
                fontSize: 22,
                height: 1.2,
                letterSpacing: -0.3,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pitch,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: action.primary
                        ? AppColors.accentPrimary
                        : AppColors.surfaceElevated,
                    foregroundColor: action.primary
                        ? Colors.white
                        : AppColors.textPrimary,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: action.onPressed,
                  icon: Icon(action.icon, size: 20, color: action.iconColor),
                  label: Text(action.label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le rappel du chiffrement, en bas de l'Accueil.
class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        gradient: AppGradients.certified,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.homeTrustOverline,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandOr,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.homeTrustBody,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFF9E5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.lock_outline, color: AppColors.brandOr, size: 28),
        ],
      ),
    );
  }
}
