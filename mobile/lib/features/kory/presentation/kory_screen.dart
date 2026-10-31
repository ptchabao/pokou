import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_create_screen.dart';
import 'kory_pot_screen.dart';

/// Kory — l'entrée du module (écran APP-3).
///
/// Le chiffre en tête est « mes contributions confirmées », jamais un
/// solde : rien n'est détenu par Pokou (BM-01). Le rappel juste en dessous
/// le dit en toutes lettres, parce que c'est la question que pose quelqu'un
/// qui voit un montant dans une application.
class KoryScreen extends ConsumerWidget {
  const KoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final pots = ref.watch(koryPotsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          refreshKory(ref);
          await ref.read(koryPotsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: PokouAppBar(title: l.koryTitle)),
            const SliverToBoxAdapter(child: _SummaryCard()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ModuleActionButton(
                        label: l.koryCreate,
                        icon: Icons.add,
                        expanded: true,
                        onPressed: () => openKoryCreate(context, ref),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ModuleQuietButton(
                      label: l.koryJoin,
                      expanded: false,
                      onPressed: () => _join(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            ...pots.when(
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ModuleEmptyState(
                    icon: Icons.cloud_off,
                    title: l.koryUnavailable,
                    message: l.modulesCheckNetwork,
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: ModuleEmptyState(
                          icon: Icons.savings_outlined,
                          title: l.koryNone,
                          message: l.koryNoneBody,
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        sliver: SliverList.separated(
                          itemCount: items.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) => index == items.length
                              ? const _TontineTeaser()
                              : KoryPotCard(pot: items[index]),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.koryJoinTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l.koryJoinHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l.koryJoin),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      final pot = await ref.read(koryRepositoryProvider).join(code);
      refreshKory(ref);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.koryJoinUnknown)));
    }
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final summary = ref.watch(korySummaryProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ModuleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.koryMonthTotal,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              formatFcfa(summary?.monthConfirmedTotal ?? 0),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if ((summary?.toReviewCount ?? 0) > 0) ...[
              const SizedBox(height: 6),
              KoryStatusPill(
                icon: Icons.hourglass_top,
                label: l.koryToReview('${summary!.toReviewCount}'),
                color: AppColors.feedbackWarning,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.koryNoMoney,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Une cagnotte dans une liste — réutilisée par l'accueil.
class KoryPotCard extends StatelessWidget {
  const KoryPotCard({super.key, required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final progress = pot.progress;
    return ModuleCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModuleBadge(
                icon: pot.isCotisation
                    ? Icons.event_repeat_outlined
                    : Icons.savings_outlined,
                color: AppColors.accentPrimary,
                muted: !pot.isOpen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      pot.isCotisation
                          ? l.koryKindCotisation
                          : l.koryKindCagnotte,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!pot.isOpen)
                KoryStatusPill(
                  icon: Icons.lock_outline,
                  label: l.koryClosed,
                  color: AppColors.textSecondary,
                )
              else if ((pot.pendingCount ?? 0) > 0)
                KoryStatusPill(
                  icon: Icons.hourglass_top,
                  label: l.koryToReview('${pot.pendingCount}'),
                  color: AppColors.feedbackWarning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.koryTotalConfirmed,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          Text(
            formatFcfa(pot.confirmedTotal),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ModuleProgressBar(
              value: progress,
              color: AppColors.accentPrimary,
              done: progress >= 1,
            ),
            const SizedBox(height: 4),
            // Le pourcentage en TEXTE, pas seulement en barre (section 7.6).
            Text(
              '${(progress * 100).round()} % · ${l.koryGoal(formatFcfa(pot.goalAmount!))}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          if (pot.dueAt != null) ...[
            const SizedBox(height: 4),
            Text(
              l.koryDue(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(pot.dueAt!.toLocal()),
              ),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// La tontine en rotation existe dans le cahier des charges, mais pas
/// avant Kory Plus (mois 13). On l'annonce sans la proposer.
class _TontineTeaser extends StatelessWidget {
  const _TontineTeaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.autorenew, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              L.of(context).koryTontinePlus,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une pastille d'état : icône ET libellé, jamais la couleur seule (DS-06).
class KoryStatusPill extends StatelessWidget {
  const KoryStatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
