import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/status_halo.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/status_model.dart';
import 'post_status_screen.dart';
import 'status_controller.dart';
import 'status_list_screen.dart';
import 'story_viewer_screen.dart';

/// APP-2 · La bande des statuts, en tête des Discussions : « Mon statut »
/// avec un « + », puis les contacts qui ont un statut — non vus d'abord,
/// cerclés de cuivre (maquette Terre de Confiance).
class StatusStrip extends ConsumerWidget {
  const StatusStrip({super.key});

  static const _avatar = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final me = ref.watch(authControllerProvider).user;
    final feed = [
      ...(ref.watch(statusFeedProvider).valueOrNull ??
          const <StatusFeedItem>[]),
    ]..sort((a, b) => (b.hasUnseen ? 1 : 0) - (a.hasUnseen ? 1 : 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.discussionsStatusesNews,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimaryDark,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatusListScreen()),
                ),
                child: Text(l.homeSeeAll),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _Item(
                label: l.statusMyStatus,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PostStatusScreen()),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ContactAvatar(
                      avatar: me?.avatar,
                      displayName: me?.fullName ?? '',
                      size: _avatar,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final item in feed)
                _Item(
                  label: item.displayName.split(' ').first,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoryViewerScreen(item: item),
                    ),
                  ),
                  child: StatusHalo(
                    size: _avatar,
                    seen: !item.hasUnseen,
                    thickness: 2,
                    child: ContactAvatar(
                      avatar: item.avatar,
                      displayName: item.displayName,
                      size: _avatar - 8,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: 72,
      child: Column(
        children: [
          const SizedBox(height: 4),
          SizedBox(width: 56, height: 56, child: Center(child: child)),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
