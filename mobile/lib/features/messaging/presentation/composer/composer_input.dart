import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// La pilule de saisie, la même en conversation et en groupe :
///
/// ```text
/// [ 📎 ] [ 😀 ] [ Message…                 ] [ 📷 ]
/// ```
///
/// Le bouton micro / envoi reste DEHORS, à droite (voir mic_button.dart) :
/// il porte l'appui long de l'enregistrement et doit rester monté pendant
/// que la pilule cède la place à la barre d'enregistrement.
///
/// ── Ce qui bouge, et ce qui ne bouge pas ───────────────────────────────
///
/// Chaque frappe ne reconstruit que ce qui en dépend : l'appareil photo
/// écoute le texte, l'anneau de focus écoute le focus. Les deux écrans
/// n'ont plus à se reconstruire en entier pour faire disparaître une icône.
///
/// - **l'appareil photo** se retire en rétrécissant dès le premier
///   caractère, pour laisser la place au texte, et revient quand le champ
///   se vide ;
/// - **l'emoji** pivote vers le clavier quand le panneau est ouvert ;
/// - **le champ** grandit jusqu'à six lignes, puis défile.
///
/// Les deux écrans avaient chacun leur pilule, et elles avaient divergé :
/// trombone à droite ici, « + » à gauche là, l'emoji d'un côté ou de
/// l'autre, un anneau de focus en conversation et pas en groupe.
class ComposerInputPill extends StatelessWidget {
  const ComposerInputPill({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.emojiOpen,
    required this.enabled,
    required this.onAttach,
    required this.onToggleEmoji,
    required this.onCamera,
    required this.onSubmitted,
    required this.attachTooltip,
    required this.emojiTooltip,
    required this.cameraTooltip,
    this.onFieldTap,
    this.extraActions = const [],
    this.highlighted = false,
    this.glow = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool emojiOpen;

  /// Faux pendant un envoi : les boutons ne répondent plus.
  final bool enabled;

  final VoidCallback onAttach;
  final VoidCallback onToggleEmoji;
  final VoidCallback onCamera;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onFieldTap;

  final String attachTooltip;
  final String emojiTooltip;
  final String cameraTooltip;

  /// Des actions propres à un écran, entre l'emoji et le champ.
  final List<Widget> extraActions;

  /// Anneau vert même sans focus (mode « / » de la conversation).
  final bool highlighted;

  /// Halo autour de la pilule (mode « / »).
  final bool glow;

  /// Au-delà, le champ défile au lieu de pousser la conversation hors de
  /// l'écran.
  static const maxLines = 6;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, child) {
        final ring = highlighted || focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.chatComposerBg,
            borderRadius: BorderRadius.circular(28),
            // La pilule se détache de la barre par le contraste des deux
            // surfaces ; l'anneau ne dit que « c'est ici qu'on tape ».
            border: Border.all(
              color: ring ? AppColors.chatActionGreen : Colors.transparent,
              width: ring ? 2 : 1,
            ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: AppColors.chatActionGreen.withValues(alpha: 0.4),
                      blurRadius: 15,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ComposerIconButton(
            icon: Icons.attach_file,
            onPressed: enabled ? onAttach : null,
            tooltip: attachTooltip,
          ),
          ComposerIconButton(
            // Le sourire pivote vers le clavier : le même bouton ramène
            // au clavier système.
            icon: emojiOpen
                ? Icons.keyboard_outlined
                : Icons.sentiment_satisfied_alt_outlined,
            onPressed: enabled ? onToggleEmoji : null,
            tooltip: emojiTooltip,
          ),
          ...extraActions,
          Expanded(
            child: Padding(
              // Le texte s'aligne sur le centre des icônes de 48 points
              // tant qu'il tient sur une ligne.
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onTap: onFieldTap,
                minLines: 1,
                maxLines: maxLines,
                textInputAction: TextInputAction.send,
                onSubmitted: onSubmitted,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: hintText,
                  // UNE ligne : un indicateur qui passe à la ligne
                  // dédouble la pilule avant qu'on ait tapé quoi que ce
                  // soit.
                  hintMaxLines: 1,
                  hintStyle: TextStyle(
                    color: AppColors.chatIconMuted,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final typing = value.text.trim().isNotEmpty;
              return AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: AnimatedScale(
                  scale: typing ? 0 : 1,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: typing
                      ? const SizedBox(
                          width: 6,
                          height: kMinInteractiveDimension,
                        )
                      : Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ComposerIconButton(
                            icon: Icons.photo_camera_outlined,
                            onPressed: enabled ? onCamera : null,
                            tooltip: cameraTooltip,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Une icône de la pilule : cible de 48 points, ondulation verte.
class ComposerIconButton extends StatelessWidget {
  const ComposerIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Lu par TalkBack et VoiceOver, affiché à l'appui long.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: AppColors.chatActionGreen.withValues(alpha: 0.3),
        highlightColor: AppColors.chatActionGreen.withValues(alpha: 0.15),
        onTap: onPressed,
        child: SizedBox(
          width: kMinInteractiveDimension,
          height: kMinInteractiveDimension,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween<double>(begin: -0.15, end: 0).animate(animation),
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 22,
              color: AppColors.chatIconMuted,
            ),
          ),
        ),
      ),
    );
    final label = tooltip;
    return label == null ? button : Tooltip(message: label, child: button);
  }
}
