import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
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
            SliverToBoxAdapter(
              child: PokouAppBar(
                title: l.koryTitle,
                subtitle: l.korySubtitle,
                showStatus: false,
                leading: const ModuleBadge(
                  icon: Icons.savings_outlined,
                  color: AppColors.accentPrimary,
                  size: 36,
                ),
              ),
            ),
            // Maquette APP-3 : surtitre « ÉPARGNE SOLIDAIRE », grand titre,
            // pastille du sous-titre.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.koryOverline.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                          Text(
                            l.navKory,
                            style: TextStyle(
                              fontSize: 28,
                              height: 36 / 28,
                              letterSpacing: -0.2,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l.korySubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _SummaryCard()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    ModuleActionButton(
                      label: l.koryCreate,
                      icon: Icons.add,
                      onPressed: () => openKoryCreate(context, ref),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ModuleQuietButton(
                            icon: Icons.person_add_alt_1_outlined,
                            label: l.koryJoin,
                            onPressed: () => _join(context, ref),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ModuleQuietButton(
                            icon: Icons.receipt_long_outlined,
                            label: l.koryJournalTab,
                            onPressed: () {
                              final first = pots.valueOrNull?.firstOrNull;
                              if (first == null) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      KoryPotScreen(potId: first.id),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.koryMyPots,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 28 / 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if ((pots.valueOrNull ?? const []).any((p) => p.isOpen))
                      Text(
                        l.koryActiveCount(
                          '${pots.valueOrNull!.where((p) => p.isOpen).length}',
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
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
                          // Un état vide qui GUIDE : l'action est là.
                          action: ModuleActionButton(
                            label: l.koryCreate,
                            icon: Icons.add,
                            expanded: false,
                            onPressed: () => openKoryCreate(context, ref),
                          ),
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
                              ? _TontineCard(
                                  pot: items
                                      .where((pot) => pot.isTontine)
                                      .firstOrNull,
                                )
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
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id)));
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
    final amount = formatFcfa(summary?.monthConfirmedTotal ?? 0);
    // « 15 000 FCFA » : le chiffre en grand, la devise en terracotta.
    final split = amount.lastIndexOf(' ');
    final figure = split > 0 ? amount.substring(0, split) : amount;
    final currency = split > 0 ? amount.substring(split + 1) : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.card,
          boxShadow: AppElevation.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.koryMonthTotal,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const ModuleBadge(
                  icon: Icons.savings_outlined,
                  color: AppColors.accentPrimary,
                  size: 44,
                ),
              ],
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: figure,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (currency.isNotEmpty)
                    TextSpan(
                      text: ' $currency',
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
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
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.koryNoMoney,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
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
  const KoryPotCard({super.key, required this.pot, this.dark = false});

  final KoryPot pot;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final progress = pot.progress;
    return ModuleCard(
      backgroundColor: dark ? AppColors.brandEbene : null,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModuleBadge(
                icon: pot.isCotisation
                    ? Icons.event_repeat_outlined
                    : Icons.savings_outlined,
                color: dark ? AppColors.brandOr : AppColors.accentPrimary,
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
                      style: TextStyle(
                        color: dark
                            ? AppColors.neutralCreme
                            : AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      pot.isCotisation
                          ? l.koryKindCotisation
                          : l.koryKindCagnotte,
                      style: TextStyle(
                        color: dark
                            ? AppColors.neutralCreme.withValues(alpha: 0.8)
                            : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (pot.organizerName != null)
                      Text(
                        '${pot.organizerName} · ${pot.entries.length} contributions confirmées',
                        style: TextStyle(
                          color: dark
                              ? AppColors.neutralCreme.withValues(alpha: 0.8)
                              : AppColors.textSecondary,
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
                  color: dark
                      ? AppColors.neutralCreme
                      : AppColors.textSecondary,
                )
              else if ((pot.pendingCount ?? 0) > 0)
                KoryStatusPill(
                  icon: Icons.hourglass_top,
                  label: l.koryToReview('${pot.pendingCount}'),
                  color: dark ? AppColors.brandOr : AppColors.feedbackWarning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.koryTotalConfirmed,
            style: TextStyle(
              color: dark ? AppColors.neutralCreme : AppColors.textSecondary,
              fontSize: 12,
            ),
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
              color: dark ? AppColors.brandOr : AppColors.accentPrimary,
              done: progress >= 1,
            ),
            const SizedBox(height: 4),
            // Le pourcentage en TEXTE, pas seulement en barre (section 7.6).
            Text(
              '${(progress * 100).round()} % · ${l.koryGoal(formatFcfa(pot.goalAmount!))}',
              style: TextStyle(
                color: dark
                    ? AppColors.neutralCreme.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
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
              style: TextStyle(
                color: dark
                    ? AppColors.neutralCreme.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// La tontine en rotation existe dans le cahier des charges, mais pas
/// avant Kory Plus (mois 13). On l'annonce sans la proposer.
class _TontineCard extends StatelessWidget {
  const _TontineCard({required this.pot});

  final KoryPot? pot;

  @override
  Widget build(BuildContext context) {
    if (pot == null) return const SizedBox.shrink();
    final round =
        pot!.currentRound != null &&
            pot!.currentRound! > 0 &&
            pot!.currentRound! <= pot!.rounds.length
        ? pot!.rounds[pot!.currentRound! - 1]
        : pot!.rounds.firstOrNull;
    return ModuleCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot!.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pot!.title} · Kory Plus · tour ${pot!.currentRound ?? 0} sur ${pot!.rounds.length}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Tontine · ${pot!.groupId == null ? '' : pot!.organizerName ?? ''} · bénéficiaire du mois : ${round?.beneficiaryName ?? '—'}',
          ),
          if (round != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                KoryStatusPill(
                  icon: Icons.schedule,
                  label:
                      '${formatFcfa(round.expectedTotal)} attendus aujourd’hui',
                  color: AppColors.feedbackWarning,
                ),
                const Spacer(),
                Text(
                  'Contribuer',
                  style: TextStyle(
                    color: AppColors.accentPrimaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
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
