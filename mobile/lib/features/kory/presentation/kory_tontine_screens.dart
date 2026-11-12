import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../modules/shared/module_payment.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_cotisation_screens.dart';
import 'kory_create_screen.dart';
import 'kory_draft.dart';
import 'kory_export.dart';
import 'kory_journal_screen.dart';
import 'kory_pay_screens.dart';
import 'kory_pot_screen.dart';
import 'kory_review_screen.dart';
import 'kory_screen.dart';
import 'kory_ui.dart';

/// Mon identifiant, pour savoir quel tour est le mien.
int? _me(WidgetRef ref) => ref.watch(authControllerProvider).user?.id;

/// « de décembre à juillet » : le premier et le dernier tour.
(DateTime, DateTime)? _span(KoryPot pot) {
  if (pot.rounds.isNotEmpty) {
    final first = pot.rounds.first.dueAt;
    final last = pot.rounds.last.dueAt;
    if (first != null && last != null) return (first, last);
  }
  final start = pot.dueAt;
  final count = pot.members.where((m) => !m.declined).length;
  if (start == null || count < 1 || pot.period == null) return null;
  return (start, koryAddPeriod(start, pot.period!, count - 1));
}

String _spanText(BuildContext context, KoryPot pot, int count) {
  final l = L.of(context);
  final span = _span(pot);
  if (span == null) return '$count';
  return l.koryXRoundsSpan(
    count,
    koryMonth(context, span.$1).toLowerCase(),
    koryMonth(context, span.$2).toLowerCase(),
  );
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  int potId,
  Future<Object?> Function() action, {
  String? done,
}) async {
  try {
    await action();
    refreshKory(ref, potId: potId);
    if (done != null && context.mounted) koryToast(context, done);
  } catch (_) {
    if (context.mounted) koryFailed(context);
  }
}

/// Kory Plus : ouvrir le paiement des frais d'ouverture. Rien n'est accordé
/// ici — c'est la confirmation reçue par le serveur qui fait entrer dans la
/// tontine, et la page se met à jour d'elle-même (kory:updated).
Future<void> _payPlusFee(
  BuildContext context,
  WidgetRef ref,
  KoryPot pot,
) async {
  final l = L.of(context);
  try {
    final url = await ref.read(koryRepositoryProvider).payPlusFee(pot.id);
    if (!context.mounted) return;
    await openPaymentGateway(
      context,
      url,
      pendingMessage: l.koryXFeePaymentPending,
    );
    refreshKory(ref, potId: pot.id);
  } catch (_) {
    if (context.mounted) koryFailed(context);
  }
}

/// KOR-8 / 25 : le montant des frais. Qui les a réglés se lit juste dessous,
/// dans la liste des membres.
class _PlusFeeCard extends StatelessWidget {
  const _PlusFeeCard({required this.fee});

  final KoryPlusFee fee;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return KoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.koryXPlusFeeTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.koryXPlusFeeBody(
              formatFcfa(fee.amountHt),
              formatFcfa(fee.amountTtc),
            ),
            style: TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }
}

// ── KOR-24 · Membres et ordre (création) ─────────────────────────────────

class KoryTontineMembersScreen extends ConsumerStatefulWidget {
  const KoryTontineMembersScreen({super.key, required this.draft});

  final KoryDraft draft;

  @override
  ConsumerState<KoryTontineMembersScreen> createState() =>
      _KoryTontineMembersScreenState();
}

