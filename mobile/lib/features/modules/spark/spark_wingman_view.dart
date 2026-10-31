import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../shared/module_ui.dart';
import 'spark_controller.dart';
import 'spark_feed_view.dart';
import 'spark_model.dart';

/// Les avis qu'on me demande.
///
/// Accessible même sans Spark activé : on peut rendre ce service à un ami
/// sans y être soi-même, et c'est exactement par là que le module se diffuse.
class SparkWingmanScreen extends ConsumerWidget {
  const SparkWingmanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(wingmanRequestsProvider);

    return ModuleScaffold(
      title: L.of(context).wingmanTitle,
      subtitle: L.of(context).wingmanAnon,
      child: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: L.of(context).wingmanUnavailable,
          message: L.of(context).modulesCheckNetwork,
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return ModuleEmptyState(
              icon: Icons.how_to_vote_outlined,
              title: L.of(context).wingmanNothing,
              message: L.of(context).wingmanNothingBody,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _RequestCard(request: requests[index]),
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request});

  final WingmanRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _vote(String vote) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(sparkRepositoryProvider)
          .castWingmanVote(widget.request.id, vote);
      ref.invalidate(wingmanRequestsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.request.candidate;
    return ModuleCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.tile),
            ),
            child: SparkPhotoView(
              photo: candidate.photos.isEmpty ? null : candidate.photos.first,
              height: 200,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.of(context).wingmanAsksYou(widget.request.askedBy),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${candidate.displayName}, ${candidate.age}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (candidate.bio != null && candidate.bio!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    candidate.bio!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ModuleQuietButton(
                        label: L.of(context).wingmanMeh,
                        onPressed: _busy ? null : () => _vote('RED'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ModuleActionButton(
                        label: L.of(context).wingmanWorthIt,
                        busy: _busy,
                        onPressed: () => _vote('GREEN'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  // Dit au votant : c'est ce qui permet de répondre
                  // honnêtement sans craindre une dispute.
                  L.of(context).wingmanPrivacy,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
