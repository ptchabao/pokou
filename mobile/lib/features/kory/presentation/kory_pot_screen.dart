import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_screen.dart';

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
          : (pot.isCotisation ? l.koryKindCotisation : l.koryKindCagnotte),
      actions: [
        if (pot != null)
          IconButton(
            tooltip: l.koryShareCode(pot.joinCode),
            icon: const Icon(Icons.share_outlined),
            onPressed: () =>
                Share.share(l.koryShareText(pot.title, pot.joinCode)),
          ),
        if (pot != null && pot.isOrganizer && pot.isOpen)
          IconButton(
            tooltip: l.koryCloseAction,
            icon: const Icon(Icons.lock_outline),
            onPressed: () => _close(context, ref, pot),
          ),
      ],
      floatingActionButton: pot != null && pot.isOpen
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
              onPressed: () => _declare(context, ref, pot),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(l.koryDeclare),
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

  Future<void> _close(BuildContext context, WidgetRef ref, KoryPot pot) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l.koryCloseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.koryCloseAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, ref, () => ref.read(koryRepositoryProvider).close(pot.id));
  }

  Future<void> _declare(BuildContext context, WidgetRef ref, KoryPot pot) async {
    final declared = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (_) => _DeclareSheet(pot: pot),
    );
    if (declared == true && context.mounted) {
      refreshKory(ref, potId: pot.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).koryDeclared)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).koryActionFailed)),
      );
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.koryCopied)),
                  );
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
      _ => (
        Icons.hourglass_top,
        l.koryStatusDeclared,
        AppColors.feedbackWarning,
      ),
    };
    final subtitle = [
      DateFormat.yMMMd(locale).add_Hm().format(entry.declaredAt.toLocal()),
      if (entry.periodLabel != null) entry.periodLabel!,
      if (entry.walletReference != null) entry.walletReference!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ModuleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.isMine
                        ? l.koryYou
                        : (entry.contributorName ?? '—'),
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
            const SizedBox(height: 6),
            Row(
              children: [
                KoryStatusPill(icon: icon, label: label, color: color),
                const Spacer(),
                if (pot.isCollector && entry.isPending) ...[
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
    try {
      await ref
          .read(koryRepositoryProvider)
          .review(pot.id, entry.id, confirm: confirm);
      HapticFeedback.lightImpact();
      refreshKory(ref, potId: pot.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).koryActionFailed)),
      );
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
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l.koryAmount),
            ),
            const SizedBox(height: 8),
            TextField(
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
                controller: _period,
                maxLength: 12,
                decoration: InputDecoration(labelText: l.koryPeriodLabel),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
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