class _KoryTontineMembersScreenState
    extends ConsumerState<KoryTontineMembersScreen> {
  late List<int> _order = [
    for (final m in widget.draft.group?.members ?? const []) m.userId,
  ];
  late Set<int> _chosen = {..._order};
  int? _deputy;
  String _mode = 'DRAW';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final draft = widget.draft;
    final me = _me(ref);
    final chosen = [
      for (final id in _order)
        if (_chosen.contains(id) || id == me) id,
    ];
    String name(int id) => id == me ? l.koryYou : draft.nameOf(id);
    return KoryPage(
      title: l.koryXMembersAndOrder,
      subtitle: l.koryXTontineStepOf(draft.title, '2'),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.koryXContinue,
            onPressed: chosen.length < 2
                ? null
                : () async {
                    draft.memberIds = chosen;
                    draft.deputyId = chosen.contains(_deputy) ? _deputy : null;
                    draft.drawMode = _mode;
                    final potId = await Navigator.of(context).push<int>(
                      MaterialPageRoute(
                        builder: (_) => KoryTontineOpenScreen(draft: draft),
                      ),
                    );
                    if (potId != null && context.mounted) {
                      Navigator.of(context).pop(potId);
                    }
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KorySection(l.koryXMembersCount(chosen.length)),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final id in _order)
                  KoryPersonRow(
                    name: name(id),
                    subtitle: id == me
                        ? l.koryXAdministrator
                        : id == _deputy
                        ? l.koryXDeputy
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (id != me && _chosen.contains(id))
                          IconButton(
                            tooltip: l.koryXMakeDeputy,
                            icon: Icon(
                              id == _deputy
                                  ? Icons.verified_user
                                  : Icons.verified_user_outlined,
                              color: id == _deputy
                                  ? AppColors.accentPrimary
                                  : AppColors.textMuted,
                            ),
                            onPressed: () => setState(
                              () => _deputy = _deputy == id ? null : id,
                            ),
                          ),
                        Checkbox(
                          value: id == me || _chosen.contains(id),
                          onChanged: id == me
                              ? null
                              : (v) => setState(() {
                                  _chosen = {..._chosen};
                                  v == true
                                      ? _chosen.add(id)
                                      : _chosen.remove(id);
                                }),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          KorySection(l.koryRotation),
          KoryChoice(
            selected: _mode == 'DRAW',
            title: l.koryXDrawAtStart,
            subtitle: l.koryXDrawAtStartSub,
            onTap: () => setState(() => _mode = 'DRAW'),
          ),
          KoryChoice(
            selected: _mode == 'FIXED',
            title: l.koryXFixOrder,
            subtitle: l.koryXFixOrderSub,
            onTap: () => setState(() => _mode = 'FIXED'),
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorderItem: (from, to) => setState(() {
                final next = [...chosen];
                next.insert(to, next.removeAt(from));
                _order = [
                  ...next,
                  for (final id in _order)
                    if (!next.contains(id)) id,
                ];
              }),
              children: [
                for (final (index, id) in chosen.indexed)
                  ListTile(
                    key: ValueKey(id),
                    contentPadding: EdgeInsets.zero,
                    leading: KoryAvatar('${index + 1}', size: 32),
                    title: Text(name(id)),
                    subtitle: draft.dueAt == null
                        ? null
                        : Text(
                            koryMonth(
                              context,
                              koryAddPeriod(draft.dueAt!, draft.period, index),
                            ),
                          ),
                    trailing: const Icon(Icons.drag_handle),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          KoryNotice(
            text: _deputy == null
                ? l.koryXNoDeputyNotice
                : l.koryXDeputyNotice(draft.nameOf(_deputy!)),
          ),
        ],
      ),
    );
  }
}

// ── KOR-8 · Nouvelle tontine, étape 3 : vérifier et inviter ──────────────

class KoryTontineOpenScreen extends ConsumerStatefulWidget {
  const KoryTontineOpenScreen({super.key, required this.draft});

  final KoryDraft draft;

  @override
  ConsumerState<KoryTontineOpenScreen> createState() =>
      _KoryTontineOpenScreenState();
}

class _KoryTontineOpenScreenState extends ConsumerState<KoryTontineOpenScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final d = widget.draft;
    final count = d.memberIds.length;
    final start = d.dueAt ?? koryAddPeriod(DateTime.now(), d.period, 1);
    final end = koryAddPeriod(start, d.period, count - 1);
    return KoryPage(
      title: l.koryXNewTontine,
      subtitle: l.koryXTontineStepOf(d.group?.name ?? d.title, '3'),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.koryXOpenAndInvite(count - 1),
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              final id = await koryCreateFromDraft(context, ref, d);
              if (!context.mounted) return;
              if (id == null) {
                setState(() => _busy = false);
              } else {
                Navigator.of(context).pop(id);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            d.title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          KoryCard(
            child: Column(
              children: [
                KoryLine(
                  l.koryXStakeLabel,
                  l.koryXAmountPer(
                    formatFcfa(d.amount ?? 0),
                    koryPeriodLabel(l, d.period),
                  ),
                ),
                KoryLine(
                  l.koryXMembersAndRounds,
                  l.koryXRoundsSpan(
                    count,
                    koryMonth(context, start).toLowerCase(),
                    koryMonth(context, end).toLowerCase(),
                  ),
                ),
                KoryLine(
                  l.koryXLeveePerRound,
                  formatFcfa((d.amount ?? 0) * (count - 1)),
                ),
                KoryLine(
                  l.koryRotation,
                  d.drawMode == 'DRAW' ? l.koryXDrawLogged : l.koryXFixedOrder,
                ),
                if (d.deputyId != null)
                  KoryLine(l.koryXDeputy, d.nameOf(d.deputyId!)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(text: l.koryXStartsWhenAllAccept),
          const SizedBox(height: 10),
          KoryNotice(text: l.koryTontineNote),
        ],
      ),
    );
  }
}

// ── La tontine : en attente (KOR-8, 25), en cours (KOR-7), terminée ─────

class KoryTontineScreen extends ConsumerWidget {
  const KoryTontineScreen({super.key, required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pot.isPending) {
      final me = _me(ref);
      final mine = pot.members.where((m) => m.userId == me).firstOrNull;
      if (pot.isAdmin) return _PendingAdminView(pot: pot);
      return _InvitationView(pot: pot, member: mine);
    }
    return _TontineView(pot: pot);
  }
}

/// La pastille d'un membre invité : accepté (ou payé), en attente, a refusé.
Widget _memberPill(L l, KoryMemberInfo m, {bool feeDue = false}) {
  if (feeDue && !m.declined) {
    return m.feePaid
        ? KoryStatusPill(
            icon: Icons.check_circle,
            label: l.koryXFeePaid,
            color: AppColors.feedbackSuccess,
          )
        : KoryStatusPill(
            icon: Icons.hourglass_top,
            label: l.koryXWaiting,
            color: AppColors.securityWarning,
          );
  }
  if (m.declined) {
    return KoryStatusPill(
      icon: Icons.block,
      label: l.koryXDeclinedInvite,
      color: AppColors.securityCritical,
    );
  }
  return m.accepted
      ? KoryStatusPill(
          icon: Icons.check_circle,
          label: l.koryXAccepted,
          color: AppColors.feedbackSuccess,
        )
      : KoryStatusPill(
          icon: Icons.hourglass_top,
          label: l.koryXWaiting,
          color: AppColors.securityWarning,
        );
}

class _AcceptedCard extends StatelessWidget {
  const _AcceptedCard({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final invited = pot.members.where((m) => !m.declined).toList();
    final feeDue = pot.plusFee?.isDue ?? false;
    final accepted = invited
        .where((m) => feeDue ? m.feePaid : m.accepted)
        .length;
    return KoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feeDue
                ? l.koryXPlusFeePaidOf('$accepted', '${invited.length}')
                : l.koryXAcceptedOf('$accepted', '${invited.length}'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: invited.isEmpty ? 0 : accepted / invited.length,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.feedbackSuccess,
            ),
          ),
          const SizedBox(height: 6),
          for (final m in pot.members)
            KoryPersonRow(
              name: m.name ?? '—',
              subtitle: m.isAdmin
                  ? l.koryXAdministrator
                  : m.isDeputy
                  ? l.koryXDeputy
                  : null,
              muted: m.declined,
              trailing: _memberPill(l, m, feeDue: pot.plusFee?.isDue ?? false),
            ),
        ],
      ),
    );
  }
}

