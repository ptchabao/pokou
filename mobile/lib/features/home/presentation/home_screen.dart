import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/contact_avatar.dart';
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
import '../../../core/widgets/pokou_illustration.dart';

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
    final unreadMessages = ref.watch(
      discussionsProvider.select(
        (async) => (async.valueOrNull ?? const <ConversationSummary>[])
            .where((d) => !d.isArchived)
            .fold<int>(0, (sum, d) => sum + d.unreadCount),
      ),
    );
    final services = <_Service>[
      if (config.has('kory'))
        _Service(
          title: l.navKory,
          pitch: l.homeKoryShort,
          illustration: PokouIllustrations.kory,
          tint: const Color(0xFFF9E4D6),
          darkTint: const Color(0xFF3A2A22),
          ink: AppColors.accentPrimaryDark,
          actionIcon: Icons.add,
          actionLabel: l.koryCreate,
          onAction: () => openKoryCreate(context, ref),
          onTap: () => onOpenTab(PokouTab.kory),
        ),
      if (config.has('honam'))
        _Service(
          title: l.navHonam,
          pitch: l.homeHonamShort,
          illustration: PokouIllustrations.honam,
          tint: const Color(0xFFDFF3E4),
          darkTint: const Color(0xFF1F2E24),
          ink: AppColors.feedbackSuccess,
          actionIcon: Icons.document_scanner_outlined,
          actionLabel: l.honamSend,
          onAction: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HonamSendScreen())),
          onTap: () => onOpenTab(PokouTab.honam),
        ),
      if (config.has('assime'))
        _Service(
          title: l.homeAssimeTitle,
          pitch: l.homeAssimeShort,
          illustration: PokouIllustrations.assime,
          tint: const Color(0xFFFCEFC7),
          darkTint: const Color(0xFF33290F),
          ink: AppColors.warning,
          actionIcon: Icons.arrow_forward,
          actionLabel: l.homeAssimeCta,
          onAction: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
        ),
    ];

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
            // ── En-tête : la salutation et l'état du jour à gauche, la
            // cloche et la photo à droite. Pas de barre de titre : l'onglet
            // dit déjà « Accueil ».
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: _Header(
                  firstName: firstName,
                  unreadMessages: unreadMessages,
                  bell: _Bell(
                    unread: unreadNotifications,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsCenterScreen(),
                      ),
                    ),
                  ),
                  avatar: user == null
                      ? null
                      : Semantics(
                          button: true,
                          label: l.navProfile,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: ContactAvatar(
                                avatar: user.avatar,
                                displayName: user.fullName ?? '',
                                size: 42,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            // ── Recherche en pilule, et Baba dans le carré sombre voisin.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _SearchRow(
                onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                ),
                onBaba: () =>
                    context.push('/chat/$kNoMonitor', extra: l.navBaba),
              ),
            ),
            // ── Les services, en grille de cartes pastel illustrées.
            if (services.isNotEmpty) ...[
              _SectionHeader(title: l.homeServicesTitle),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ServiceGrid(services: services),
              ),
            ],
            _InProgress(kory: config.has('kory'), honam: config.has('honam')),
            _RecentDiscussions(onSeeAll: () => onOpenTab(PokouTab.discussions)),
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

/// L'en-tête : « Bonjour Parrain » en gras, et dessous ce qui attend
/// aujourd'hui — les messages non lus, ou l'accroche quand tout est lu.
class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.unreadMessages,
    required this.bell,
    required this.avatar,
  });

  final String firstName;
  final int unreadMessages;
  final Widget bell;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isEmpty
                    ? l.homeHelloOverline
                    : l.homeGreeting(firstName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 26,
                  height: 1.2,
                  letterSpacing: -0.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                unreadMessages > 0
                    ? l.homeUnreadSummary(unreadMessages)
                    : l.homeTagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: unreadMessages > 0
                      ? AppColors.accentPrimaryDark
                      : AppColors.textSecondary,
                  fontWeight: unreadMessages > 0
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        bell,
        if (avatar != null) ...[const SizedBox(width: 4), avatar!],
        const SizedBox(width: 8),
      ],
    );
  }
}

/// La recherche en pilule, et à côté un carré sombre : Baba, l'assistant.
/// Le contraste du carré dit qu'il fait autre chose que chercher.
class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.onSearch, required this.onBaba});

  final VoidCallback onSearch;
  final VoidCallback onBaba;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.surface,
            shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onSearch,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.homeSearchEverything,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: l.homeBabaTitle,
          child: Semantics(
            button: true,
            label: l.navBaba,
            child: Material(
              // Ébène sur fond clair ; en sombre, l'ébène se fondrait dans
              // le fond — le carré passe à l'or, l'étoile à l'ébène.
              color: AppColors.isDark
                  ? AppColors.brandOr
                  : AppColors.brandEbene,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onBaba,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.isDark
                        ? AppColors.brandEbene
                        : AppColors.brandOr,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Service {
  const _Service({
    required this.title,
    required this.pitch,
    required this.illustration,
    required this.tint,
    required this.darkTint,
    required this.ink,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    required this.onTap,
  });

  final String title;
  final String pitch;
  final PokouIllustrations illustration;
  final Color tint;
  final Color darkTint;
  final Color ink;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onTap;
}

/// Les services en grille à deux colonnes. Un nombre impair : le dernier
/// prend toute la largeur, à l'horizontale, plutôt que de laisser un trou.
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.services});

  final List<_Service> services;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < services.length; i += 2) {
      final last = i + 1 >= services.length;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: last
              ? _ServiceTile(service: services[i], wide: true)
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _ServiceTile(service: services[i])),
                      const SizedBox(width: 12),
                      Expanded(child: _ServiceTile(service: services[i + 1])),
                    ],
                  ),
                ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// Une carte de service : fond pastel uni, le nom et sa promesse en haut,
/// l'illustration en bas, et un bouton rond pour l'action directe.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, this.wide = false});

  final _Service service;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.isDark ? service.darkTint : service.tint;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          service.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 19,
            height: 1.2,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          service.pitch,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.3,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
    final action = Tooltip(
      message: service.actionLabel,
      child: Semantics(
        button: true,
        label: service.actionLabel,
        child: Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: service.onAction,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(service.actionIcon, size: 20, color: service.ink),
            ),
          ),
        ),
      ),
    );
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: service.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: wide
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [text, const SizedBox(height: 12), action],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PokouIllustration(service.illustration, height: 104),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text,
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        action,
                        const Spacer(),
                        PokouIllustration(service.illustration, height: 88),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing, this.dot = false});

  final String title;
  final Widget? trailing;
  final bool dot;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 12, 10),
    // Le titre à gauche, le lien à droite, sur la MÊME ligne médiane : le
    // lien flottait au-dessus du titre.
    child: Row(
      children: [
        if (dot) ...[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accentPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
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
            padding: const EdgeInsets.only(right: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(unread > 0 ? l.homeSeeAllUnread('$unread') : l.homeSeeAll),
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
