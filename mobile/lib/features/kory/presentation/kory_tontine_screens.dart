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
import 'kory_home_widgets.dart';
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

/// Kory Plus : ouvrir le paiement des frais d'ouverture, par CashPay. Rien
/// n'est accordé ici — c'est la confirmation reçue par le serveur qui fait
/// entrer dans la tontine, et la page se met à jour d'elle-même
/// (kory:updated). [forOthers] : l'administrateur règle aussi ceux qui
/// n'ont pas encore payé (KOR-8).
Future<void> _payPlusFee(
  BuildContext context,
  WidgetRef ref,
  KoryPot pot, {
  bool forOthers = false,
}) async {
  final l = L.of(context);
  try {
    final url = await ref
        .read(koryRepositoryProvider)
        .payPlusFee(pot.id, forOthers: forOthers);
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

/// KOR-8 / 25 : les frais d'ouverture, dans un encadré ambré, avec où en
/// sont les paiements. [ttcFirst] : le montant TTC en grand (l'invitation,
/// KOR-25), sinon la phrase « 1 000 FCFA HT (1 180 FCFA TTC) par membre ».
class _PlusFeeCard extends StatelessWidget {
  const _PlusFeeCard({
    required this.pot,
    required this.fee,
    this.ttcFirst = false,
  });

  final KoryPot pot;
  final KoryPlusFee fee;
  final bool ttcFirst;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final invited = pot.members.where((m) => !m.declined).toList();
    final paid = invited.where((m) => m.feePaid).length;
    return KoryCard(
      color: AppColors.securityWarning.withValues(
        alpha: AppColors.isDark ? 0.16 : 0.08,
      ),
      borderColor: AppColors.securityWarning.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.koryXPlusFeeTitle,
            style: ttcFirst
                ? TextStyle(fontSize: 13, color: AppColors.textSecondary)
                : TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
          ),
          if (ttcFirst) ...[
            Text(
              l.koryMqTtc(formatFcfa(fee.amountTtc)),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              l.koryMqFeeHtOnce(formatFcfa(fee.amountHt)),
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              l.koryXPlusFeeBody(
                formatFcfa(fee.amountHt),
                formatFcfa(fee.amountTtc),
              ),
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ],
          if (invited.isNotEmpty) ...[
            const SizedBox(height: 10),
            KoryProgressBar(value: paid / invited.length),
            const SizedBox(height: 6),
            Text(
              l.koryXPlusFeePaidOf('$paid', '${invited.length}'),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
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
  bool _expanded = false;
  bool _busy = false;

  /// La création se fait ici : l'étape 3 (KOR-8) est la tontine elle-même,
  /// où chacun paie ses frais d'ouverture.
  Future<void> _create(List<int> chosen) async {
    final draft = widget.draft;
    draft.memberIds = chosen;
    draft.deputyId = chosen.contains(_deputy) ? _deputy : null;
    draft.drawMode = _mode;
    setState(() => _busy = true);
    final potId = await koryCreateFromDraft(context, ref, draft);
    if (!mounted) return;
    if (potId == null) {
      setState(() => _busy = false);
    } else {
      Navigator.of(context).pop(potId);
    }
  }

  /// « Ajouter » : les membres de la discussion qui ne sont pas encore dans
  /// la tontine.
  Future<void> _add() async {
    final l = L.of(context);
    final others = [
      for (final id in _order)
        if (!_chosen.contains(id) && id != _me(ref)) id,
    ];
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            KorySection(l.koryMqAddMember),
            if (others.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l.koryMqEveryoneIn,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            for (final id in others)
              KoryPersonRow(
                name: widget.draft.nameOf(id),
                subtitle: l.koryMqOnPokou,
                onTap: () => Navigator.pop(sheetContext, id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _chosen = {..._chosen, picked});
  }

  /// Toucher un membre : le désigner suppléant, ou le retirer.
  Future<void> _manage(int id) async {
    final l = L.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(
                id == _deputy ? l.koryMqRemoveDeputy : l.koryXMakeDeputy,
              ),
              onTap: () => Navigator.pop(sheetContext, 'deputy'),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: Text(l.koryMqRemoveMember),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    setState(() {
      if (action == 'deputy') {
        _deputy = _deputy == id ? null : id;
      } else {
        _chosen = {..._chosen}..remove(id);
        if (_deputy == id) _deputy = null;
      }
    });
  }

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
    // La maquette montre trois membres, puis « et 5 autres » : moi d'abord,
    // puis le suppléant.
    final shown = [
      ?me,
      if (_deputy != null && chosen.contains(_deputy)) _deputy!,
      for (final id in chosen)
        if (id != me && id != _deputy) id,
    ];
    final folded = !_expanded && shown.length > 4;
    final visible = folded ? shown.take(3).toList() : shown;
    final hidden = folded ? shown.skip(3).toList() : const <int>[];
    return KoryPage(
      title: l.koryXMembersAndOrder,
      subtitle: l.koryXTontineStepOf(draft.title, '2'),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.koryXContinue,
            busy: _busy,
            onPressed: chosen.length < 2 ? null : () => _create(chosen),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KorySection(
            l.koryXMembersCount(chosen.length),
            trailing: l.koryMqAdd,
            onTrailing: _add,
          ),
          KoryCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final id in visible)
                  KoryPersonRow(
                    name: name(id),
                    subtitle: id == me
                        ? l.koryXAdministrator
                        : id == _deputy
                        ? l.koryXDeputy
                        : l.koryMqOnPokou,
                    onTap: id == me ? null : () => _manage(id),
                    trailing: id == _deputy
                        ? KoryStatusPill(
                            icon: Icons.verified_user_outlined,
                            label: l.koryXDeputy,
                            color: AppColors.accentPrimary,
                          )
                        : null,
                  ),
                if (hidden.isNotEmpty)
                  KoryPersonRow(
                    name: l.koryMqAndOthers(hidden.length),
                    subtitle: hidden.map(name).join(', '),
                    muted: true,
                    onTap: () => setState(() => _expanded = true),
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
          Text(
            _deputy == null
                ? l.koryXNoDeputyNotice
                : l.koryXDeputyNotice(draft.nameOf(_deputy!)),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── La tontine : en attente (KOR-8, 25), en cours (KOR-7), terminée ─────
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

/// Les membres invités et leur réponse. Kory Plus payant : à droite, le
/// montant TTC et « Payé » / « En attente » (KOR-8) ; la progression est
/// alors dans l'encadré des frais.
class _AcceptedCard extends StatelessWidget {
  const _AcceptedCard({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final invited = pot.members.where((m) => !m.declined).toList();
    final fee = pot.plusFee;
    final feeDue = fee?.isDue ?? false;
    final accepted = invited.where((m) => m.accepted).length;
    return KoryCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!feeDue) ...[
            const SizedBox(height: 8),
            Text(
              l.koryXAcceptedOf('$accepted', '${invited.length}'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            KoryProgressBar(
              value: invited.isEmpty ? 0 : accepted / invited.length,
            ),
            const SizedBox(height: 6),
          ],
          for (final m in pot.members)
            KoryPersonRow(
              name: m.name ?? '—',
              subtitle: m.isAdmin
                  ? l.koryXAdministrator
                  : m.isDeputy
                  ? l.koryXDeputy
                  : null,
              muted: m.declined,
              trailing: feeDue && !m.declined
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatFcfa(fee!.amountTtc),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _memberPill(l, m, feeDue: true),
                      ],
                    )
                  : _memberPill(l, m),
            ),
        ],
      ),
    );
  }
}

/// Cotisation, membres et tours, ordre : le résumé d'une tontine en attente.
class _TontineSummary extends StatelessWidget {
  const _TontineSummary({required this.pot, this.withAdmin = false});

  final KoryPot pot;
  final bool withAdmin;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final count = pot.members.where((m) => !m.declined).length;
    return KoryCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          KoryLine(
            l.koryMqStake,
            l.koryXAmountPer(
              formatFcfa(pot.amountPerMember ?? 0),
              koryPeriodLabel(l, pot.period),
            ),
          ),
          KoryLine(l.koryXMembersAndRounds, _spanText(context, pot, count)),
          KoryLine(
            l.koryRotation,
            pot.drawMode == 'DRAW'
                ? (withAdmin ? l.koryXDrawAtStart : l.koryXDrawLogged)
                : l.koryXFixedOrder,
          ),
          if (withAdmin)
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
    );
  }
}

/// KOR-8 : ouvrir la tontine — vue de l'administrateur, tant que tous n'ont
/// pas payé (ou accepté). C'est l'étape 3 de la création.
class _PendingAdminView extends ConsumerStatefulWidget {
  const _PendingAdminView({required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<_PendingAdminView> createState() => _PendingAdminViewState();
}

class _PendingAdminViewState extends ConsumerState<_PendingAdminView> {
  bool _busy = false;

  Future<void> _pay({required bool forOthers}) async {
    setState(() => _busy = true);
    await _payPlusFee(context, ref, widget.pot, forOthers: forOthers);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remind() async {
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      final n = await ref.read(koryRepositoryProvider).remind(widget.pot.id);
      refreshKory(ref, potId: widget.pot.id);
      if (mounted) koryToast(context, l.koryXReminded(n));
    } catch (_) {
      if (mounted) koryToast(context, l.koryXRemindTooSoon);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pot = widget.pot;
    final repo = ref.read(koryRepositoryProvider);
    final me = _me(ref);
    final fee = pot.plusFee;
    final feeDue = fee != null && fee.isDue;
    final invited = pot.members.where((m) => !m.declined).toList();
    // Kory Plus payant : on attend un paiement ; sinon, une réponse.
    final waiting = invited
        .where((m) => feeDue ? !(m.feePaid && m.accepted) : !m.accepted)
        .length;
    final unpaid = feeDue ? invited.where((m) => !m.feePaid).toList() : [];
    final othersUnpaid = unpaid.where((m) => m.userId != me).length;
    final declined = pot.members.where((m) => m.declined).length;
    final accepted = pot.members.where((m) => m.accepted).length;
    final canStart = waiting == 0 && declined > 0 && accepted >= 2;
    return KoryPage(
      title: l.koryXNewTontine,
      subtitle: [
        l.koryXKoryPlus,
        l.koryXTontineStepOf(pot.groupName ?? pot.title, '3'),
      ].join(' · '),
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
          if (canStart)
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
          else if (othersUnpaid > 0)
            // « Payer pour les 3 restants · 3 540 FCFA TTC »
            KoryButton(
              label: l.koryMqPayForRemaining(
                unpaid.length,
                formatFcfa(fee!.amountTtc * unpaid.length),
              ),
              busy: _busy,
              onPressed: () => _pay(forOthers: true),
            )
          else if (feeDue && !fee.iPaid)
            KoryButton(
              label: l.koryXPayMyFee(formatFcfa(fee.amountTtc)),
              busy: _busy,
              onPressed: () => _pay(forOthers: false),
            ),
          // Ses seuls frais, quand d'autres restent à payer.
          if (!canStart && othersUnpaid > 0 && !fee!.iPaid)
            TextButton(
              onPressed: _busy ? null : () => _pay(forOthers: false),
              child: Text(l.koryXPayMyFee(formatFcfa(fee.amountTtc))),
            ),
          if (waiting > 0)
            TextButton(
              onPressed: _busy ? null : _remind,
              child: Text(l.koryXRemindMembers(waiting)),
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
            _TontineSummary(pot: pot),
            if (feeDue) ...[
              const SizedBox(height: 10),
              _PlusFeeCard(pot: pot, fee: fee),
            ],
            const SizedBox(height: 10),
            _AcceptedCard(pot: pot),
            const SizedBox(height: 12),
            KoryNotice(
              text: declined > 0
                  ? l.koryXSomeoneDeclined
                  : feeDue
                  ? l.koryMqStartsWhenAllPaid
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
    // Ses frais peuvent avoir été réglés par l'administrateur : il reste
    // alors à accepter soi-même.
    final mustPay = feeDue && member != null && !member.feePaid;
    final answered = member == null || member.declined || member.accepted;
    return KoryPage(
      title: l.koryXInvitation,
      subtitle: l.koryXTontineInviteFrom(pot.organizerName ?? '—'),
      footer: answered
          ? null
          : KoryFooter(
              children: [
                KoryButton(
                  label: mustPay
                      ? l.koryMqPayTtcByCashPay(formatFcfa(fee.amountTtc))
                      : l.koryXAcceptInvite,
                  busy: _busy,
                  onPressed: mustPay
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
          KoryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pot.title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  [l.koryXKoryPlus, ?pot.groupName].join(' · '),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _TontineSummary(pot: pot, withAdmin: true),
          if (feeDue) ...[
            const SizedBox(height: 10),
            _PlusFeeCard(pot: pot, fee: fee, ttcFirst: true),
          ],
          const SizedBox(height: 12),
          if (feeDue && member != null && member.feePaid && member.accepted)
            KoryNotice(tone: KoryTone.success, text: l.koryXFeeYouPaid)
          else if (member != null && member.declined)
            KoryNotice(tone: KoryTone.danger, text: l.koryXYouDeclined)
          else if (feeDue)
            KoryNotice(text: l.koryMqStartsWhenAllPaid)
          else if (member != null && member.accepted)
            KoryNotice(tone: KoryTone.success, text: l.koryXYouAccepted)
          else
            KoryNotice(text: l.koryXStartsWhenAllAccept),
        ],
      ),
    );
  }
}

// ── KOR-7 · La tontine en cours ──────────────────────────────────────────

void _openReport(BuildContext context, KoryPot pot) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => KoryTontineReportScreen(potId: pot.id)),
    );

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
                color: AppColors.terracottaTint.withValues(alpha: 0.35),
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
                    if (round.expectedTotal > 0) ...[
                      const SizedBox(height: 10),
                      KoryProgressBar(
                        value: round.confirmedTotal / round.expectedTotal,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      l.koryMqRoundCounts(
                        '${round.confirmedCount}',
                        '${round.declaredCount}',
                        '${round.lateCount}',
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
              KoryNotice(tone: KoryTone.success, text: l.koryXTontineDone),
            // « Contribuer » et « Rapport », sous la carte du tour.
            if (pot.isOpen) ...[
              const SizedBox(height: 10),
              if (contribute && !declaredThisRound)
                KoryButtonPair(
                  first: KoryButton(
                    label: l.koryHomeContribute,
                    onPressed: () => openKoryContribute(
                      context,
                      ref,
                      pot,
                      amount: pot.amountPerMember,
                    ),
                  ),
                  second: KoryButton(
                    outlined: true,
                    label: l.koryXReport,
                    onPressed: () => _openReport(context, pot),
                  ),
                )
              else
                KoryButton(
                  outlined: true,
                  label: l.koryXReport,
                  onPressed: () => _openReport(context, pot),
                ),
            ],
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
                        // « relance ce matin » sous ceux qui sont en retard.
                        subtitle: c.status == 'LATE' && pot.remindedAt != null
                            ? l.koryMqReminded(
                                koryWhen(context, pot.remindedAt!),
                              )
                            : null,
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
              KoryRowsCard(
                children: [
                  // Ma levée : son tour en cours mène à la confirmation
                  // (KOR-27), sinon au calendrier des tours (KOR-26).
                  KoryChevronRow(
                    label: l.koryXMyLevee,
                    trailing: myRound.dueAt == null
                        ? l.koryRoundNumber('${myRound.number}')
                        : koryMonth(context, myRound.dueAt!).toLowerCase(),
                    strongTrailing: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => myRound.isCurrent
                            ? KoryReviewScreen(potId: pot.id)
                            : KoryTontineDrawScreen(potId: pot.id),
                      ),
                    ),
                  ),
                  if (pot.isOpen &&
                      myRound.status == 'UPCOMING' &&
                      !swaps.any(
                        (s) => s.requesterId == me || s.targetId == me,
                      ))
                    KoryChevronRow(
                      label: l.koryXSwapMyMonth,
                      trailing: l.koryXWithAnotherMember,
                      strongTrailing: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KoryTontineSwapScreen(pot: pot),
                        ),
                      ),
                    ),
                ],
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
