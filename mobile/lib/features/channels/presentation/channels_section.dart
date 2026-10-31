import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../data/channel_model.dart';
import 'channel_controller.dart';
import 'channel_editor_screen.dart';
import 'channel_screen.dart';
import 'channel_search_screen.dart';
import 'channel_certification_screen.dart';
import 'channel_avatar.dart';
import 'channel_skeletons.dart';

class ChannelsSection extends ConsumerWidget {
  const ChannelsSection({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    PokouChannel? channel,
  }) async {
    final saved = await Navigator.of(context).push<PokouChannel>(
      MaterialPageRoute(builder: (_) => ChannelEditorScreen(channel: channel)),
    );
    if (saved != null) ref.invalidate(myChannelsProvider);
  }

  Future<void> _shareInvite(
    BuildContext context,
    WidgetRef ref,
    PokouChannel channel,
  ) async {
    try {
      final link = await ref
          .read(channelRepositoryProvider)
          .regenerateInviteLink(channel.id);
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelLinkCopiedClipboard)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelLinkUnavailableShort)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(myChannelsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                L.of(context).channelsSection,
                // Outfit, à la même taille que « Statuts » juste au-dessus :
                // deux sections de la même page ne peuvent pas avoir deux
                // niveaux de titre différents, sinon l'une paraît
                // subordonnée à l'autre alors qu'elles sont sœurs.
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChannelSearchScreen()),
              ),
              icon: const Icon(Icons.search),
              tooltip: L.of(context).channelSearchTooltip,
            ),
            IconButton(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: L.of(context).channelCreateTooltip,
            ),
          ],
        ),
        // Les chaînes suivies, PUIS les suggestions — et non l'une OU
        // l'autre.
        //
        // La version précédente écrivait `items.isEmpty ? suggestions :
        // liste`. S'abonner à une chaîne faisait donc passer la liste de
        // vide à non vide, et toutes les autres suggestions disparaissaient
        // d'un coup : l'utilisateur perdait sa page de découverte au moment
        // précis où il venait de montrer qu'elle l'intéressait.
        //
        // Découvrir et suivre ne s'excluent pas. On n'arrête pas de proposer
        // des chaînes parce que quelqu'un en suit une.
        channels.when(
          loading: () => const ChannelListSkeleton(),
          error: (_, _) => const _SuggestedChannels(),
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final channel in items)
                _ChannelTile(
                  channel: channel,
                  onOpen: () => _open(context, ref, channel),
                  onEdit: () => _edit(context, ref, channel: channel),
                  onInvite: () => _shareInvite(context, ref, channel),
                ),
              if (items.isNotEmpty) const SizedBox(height: 16),
              _SuggestedChannels(showEmptyHint: items.isEmpty),
            ],
          ),
        ),
      ],
    );
  }
}

/// Entrer dans la chaîne : son fil de publications. C'est là que tout se
/// passe — la tuile n'était qu'une vignette, elle ne menait nulle part.
///
/// Hors des classes : le geste est le même qu'on suive déjà la chaîne ou
/// qu'on vienne de la découvrir dans les suggestions. Les suggestions sont
/// réévaluées au retour, parce qu'on a pu s'abonner depuis le fil.
Future<void> _open(
  BuildContext context,
  WidgetRef ref,
  PokouChannel channel,
) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ChannelScreen(channel: channel)));
  ref.invalidate(myChannelsProvider);
  ref.invalidate(suggestedChannelsProvider);
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.card,
      ),
      child: Text(
        L.of(context).channelEmptyHint,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

/// Ce qu'on montre à quelqu'un qui ne suit aucune chaîne.
///
/// L'espace était vide, avec pour seule phrase « Créez une chaîne pour
/// partager vos actualités » — un message qui s'adresse à celui qui veut
/// PUBLIER, alors que la plupart des gens arrivent pour LIRE. Ils
/// repartaient sans rien avoir trouvé, faute de point d'entrée.
///
/// L'ancien message reste, mais en dernier recours : quand il n'y a
/// vraiment rien à proposer, inventer une liste serait pire que le vide.
class _SuggestedChannels extends ConsumerWidget {
  const _SuggestedChannels({this.showEmptyHint = true});

  /// Faut-il retomber sur « créez une chaîne » quand il n'y a rien à
  /// proposer ?
  ///
  /// Non quand l'utilisateur en suit déjà : lui dire que son espace est vide
  /// alors qu'il ne l'est pas serait faux, et occuperait la place pour rien.
  final bool showEmptyHint;

  Future<void> _follow(
    BuildContext context,
    WidgetRef ref,
    PokouChannel channel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = L.of(context).channelFollowed(channel.name);
    final failed = L.of(context).channelFollowFailed;
    try {
      await ref.read(channelRepositoryProvider).follow(channel.id);
      // Les deux listes changent d'un coup : celle qu'on suit gagne une
      // ligne, celle des suggestions en perd une.
      ref.invalidate(myChannelsProvider);
      ref.invalidate(suggestedChannelsProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(suggestedChannelsProvider)
        .when(
          loading: () => const ChannelListSkeleton(),
          // Sans réseau, il n'y a rien à découvrir : on retombe sur
          // l'invitation à créer, qui reste vraie.
          error: (_, _) =>
              showEmptyHint ? const _EmptyChannels() : const SizedBox.shrink(),
          data: (suggestions) {
            if (suggestions.isEmpty) {
              return showEmptyHint
                  ? const _EmptyChannels()
                  : const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.of(context).channelSuggestedTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L.of(context).channelSuggestedBody,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                for (final channel in suggestions)
                  _SuggestionTile(
                    channel: channel,
                    onOpen: () => _open(context, ref, channel),
                    onFollow: () => _follow(context, ref, channel),
                  ),
              ],
            );
          },
        );
  }
}

/// Une chaîne proposée : on peut l'ouvrir pour voir ce qu'elle publie, ou
/// s'y abonner directement.
///
/// L'ouvrir AVANT de s'abonner est le geste attendu — une chaîne est
/// publique, et s'engager sans avoir lu une ligne n'a pas de sens.
class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.channel,
    required this.onOpen,
    required this.onFollow,
  });

  final PokouChannel channel;
  final VoidCallback onOpen;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: AppRadius.card,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
        ),
        child: Row(
          children: [
            ChannelAvatar(channel: channel),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.accentPrimaryDark,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    channel.description?.trim().isNotEmpty == true
                        ? channel.description!
                        : L.of(context).channelFollowers(channel.followerCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onFollow,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(L.of(context).channelFollow),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.onOpen,
    required this.onEdit,
    required this.onInvite,
  });

  final PokouChannel channel;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: AppRadius.card,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
        ),
        child: Row(
          children: [
            ChannelAvatar(channel: channel),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.accentPrimaryDark,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    L.of(context).channelFollowers(channel.followerCount),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // La certification ne se propose qu'au PROPRIÉTAIRE, et
            // seulement tant qu'elle manque : un badge déjà obtenu se voit
            // dans le titre, le reproposer laisserait croire qu'il a expiré.
            if (channel.isOwner && !channel.isVerified)
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ChannelCertificationScreen(channel: channel),
                  ),
                ),
                icon: const Icon(Icons.verified_outlined),
                tooltip: L.of(context).certifyTooltip,
              ),
            if (channel.isAdmin) ...[
              IconButton(
                onPressed: onInvite,
                icon: const Icon(Icons.link),
                tooltip: L.of(context).channelGenerateLink,
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: L.of(context).channelEditTooltip,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
