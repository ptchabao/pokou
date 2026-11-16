import '../../marketplace/presentation/assime_extras.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/country/country_config.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../../core/theme/app_radius.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/status_halo.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/status_model.dart';
import 'post_status_screen.dart';
import 'status_controller.dart';
import 'status_privacy_screen.dart';
import 'status_time.dart';
import 'story_viewer_screen.dart';
import '../../../core/widgets/skeleton.dart';
import '../../channels/presentation/channel_controller.dart';
import '../../channels/presentation/channels_section.dart';
import '../../marketplace/presentation/ad_card.dart';
import '../../marketplace/presentation/marketplace_controller.dart';

/// Statuts (STA-1) : « Mon statut » en tête, puis une LISTE — les récents
/// d'abord, ceux déjà vus ensuite — et la ligne « Qui voit mes statuts ».
///
/// Onglet au lot 1, écran poussé ailleurs (bande des Discussions, Plus) :
/// la flèche de retour n'apparaît que quand il y a où revenir.
///
/// Hors lot 1, la publicité de l'emplacement « Statuts » et les chaînes
/// restent sous la liste : elles n'ont pas d'autre porte d'entrée.
class StatusListScreen extends ConsumerWidget {
  const StatusListScreen({super.key});

  Future<void> _openViewer(
    BuildContext context,
    WidgetRef ref,
    StatusFeedItem item,
  ) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StoryViewerScreen(item: item)));
    ref.invalidate(statusFeedProvider);
  }

  Future<void> _openComposer(
    BuildContext context,
    WidgetRef ref, {
    StatusComposerStart start = StatusComposerStart.text,
  }) async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PostStatusScreen(start: start)),
    );
    if (posted == true) ref.invalidate(statusFeedProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final myUserId = ref.watch(authControllerProvider).user?.id;
    final feedAsync = ref.watch(statusFeedProvider);
    final lot1 = isLot1(ref.watch(currentCountryConfigProvider).modules);
    final audience = ref.watch(statusPrivacyProvider).valueOrNull;

    return Scaffold(
      // Un fond plein : ouvert par-dessus la coquille (« Tout voir » de la
      // bande des statuts), l'écran n'a plus le fond de la coquille derrière
      // lui, et un fond transparent laissait voir du noir.
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            PokouAppBar(
              title: l.statusFeedTitle,
              subtitle: l.statusFeedSubtitle,
              showStatus: false,
              leading: Navigator.of(context).canPop()
                  ? const PokouBackButton()
                  : null,
              actions: [
                PokouAppBarAction(
                  icon: Icons.photo_camera_outlined,
                  tooltip: l.statusCamera,
                  onPressed: () => _openComposer(
                    context,
                    ref,
                    start: StatusComposerStart.photo,
                  ),
                ),
                const SizedBox(width: 8),
                PokouAppBarAction(
                  icon: Icons.edit_outlined,
                  tooltip: l.statusNewTitle,
                  onPressed: () => _openComposer(context, ref),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (!lot1) {
                    ref.invalidate(myChannelsProvider);
                    ref.invalidate(suggestedChannelsProvider);
                    ref.invalidate(adFeedProvider('STATUS'));
                  }
                  ref.invalidate(statusPrivacyProvider);
                  ref.invalidate(statusFeedProvider);
                  await ref.read(statusFeedProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    ...feedAsync.when(
                      loading: () => [
                        const _MyStatusCard(mine: null, onTap: null),
                        const SizedBox(height: 16),
                        const SkeletonList(),
                      ],
                      error: (_, _) => [
                        _MyStatusCard(
                          mine: null,
                          onTap: () => _openComposer(context, ref),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => ref.invalidate(statusFeedProvider),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(l.statusFeedUnavailable),
                          ),
                        ),
                      ],
                      data: (items) {
                        StatusFeedItem? mine;
                        final recent = <StatusFeedItem>[];
                        final seen = <StatusFeedItem>[];
                        for (final item in items) {
                          if (item.userId == myUserId) {
                            mine = item;
                          } else if (item.allViewed) {
                            seen.add(item);
                          } else {
                            recent.add(item);
                          }
                        }
                        final myStatus = mine;
                        // Une seule place sponsorisée, jamais devant les
                        // proches, et jamais au lot 1.
                        final sponsored = lot1
                            ? null
                            : ref.watch(sponsoredStatusProvider).valueOrNull;
                        return [
                          _MyStatusCard(
                            mine: myStatus,
                            onTap: myStatus != null
                                ? () => _openViewer(context, ref, myStatus)
                                : () => _openComposer(context, ref),
                            onAdd: () => _openComposer(context, ref),
                          ),
                          if (recent.isNotEmpty) ...[
                            _SectionLabel(l.statusRecent),
                            for (final item in recent)
                              _StatusRow(
                                item: item,
                                onTap: () => _openViewer(context, ref, item),
                              ),
                          ],
                          if (sponsored != null &&
                              recent.length + 1 >= sponsored.every) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SponsoredStatusTile(sponsored: sponsored),
                            ),
                          ],
                          if (seen.isNotEmpty) ...[
                            _SectionLabel(l.statusSeen),
                            for (final item in seen)
                              _StatusRow(
                                item: item,
                                onTap: () => _openViewer(context, ref, item),
                              ),
                          ],
                          if (recent.isEmpty && seen.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 4,
                              ),
                              child: Text(
                                l.statusNoneYet,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ];
                      },
                    ),
                    const SizedBox(height: 16),
                    _WhoSeesRow(
                      value: audience?.audience.labelOf(l),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StatusPrivacyScreen(),
                          ),
                        );
                        ref.invalidate(statusPrivacyProvider);
                      },
                    ),
                    if (!lot1) ...[
                      const SizedBox(height: 24),
                      // Les publicités vendues pour l'emplacement « Statuts »,
                      // SOUS la liste : une publicité déguisée en statut d'ami
                      // se lirait comme une tromperie.
                      if (ref
                              .watch(adFeedProvider('STATUS'))
                              .valueOrNull
                              ?.firstOrNull
                          case final ad?) ...[
                        AdCard(ad: ad),
                        const SizedBox(height: 24),
                      ],
                      const ChannelsSection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Une personne : sa photo dans l'anneau (plein tant qu'il reste un statut
/// non vu), son nom, le ✓ d'un compte certifié, et l'âge du dernier statut.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.item, required this.onTap});

  final StatusFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = item.statuses.lastOrNull;
    return InkWell(
      borderRadius: AppRadius.chip,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            StatusHalo(
              size: 50,
              thickness: 2.5,
              seen: item.allViewed,
              seenColor: AppColors.border,
              child: ContactAvatar(
                avatar: item.avatar,
                displayName: item.displayName,
                size: 42,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (item.isVerified) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(size: 14),
                      ],
                    ],
                  ),
                  if (latest != null)
                    Text(
                      statusAgo(L.of(context), latest.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Qui voit mes statuts · Mes contacts › » — le réglage à portée de main,
/// là où l'on publie.
class _WhoSeesRow extends StatelessWidget {
  const _WhoSeesRow({required this.value, required this.onTap});

  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.chip,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  L.of(context).statusWhoSees,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// La carte « Mon statut », en tête de l'écran : ma photo avec sa pastille
/// « + ». Sans statut, la toucher ouvre le compositeur ; avec, elle montre
/// les miens — la pastille, elle, en ajoute toujours un.
class _MyStatusCard extends ConsumerWidget {
  const _MyStatusCard({required this.mine, required this.onTap, this.onAdd});

  final StatusFeedItem? mine;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final moi = ref.watch(authControllerProvider).user;
    final latest = mine?.statuses.lastOrNull;

    return InkWell(
      borderRadius: AppRadius.chip,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                StatusHalo(
                  size: 50,
                  thickness: 2.5,
                  seen: true,
                  seenColor: mine == null
                      ? Colors.transparent
                      : AppColors.accentPrimary,
                  child: ContactAvatar(
                    avatar: moi?.avatar,
                    displayName: moi?.displayName ?? l.callYou,
                    size: 42,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: onAdd ?? onTap,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.statusMineTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    latest == null
                        ? l.statusMineBody
                        : statusAgo(l, latest.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
