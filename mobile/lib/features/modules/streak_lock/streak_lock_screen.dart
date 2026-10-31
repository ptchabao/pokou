import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../shared/module_payment.dart';
import '../shared/module_ui.dart';
import 'streak_lock_controller.dart';
import 'streak_lock_model.dart';

/// La couleur du module — pastille et compte à rebours, rien d'autre.
const _flame = Color(0xFFFF6B35);

/// Streak Lock — mes chaînes, et celles qui peuvent encore être sauvées.
class StreakLockScreen extends ConsumerWidget {
  const StreakLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streaksAsync = ref.watch(streaksProvider);

    return ModuleScaffold(
      title: 'Streak Lock',
      subtitle: L.of(context).streakSubtitle,
      child: streaksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: L.of(context).streakUnavailable,
          message: L.of(context).streakCheckConnection,
        ),
        data: (streaks) {
          if (streaks.isEmpty) {
            return ModuleEmptyState(
              icon: Icons.local_fire_department_outlined,
              title: L.of(context).streakEmptyTitle,
              message: L.of(context).streakEmptyBody,
            );
          }
          // Les chaînes rompues remontent en tête côté serveur : ce sont les
          // seules où une action est encore possible, et elles ont une
          // échéance. Les mélanger au reste reviendrait à les cacher.
          final rescuable = streaks
              .where((streak) => streak.canRestore)
              .toList();
          final running = streaks
              .where((streak) => !streak.canRestore)
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(streaksProvider);
              await ref.read(streaksProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                if (rescuable.isNotEmpty) ...[
                  ModuleSectionTitle(
                    L.of(context).streakToRescue,
                    subtitle: L.of(context).streakToRescueSub,
                  ),
                  for (final streak in rescuable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BrokenStreakCard(streak: streak),
                    ),
                ],
                if (running.isNotEmpty) ...[
                  ModuleSectionTitle(
                    rescuable.isEmpty
                        ? L.of(context).streakMine
                        : L.of(context).streakRunning,
                  ),
                  for (final streak in running)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RunningStreakTile(streak: streak),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Une chaîne qui tient : une ligne, sans bouton.
///
/// Rien à faire ici, donc rien à appuyer. Poser un bouton sur chaque ligne
/// donnerait à la liste l'allure d'une file d'attente d'actions, alors
/// qu'elle n'en demande aucune.
class _RunningStreakTile extends StatelessWidget {
  const _RunningStreakTile({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ModuleBadge(
            icon: Icons.local_fire_department,
            color: _flame,
            size: 42,
            muted: streak.currentDays == 0,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  streak.bestDays > streak.currentDays
                      ? L.of(context).streakRecord(streak.bestDays)
                      : L.of(context).streakLongest,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${streak.currentDays}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: streak.currentDays == 0 ? AppColors.textMuted : _flame,
                ),
              ),
              Text(
                'jours',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Une chaîne rompue, avec son compte à rebours.
class _BrokenStreakCard extends ConsumerStatefulWidget {
  const _BrokenStreakCard({required this.streak});

  final Streak streak;

  @override
  ConsumerState<_BrokenStreakCard> createState() => _BrokenStreakCardState();
}

class _BrokenStreakCardState extends ConsumerState<_BrokenStreakCard> {
  Timer? _ticker;
  late int _secondsLeft;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.streak.secondsLeft;
    // Le décompte est local pour l'AFFICHAGE seulement. L'autorité reste le
    // serveur, qui revérifie la fenêtre au moment de la confirmation : une
    // horloge de téléphone en avance ne doit rien ouvrir ni fermer.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 1 << 30));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(streakLockRepositoryProvider)
          .restore(widget.streak.peerId);
      if (!mounted) return;
      await openPaymentGateway(
        context,
        url,
        pendingMessage: L.of(context).streakRestorePending,
      );
      ref.invalidate(streaksProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).streakDeadlinePassed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _countdown {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.streak;
    final expired = _secondsLeft <= 0;

    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModuleBadge(
                icon: Icons.local_fire_department,
                color: _flame,
                muted: expired,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streak.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      L.of(context).streakBroken(streak.brokenDays),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                  size: 18,
                  color: expired ? AppColors.textMuted : _flame,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // Le temps restant est dit en clair : découvrir après
                    // coup qu'il était trop tard est ce qui rendrait ce
                    // module détestable.
                    expired
                        ? L.of(context).streakExpired
                        : L.of(context).streakCountdown(_countdown),
                    style: TextStyle(
                      color: expired
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!expired) ...[
            const SizedBox(height: 12),
            ModuleActionButton(
              label: L.of(context).streakRescueAction(streak.restoreAmount),
              busy: _busy,
              onPressed: _restore,
            ),
          ],
        ],
      ),
    );
  }
}
