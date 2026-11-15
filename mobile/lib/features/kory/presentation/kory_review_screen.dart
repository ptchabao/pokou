import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_tontine_screens.dart';
import 'kory_home_widgets.dart';
import 'kory_ui.dart';
import 'kory_wallet.dart';

/// Confirmer ou contester une contribution — la même tuile partout : écran
/// « À confirmer » (KOR-4), levée de tontine (KOR-27), suivi d'une
/// cotisation (KOR-20).
class KoryReviewTile extends ConsumerStatefulWidget {
  const KoryReviewTile({super.key, required this.pot, required this.entry});

  final KoryPot pot;
  final KoryEntry entry;

  @override
  ConsumerState<KoryReviewTile> createState() => _KoryReviewTileState();
}

class _KoryReviewTileState extends ConsumerState<KoryReviewTile> {
  bool _busy = false;

  Future<void> _review(bool confirm) async {
    final l = L.of(context);
    String? reason;
    if (!confirm) {
      // « Pas reçu » demande un motif : il est montré au contributeur.
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setLocal) => AlertDialog(
            title: Text(l.koryRejectReasonTitle),
            content: TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: controller,
              autofocus: true,
              maxLength: 280,
              onChanged: (_) => setLocal(() {}),
              decoration: InputDecoration(hintText: l.koryRejectReasonHint),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l.actionCancel),
              ),
              FilledButton(
                onPressed: controller.text.trim().length < 3
                    ? null
                    : () => Navigator.pop(dialogContext, controller.text),
                child: Text(l.koryReject),
              ),
            ],
          ),
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(koryRepositoryProvider)
          .review(
            widget.pot.id,
            widget.entry.id,
            confirm: confirm,
            reason: reason,
          );
      HapticFeedback.lightImpact();
      refreshKory(ref, potId: widget.pot.id);
    } catch (_) {
      if (mounted) koryFailed(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showProof(int mediaId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          child: MediaImage(
            mediaId: mediaId,
            extension: 'jpg',
            fit: BoxFit.contain,
            semanticLabel: L.of(context).koryXSmsCaptureAttached,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final entry = widget.entry;
    final proof = entry.proofMediaId;
    final operator = KoryWallet.of(entry.contributorPhoneMasked)?.operator;
    final subtitle = [
      ?operator,
      if (entry.walletReference != null)
        l.koryXRefShort(entry.walletReference!),
      if (entry.periodLabel != null) entry.periodLabel!,
      if (entry.roundNumber != null) l.koryRoundNumber('${entry.roundNumber}'),
      koryTime(entry.declaredAt),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KoryCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KoryPersonRow(
              name: entry.contributorName ?? '—',
              subtitle: subtitle,
              trailing: Text(
                formatFcfa(entry.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (entry.note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  entry.note!,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            if (proof != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _showProof(proof),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(l.koryXSmsCaptureAttached),
                ),
              ),
            const SizedBox(height: 4),
            // « Reçu » plein à gauche, « Pas reçu » à contour à droite.
            KoryButtonPair(
              first: KoryButton(
                label: l.koryConfirm,
                busy: _busy,
                onPressed: () => _review(true),
              ),
              second: KoryButton(
                outlined: true,
                label: l.koryReject,
                onPressed: _busy ? null : () => _review(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KOR-4 · À confirmer / KOR-27 · Ta levée ─────────────────────────────

class KoryReviewScreen extends ConsumerWidget {
  const KoryReviewScreen({super.key, required this.potId});

  final int potId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(koryPotProvider(potId));
    final pot = async.valueOrNull;
    if (pot == null) {
      return KoryPage(
        title: l.koryToConfirmLabel,
        loading: async.isLoading,
        body: Center(child: Text(l.koryUnavailable)),
      );
    }
    final pending = [
      for (final e in pot.entries)
        if (e.canReview && e.isPending) e,
    ];
    final round = pot.isTontine
        ? pot.rounds.where((r) => r.isCurrent).firstOrNull
        : null;
    final myLevee = round != null && pot.isCollector;
    final operator = KoryWallet.of(pot.collectorPhone)?.operator;
    final late = [
      if (round != null)
        for (final c in round.contributors)
          if (c.status == 'LATE') c.name ?? '—',
    ];
    return KoryPage(
      title: myLevee
          ? l.koryXMyLeveeOf(koryMonth(context, round.dueAt ?? DateTime.now()))
          : l.koryXToConfirmCount('${pending.length}'),
      subtitle: myLevee
          ? l.koryMqRoundSubtitle(
              pot.title,
              '${round.number}',
              '${pot.rounds.length}',
            )
          : l.koryXOrganizerView(pot.title),
      footer: pot.isTontine
          ? KoryFooter(
              children: [
                KoryButton(
                  outlined: true,
                  label: l.koryXSeeReport,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KoryTontineReportScreen(potId: pot.id),
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          refreshKory(ref, potId: potId);
          await ref.read(koryPotProvider(potId).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (myLevee) ...[
              _LeveeCard(pot: pot, round: round, toConfirm: pending.length),
              const SizedBox(height: 12),
            ],
            KoryNotice(
              text: myLevee
                  ? l.koryXOnlyYouConfirm
                  : operator == null
                  ? l.koryXCheckWallet
                  : l.koryMqCheckWalletOf(operator),
            ),
            // Le titre de l'écran compte déjà ce qui reste à confirmer : pas
            // d'en-tête répété, sauf sur la levée (dont le titre est le mois).
            if (myLevee)
              KorySection(l.koryXToConfirmCount('${pending.length}'))
            else
              const SizedBox(height: 12),
            if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l.koryXNothingToConfirm,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              for (final entry in pending)
                KoryReviewTile(key: ValueKey(entry.id), pot: pot, entry: entry),
            if (late.isNotEmpty) ...[
              const SizedBox(height: 4),
              KoryCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: KoryLine(
                  l.koryXLateCount('${late.length}'),
                  [
                    late.join(', '),
                    if (pot.remindedAt != null)
                      l.koryMqReminded(koryWhen(context, pot.remindedAt!)),
                  ].join(' · '),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l.koryXRejectNeedsReason,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// KOR-27 : ce que je reçois ce tour — confirmé, attendu, et où en est
/// chacun.
class _LeveeCard extends StatelessWidget {
  const _LeveeCard({
    required this.pot,
    required this.round,
    required this.toConfirm,
  });

  final KoryPot pot;
  final KoryRound round;
  final int toConfirm;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final stake = pot.amountPerMember;
    return KoryCard(
      color: AppColors.terracottaTint.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.koryXYouReceive,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l.koryMqAmountConfirmed(formatFcfa(round.confirmedTotal)),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            [
              l.koryMqOnExpected(formatFcfa(round.expectedTotal)),
              if (stake != null && round.expectedCount > 0)
                l.koryMqTimesStake('${round.expectedCount}', formatFcfa(stake)),
            ].join(' · '),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (round.expectedTotal > 0) ...[
            const SizedBox(height: 10),
            KoryProgressBar(value: round.confirmedTotal / round.expectedTotal),
          ],
          const SizedBox(height: 8),
          Text(
            l.koryMqLeveeCounts(
              '${round.confirmedCount}',
              '$toConfirm',
              '${round.lateCount}',
            ),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