/// KOR-8 : vue de l'administrateur, tant que tous n'ont pas accepté.
class _PendingAdminView extends ConsumerStatefulWidget {
  const _PendingAdminView({required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<_PendingAdminView> createState() => _PendingAdminViewState();
}

class _PendingAdminViewState extends ConsumerState<_PendingAdminView> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final repo = ref.read(koryRepositoryProvider);
    final waiting = pot.members.where((m) => !m.accepted && !m.declined).length;
    final declined = pot.members.where((m) => m.declined).length;
    final accepted = pot.members.where((m) => m.accepted).length;
    final canStart = waiting == 0 && declined > 0 && accepted >= 2;
    final count = pot.members.where((m) => !m.declined).length;
    final fee = pot.plusFee;
    final mustPay = fee != null && fee.isDue && !fee.iPaid;
    return KoryPage(
      title: pot.title,
      subtitle: l.koryXPendingSubtitle(pot.groupName ?? l.koryKindTontine),
      actions: [
        IconButton(
          tooltip: l.koryXDissolve,
          icon: const Icon(Icons.delete_forever_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => KoryTontineDissolveScreen(pot: pot),
            ),
          ),
        ),
      ],
      footer: KoryFooter(
        children: [
          if (mustPay)
            KoryButton(
              icon: Icons.account_balance_wallet_outlined,
              label: l.koryXPayMyFee(formatFcfa(fee.amountTtc)),
              busy: _busy,
              onPressed: () async {
                setState(() => _busy = true);
                await _payPlusFee(context, ref, pot);
                if (mounted) setState(() => _busy = false);
              },
            )
          else if (canStart)
            KoryButton(
              label: l.koryXStartWithout(declined),
              busy: _busy,
              onPressed: () async {
                setState(() => _busy = true);
                await _run(
                  context,
                  ref,
                  pot.id,
                  () => repo.startTontine(pot.id),
                );
                if (mounted) setState(() => _busy = false);
              },
            )
          else
            KoryButton(
              quiet: true,
              icon: Icons.notifications_active_outlined,
              label: l.koryXRemindMembers(waiting),
              busy: _busy,
              onPressed: waiting == 0
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final n = await repo.remind(pot.id);
                        refreshKory(ref, potId: pot.id);
                        if (context.mounted) {
                          koryToast(context, l.koryXReminded(n));
                        }
                      } catch (_) {
                        if (context.mounted) {
                          koryToast(context, l.koryXRemindTooSoon);
                        }
                      }
                      if (mounted) setState(() => _busy = false);
                    },
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
            KoryCard(
              child: Column(
                children: [
                  KoryLine(
                    l.koryXStakeLabel,
                    l.koryXAmountPer(
                      formatFcfa(pot.amountPerMember ?? 0),
                      koryPeriodLabel(l, pot.period),
                    ),
                  ),
                  KoryLine(
                    l.koryXMembersAndRounds,
                    _spanText(context, pot, count),
                  ),
                  KoryLine(
                    l.koryRotation,
                    pot.drawMode == 'DRAW'
                        ? l.koryXDrawLogged
                        : l.koryXFixedOrder,
                  ),
                ],
              ),
            ),
            if (fee != null && fee.isDue) ...[
              const SizedBox(height: 10),
              _PlusFeeCard(fee: fee),
            ],
            const SizedBox(height: 10),
            _AcceptedCard(pot: pot),
            const SizedBox(height: 12),
            KoryNotice(
              text: declined > 0
                  ? l.koryXSomeoneDeclined
                  : (fee?.isDue ?? false)
                  ? l.koryXStartsWhenAllPaid
                  : l.koryXStartsWhenAllAccept,
            ),
          ],
        ),
      ),
    );
  }
}

