import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Le panneau emoji, sous la barre de saisie.
///
/// ── Pourquoi un panneau, alors que le clavier en propose déjà ───────────
///
/// Le clavier système a bien ses emojis, mais y accéder demande de le
/// basculer — un geste différent selon le clavier installé, et introuvable
/// pour beaucoup de gens. Un bouton 😊 dans la barre les met à une touche,
/// et c'est ce que fait toute messagerie moderne.
///
/// ── La hauteur, qui n'est pas un détail ────────────────────────────────
///
/// Le panneau prend la hauteur du CLAVIER, mémorisée pendant qu'il était
/// ouvert. Sans cela, ouvrir le panneau ferait sauter toute la conversation
/// — le clavier disparaît, la vue remonte, le panneau apparaît, elle
/// redescend. Deux secousses pour un geste.
///
/// Repli à 280 points quand le clavier n'a jamais été ouvert : c'est la
/// hauteur moyenne d'un clavier Android, assez proche pour que le saut soit
/// imperceptible.
class EmojiPanel extends StatelessWidget {
  const EmojiPanel({
    super.key,
    required this.controller,
    required this.height,
    required this.onBackspace,
  });

  /// Le champ de saisie. L'emoji s'insère À LA POSITION DU CURSEUR, pas à la
  /// fin : quelqu'un qui corrige le début de sa phrase doit pouvoir y mettre
  /// un emoji sans que celui-ci file en queue.
  final TextEditingController controller;

  final double height;

  /// La touche d'effacement du panneau — sans elle, il faut rouvrir le
  /// clavier pour retirer un emoji qu'on vient de poser.
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: EmojiPicker(
        textEditingController: controller,
        onBackspacePressed: onBackspace,
        config: Config(
          height: height,
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: AppColors.chatComposerBg,
            columns: 8,
            emojiSizeMax: 28,
            verticalSpacing: 4,
            horizontalSpacing: 4,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: AppColors.chatComposerBg,
            indicatorColor: AppColors.accentPrimary,
            iconColorSelected: AppColors.accentPrimaryDark,
            iconColor: AppColors.textMuted,
            dividerColor: AppColors.border.withValues(alpha: 0.5),
            recentTabBehavior: RecentTabBehavior.RECENT,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: AppColors.chatComposerBg,
            buttonColor: AppColors.surfaceElevated,
            buttonIconColor: AppColors.textSecondary,
            showSearchViewButton: true,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: AppColors.chatComposerBg,
            buttonIconColor: AppColors.textSecondary,
          ),
          skinToneConfig: const SkinToneConfig(enabled: true),
        ),
      ),
    );
  }
}
