import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';

/// Le fichier local d'un sticker.
///
/// `keepAlive` VOLONTAIRE, contrairement à presque tout le reste de
/// l'application : un panneau de stickers défile, et chaque aller-retour
/// fait disparaître puis réapparaître les vignettes déjà affichées. Le
/// fichier, lui, est déjà sur le disque — c'est seulement la résolution du
/// chemin qu'on garde.
final stickerFileProvider = FutureProvider.family<File, int>((ref, mediaId) {
  ref.keepAlive();
  return ref
      .watch(mediaRepositoryProvider)
      .resolveLocalFile(mediaId, extension: 'webp');
});

/// Un sticker à l'écran — SANS CADRE, sans fond, sans coins arrondis.
///
/// C'est ce qui le distingue d'une image, et ce n'est pas cosmétique : un
/// sticker est découpé, sa transparence fait partie du dessin. L'enfermer
/// dans une bulle le poserait sur un rectangle de couleur et détruirait
/// l'effet.
class StickerImage extends ConsumerWidget {
  const StickerImage({super.key, required this.mediaId, required this.size});

  final int mediaId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(stickerFileProvider(mediaId));
    return SizedBox(
      width: size,
      height: size,
      child: file.when(
        // Un creux de la taille finale, pas un rond qui tourne : la grille
        // ne doit pas se réagencer quand les images arrivent.
        loading: () => _Placeholder(size: size),
        error: (_, __) => Icon(
          Icons.broken_image_outlined,
          size: size * 0.5,
          color: AppColors.chatIconMuted,
        ),
        data: (f) => Image.file(
          f,
          fit: BoxFit.contain,
          // Décoder à la taille d'affichage : une grille de trente
          // vignettes en pleine résolution suffit à faire tousser un
          // téléphone d'entrée de gamme.
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            size: size * 0.5,
            color: AppColors.chatIconMuted,
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(size * 0.15),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.chatIconMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
