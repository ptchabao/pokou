import '../../marketplace/presentation/assime_extras.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_radius.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_app_bar.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/status_halo.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/status_model.dart';
import 'post_status_screen.dart';
import 'status_controller.dart';
import 'story_viewer_screen.dart';
import '../../../core/widgets/skeleton.dart';
import '../../channels/presentation/channel_controller.dart';
import '../../channels/presentation/channels_section.dart';
import '../../marketplace/presentation/ad_card.dart';
import '../../marketplace/presentation/marketplace_controller.dart';

/// Onglet Actualités : statuts horizontaux, puis chaînes verticales.
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

  Future<void> _openComposer(BuildContext context, WidgetRef ref) async {
    final posted = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PostStatusScreen()));
    if (posted == true) ref.invalidate(statusFeedProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUserId = ref.watch(authControllerProvider).user?.id;
    final feedAsync = ref.watch(statusFeedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Le MÊME en-tête que le Marché et les Discussions. Trois
            // écrans qui posaient chacun leur titre à leur façon en
            // rendaient trois applications différentes.
            PokouAppBar(title: L.of(context).statusFeedTitle),
            Expanded(
              child: RefreshIndicator(
                // Les deux listes se rafraîchissent ensemble : le geste
                // porte sur la page, pas sur la bande de statuts.
                onRefresh: () async {
                  ref.invalidate(myChannelsProvider);
                  ref.invalidate(suggestedChannelsProvider);
                  ref.invalidate(adFeedProvider('STATUS'));
                  ref.invalidate(statusFeedProvider);
                  await ref.read(statusFeedProvider.future);
                },
                // Une seule liste pour toute la page, et les chaînes EN
                // DEHORS de l'état du fil de statuts.
                //
                // Elles étaient construites dans sa branche `data`, donc
                // elles n'apparaissaient qu'une fois les statuts arrivés —
                // et disparaissaient entièrement si le fil échouait, alors
                // qu'elles n'en dépendent en rien. Deux sources différentes,
                // deux chargements indépendants.
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    // « Mon Actu » EN TÊTE, et non noyé en première vignette
                    // de la bande.
                    //
                    // Publier était la première pastille d'une liste
                    // horizontale, de la même taille que les statuts des
                    // autres : l'action la plus importante de l'écran avait
                    // exactement le poids visuel d'un visage parmi dix. Elle
                    // prend maintenant une carte, avec ce qu'il faut savoir
                    // avant de publier — la durée et qui verra.
                    const _MyStatusCard(),
                    const SizedBox(height: 20),
                    // En-tête de section en Outfit, à la taille d'un
                    // titre et non d'une étiquette.
                    //
                    // Il était rendu en 13 points gris clair, c'est-à-dire
                    // moins visible que le contenu qu'il annonce. Une
                    // section dont le titre se lit après ce qu'il annonce
                    // ne sert à rien : l'œil descend, trouve des visages,
                    // et remonte pour comprendre.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        L.of(context).statusSection,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 86,
                      child: feedAsync.when(
                        loading: () => const _StatusStripSkeleton(),
                        error: (error, _) => Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => ref.invalidate(statusFeedProvider),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(L.of(context).statusFeedUnavailable),
                          ),
                        ),
                        data: (items) {
                          StatusFeedItem? mine;
                          final others = <StatusFeedItem>[];
                          for (final item in items) {
                            if (item.userId == myUserId) {
                              mine = item;
                            } else {
                              others.add(item);
                            }
                          }
                          final myStatus = mine;
                          // Une seule place sponsorisée (Assimé 14), et au
                          // plus un statut sponsorisé tous les 5 : elle ne
                          // vient qu'après 4 statuts de proches, jamais
                          // devant eux.
                          final sponsored = ref.watch(sponsoredStatusProvider).valueOrNull;
                          final sponsoredAt = sponsored != null && others.length >= sponsored.every - 1
                              ? sponsored.every - 1
                              : null;

                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: others.length + 1 + (sponsoredAt != null ? 1 : 0),
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 4),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _StatusTile(
                                  status: myStatus?.statuses.lastOrNull,
                                  avatar: myStatus?.avatar,
                                  initial: L.of(context).statusMine,
                                  seen: myStatus == null || myStatus.allViewed,
                                  showAddBadge: true,
                                  onTap: myStatus != null
                                      ? () =>
                                            _openViewer(context, ref, myStatus)
                                      : () => _openComposer(context, ref),
                                  onAddTap: () => _openComposer(context, ref),
                                );
                              }
                              if (sponsoredAt != null && index == sponsoredAt + 1) {
                                return SponsoredStatusTile(sponsored: sponsored!);
                              }
                              final item = others[index - 1 - (sponsoredAt != null && index > sponsoredAt + 1 ? 1 : 0)];
                              return _StatusTile(
                                status: item.statuses.lastOrNull,
                                avatar: item.avatar,
                                initial: item.displayName.isNotEmpty
                                    ? item.displayName[0].toUpperCase()
                                    : '?',
                                seen: item.allViewed,
                                showAddBadge: false,
                                onTap: () => _openViewer(context, ref, item),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Les publicités vendues pour l'emplacement « Statuts ».
                    // Entre les statuts et les chaînes, jamais dans la bande
                    // elle-même : une publicité déguisée en statut d'ami se
                    // lit comme une tromperie.
                    if (ref
                            .watch(adFeedProvider('STATUS'))
                            .valueOrNull
                            ?.firstOrNull
                        case final ad?) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AdCard(ad: ad),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Pas de titre « Chaînes » ici : ChannelsSection porte
                    // le sien, avec les boutons rechercher et créer. Les
                    // deux se suivaient, et le mot s'affichait deux fois.
                    const ChannelsSection(),
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

/// L'attente de la bande de statuts : des ronds, parce que ce sont des ronds
/// qui vont arriver.
///
/// ── Pourquoi une liste et non une `Row` ────────────────────────────────
///
/// C'était une `Row` de cinq ronds de 68 points, marge comprise : 360
/// points pour 352 disponibles sur un écran courant. Elle débordait de 8
/// points À CHAQUE ouverture de l'onglet, avec le bandeau rayé de Flutter —
/// invisible en release, mais bien réel, et signalé depuis un vrai
/// téléphone.
///
/// Le commentaire d'origine disait « cinq, de quoi remplir la largeur d'un
/// téléphone ». L'intention était juste, le compte ne l'était pas : la
/// largeur dépend de l'appareil, et aucun nombre écrit à la main ne peut
/// être juste sur tous.
///
/// Le squelette prend donc la MÊME forme que ce qu'il remplace — une liste
/// horizontale. Elle ne peut pas déborder, quelle que soit la largeur, et
/// la transition vers les vrais statuts ne fait plus sauter la mise en
/// page.
class _StatusStripSkeleton extends StatelessWidget {
  const _StatusStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Le squelette ne se fait pas défiler : il n'y a rien à y lire.
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, _) => const SkeletonCircle(size: 68),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.status,
    this.avatar,
    required this.initial,
    required this.seen,
    required this.showAddBadge,
    required this.onTap,
    this.onAddTap,
  });

  final PokouStatus? status;
  final MediaMeta? avatar;
  final String initial;
  final bool seen;
  final bool showAddBadge;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          StatusHalo(
            size: 68,
            thickness: 3.5,
            seen: seen,
            seenColor: AppColors.border,
            child: _StatusPreview(
              status: status,
              initial: initial,
              avatar: avatar,
            ),
          ),
          if (showAddBadge)
            Positioned(
              top: 24,
              right: 0,
              child: GestureDetector(
                onTap: onAddTap,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentPrimaryDark,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPreview extends ConsumerWidget {
  const _StatusPreview({
    required this.status,
    required this.initial,
    this.avatar,
  });

  final PokouStatus? status;
  final String initial;
  final MediaMeta? avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = status;
    final preview = current?.media != null
        ? ClipOval(
            child: FutureBuilder(
              future: ref
                  .read(mediaRepositoryProvider)
                  .resolveLocalFile(
                    current!.media!.id,
                    extension: mediaExtension(current.media!),
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.file(snapshot.data!, fit: BoxFit.cover);
                }
                return ColoredBox(color: AppColors.accentPrimaryLight);
              },
            ),
          )
        : CircleAvatar(
            backgroundColor: AppColors.accentPrimaryLight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                (current?.textContent?.trim().isNotEmpty ?? false)
                    ? current!.textContent!.trim()
                    : initial,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: preview),
        if (avatar != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: ContactAvatar(
              avatar: avatar,
              displayName: initial,
              size: 22,
            ),
          ),
      ],
    );
  }
}

