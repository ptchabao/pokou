import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

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
    final l = L.of(context);
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
            emojiSizeMax: 30,
            verticalSpacing: 6,
            horizontalSpacing: 2,
            gridPadding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            // « No Recents », en anglais, au milieu d'une app en français.
            noRecents: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.emojiNoRecents,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: AppColors.chatComposerBg,
            indicatorColor: AppColors.accentPrimary,
            iconColorSelected: AppColors.accentPrimaryDark,
            iconColor: AppColors.textMuted,
            dividerColor: AppColors.border.withValues(alpha: 0.6),
            recentTabBehavior: RecentTabBehavior.RECENT,
            // On arrive sur les VISAGES : l'onglet des récents est vide la
            // première fois, et le panneau s'ouvrait sur un écran blanc.
            initCategory: Category.SMILEYS,
            // La recherche, au bout de la rangée des catégories.
            extraTab: CategoryExtraTab.SEARCH,
          ),
          // Plus de barre du bas : ses deux boutons flottaient sur la
          // grille. Effacer est dans la barre du panneau, chercher dans la
          // rangée des catégories.
          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
          searchViewConfig: SearchViewConfig(
            backgroundColor: AppColors.chatComposerBg,
            buttonIconColor: AppColors.textSecondary,
            hintText: l.emojiSearchHint,
            hintTextStyle: TextStyle(color: AppColors.textMuted),
            inputTextStyle: TextStyle(color: AppColors.textPrimary),
          ),
          skinToneConfig: const SkinToneConfig(enabled: true),
        ),
      ),
    );
  }
}
