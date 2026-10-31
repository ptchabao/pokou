import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/skeleton.dart';

/// L'attente d'une liste de chaînes — celle qu'on suit, les suggestions, les
/// résultats de recherche.
///
/// Trois lignes de la forme exacte d'une tuile : le rond de l'image, le nom
/// et sa ligne d'abonnés. La liste occupe donc déjà sa place, et l'arrivée
/// des vraies chaînes ne fait pas sauter ce qui suit.
class ChannelListSkeleton extends StatelessWidget {
  const ChannelListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.card,
              ),
              child: const Row(
                children: [
                  SkeletonCircle(size: 44),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 13),
                        SizedBox(height: 7),
                        SkeletonBox(width: 88, height: 11),
                      ],
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
