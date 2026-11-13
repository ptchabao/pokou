import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/deeplink/invite_link_parser.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_illustration.dart';
import '../../../l10n/app_localizations.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_cotisation_screens.dart';
import 'kory_home_widgets.dart';
import 'kory_journal_screen.dart';
import 'kory_participants_screen.dart';
import 'kory_pay_screens.dart';
import 'kory_pledge_screens.dart';
import 'kory_review_screen.dart';
import 'kory_screen.dart';
import 'kory_tontine_screens.dart';
import 'kory_ui.dart';
import 'kory_wallet.dart';

/// Une collecte, quelle que soit sa nature : l'écran se choisit selon ce que
/// le serveur décrit — cagnotte (KOR-1), cotisation (KOR-20 / 21), tontine
/// (KOR-7, 8, 25). C'est l'entrée unique des liens, des notifications et
/// de la liste.
class KoryPotScreen extends ConsumerWidget {
  const KoryPotScreen({super.key, required this.potId});

  final int potId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(koryPotProvider(potId));
    final pot = async.valueOrNull;
    if (pot == null) {
      return KoryPage(
        title: l.koryTitle,
        loading: async.isLoading,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: KoryHomeMessage(
              illustration: PokouIllustrations.offline,
              title: l.koryUnavailable,
              message: l.modulesCheckNetwork,
              actions: [
                KoryHomePillButton(
                  icon: Icons.refresh,
                  label: l.actionRetry,
                  onPressed: () => refreshKory(ref, potId: potId),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final Widget screen = pot.isTontine
        ? KoryTontineScreen(pot: pot)
        : pot.isCotisation
        ? KoryCotisationScreen(pot: pot)
        : _CagnotteView(pot: pot);
    if (!pot.isFrozen) return screen;
    // Suspendue par l'équipe : un bandeau permanent dit pourquoi rien ne
    // répond plus (le serveur refuse tout geste, en 423).
    return Column(
      children: [
        Expanded(child: screen),
        Material(
          color: AppColors.securityWarning.withValues(alpha: 0.14),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    color: AppColors.securityWarning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.koryFrozenTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.koryFrozenBody(pot.frozenReason ?? '—'),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Partager le lien d'une cagnotte : le texte ET un lien direct, qui ouvre
/// l'invitation dans Pokou (KOR-10) ou propose d'installer l'application.
void koryShare(BuildContext context, KoryPot pot) {
  final l = L.of(context);
  Share.share(
    '${l.koryShareText(pot.title, pot.joinCode)}\n'
    '$pokouLinkBaseUrl/k/${Uri.encodeComponent(pot.joinCode)}',
  );
}

/// Peut-on déclarer un versement ? Ouvert, ou clôturé avec un reste à
/// verser sur son engagement (KOR-16) ; jamais le bénéficiaire d'un tour.
bool koryCanContribute(KoryPot pot) =>
    !pot.isFrozen &&
    (pot.isOpen || (pot.myPledge?.remaining ?? 0) > 0) &&
    !(pot.isTontine && pot.isCollector) &&
    !pot.isPending;

// ── KOR-1 · Cagnotte ─────────────────────────────────────────────────────

class _CagnotteView extends ConsumerWidget {
  const _CagnotteView({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final wallet = KoryWallet.of(pot.collectorPhone);
    final toConfirm = pot.declaredTotal - pot.confirmedTotal;
    final pending = pot.entries.where((e) => e.canReview && e.isPending).length;
    final manager = pot.isOrganizer || pot.isCollector;
    final caption = [
      if (pot.goalAmount != null) l.koryXOnGoalOf(formatFcfa(pot.goalAmount!)),
      if (pot.dueAt != null) l.koryXClosesOn(koryDay(context, pot.dueAt!)),
    ].join(' · ');
    return KoryPage(
      title: pot.title,
      subtitle: [l.koryKindCagnotte, ?pot.groupName].join(' · '),
      actions: [
        if (pot.joinCode.isNotEmpty)
          IconButton(
            tooltip: l.koryXShareLink,
            icon: const Icon(Icons.ios_share),
            onPressed: () => koryShare(context, pot),
          ),
        if (manager && pot.isOpen)
          IconButton(
            tooltip: l.koryFinishCta,
            icon: const Icon(Icons.lock_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => KoryFinishScreen(pot: pot)),
            ),
          ),
      ],
      footer: koryCanContribute(pot)
          ? KoryFooter(
              children: [
                KoryButton(
                  icon: Icons.volunteer_activism_outlined,
                  label: l.koryHomeContribute,
                  onPressed: () => openKoryContribute(
                    context,
                    ref,
                    pot,
                    amount: (pot.myPledge?.remaining ?? 0) > 0
                        ? pot.myPledge!.remaining
                        : null,
                  ),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          refreshKory(ref, potId: pot.id);
          await ref.read(koryPotProvider(pot.id).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            KoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KoryFigure(
                    label: l.koryTotalConfirmed,
                    amount: pot.confirmedTotal,
                    caption: caption.isEmpty ? null : caption,
                    trailing: koryOpenPill(l, pot),
                  ),
                  if (pot.progress != null) ...[
                    const SizedBox(height: 10),
                    KoryProgressBar(value: pot.progress!, muted: !pot.isOpen),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Les deux tuiles à la même hauteur, quelle que soit la précision.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Tile(
                      label: l.koryXDeclaredLabel,
                      value: formatFcfa(pot.declaredTotal),
                      caption: toConfirm > 0
                          ? l.koryXOfWhichToConfirm(formatFcfa(toConfirm))
                          : null,
                    ),
                  ),
                  if (pot.remainingToCollect != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Tile(
                        label: l.koryXRemainingLabel,
                        value: formatFcfa(pot.remainingToCollect!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            KoryCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  KoryPersonRow(
                    name: pot.isCollector
                        ? l.koryYou
                        : (pot.collectorName ?? '—'),
                    subtitle: pot.isCollector
                        ? l.koryCollectorIsYou
                        : l.koryXCollectorWallet(wallet?.label ?? '—'),
                  ),
                  if (pot.beneficiaryName != null)
                    KoryLine(l.koryXBeneficiary, pot.beneficiaryName!),
                  if (pot.description != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          pot.description!,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (pot.isCollector && pending > 0) ...[
              const SizedBox(height: 10),
              KoryActionRow(
                icon: Icons.hourglass_top,
                color: AppColors.securityWarning,
                title: l.koryXToConfirmCount('$pending'),
                subtitle: l.koryXCheckWalletShort,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => KoryReviewScreen(potId: pot.id),
                  ),
                ),
              ),
            ],
            KoryPledgeBlock(pot: pot),
            if (manager && pot.isOpen) ...[
              const SizedBox(height: 10),
              KoryActionRow(
                icon: Icons.group_add_outlined,
                title: l.koryParticipantsTitle,
                subtitle: l.koryParticipantsCount(pot.participantsCount),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        KoryParticipantsScreen(potId: pot.id, title: pot.title),
                  ),
                ),
              ),
            ],
            KoryJournalPreview(pot: pot),
            const SizedBox(height: 16),
            KoryNotice(text: l.koryNoMoney),
          ],
        ),
      ),
    );
  }
}

/// « Ouverte » / « Clôturée » : icône et mot, jamais la couleur seule.
Widget koryOpenPill(L l, KoryPot pot) => pot.isOpen
    ? KoryStatusPill(
        icon: Icons.lock_open,
        label: l.koryOpen,
        color: AppColors.feedbackSuccess,
      )
    : KoryStatusPill(
        icon: Icons.lock_outline,
        label: pot.isDissolved ? l.koryXDissolved : l.koryClosed,
        color: AppColors.textSecondary,
      );

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => KoryCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
      ],
    ),
  );
}

/// Une ligne qui mène ailleurs : icône, titre, précision, chevron.
class KoryActionRow extends StatelessWidget {
  const KoryActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => KoryCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: color ?? AppColors.accentPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
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

/// L'engagement dans la cagnotte : s'engager (KOR-12), suivre son
/// engagement (KOR-13 / 14), verser la fin après la clôture (KOR-16) ; pour
/// le collecteur, clôturer ou prolonger à la date de fin (KOR-15).
class KoryPledgeBlock extends ConsumerWidget {
  const KoryPledgeBlock({super.key, required this.pot});

  final KoryPot pot;

  Future<void> _open(BuildContext context, WidgetRef ref, Widget screen) async {
    final next = await Navigator.of(
      context,
    ).push<Object?>(MaterialPageRoute(builder: (_) => screen));
    if (next == KoryNextStep.pay && context.mounted) {
      final remaining = pot.myPledge?.remaining ?? 0;
      await openKoryContribute(
        context,
        ref,
        pot,
        amount: remaining > 0 ? remaining : null,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pot.isTontine) return const SizedBox.shrink();
    final l = L.of(context);
    final mine = pot.myPledge;
    final children = <Widget>[];

    if (pot.isDue && (pot.isCollector || pot.isOrganizer)) {
      children.add(
        KoryNotice(
          tone: KoryTone.warning,
          text: l.koryFinishDueNotice,
          children: [
            const SizedBox(height: 10),
            KoryButton(
              label: l.koryFinishCta,
              onPressed: () => _open(context, ref, KoryFinishScreen(pot: pot)),
            ),
          ],
        ),
      );
    }

    if (!pot.isOpen && mine != null && mine.remaining > 0) {
      children.add(
        KoryActionRow(
          icon: Icons.lock_clock_outlined,
          title: l.koryClosedTitle,
          subtitle: l.koryPayAmount(formatFcfa(mine.remaining)),
          onTap: () => _open(context, ref, KoryClosedScreen(pot: pot)),
        ),
      );
      // L'initiateur participe comme les autres : il peut s'engager aussi.
    } else if (pot.isOpen && !pot.isCotisation) {
      if (mine == null) {
        children.add(
          KoryButton(
            quiet: true,
            icon: Icons.handshake_outlined,
            label: l.koryPledgeTitle,
            onPressed: () => _open(context, ref, KoryPledgeScreen(pot: pot)),
          ),
        );
      } else {
        children.add(
          KoryActionRow(
            icon: Icons.handshake_outlined,
            title: l.koryXMyPledgeAmount(formatFcfa(mine.total)),
            subtitle: mine.isFirm
                ? l.koryXFirmRemaining(formatFcfa(mine.remaining))
                : l.koryXEditableRemaining(formatFcfa(mine.remaining)),
            onTap: () => _open(context, ref, KoryMyPledgeScreen(potId: pot.id)),
          ),
        );
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children) ...[c, const SizedBox(height: 10)],
        ],
      ),
    );
  }
}

/// Le journal en bref : les dernières contributions, puis « Voir tout ».
class KoryJournalPreview extends StatelessWidget {
  const KoryJournalPreview({super.key, required this.pot, this.limit = 4});

  final KoryPot pot;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    void openJournal() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => KoryJournalScreen(potId: pot.id)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KorySection(
          l.koryJournalTab,
          trailing: l.koryXContributionsCount(pot.entries.length),
          onTrailing: openJournal,
        ),
        if (pot.entries.isEmpty)
          Text(
            l.koryJournalEmpty,
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final entry in pot.entries.take(limit))
                  KoryEntryRow(pot: pot, entry: entry),
              ],
            ),
          ),
        if (pot.entries.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: openJournal,
              child: Text(l.koryXSeeJournal),
            ),
          ),
      ],
    );
  }
}