// ── KOR-25 · Invitation dans une tontine ─────────────────────────────────

class _InvitationView extends ConsumerStatefulWidget {
  const _InvitationView({required this.pot, required this.member});

  final KoryPot pot;
  final KoryMemberInfo? member;

  @override
  ConsumerState<_InvitationView> createState() => _InvitationViewState();
}

class _InvitationViewState extends ConsumerState<_InvitationView> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    final l = L.of(context);
    final repo = ref.read(koryRepositoryProvider);
    if (!accept) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.koryXDeclineInvite),
          content: Text(l.koryXDeclineConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.koryXDeclineInvite),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    await _run(
      context,
      ref,
      widget.pot.id,
      () => accept
          ? repo.acceptTontine(widget.pot.id)
          : repo.declineTontine(widget.pot.id),
      done: accept ? l.koryXAcceptedToast : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!accept) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final member = widget.member;
    final fee = pot.plusFee;
    final feeDue = fee != null && fee.isDue;
    final answered =
        member == null ||
        member.declined ||
        (feeDue ? member.feePaid : member.accepted);
    final count = pot.members.where((m) => !m.declined).length;
    return KoryPage(
      title: l.koryXInvitation,
      subtitle: l.koryXTontineInviteFrom(pot.organizerName ?? '—'),
      footer: answered
          ? null
          : KoryFooter(
              children: [
                KoryButton(
                  icon: feeDue ? Icons.account_balance_wallet_outlined : null,
                  label: feeDue
                      ? l.koryXPayAndJoin(formatFcfa(fee.amountTtc))
                      : l.koryXAcceptInvite,
                  busy: _busy,
                  onPressed: feeDue
                      ? () async {
                          setState(() => _busy = true);
                          await _payPlusFee(context, ref, pot);
                          if (mounted) setState(() => _busy = false);
                        }
                      : () => _answer(true),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _answer(false),
                  child: Text(l.koryXDeclineInvite),
                ),
              ],
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            pot.title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            [l.koryXKoryPlus, ?pot.groupName].join(' · '),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          KoryCard(
            child: Column(
              children: [
                KoryLine(
                  l.koryXStakeLabel,
                  l.koryXAmountPer(
                    formatFcfa(pot.amountPerMember ?? 0),
                    koryPeriodLabel(l, pot.period),
                  ),
                ),
                KoryLine(
                  l.koryXMembersAndRounds,
                  _spanText(context, pot, count),
                ),
                KoryLine(
                  l.koryRotation,
                  pot.drawMode == 'DRAW'
                      ? l.koryXDrawAtStart
                      : l.koryXFixedOrder,
                ),
                KoryLine(
                  l.koryXAdministrator,
                  pot.deputyName == null
                      ? (pot.organizerName ?? '—')
                      : l.koryXAdminWithDeputy(
                          pot.organizerName ?? '—',
                          pot.deputyName!,
                        ),
                ),
              ],
            ),
          ),
          if (feeDue) ...[const SizedBox(height: 10), _PlusFeeCard(fee: fee)],
          const SizedBox(height: 10),
          _AcceptedCard(pot: pot),
          const SizedBox(height: 12),
          if (feeDue && member != null && member.feePaid)
            KoryNotice(tone: KoryTone.success, text: l.koryXFeeYouPaid)
          else if (feeDue && member != null && !member.declined)
            KoryNotice(text: l.koryXStartsWhenAllPaid)
          else if (member != null && member.accepted)
            KoryNotice(tone: KoryTone.success, text: l.koryXYouAccepted)
          else if (member != null && member.declined)
            KoryNotice(tone: KoryTone.danger, text: l.koryXYouDeclined)
          else
            KoryNotice(text: l.koryXStartsWhenAllAccept),
          const SizedBox(height: 10),
          KoryNotice(text: l.koryTontineNote),
        ],
      ),
    );
  }
}

// ── KOR-7 · La tontine en cours ──────────────────────────────────────────

