import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../shared/module_ui.dart';
import 'heart_league_controller.dart';
import 'heart_league_model.dart';

/// Les couleurs des cinq ligues.
///
/// Elles sont le SEUL endroit de cet écran où la couleur porte du sens, et
/// elles ne remplacent pas la palette de l'application : le reste — surfaces,
/// filets, encre — reste celui de Pokou. Une page entièrement dorée parce
/// qu'on est en Or se lirait comme une autre application.
const _leagueColors = {
  'BRONZE': Color(0xFFA1673B),
  'ARGENT': Color(0xFF8E9AA3),
  'OR': Color(0xFFD4AF37),
  'DIAMANT': Color(0xFF4FB6E0),
  'COURONNE': Color(0xFF7C3AED),
};

Color _colorFor(String code) =>
    _leagueColors[code] ?? AppColors.accentPrimaryDark;

/// Heart League — ma ligue, et le classement.
class HeartLeagueScreen extends ConsumerWidget {
  const HeartLeagueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingAsync = ref.watch(leagueStandingProvider);
    final rankingAsync = ref.watch(leagueRankingProvider);

    return ModuleScaffold(
      title: 'Heart League',
      subtitle: L.of(context).leagueSubtitle,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(leagueStandingProvider);
          ref.invalidate(leagueRankingProvider);
          await ref.read(leagueStandingProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            standingAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => ModuleEmptyState(
                icon: Icons.cloud_off,
                title: L.of(context).leagueUnavailable,
                message: L.of(context).streakCheckConnection,
              ),
              data: (standing) => _StandingCard(standing: standing),
            ),
            ModuleSectionTitle(L.of(context).leagueRanking),
            rankingAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (ranking) => _RankingList(ranking: ranking),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingCard extends ConsumerStatefulWidget {
  const _StandingCard({required this.standing});

  final LeagueStanding standing;

  @override
  ConsumerState<_StandingCard> createState() => _StandingCardState();
}

class _StandingCardState extends ConsumerState<_StandingCard> {
  bool _busy = false;

  Future<void> _protect() async {
    setState(() => _busy = true);
    try {
      final url = await ref.read(heartLeagueRepositoryProvider).buyProtection();
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      // On ne se réjouit PAS ici : l'effet est posé à la confirmation du
      // paiement, côté serveur. Afficher « protégé » dès l'ouverture de la
      // page de paiement mentirait à qui abandonne ensuite.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).leagueProtectPending)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).leaguePaymentFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final standing = widget.standing;
    final color = _colorFor(standing.leagueCode);

    return ModuleCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.emoji_events, color: color, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      standing.leagueLabel,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      '${standing.points} points',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: standing.progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            standing.isTop
                ? L.of(context).leagueAtTop
                // `isTop` est exactement `nextLabel == null` : dans cette
                // branche les deux champs sont renseignés.
                : L
                      .of(context)
                      .leaguePointsNeeded(
                        standing.pointsNeeded ?? 0,
                        standing.nextLabel!,
                      ),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          // Le décompte est ANNONCÉ, pas découvert après coup. Quelqu'un qui
          // perd des points sans avoir été prévenu n'en conclut pas qu'il
          // doit revenir : il en conclut que l'application est injuste.
          if (standing.isProtected)
            Row(
              children: [
                Icon(
                  Icons.shield,
                  size: 17,
                  color: AppColors.accentPrimaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L.of(context).leagueProtected,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Icon(Icons.schedule, size: 17, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    standing.daysUntilDecay <= 0
                        ? L.of(context).leagueDecayNow
                        : L.of(context).leagueDecayIn(standing.daysUntilDecay),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _protect,
                icon: _busy
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shield_outlined, size: 17),
                label: Text(L.of(context).leagueProtectAction),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentPrimaryDark,
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({required this.ranking});

  final LeagueRanking ranking;

  @override
  Widget build(BuildContext context) {
    if (ranking.items.isEmpty) {
      return Text(
        L.of(context).leagueNobodyRanked,
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    // Ma place est rappelée SOUS le tableau quand je n'y figure pas : un
    // classement où l'on ne se voit pas ne dit rien à celui qui le consulte.
    final amListed = ranking.items.any((entry) => entry.isMe);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < ranking.items.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: AppColors.border, indent: 56),
                _RankingRow(entry: ranking.items[i]),
              ],
            ],
          ),
        ),
        if (!amListed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              L.of(context).leagueMyRank(ranking.myRank, ranking.myPoints),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.entry});

  final LeagueEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(entry.leagueCode);
    return Container(
      color: entry.isMe ? AppColors.surfaceElevated : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: entry.rank <= 3 ? color : AppColors.textMuted,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              entry.isMe ? L.of(context).callYou : entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: entry.isMe ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${entry.points}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
