import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/deeplink/invite_link_parser.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_pledge_screens.dart';
import 'kory_screen.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Une cagnotte : où envoyer l'argent, ce qui a été confirmé, et le journal.
///
/// Le numéro du collecteur est en tête et copiable : c'est vers lui que part
/// la contribution, depuis le wallet de chacun. Pokou ne propose aucun
/// bouton « payer » — il n'y a rien à payer à Pokou.
class KoryPotScreen extends ConsumerWidget {
  const KoryPotScreen({super.key, required this.potId});

  final int potId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(koryPotProvider(potId));
    final pot = async.valueOrNull;

    return ModuleScaffold(
      title: pot?.title ?? l.koryTitle,
      subtitle: pot == null
          ? null
          : (pot.isTontine
                ? l.koryKindTontine
                : pot.isCotisation
                ? l.koryKindCotisation
                : l.koryKindCagnotte),
      actions: [
        if (pot != null && !pot.isTontine)
          IconButton(
            tooltip: l.koryShareCode(pot.joinCode),
            icon: const Icon(Icons.share_outlined),
            onPressed: () =>
                // Le texte ET un lien direct : touché, il ouvre Pokou sur la
                // cagnotte (et la rejoint) ; sans l'application, il propose
                // de l'installer.
                Share.share(
                  '${l.koryShareText(pot.title, pot.joinCode)}\n'
                  '$pokouLinkBaseUrl/k/${Uri.encodeComponent(pot.joinCode)}',
                ),
          ),
        if (pot != null && pot.isTontine && pot.isOrganizer && pot.isOpen)
          IconButton(
            tooltip: l.koryNextRound,
            icon: const Icon(Icons.skip_next_outlined),
            onPressed: () => _nextRound(context, ref, pot),
          ),
        if (pot != null &&
            !pot.isTontine &&
            (pot.isOrganizer || pot.isCollector) &&
            pot.isOpen)
          IconButton(
            tooltip: l.koryFinishCta,
            icon: const Icon(Icons.lock_outline),
            onPressed: () => _close(context, ref, pot),
          ),
      ],
      // Dans une tontine, le bénéficiaire du tour reçoit : il ne mise pas.
      // Après la clôture, seul celui qui doit encore une part de son
      // engagement peut déclarer un versement (KOR-16).
      floatingActionButton:
          pot != null &&
              (pot.isOpen || (pot.myPledge?.remaining ?? 0) > 0) &&
              !(pot.isTontine && pot.isCollector)
          // Une icône, pas un libellé : le texte débordait du bouton.
          ? FloatingActionButton(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
              tooltip: l.koryDeclareTitle,
              onPressed: () => _declare(context, ref, pot),
              child: const Icon(Icons.add_task),
            )
          : null,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.koryUnavailable,
          message: l.modulesCheckNetwork,
        ),
        data: (pot) => RefreshIndicator(
          onRefresh: () async {
            refreshKory(ref, potId: potId);
            await ref.read(koryPotProvider(potId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _Header(pot: pot),
              const SizedBox(height: 12),
              _PayTo(pot: pot),
              _PledgeEntry(pot: pot, onPay: () => _declare(context, ref, pot)),
              if (pot.isTontine) ...[
                ModuleSectionTitle(l.koryRounds),
                for (final round in pot.rounds) _RoundTile(round: round),
              ],
              ModuleSectionTitle(l.koryJournal),
              if (pot.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l.koryJournalEmpty,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                for (final entry in pot.entries)
                  _EntryTile(pot: pot, entry: entry),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _nextRound(
    BuildContext context,
    WidgetRef ref,
    KoryPot pot,
  ) async {
    final l = L.of(context);
    final last =
        pot.currentRound != null && pot.currentRound == pot.rounds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.koryNextRound),
        content: Text(last ? l.koryLastRoundBody : l.koryNextRoundBody),
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
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(koryRepositoryProvider).nextRound(pot.id),
    );
  }

  /// KOR-15 : clôturer OU prolonger — un seul écran pour les deux choix.
  Future<void> _close(BuildContext context, WidgetRef ref, KoryPot pot) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => KoryFinishScreen(pot: pot)));
  }