class _TontineView extends ConsumerWidget {
  const _TontineView({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final me = _me(ref);
    final repo = ref.read(koryRepositoryProvider);
    final round = pot.rounds.where((r) => r.isCurrent).firstOrNull;
    final upcoming = pot.rounds.where((r) => r.status == 'UPCOMING').toList();
    final myRound = pot.rounds.where((r) => r.beneficiaryId == me).firstOrNull;
    final pendingForMe = pot.entries.where((e) => e.canReview && e.isPending);
    final swaps = pot.swaps.where((s) => s.isOpen).toList();
    final contribute = koryCanContribute(pot) && round != null;
    final declaredThisRound =
        round != null &&
        pot.entries.any(
          (e) =>
              e.isMine &&
              e.roundNumber == round.number &&
              (e.status == 'CONFIRMED' || e.isPending),
        );
    return KoryPage(
      title: pot.title,
      subtitle: [l.koryXKoryPlus, ?pot.groupName].join(' · '),
      actions: [
        if (pot.isAdmin && pot.isOpen)
          PopupMenuButton<String>(
            tooltip: l.koryXMoreActions,
            onSelected: (value) async {
              switch (value) {
                case 'next':
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(l.koryNextRound),
                      content: Text(
                        pot.currentRound == pot.rounds.length
                            ? l.koryLastRoundBody
                            : l.koryNextRoundBody,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(l.actionCancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: Text(l.koryNextRound),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await _run(
                      context,
                      ref,
                      pot.id,
                      () => repo.nextRound(pot.id),
                    );
                  }
                case 'remind':
                  try {
                    final n = await repo.remind(pot.id);
                    refreshKory(ref, potId: pot.id);
                    if (context.mounted) koryToast(context, l.koryXReminded(n));
                  } catch (_) {
                    if (context.mounted) {
                      koryToast(context, l.koryXRemindTooSoon);
                    }
                  }
                case 'dissolve':
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KoryTontineDissolveScreen(pot: pot),
                    ),
                  );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'next', child: Text(l.koryNextRound)),
              PopupMenuItem(value: 'remind', child: Text(l.koryXRemindLate)),
              PopupMenuItem(value: 'dissolve', child: Text(l.koryXDissolve)),
            ],
          ),
      ],
      footer: pot.isOpen
          ? KoryFooter(
              children: [
                Row(
                  children: [
                    if (contribute && !declaredThisRound) ...[
                      Expanded(
                        child: KoryButton(
                          label: l.koryHomeContribute,
                          onPressed: () => openKoryContribute(
                            context,
                            ref,
                            pot,
                            amount: pot.amountPerMember,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: KoryButton(
                        quiet: true,
                        label: l.koryXReport,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                KoryTontineReportScreen(potId: pot.id),
                          ),
                        ),
                      ),
                    ),
                  ],
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
            if (pot.isDissolved)
              KoryNotice(
                tone: KoryTone.danger,
                title: l.koryXDissolvedTitle,
                text: l.koryXDissolvedReason(pot.dissolveReason ?? '—'),
              )
            else if (round != null)
              KoryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.koryXRoundOfMonth(
                        '${round.number}',
                        '${pot.rounds.length}',
                        round.dueAt == null
                            ? ''
                            : koryMonth(context, round.dueAt!).toLowerCase(),
                      ),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      round.beneficiaryId == me
                          ? l.koryXYouReceive
                          : l.koryHomeBeneficiary(round.beneficiaryName ?? '—'),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      l.koryXStakeDue(
                        formatFcfa(pot.amountPerMember ?? 0),
                        round.dueAt == null
                            ? '—'
                            : koryDay(context, round.dueAt!),
                      ),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.koryXRoundCounts(
                        '${round.confirmedCount}',
                        '${round.declaredCount}',
                        '${round.lateCount}',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )
            else
              KoryNotice(tone: KoryTone.success, text: l.koryXTontineDone),
            if (pendingForMe.isNotEmpty) ...[
              const SizedBox(height: 10),
              KoryActionRow(
                icon: Icons.hourglass_top,
                color: AppColors.securityWarning,
                title: l.koryXToConfirmCount('${pendingForMe.length}'),
                subtitle: l.koryXOnlyYouConfirmShort,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => KoryReviewScreen(potId: pot.id),
                  ),
                ),
              ),
            ],
            for (final swap in swaps)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _SwapCard(pot: pot, swap: swap, me: me),
              ),
            if (round != null && round.contributors.isNotEmpty) ...[
              KorySection(l.koryXThisRound),
              KoryCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    for (final c in round.contributors)
                      KoryPersonRow(
                        name: c.userId == me ? l.koryYou : (c.name ?? '—'),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatFcfa(pot.amountPerMember ?? 0),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            koryStatusPill(l, c.status),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (upcoming.isNotEmpty) ...[
              KorySection(
                l.koryXNextRounds,
                trailing: l.koryXCalendar,
                onTrailing: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => KoryTontineDrawScreen(potId: pot.id),
                  ),
                ),
              ),
              KoryCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    for (final r in upcoming.take(3))
                      KoryLine(
                        r.dueAt == null
                            ? l.koryRoundNumber('${r.number}')
                            : koryMonth(context, r.dueAt!),
                        r.beneficiaryId == me
                            ? l.koryYou
                            : (r.beneficiaryName ?? '—'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              [
                if (pot.drawnAt != null)
                  pot.drawMode == 'DRAW'
                      ? l.koryXDrawnOn(koryDate(context, pot.drawnAt!))
                      : l.koryXFixedOn(koryDate(context, pot.drawnAt!)),
                if (pot.deputyName != null) l.koryXDeputyIs(pot.deputyName!),
              ].join(' '),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (myRound != null) ...[
              const SizedBox(height: 12),
              KoryCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    KoryLine(
                      l.koryXMyLevee,
                      myRound.dueAt == null
                          ? l.koryRoundNumber('${myRound.number}')
                          : koryMonth(context, myRound.dueAt!).toLowerCase(),
                    ),
                    if (pot.isOpen &&
                        myRound.status == 'UPCOMING' &&
                        !swaps.any(
                          (s) => s.requesterId == me || s.targetId == me,
                        ))
                      KoryPersonRow(
                        name: l.koryXSwapMyMonth,
                        subtitle: l.koryXWithAnotherMember,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => KoryTontineSwapScreen(pot: pot),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            KoryJournalPreview(pot: pot),
          ],
        ),
      ),
    );
  }
}

/// Un échange de mois en cours : ce que je peux en faire (KOR-28).
class _SwapCard extends ConsumerWidget {
  const _SwapCard({required this.pot, required this.swap, required this.me});

  final KoryPot pot;
  final KorySwap swap;
  final int? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final repo = ref.read(koryRepositoryProvider);
    final requester = swap.requesterId == me
        ? l.koryYou
        : (swap.requesterName ?? '—');
    final target = swap.targetId == me ? l.koryYou : (swap.targetName ?? '—');
    final actions = <Widget>[];
    if (swap.status == 'PENDING' && swap.targetId == me) {
      actions.addAll([
        KoryButton(
          label: l.koryXAcceptSwap,
          onPressed: () => _run(
            context,
            ref,
            pot.id,
            () => repo.acceptSwap(pot.id, swap.id),
          ),
        ),
        TextButton(
          onPressed: () => _run(
            context,
            ref,
            pot.id,
            () => repo.refuseSwap(pot.id, swap.id),
          ),
          child: Text(l.koryXRefuse),
        ),
      ]);
    } else if (swap.status == 'ACCEPTED' && pot.isAdmin) {
      actions.addAll([
        KoryButton(
          label: l.koryXApproveSwap,
          onPressed: () => _run(
            context,
            ref,
            pot.id,
            () => repo.approveSwap(pot.id, swap.id),
            done: l.koryXCalendarUpdated,
          ),
        ),
        TextButton(
          onPressed: () => _run(
            context,
            ref,
            pot.id,
            () => repo.refuseSwap(pot.id, swap.id),
          ),
          child: Text(l.koryXRefuse),
        ),
      ]);
    } else if (swap.requesterId == me) {
      actions.add(
        TextButton(
          onPressed: () => _run(
            context,
            ref,
            pot.id,
            () => repo.refuseSwap(pot.id, swap.id),
          ),
          child: Text(l.koryXWithdrawRequest),
        ),
      );
    }
    return KoryNotice(
      tone: KoryTone.warning,
      icon: Icons.swap_horiz,
      title: l.koryXSwapRequest(requester, target),
      text: [
        l.koryXSwapRounds('${swap.requesterRound}', '${swap.targetRound}'),
        if (swap.status == 'ACCEPTED')
          l.koryXSwapWaitingAdmin
        else if (swap.targetId != me)
          l.koryXSwapWaitingMember(target),
        if (swap.message != null) '« ${swap.message} »',
      ].join('\n'),
      children: [
        if (actions.isNotEmpty) ...[const SizedBox(height: 10), ...actions],
      ],
    );
  }
}

// ── KOR-26 · La tontine démarre : le calendrier ──────────────────────────

class KoryTontineDrawScreen extends ConsumerWidget {
  const KoryTontineDrawScreen({super.key, required this.potId});

  final int potId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(koryPotProvider(potId));
    final pot = async.valueOrNull;
    if (pot == null) {
      return KoryPage(
        title: l.koryXCalendar,
        loading: async.isLoading,
        body: Center(child: Text(l.koryUnavailable)),
      );
    }
    final me = _me(ref);
    return KoryPage(
      title: l.koryXTontineStarts,
      subtitle: '${pot.title} · ${l.koryXKoryPlus}',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryNotice(
            tone: KoryTone.success,
            text: l.koryXAllAccepted(pot.rounds.length),
          ),
          const SizedBox(height: 12),
          if (pot.drawnAt != null)
            KoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pot.drawMode == 'DRAW'
                        ? l.koryXDrawAt(
                            koryDay(context, pot.drawnAt!),
                            koryTime(pot.drawnAt!),
                          )
                        : l.koryXFixedAt(koryDay(context, pot.drawnAt!)),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    l.koryXSeal(pot.drawSeal ?? '—'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          KorySection(
            pot.rounds.firstOrNull?.dueAt == null
                ? l.koryXCalendar
                : l.koryXCalendarDay(
                    '${pot.rounds.first.dueAt!.toLocal().day}',
                  ),
          ),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final r in pot.rounds)
                  KoryPersonRow(
                    name: r.dueAt == null
                        ? l.koryRoundNumber('${r.number}')
                        : koryMonth(context, r.dueAt!),
                    subtitle: r.beneficiaryId == me
                        ? l.koryYou
                        : (r.beneficiaryName ?? '—'),
                    muted: r.isCancelled || r.isDone,
                    trailing: r.beneficiaryId == me
                        ? KoryStatusPill(
                            icon: Icons.star_outline,
                            label: l.koryXYourMonth,
                            color: AppColors.accentPrimary,
                          )
                        : r.isCancelled
                        ? KoryStatusPill(
                            icon: Icons.block,
                            label: l.koryXCancelled,
                            color: AppColors.textSecondary,
                          )
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(text: l.koryXSwapNotice),
        ],
      ),
    );
  }
}

