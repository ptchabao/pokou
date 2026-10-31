import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/sticker_models.dart';
import 'sticker_image.dart';
import 'sticker_providers.dart';

/// Les stickers proposés pour l'emoji qu'on vient de taper.
///
/// ── Ce qui décide de son apparition ────────────────────────────────────
///
/// Rien d'autre que l'emoji terminal. Pas de bouton, pas de geste : on
/// tape 😂, la bande apparaît ; on continue à écrire, elle disparaît. Une
/// bande qui resterait à l'écran volerait une ligne à la conversation pour
/// une proposition devenue hors sujet.
///
/// ── Pourquoi elle ne prend AUCUNE place quand elle est vide ────────────
///
/// Réserver sa hauteur « au cas où » ferait remonter le fil de 64 points en
/// permanence, pour une bande visible quelques secondes par heure. Elle
/// occupe donc zéro tant qu'il n'y a rien à montrer — y compris pendant le
/// chargement, sans quoi chaque emoji tapé ferait sauter la conversation
/// avant même de savoir s'il existe un sticker à proposer.
class StickerSuggestionBar extends ConsumerWidget {
  const StickerSuggestionBar({
    super.key,
    required this.emoji,
    required this.onSelected,
  });

  /// L'emoji terminal du champ de saisie, ou une chaîne vide.
  final String emoji;

  final void Function(Sticker sticker) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (emoji.isEmpty) return const SizedBox.shrink();

    final suggestions = ref.watch(stickerSuggestionProvider(emoji));
    final items = suggestions.valueOrNull ?? const <Sticker>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 64,
      color: AppColors.chatComposerBg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final sticker = items[index];
          return InkWell(
            onTap: () => onSelected(sticker),
            borderRadius: BorderRadius.circular(8),
            child: StickerImage(mediaId: sticker.mediaId, size: 52),
          );
        },
      ),
    );
  }
}