  Future<void> _declare(
    BuildContext context,
    WidgetRef ref,
    KoryPot pot,
  ) async {
    final declared = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (_) => _DeclareSheet(pot: pot),
    );
    if (declared == true && context.mounted) {
      refreshKory(ref, potId: pot.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).koryDeclared)));
    }
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      refreshKory(ref, potId: potId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).koryActionFailed)));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final progress = pot.progress;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.koryTotalConfirmed,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              pot.isOpen
                  ? KoryStatusPill(
                      icon: Icons.lock_open,
                      label: l.koryOpen,
                      color: AppColors.feedbackSuccess,
                    )
                  : KoryStatusPill(
                      icon: Icons.lock_outline,
                      label: l.koryClosed,
                      color: AppColors.textSecondary,
                    ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatFcfa(pot.confirmedTotal),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            l.koryDeclaredTotal(formatFcfa(pot.declaredTotal)),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (pot.remainingToCollect != null)
            Text(
              l.koryRemaining(formatFcfa(pot.remainingToCollect!)),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ModuleProgressBar(
              value: progress,
              color: AppColors.accentPrimary,
              done: progress >= 1,
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).round()} % · ${l.koryGoal(formatFcfa(pot.goalAmount!))}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          if (pot.isCotisation && pot.amountPerMember != null) ...[
            const SizedBox(height: 6),
            Text(
              l.koryPerMember(
                formatFcfa(pot.amountPerMember!),
                pot.period == 'WEEKLY'
                    ? l.koryPeriodWeekly
                    : l.koryPeriodMonthly,
              ),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          if (pot.dueAt != null) ...[
            const SizedBox(height: 4),
            Text(
              l.koryDue(DateFormat.yMMMd(locale).format(pot.dueAt!.toLocal())),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l.koryMyShare(formatFcfa(pot.myConfirmedTotal)),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (pot.description != null) ...[
            const SizedBox(height: 8),
            Text(pot.description!),
          ],
        ],
      ),
    );
  }
}