/// La carte « Mon Actu », en tête de l'écran.
///
/// Elle porte l'action de publication et les deux choses qu'il faut savoir
/// avant de le faire : ça dure 24 heures, et ce sont les contacts qui le
/// voient. Les dire ICI plutôt que dans l'écran suivant, c'est laisser
/// quelqu'un renoncer avant d'avoir composé.
class _MyStatusCard extends ConsumerWidget {
  const _MyStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final moi = ref.watch(authControllerProvider).user;

    return InkWell(
      borderRadius: AppRadius.chip,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PostStatusScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.chip,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // L'avatar avec sa pastille « + » : le geste se comprend sans
            // lire, et c'est le même signe dans toutes les messageries.
            Stack(
              clipBehavior: Clip.none,
              children: [
                // `ContactAvatar` et non `IdentityAvatar` : cet écran a
                // son PROPRE anneau, segmenté par statut et plus riche que
                // le cercle générique. Et sur ma propre carte, ni anneau ni
                // point n'apprendraient quoi que ce soit.
                ContactAvatar(
                  avatar: moi?.avatar,
                  displayName: moi?.displayName ?? l.callYou,
                  size: 48,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.statusMineTitle,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.statusMineBody,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 13,
                        color: AppColors.accentPrimaryDark,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l.statusMineVisibility,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accentPrimaryDark,
                          ),
                        ),
                      ),
                    ],
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
