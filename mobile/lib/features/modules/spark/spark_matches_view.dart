import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../shared/module_ui.dart';
import 'spark_controller.dart';
import 'spark_feed_view.dart';
import 'spark_model.dart';
import 'spark_room_screen.dart';
import 'spark_screen.dart';
import '../../../core/widgets/skeleton.dart';

/// Mes matchs — salles en cours d'abord, elles ont une échéance.
class SparkMatchesView extends ConsumerWidget {
  const SparkMatchesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(sparkMatchesProvider);

    return matchesAsync.when(
      loading: () => const SkeletonList(),
      error: (_, _) => ModuleEmptyState(
        icon: Icons.cloud_off,
        title: L.of(context).sparkMatchesUnavailable,
        message: L.of(context).streakCheckConnection,
      ),
      data: (matches) {
        if (matches.isEmpty) {
          return ModuleEmptyState(
            icon: Icons.favorite_border,
            title: L.of(context).sparkNoMatchTitle,
            message: L.of(context).sparkNoMatchBody,
          );
        }
        final open = matches.where((match) => match.isOpen).toList();
        final settled = matches.where((match) => !match.isOpen).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sparkMatchesProvider);
            await ref.read(sparkMatchesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (open.isNotEmpty) ...[
                ModuleSectionTitle(
                  L.of(context).sparkOpenRooms,
                  subtitle: L.of(context).sparkOpenRoomsSub,
                ),
                for (final match in open)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MatchTile(match: match, urgent: true),
                  ),
              ],
              if (settled.isNotEmpty) ...[
                ModuleSectionTitle(
                  open.isEmpty
                      ? L.of(context).sparkMyMatches
                      : L.of(context).sparkMore,
                ),
                for (final match in settled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MatchTile(match: match, urgent: false),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.urgent});

  final SparkMatch match;
  final bool urgent;

  String _subtitleOf(L l) {
    if (match.isOpen) {
      final minutes = match.roomSecondsLeft ~/ 60;
      final seconds = match.roomSecondsLeft % 60;
      return l.sparkRoomOpen('$minutes:${seconds.toString().padLeft(2, '0')}');
    }
    return switch (match.status) {
      'CONTINUED' => l.sparkBothYes,
      'SAVED' => l.sparkMatchSaved,
      _ => l.sparkRoomClosed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final peer = match.peer;
    return ModuleCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SparkRoomScreen(matchId: match.id)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 56,
              height: 56,
              child: SparkPhotoView(
                photo: (peer?.photos.isEmpty ?? true)
                    ? null
                    : peer!.photos.first,
                height: 56,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer == null
                      ? L.of(context).sparkMatch
                      : L
                            .of(context)
                            .sparkPersonAge(peer.displayName, peer.age),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitleOf(L.of(context)),
                  style: TextStyle(
                    color: urgent ? sparkAccent : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: urgent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