class _PayTo extends StatelessWidget {
  const _PayTo({required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (pot.isCollector) {
      return _Notice(icon: Icons.info_outline, text: l.koryCollectorIsYou);
    }
    final phone = pot.collectorPhone;
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.koryCollector(pot.collectorName ?? phone ?? ''),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (phone != null) ...[
            const SizedBox(height: 4),
            Text(
              l.koryPayTo(phone),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: phone));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l.koryCopied)));
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(l.koryCopyPhone),
              ),
            ),
          ],
          const SizedBox(height: 4),
          _Notice(icon: Icons.shield_outlined, text: l.koryNoMoney),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.pot, required this.entry});

  final KoryPot pot;
  final KoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (icon, label, color) = switch (entry.status) {
      'CONFIRMED' => (
        Icons.check_circle,
        l.koryStatusConfirmed,
        AppColors.feedbackSuccess,
      ),
      'REJECTED' => (
        Icons.cancel_outlined,
        l.koryStatusRejected,
        AppColors.feedbackDanger,
      ),
      _ => (Icons.schedule, l.koryStatusDeclared, AppColors.feedbackWarning),
    };
    final subtitle = [
      DateFormat.yMMMd(locale).add_Hm().format(entry.declaredAt.toLocal()),
      if (entry.roundNumber != null) l.koryRoundNumber('${entry.roundNumber}'),
      if (entry.periodLabel != null) entry.periodLabel!,
      if (entry.walletReference != null) entry.walletReference!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ModuleCard(
        // Ma contribution contestée : toucher ouvre ce que je peux faire
        // (KOR-5).
        onTap: entry.isMine && entry.isContested && pot.isOpen
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KoryContestedScreen(pot: pot, entry: entry),
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.isMine ? l.koryYou : (entry.contributorName ?? '—'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  formatFcfa(entry.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (entry.note != null) ...[
              const SizedBox(height: 4),
              Text(entry.note!),
            ],
            if (entry.isContested && entry.reviewReason != null) ...[
              const SizedBox(height: 4),
              Text(
                l.koryContestedReason(entry.reviewReason!),
                style: TextStyle(color: AppColors.feedbackDanger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                KoryStatusPill(icon: icon, label: label, color: color),
                const Spacer(),
                if (entry.isPending &&
                    (entry.canReview ||
                        (pot.isCollector && !pot.isTontine))) ...[
                  TextButton(
                    onPressed: () => _review(context, ref, confirm: false),
                    child: Text(l.koryReject),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => _review(context, ref, confirm: true),
                    child: Text(l.koryConfirm),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref, {
    required bool confirm,
  }) async {
    String? reason;
    if (!confirm) {
      // KOR-5 : le motif est montré au contributeur.
      final l = L.of(context);
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.koryRejectReasonTitle),
          content: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: controller,
            autofocus: true,
            maxLength: 280,
            decoration: InputDecoration(hintText: l.koryRejectReasonHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(l.koryReject),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !context.mounted) return;
    }
    try {
      await ref
          .read(koryRepositoryProvider)
          .review(pot.id, entry.id, confirm: confirm, reason: reason);
      HapticFeedback.lightImpact();
      refreshKory(ref, potId: pot.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).koryActionFailed)));
    }
  }
}

class _DeclareSheet extends ConsumerStatefulWidget {
  const _DeclareSheet({required this.pot});

  final KoryPot pot;

  @override
  ConsumerState<_DeclareSheet> createState() => _DeclareSheetState();
}

class _DeclareSheetState extends ConsumerState<_DeclareSheet> {
  late final _amount = TextEditingController(
    text: widget.pot.amountPerMember?.toString() ?? '',
  );
  final _reference = TextEditingController();
  final _note = TextEditingController();
  late final _period = TextEditingController(
    text: widget.pot.isCotisation
        ? DateFormat('yyyy-MM').format(DateTime.now())
        : '',
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    _period.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = L.of(context);
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount < 1) {
      setState(() => _error = l.koryNeedAmount);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(koryRepositoryProvider)
          .declare(
            widget.pot.id,
            amount: amount,
            walletReference: _reference.text.trim(),
            periodLabel: _period.text.trim(),
            note: _note.text.trim(),
          );
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.koryActionFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModuleSheetTitle(l.koryDeclareTitle),
            const SizedBox(height: 4),
            Text(
              'Je m’engage : modifiable pendant 8 h avant de devenir ferme (KOR-12). Pokou ne touche aucun fonds.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l.koryAmount),
            ),
            const SizedBox(height: 8),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: _reference,
              maxLength: 64,
              decoration: InputDecoration(
                labelText: l.koryWalletRef,
                helperText: l.koryWalletRefHelp,
                helperMaxLines: 2,
              ),
            ),
            if (widget.pot.isCotisation) ...[
              const SizedBox(height: 8),
              TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                controller: _period,
                maxLength: 12,
                decoration: InputDecoration(labelText: l.koryPeriodLabel),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: _note,
              maxLength: 280,
              decoration: InputDecoration(labelText: l.koryNote),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppColors.feedbackDanger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.feedbackDanger),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ModuleActionButton(
              label: l.koryDeclare,
              expanded: true,
              busy: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un tour de tontine : qui reçoit, quand, et ce qu'il a confirmé.
class _RoundTile extends StatelessWidget {
  const _RoundTile({required this.round});

  final KoryRound round;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (icon, color) = switch (round.status) {
      'CURRENT' => (Icons.play_circle_outline, AppColors.accentPrimary),
      'DONE' => (Icons.check_circle, AppColors.feedbackSuccess),
      _ => (Icons.schedule, AppColors.textSecondary),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        '${l.koryRoundNumber('${round.number}')} · ${round.beneficiaryName ?? '—'}',
      ),
      subtitle: Text(
        [
          if (round.dueAt != null)
            DateFormat.yMMMd(locale).format(round.dueAt!.toLocal()),
          l.koryRoundConfirmed(
            formatFcfa(round.confirmedTotal),
            formatFcfa(round.expectedTotal),
          ),
        ].join(' · '),
      ),
      selected: round.status == 'CURRENT',
    );
  }
}

/// L'engagement dans l'écran de la cagnotte : s'engager (KOR-12), suivre son
/// engagement (KOR-13 / 14), verser la fin après la clôture (KOR-16) ; pour
/// le collecteur, clôturer ou prolonger à la date de fin (KOR-15).
class _PledgeEntry extends StatelessWidget {
  const _PledgeEntry({required this.pot, required this.onPay});

  final KoryPot pot;
  final VoidCallback onPay;

  Future<void> _open(BuildContext context, Widget screen) async {
    final next = await Navigator.of(
      context,
    ).push<Object?>(MaterialPageRoute(builder: (_) => screen));
    if (next == KoryNextStep.pay) onPay();
  }

  @override
  Widget build(BuildContext context) {
    if (pot.isTontine) return const SizedBox.shrink();
    final l = L.of(context);
    final mine = pot.myPledge;
    final children = <Widget>[];

    if (pot.isDue && (pot.isCollector || pot.isOrganizer)) {
      children.add(
        ModuleCallout(
          tone: CalloutTone.amber,
          text: l.koryFinishDueNotice,
          children: [
            const SizedBox(height: 8),
            ModuleActionButton(
              label: l.koryFinishCta,
              expanded: false,
              onPressed: () => _open(context, KoryFinishScreen(pot: pot)),
            ),
          ],
        ),
      );
    }

    if (!pot.isOpen && mine != null && mine.remaining > 0) {
      children.add(
        ModuleCard(
          onTap: () => _open(context, KoryClosedScreen(pot: pot)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.koryClosedTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${l.koryToPay} : ${formatFcfa(mine.remaining)}',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
    } else if (pot.isOpen && !pot.isCollector) {
      if (mine == null) {
        children.add(
          ModuleQuietButton(
            label: l.koryPledgeTitle,
            icon: Icons.handshake_outlined,
            onPressed: () => _open(context, KoryPledgeScreen(pot: pot)),
          ),
        );
      } else {
        children.add(
          ModuleCard(
            onTap: () => _open(context, KoryMyPledgeScreen(potId: pot.id)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.koryMyPledgeTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${l.koryMyPledgeTotal(formatFcfa(mine.total))} · '
                        '${l.koryRemainingToPay} : ${formatFcfa(mine.remaining)}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          for (final c in children) ...[c, const SizedBox(height: 8)],
        ],
      ),
    );
  }
}