/// Une contribution : qui, quand, combien, son statut. Ma contribution
/// contestée s'ouvre sur ce que je peux faire (KOR-5).
class KoryEntryRow extends StatelessWidget {
  const KoryEntryRow({super.key, required this.pot, required this.entry});

  final KoryPot pot;
  final KoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final subtitle = [
      koryRelative(context, entry.declaredAt),
      if (entry.roundNumber != null) l.koryRoundNumber('${entry.roundNumber}'),
      if (entry.periodLabel != null) entry.periodLabel!,
    ].join(' · ');
    return KoryPersonRow(
      name: entry.isMine ? l.koryYou : (entry.contributorName ?? '—'),
      subtitle: subtitle,
      onTap: entry.isMine && entry.isContested && pot.isOpen
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => KoryContestedScreen(pot: pot, entry: entry),
              ),
            )
          : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            entry.amountHidden ? '•••' : formatFcfa(entry.amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          koryStatusPill(l, entry.status),
        ],
      ),
    );
  }
}

/// « il y a 2 h », ou le jour et l'heure.
String koryRelative(BuildContext context, DateTime at) {
  final l = L.of(context);
  final diff = DateTime.now().difference(at.toLocal());
  if (diff.inMinutes < 60) {
    return l.koryXMinutesAgo(diff.inMinutes.clamp(1, 59));
  }
  if (diff.inHours < 24) return l.koryXHoursAgo(diff.inHours);
  return '${koryDay(context, at)} · ${koryTime(at)}';
}