// ── KOR-28 · Échanger mon mois ───────────────────────────────────────────

class KoryTontineSwapScreen extends ConsumerStatefulWidget {
  const KoryTontineSwapScreen({super.key, required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<KoryTontineSwapScreen> createState() =>
      _KoryTontineSwapScreenState();
}

class _KoryTontineSwapScreenState extends ConsumerState<KoryTontineSwapScreen> {
  final _message = TextEditingController();
  int? _with;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String _roundLabel(KoryRound r) {
    final l = L.of(context);
    return r.dueAt == null
        ? l.koryRoundNumber('${r.number}')
        : '${koryMonth(context, r.dueAt!)} · ${l.koryRoundNumber('${r.number}').toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final me = _me(ref);
    final mine = pot.rounds.where((r) => r.beneficiaryId == me).firstOrNull;
    final others = [
      for (final r in pot.rounds)
        if (r.status == 'UPCOMING' && r.beneficiaryId != me) r,
    ];
    final chosen = others.where((r) => r.beneficiaryId == _with).firstOrNull;
    final admin =
        pot.members.where((m) => m.isAdmin).firstOrNull?.name ??
        pot.organizerName ??
        '—';
    return KoryPage(
      title: l.koryXSwapMyMonth,
      subtitle: pot.title,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: chosen == null
                ? l.koryXSendRequest
                : l.koryXSendRequestTo(chosen.beneficiaryName ?? '—'),
            busy: _busy,
            onPressed: chosen == null
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ref
                          .read(koryRepositoryProvider)
                          .requestSwap(
                            pot.id,
                            chosen.beneficiaryId,
                            message: _message.text,
                          );
                      refreshKory(ref, potId: pot.id);
                      if (!context.mounted) return;
                      koryToast(context, l.koryXRequestSent);
                      Navigator.of(context).pop();
                    } catch (_) {
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      koryFailed(context);
                    }
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (mine != null)
            KoryCard(child: KoryLine(l.koryXYourMonth, _roundLabel(mine))),
          KorySection(l.koryXWithWhom),
          if (others.isEmpty)
            Text(
              l.koryXNoSwapPossible,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          for (final r in others)
            KoryChoice(
              selected: _with == r.beneficiaryId,
              title: r.beneficiaryName ?? '—',
              subtitle: _roundLabel(r),
              onTap: () => setState(() => _with = r.beneficiaryId),
            ),
          const SizedBox(height: 6),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _message,
            maxLength: 280,
            decoration: InputDecoration(labelText: l.koryXMessageOptional),
          ),
          KoryCard(
            child: Column(
              children: [
                _Step(1, l.koryXSwapStep1),
                _Step(2, l.koryXSwapStep2(chosen?.beneficiaryName ?? '…')),
                _Step(3, l.koryXSwapStep3(admin)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          KoryNotice(text: l.koryXSwapCalendarNotice),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        KoryAvatar('$number', size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(color: AppColors.textPrimary)),
        ),
      ],
    ),
  );
}

// ── KOR-29 · Rapport de la tontine ───────────────────────────────────────

class KoryTontineReportScreen extends ConsumerStatefulWidget {
  const KoryTontineReportScreen({super.key, required this.potId});

  final int potId;

  @override
  ConsumerState<KoryTontineReportScreen> createState() =>
      _KoryTontineReportScreenState();
}

class _KoryTontineReportScreenState
    extends ConsumerState<KoryTontineReportScreen> {
  bool _exporting = false;

  String _roundTitle(KoryRound r) {
    final l = L.of(context);
    final month = r.dueAt == null
        ? ''
        : ' · ${koryMonth(context, r.dueAt!).toLowerCase()}';
    return '${l.koryRoundNumber('${r.number}')}$month'
        '${r.isCurrent ? ' · ${l.koryXInProgress}' : ''}';
  }

  String _roundLine(KoryRound r) {
    final l = L.of(context);
    if (r.isCancelled) return l.koryXCancelled;
    if (r.status == 'UPCOMING') return l.koryXUpcoming;
    if (r.isCurrent) {
      return l.koryXRoundCounts(
        '${r.confirmedCount}',
        '${r.declaredCount}',
        '${r.lateCount}',
      );
    }
    return l.koryXHaveContributed('${r.confirmedCount}', '${r.expectedCount}');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(koryPotProvider(widget.potId));
    final pot = async.valueOrNull;
    if (pot == null) {
      return KoryPage(
        title: l.koryXReportTitle,
        loading: async.isLoading,
        body: Center(child: Text(l.koryUnavailable)),
      );
    }
    final me = _me(ref);
    // Mes mises : un tour commencé où je ne reçois pas, et ce que j'y ai fait.
    final owed = [
      for (final r in pot.rounds)
        if ((r.isCurrent || r.isDone) && r.beneficiaryId != me) r.number,
    ];
    final paid = {
      for (final e in pot.entries)
        if (e.isMine && e.status == 'CONFIRMED' && e.roundNumber != null)
          e.roundNumber!,
    };
    final mineDone = owed.where(paid.contains).length;
    return KoryPage(
      title: l.koryXReportTitle,
      subtitle: l.koryXVisibleToAllMembers(pot.title),
      footer: KoryFooter(
        children: [
          Row(
            children: [
              Expanded(
                child: KoryButton(
                  quiet: true,
                  icon: Icons.picture_as_pdf_outlined,
                  label: l.koryXExportPdf,
                  busy: _exporting,
                  onPressed: () async {
                    setState(() => _exporting = true);
                    try {
                      await korySharePdf(
                        title: l.koryXReportTitle,
                        subtitle: pot.title,
                        footer: l.koryXReportKept,
                        lines: [
                          for (final r in pot.rounds)
                            KoryExportLine(
                              r.dueAt,
                              '${_roundTitle(r)} — ${r.beneficiaryName ?? '—'} — ${_roundLine(r)}',
                            ),
                        ],
                      );
                    } catch (_) {
                      if (context.mounted) koryFailed(context);
                    } finally {
                      if (mounted) setState(() => _exporting = false);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KoryButton(
                  quiet: true,
                  icon: Icons.receipt_long_outlined,
                  label: l.koryJournalTab,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KoryJournalScreen(potId: pot.id),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryNotice(text: l.koryXReportMeaning),
          const SizedBox(height: 10),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final r in pot.rounds)
                  KoryPersonRow(
                    name: r.beneficiaryId == me
                        ? l.koryYou
                        : (r.beneficiaryName ?? '—'),
                    subtitle: '${_roundTitle(r)}\n${_roundLine(r)}',
                    muted: r.isCancelled || r.status == 'UPCOMING',
                    trailing: r.rejectedCount > 0
                        ? Text(
                            l.koryXContestedCount(r.rejectedCount),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.securityCritical,
                            ),
                          )
                        : r.lateCount > 0 && !r.isCancelled
                        ? koryStatusPill(l, 'LATE')
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          KoryCard(
            child: KoryLine(
              l.koryXYourContributions,
              l.koryXConfirmedOf('$mineDone', '${owed.length}'),
              valueColor: mineDone == owed.length
                  ? AppColors.feedbackSuccess
                  : AppColors.securityWarning,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.koryXReportKept,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── KOR-30 · Dissoudre la tontine ────────────────────────────────────────

class KoryTontineDissolveScreen extends ConsumerStatefulWidget {
  const KoryTontineDissolveScreen({super.key, required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<KoryTontineDissolveScreen> createState() =>
      _KoryTontineDissolveScreenState();
}

class _KoryTontineDissolveScreenState
    extends ConsumerState<KoryTontineDissolveScreen> {
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final done = pot.rounds.where((r) => r.isDone).length;
    final left = pot.rounds.where((r) => !r.isDone && !r.isCancelled).toList();
    final members = pot.members.where((m) => !m.declined).length;
    return KoryPage(
      title: l.koryXDissolve,
      subtitle: l.koryXAdminOnly(pot.title),
      footer: KoryFooter(
        children: [
          KoryButton(
            danger: true,
            label: l.koryXDissolve,
            busy: _busy,
            onPressed: _reason.text.trim().length < 3
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ref
                          .read(koryRepositoryProvider)
                          .dissolve(pot.id, _reason.text.trim());
                      refreshKory(ref, potId: pot.id);
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (_) {
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      koryFailed(context);
                    }
                  },
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.actionCancel),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryNotice(tone: KoryTone.danger, text: l.koryXDissolveFinal),
          const SizedBox(height: 12),
          if (pot.rounds.isNotEmpty)
            KoryCard(
              child: Column(
                children: [
                  KoryLine(
                    l.koryXPastRounds,
                    l.koryXOutOf('$done', '${pot.rounds.length}'),
                  ),
                  KoryLine(l.koryXCancelledRounds, '${left.length}'),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _reason,
            maxLength: 280,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.koryXReasonRequired),
          ),
          KorySection(l.koryXWhatHappensNext),
          for (final text in [
            l.koryXDissolveNotified(members),
            l.koryXDissolveNoMoreRounds,
            l.koryXReportKept,
            l.koryXDissolveSettle,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
