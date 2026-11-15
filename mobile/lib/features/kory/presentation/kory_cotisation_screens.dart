import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_create_screen.dart';
import 'kory_draft.dart';
import 'kory_journal_screen.dart';
import 'kory_participants_screen.dart';
import 'kory_pay_screens.dart';
import 'kory_pledge_screens.dart';
import 'kory_pot_screen.dart';
import 'kory_review_screen.dart';
import 'kory_screen.dart';
import 'kory_ui.dart';
import 'kory_wallet.dart';

String koryPeriodLabel(L l, String? period) => switch (period) {
  'WEEKLY' => l.koryPeriodWeekly,
  'BIWEEKLY' => l.koryXPeriodBiweekly,
  'QUARTERLY' => l.koryXPeriodQuarterly,
  _ => l.koryPeriodMonthly,
};

/// Une cotisation : la vue de l'organisateur (KOR-20) ou celle du membre
/// (KOR-21), selon qui regarde.
class KoryCotisationScreen extends ConsumerWidget {
  const KoryCotisationScreen({super.key, required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return pot.isAdmin || pot.isCollector
        ? _OrganizerView(pot: pot)
        : _MemberView(pot: pot);
  }
}

// ── KOR-20 · Suivi de la cotisation (organisateur) ───────────────────────

class _OrganizerView extends ConsumerStatefulWidget {
  const _OrganizerView({required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<_OrganizerView> createState() => _OrganizerViewState();
}

class _OrganizerViewState extends ConsumerState<_OrganizerView> {
  bool _reminding = false;

  Future<void> _remind() async {
    final l = L.of(context);
    setState(() => _reminding = true);
    try {
      final count = await ref
          .read(koryRepositoryProvider)
          .remind(widget.pot.id);
      refreshKory(ref, potId: widget.pot.id);
      if (mounted) koryToast(context, l.koryXReminded(count));
    } catch (_) {
      if (mounted) koryToast(context, l.koryXRemindTooSoon);
    } finally {
      if (mounted) setState(() => _reminding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final block = pot.cotisation;
    final current = block?.current;
    final pending = [
      for (final e in pot.entries)
        if (e.canReview && e.isPending) e,
    ];
    final mine = block?.myNext;
    return KoryPage(
      title: pot.title,
      subtitle: [
        l.koryKindCotisation,
        if (pot.amountPerMember != null)
          l.koryPerMember(
            formatFcfa(pot.amountPerMember!),
            koryPeriodLabel(l, pot.period),
          ),
        l.koryXOrganizerSide,
      ].join(' · '),
      actions: [
        if (pot.joinCode.isNotEmpty && pot.isOpen)
          IconButton(
            tooltip: l.koryXShareLink,
            icon: const Icon(Icons.ios_share),
            onPressed: () => koryShare(context, pot),
          ),
      ],
      // La maquette : « Journal » à contour, puis « Modifier ou arrêter la
      // cotisation » en lien ; « Contribuer » d'abord si je cotise aussi.
      footer: KoryFooter(
        children: [
          if (pot.isOpen &&
              block?.isMember == true &&
              mine != null &&
              !pot.isCollector) ...[
            KoryButton(
              label: l.koryXContributeAmount(formatFcfa(mine.amount)),
              onPressed: () =>
                  openKoryContribute(context, ref, pot, amount: mine.amount),
            ),
            const SizedBox(height: 8),
          ],
          KoryButton(
            outlined: true,
            label: l.koryJournalTab,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => KoryJournalScreen(potId: pot.id),
              ),
            ),
          ),
          if (pot.isOpen && pot.isAdmin)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KoryCotisationEditScreen(pot: pot),
                ),
              ),
              child: Text(l.koryXEditCotisation),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshKory(ref, potId: pot.id);
          await ref.read(koryPotProvider(pot.id).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (current != null)
              KoryCard(
                color: AppColors.terracottaTint.withValues(alpha: 0.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.koryXDueOn(
                        koryMonth(context, current.dueAt),
                        koryDay(context, current.dueAt),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      l.koryMqAmountConfirmed(
                        formatFcfa(current.confirmedTotal),
                      ),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      l.koryMqOnPlanned(formatFcfa(current.expectedTotal)),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Progress(
                      value: current.expectedTotal == 0
                          ? 0
                          : current.confirmedTotal / current.expectedTotal,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.koryMqPeriodCounts(
                        '${current.upToDateCount}',
                        '${current.toConfirmCount}',
                        '${current.lateCount}',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              KoryNotice(text: l.koryXNoDueYet),
            KorySection(l.koryXToConfirmCount('${pending.length}')),
            if (pending.isEmpty)
              Text(
                l.koryXNothingToConfirm,
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              for (final entry in pending)
                KoryReviewTile(key: ValueKey(entry.id), pot: pot, entry: entry),
            if (current != null && current.lateCount > 0) ...[
              const SizedBox(height: 10),
              // « En retard · 3 … Komi T., Abla G., Séna K. »
              KoryCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: KoryLine(
                  l.koryXLateCount('${current.lateCount}'),
                  current.late.map((m) => m.name ?? '—').join(', '),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pot.remindedAt == null
                          ? l.koryXRemindHint
                          : l.koryXRemindedAt(
                              koryDay(context, pot.remindedAt!),
                              koryTime(pot.remindedAt!),
                            ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: pot.isOpen && !_reminding ? _remind : null,
                    child: Text(l.koryXRemindLate),
                  ),
                ],
              ),
            ],
            if (block != null && block.history.isNotEmpty) ...[
              KorySection(
                pot.period == 'MONTHLY'
                    ? l.koryMqPreviousMonths
                    : l.koryXPreviousDues,
              ),
              KoryCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (final past in block.history)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    koryMonth(context, past.dueAt),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    l.koryXPaidOf(
                                      '${past.paidCount}',
                                      '${past.membersCount}',
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            past.paidCount >= past.membersCount
                                ? KoryStatusPill(
                                    icon: Icons.check_circle,
                                    label: l.koryXUpToDate,
                                    color: AppColors.feedbackSuccess,
                                  )
                                : koryStatusPill(l, 'LATE'),
                            if (past.contestedCount > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                l.koryXContestedCount(past.contestedCount),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.securityCritical,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (pot.isOpen && pot.isAdmin) ...[
              const SizedBox(height: 16),
              KoryActionRow(
                icon: Icons.group_add_outlined,
                title: l.koryXMembersCount(block?.membersCount ?? 0),
                subtitle: l.koryXAddMemberHint,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        KoryParticipantsScreen(potId: pot.id, title: pot.title),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1).toDouble(),
      minHeight: 8,
      backgroundColor: AppColors.surfaceElevated,
      color: AppColors.accentPrimary,
    ),
  );
}

// ── KOR-21 · Ma cotisation (membre) ──────────────────────────────────────

class _MemberView extends ConsumerWidget {
  const _MemberView({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final block = pot.cotisation;
    final next = block?.myNext;
    final wallet = KoryWallet.of(pot.collectorPhone);
    final days = next == null
        ? null
        : DateUtils.dateOnly(
            next.dueAt.toLocal(),
          ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    return KoryPage(
      title: pot.title,
      subtitle: [l.koryKindCotisation, ?pot.groupName].join(' · '),
      // « Contribuer », puis « Journal de la cotisation » en lien dessous.
      footer: KoryFooter(
        children: [
          if (pot.isOpen && next != null)
            KoryButton(
              label: l.koryXContributeAmount(formatFcfa(next.amount)),
              onPressed: () =>
                  openKoryContribute(context, ref, pot, amount: next.amount),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => KoryJournalScreen(potId: pot.id),
              ),
            ),
            child: Text(l.koryXCotisationJournal),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshKory(ref, potId: pot.id);
          await ref.read(koryPotProvider(pot.id).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (next != null)
              KoryCard(
                child: KoryFigure(
                  label: days == null || days < 0
                      ? l.koryXOverdueSince(koryDay(context, next.dueAt))
                      : l.koryXNextDueIn(days, koryDay(context, next.dueAt)),
                  amount: next.amount,
                  caption: l.koryXPlannedTo(pot.collectorName ?? '—'),
                  trailing: koryStatusPill(l, next.status),
                ),
              )
            else
              KoryNotice(
                tone: KoryTone.success,
                text: pot.isOpen ? l.koryXAllPaid : l.koryXCotisationStopped,
              ),
            const SizedBox(height: 10),
            KoryCard(
              child: Column(
                children: [
                  KoryLine(
                    l.koryXCollectorLabel,
                    [pot.collectorName ?? '—', ?wallet?.shortLabel].join(' · '),
                  ),
                  if (pot.amountPerMember != null)
                    KoryLine(
                      l.koryXAmountLabel,
                      // « 5 000 FCFA, le 10 de chaque mois »
                      pot.period == 'MONTHLY' && pot.dueAt != null
                          ? l.koryMqAmountMonthlyOn(
                              formatFcfa(pot.amountPerMember!),
                              '${pot.dueAt!.toLocal().day}',
                            )
                          : l.koryPerMember(
                              formatFcfa(pot.amountPerMember!),
                              koryPeriodLabel(l, pot.period),
                            ),
                    ),
                  KoryLine(
                    l.koryXMembersLabel,
                    '${block?.membersCount ?? 0} · ${pot.amountsVisible ? l.koryXVisibleToAll : l.koryXVisibleToCollector}',
                  ),
                  if (pot.endsAt != null)
                    KoryLine(l.koryXLastDue, koryDate(context, pot.endsAt!)),
                ],
              ),
            ),
            if (block != null && block.myPeriods.isNotEmpty) ...[
              KorySection(l.koryXMyDues),
              KoryCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (final period in block.myPeriods)
                      _MyPeriodRow(period: period),
                  ],
                ),
              ),
            ],
            for (final entry in pot.entries)
              if (entry.isMine && entry.isContested && pot.isOpen) ...[
                const SizedBox(height: 10),
                KoryActionRow(
                  icon: Icons.report_gmailerrorred_outlined,
                  color: AppColors.securityCritical,
                  title: l.koryContestedTitle,
                  subtitle: formatFcfa(entry.amount),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          KoryContestedScreen(pot: pot, entry: entry),
                    ),
                  ),
                ),
              ],
            // KOR-21 : « Rappels de cette cotisation » — J−2, jour J et
            // relance J+1, envoyés par le serveur ; chacun peut les couper.
            if (pot.cotisation?.isMember ?? false) ...[
              const SizedBox(height: 10),
              KoryCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l.koryMqRemindersTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(l.koryMqRemindersSub),
                  value: pot.cotisation!.myReminders,
                  onChanged: pot.isFrozen
                      ? null
                      : (on) async {
                          try {
                            await ref
                                .read(koryRepositoryProvider)
                                .setReminders(pot.id, enabled: on);
                            refreshKory(ref, potId: pot.id);
                          } catch (_) {
                            if (context.mounted) koryFailed(context);
                          }
                        },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MyPeriodRow extends StatelessWidget {
  const _MyPeriodRow({required this.period});

  final KoryMyPeriod period;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final when = period.declaredAt ?? period.dueAt;
    final detail = [
      l.koryXOnDay(koryDay(context, when)),
      if (period.walletReference != null)
        l.koryXRefShort(period.walletReference!),
      if (period.wasContested) l.koryXContestedThenConfirmed,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  koryMonth(context, period.dueAt),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatFcfa(period.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              koryStatusPill(l, period.status),
            ],
          ),
        ],
      ),
    );
  }
}

// ── KOR-22 · Modifier la cotisation ──────────────────────────────────────

class KoryCotisationEditScreen extends ConsumerStatefulWidget {
  const KoryCotisationEditScreen({super.key, required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<KoryCotisationEditScreen> createState() =>
      _KoryCotisationEditScreenState();
}

class _KoryCotisationEditScreenState
    extends ConsumerState<KoryCotisationEditScreen> {
  String _action = 'AMOUNT';
  late final _amount = TextEditingController(
    text: '${widget.pot.amountPerMember ?? ''}',
  );
  int? _collector;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = L.of(context);
    final pot = widget.pot;
    final amount = int.tryParse(_amount.text);
    if (_action == 'AMOUNT' && (amount == null || amount < 100)) {
      koryToast(context, l.koryNeedAmount);
      return;
    }
    if (_action == 'COLLECTOR' && _collector == null) {
      koryToast(context, l.koryXPickCollector);
      return;
    }
    if (_action == 'STOP') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.koryXStopCotisation),
          content: Text(l.koryXStopConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.koryXStopCotisation),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(koryRepositoryProvider)
          .changeCotisation(
            pot.id,
            _action,
            amount: _action == 'AMOUNT' ? amount : null,
            collectorId: _action == 'COLLECTOR' ? _collector : null,
          );
      refreshKory(ref, potId: pot.id);
      if (!mounted) return;
      koryToast(context, l.koryXSavedAndNotified);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      koryFailed(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final block = pot.cotisation;
    final current = block?.current;
    final next = block?.nextPeriodDue;
    final count = block?.membersCount ?? 0;
    final me = ref.watch(authControllerProvider).user?.id;
    return KoryPage(
      title: l.koryXEditCotisationTitle,
      subtitle: pot.title,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.koryXSaveAndNotify(count),
            busy: _busy,
            danger: _action == 'STOP',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l.koryXWhatToChange,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          KoryChoice(
            selected: _action == 'AMOUNT',
            title: l.koryXChangeAmount,
            subtitle: next == null
                ? null
                : l.koryXFromDueOf(koryDay(context, next)),
            onTap: () => setState(() => _action = 'AMOUNT'),
            child: TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.koryXNewAmountPerMember,
                suffixText: 'FCFA',
              ),
            ),
          ),
          if (next != null)
            KoryChoice(
              selected: _action == 'PAUSE',
              title: l.koryXPause,
              subtitle: l.koryXPauseSub(koryDay(context, next)),
              onTap: () => setState(() => _action = 'PAUSE'),
            ),
          KoryChoice(
            selected: _action == 'STOP',
            title: l.koryXStopCotisation,
            subtitle: current == null
                ? null
                : l.koryXLastDueOn(koryDay(context, current.dueAt)),
            onTap: () => setState(() => _action = 'STOP'),
          ),
          // « Changer de collecteur » : une ligne à chevron à part ; le
          // choix du nouveau collecteur s'ouvre dessous.
          KoryActionRow(
            icon: Icons.swap_horiz,
            title: l.koryXChangeCollector,
            subtitle: l.koryMqChangeCollectorSub,
            onTap: () => setState(() => _action = 'COLLECTOR'),
          ),
          if (_action == 'COLLECTOR')
            Column(
              children: [
                for (final m
                    in block?.members ?? const <KoryContributorState>[])
                  if (m.userId != pot.collectorId)
                    KoryPersonRow(
                      name: m.userId == me ? l.koryYou : (m.name ?? '—'),
                      onTap: () => setState(() => _collector = m.userId),
                      trailing: Icon(
                        _collector == m.userId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _collector == m.userId
                            ? AppColors.accentPrimary
                            : AppColors.textMuted,
                      ),
                    ),
              ],
            ),
          const SizedBox(height: 10),
          KoryNotice(
            text: l.koryXEditNotice(
              count,
              current == null
                  ? '—'
                  : koryMonth(context, current.dueAt).toLowerCase(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── KOR-18 · Membres de la cotisation (création) ─────────────────────────

class KoryCotisationMembersScreen extends ConsumerStatefulWidget {
  const KoryCotisationMembersScreen({super.key, required this.draft});

  final KoryDraft draft;

  @override
  ConsumerState<KoryCotisationMembersScreen> createState() =>
      _KoryCotisationMembersScreenState();
}

class _KoryCotisationMembersScreenState
    extends ConsumerState<KoryCotisationMembersScreen> {
  bool _everyone = true;
  bool _expanded = false;
  bool _outsiders = false;
  late Set<int> _chosen = {
    for (final m in widget.draft.group?.members ?? const []) m.userId,
  };
  int? _deputy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final draft = widget.draft;
    final group = draft.group!;
    final me = ref.watch(authControllerProvider).user?.id;
    final members = group.members;
    final chosen = _everyone ? {for (final m in members) m.userId} : _chosen;
    final count = chosen.length;
    // Moi, le co-organisateur, puis les autres ; repli « et N autres
    // membres » au-delà de quatre lignes, sauf quand on choisit.
    final ordered = [
      ...members.where((m) => m.userId == me),
      ...members.where((m) => m.userId == _deputy && m.userId != me),
      ...members.where((m) => m.userId != me && m.userId != _deputy),
    ];
    final fold = _everyone && !_expanded && ordered.length > 5;
    final visible = fold ? ordered.take(4).toList() : ordered;
    final hidden = fold ? ordered.length - 4 : 0;
    return KoryPage(
      title: l.koryXMembersTitle,
      subtitle: l.koryStepOf('2', draft.title, '3'),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.koryXContinueWithMembers(count),
            onPressed: count < 1
                ? null
                : () async {
                    draft.memberIds = chosen.toList();
                    draft.deputyId = chosen.contains(_deputy) ? _deputy : null;
                    final potId = await Navigator.of(context).push<int>(
                      MaterialPageRoute(
                        builder: (_) => KoryCotisationRecapScreen(draft: draft),
                      ),
                    );
                    if (potId == null || !context.mounted) return;
                    // « Ajouter hors du groupe » : par leur numéro, une fois
                    // la cotisation créée (il faut son lien pour inviter).
                    if (_outsiders) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KoryParticipantsScreen(
                            potId: potId,
                            title: draft.title,
                          ),
                        ),
                      );
                    }
                    if (context.mounted) Navigator.of(context).pop(potId);
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryChoice(
            selected: _everyone,
            title: l.koryXAllGroupMembers,
            subtitle: l.koryXGroupPeople(members.length, group.name),
            onTap: () => setState(() => _everyone = true),
          ),
          KoryChoice(
            selected: !_everyone,
            title: l.koryXChooseMembers,
            subtitle: l.koryXChooseMembersSub,
            onTap: () => setState(() => _everyone = false),
          ),
          KorySection(
            l.koryXConcernedMembers(count),
            trailing: _outsiders ? l.koryMqOutsidersAfter : l.koryMqAddOutside,
            onTrailing: () => setState(() => _outsiders = !_outsiders),
          ),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final m in visible)
                  KoryPersonRow(
                    name: m.userId == me ? l.koryYou : m.displayName,
                    subtitle: m.userId == me
                        ? l.koryXOrganizerCollector
                        : m.userId == _deputy
                        ? l.koryXCoOrganizer
                        : l.koryMqOnPokou,
                    onTap: _everyone
                        ? null
                        : () => setState(() {
                            _chosen = {..._chosen};
                            if (m.userId == me) return;
                            _chosen.contains(m.userId)
                                ? _chosen.remove(m.userId)
                                : _chosen.add(m.userId);
                          }),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // « Confirme » : ceux qui confirment les réceptions.
                        if (m.userId == me || m.userId == _deputy)
                          KoryStatusPill(
                            icon: Icons.fact_check_outlined,
                            label: l.koryMqConfirms,
                            color: AppColors.accentPrimary,
                          ),
                        if (m.userId != me && chosen.contains(m.userId))
                          IconButton(
                            tooltip: l.koryXMakeCoOrganizer,
                            icon: Icon(
                              m.userId == _deputy
                                  ? Icons.verified_user
                                  : Icons.verified_user_outlined,
                              color: m.userId == _deputy
                                  ? AppColors.accentPrimary
                                  : AppColors.textMuted,
                            ),
                            onPressed: () => setState(
                              () => _deputy = _deputy == m.userId
                                  ? null
                                  : m.userId,
                            ),
                          ),
                        Checkbox(
                          value: chosen.contains(m.userId),
                          onChanged: _everyone || m.userId == me
                              ? null
                              : (v) => setState(() {
                                  _chosen = {..._chosen};
                                  v == true
                                      ? _chosen.add(m.userId)
                                      : _chosen.remove(m.userId);
                                }),
                        ),
                      ],
                    ),
                  ),
                if (hidden > 0)
                  KoryPersonRow(
                    name: l.koryMqAndOtherMembers(hidden),
                    muted: true,
                    onTap: () => setState(() => _expanded = true),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(
            text: _deputy == null
                ? l.koryXMembersNoticeAlone
                : l.koryXMembersNoticeWith(draft.nameOf(_deputy!)),
          ),
        ],
      ),
    );
  }
}

// ── KOR-19 · Vérifier et créer ───────────────────────────────────────────

class KoryCotisationRecapScreen extends ConsumerStatefulWidget {
  const KoryCotisationRecapScreen({super.key, required this.draft});

  final KoryDraft draft;

  @override
  ConsumerState<KoryCotisationRecapScreen> createState() =>
      _KoryCotisationRecapScreenState();
}

class _KoryCotisationRecapScreenState
    extends ConsumerState<KoryCotisationRecapScreen> {
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    final id = await koryCreateFromDraft(context, ref, widget.draft);
    if (!mounted) return;
    if (id == null) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final draft = widget.draft;
    final me = ref.watch(authControllerProvider).user;
    final members = draft.group == null ? 1 : draft.memberIds.length;
    final amount = draft.amount ?? 0;
    final first = draft.dueAt ?? DateTime.now();
    final dues = [
      for (var i = 0; i < 3; i++) koryAddPeriod(first, draft.period, i),
    ].where((d) => draft.endsAt == null || !d.isAfter(draft.endsAt!)).toList();
    final wallet = KoryWallet.of(me?.phone);
    return KoryPage(
      title: l.koryXCheckAndCreate,
      subtitle: l.koryStepOf('3', draft.title, '3'),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.koryXCreateCotisation,
            busy: _busy,
            onPressed: _create,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryCard(
            child: KoryFigure(
              label: l.koryXPlannedPerDue,
              amount: amount * members,
              caption: l.koryXMembersTimes(
                members,
                formatFcfa(amount),
                koryPeriodLabel(l, draft.period),
              ),
            ),
          ),
          const SizedBox(height: 10),
          KoryCard(
            child: Column(
              children: [
                // « le 5 du mois, dès le 5 déc. »
                KoryLine(
                  l.koryMqDue,
                  draft.period == 'MONTHLY' || draft.period == 'QUARTERLY'
                      ? l.koryMqDueFrom(
                          l.koryMqDayOfMonth('${first.day}'),
                          koryDay(context, first),
                        )
                      : koryDate(context, first),
                ),
                KoryLine(
                  l.koryXEnd,
                  draft.endsAt == null
                      ? l.koryXNoEnd
                      : koryDate(context, draft.endsAt!),
                ),
                KoryLine(
                  l.koryXCollectorLabel,
                  [l.koryYou, ?wallet?.shortLabel].join(' · '),
                ),
                KoryLine(
                  l.koryXConfirmReceipts,
                  draft.deputyId == null
                      ? l.koryYou
                      : l.koryXYouAnd(draft.nameOf(draft.deputyId!)),
                ),
                KoryLine(
                  l.koryXAmountsLabel,
                  draft.amountsVisible
                      ? l.koryXVisibleToAll
                      : l.koryXVisibleToCollector,
                ),
              ],
            ),
          ),
          KorySection(l.koryXNextDues),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final due in dues)
                  KoryLine(
                    koryDate(context, due),
                    l.koryXEach(formatFcfa(amount)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(
            text: [
              // Les rappels J−2, jour J et J+1 partent du serveur.
              l.koryMqRemindersNotice,
              draft.group == null
                  ? l.koryXRecapNoticeAlone
                  : l.koryXRecapNotice(members, draft.group!.name),
            ].join(' '),
          ),
        ],
      ),
    );
  }
}
