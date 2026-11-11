import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stickers/data/sticker_models.dart';
import '../../../stickers/presentation/sticker_panel.dart';
import 'emoji_panel.dart';

/// Ce qui s'ouvre sous la barre de saisie : emoji ou stickers.
///
/// ── Pourquoi un seul panneau à deux onglets ────────────────────────────
///
/// Deux boutons dans la barre, deux panneaux qui s'ouvrent et se ferment
/// l'un l'autre : chaque bascule aurait refermé puis rouvert un conteneur
/// de la hauteur du clavier, et la conversation aurait sauté à chaque
/// passage d'un onglet à l'autre. Ici le conteneur reste, seul son contenu
/// change — c'est aussi ce que fait WhatsApp, et pour la même raison.
///
/// ── L'onglet actif SURVIT à la fermeture ───────────────────────────────
///
/// Quelqu'un qui envoie trois stickers de suite ferme le panneau entre
/// chaque envoi. Le rouvrir sur l'onglet emoji lui ferait refaire le même
/// geste à chaque fois. L'état vit donc chez l'appelant, pas ici.
class ComposerPanel extends StatelessWidget {
  const ComposerPanel({
    super.key,
    required this.controller,
    required this.height,
    required this.onBackspace,
    required this.onStickerSelected,
    required this.tab,
    required this.onTabChanged,
    required this.onGifRequested,
  });

  final TextEditingController controller;
  final double height;
  final VoidCallback onBackspace;
  final void Function(Sticker sticker) onStickerSelected;
  final ComposerPanelTab tab;
  final ValueChanged<ComposerPanelTab> onTabChanged;

  /// Ouvrir un GIF depuis les fichiers.
  ///
  /// Un BOUTON et non un troisième onglet, et c'est délibéré : un onglet
  /// promet quelque chose à parcourir. Pokou n'a pas de catalogue de GIF —
  /// pas de clé d'API, rien qui sorte vers un service tiers, c'est un choix
  /// déjà pris et documenté. Un onglet qui n'afficherait qu'un bouton
  /// « choisir un fichier » ferait une promesse que le panneau ne tient pas.
  final VoidCallback onGifRequested;

  /// La barre de sélection, en points. Assez haute pour que ses boutons
  /// fassent 44 points, la cible tactile minimale.
  static const _hauteurBarre = 56.0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Le bas de l'écran (indicateur d'accueil, barre de gestes) : le fond du
    // panneau le couvre, son contenu s'arrête au-dessus.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final contentHeight = (height - _hauteurBarre - bottomInset).clamp(
      120.0,
      height,
    );
    return _KeyboardHandoff(
      height: height,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.chatComposerBg,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: _hauteurBarre,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                  child: Row(
                    children: [
                      // Les deux choses qu'on PARCOURT : emoji et stickers.
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _Segment(
                                  icone: Icons.sentiment_satisfied_alt_rounded,
                                  label: l.stickerTabEmoji,
                                  selectionne: tab == ComposerPanelTab.emoji,
                                  onTap: () =>
                                      onTabChanged(ComposerPanelTab.emoji),
                                ),
                              ),
                              Expanded(
                                child: _Segment(
                                  icone: Icons.auto_awesome_rounded,
                                  label: l.stickerTabStickers,
                                  selectionne: tab == ComposerPanelTab.stickers,
                                  onTap: () =>
                                      onTabChanged(ComposerPanelTab.stickers),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Le GIF est une ACTION (choisir un fichier), pas un
                      // onglet : il ne ressemble donc plus à un onglet.
                      Semantics(
                        button: true,
                        label: l.convAttachGif,
                        child: Material(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(22),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onGifRequested,
                            child: SizedBox(
                              height: 44,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Center(
                                  child: ExcludeSemantics(
                                    child: Text(
                                      l.convAttachGif,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Effacer : à portée du pouce, en haut à droite, au
                      // lieu d'un bouton flottant qui recouvrait la grille.
                      if (tab == ComposerPanelTab.emoji)
                        IconButton(
                          tooltip: l.composerBackspace,
                          onPressed: onBackspace,
                          icon: Icon(
                            Icons.backspace_outlined,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: contentHeight,
                child: switch (tab) {
                  // La hauteur passée aux panneaux est celle qui RESTE une
                  // fois la barre et le bas de l'écran retirés — sinon ils
                  // débordent d'autant, et Flutter le signale.
                  ComposerPanelTab.emoji => EmojiPanel(
                    controller: controller,
                    height: contentHeight,
                    onBackspace: onBackspace,
                  ),
                  ComposerPanelTab.stickers => StickerPanel(
                    height: contentHeight,
                    onSend: onStickerSelected,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le passage de relais entre le clavier système et le panneau.
///
/// Le panneau prend la hauteur du clavier, mais il ne peut pas apparaître
/// d'un bloc : le clavier met un quart de seconde à descendre, et pendant
/// ce temps les deux s'empilaient — la barre de saisie montait de toute la
/// hauteur du panneau, puis redescendait. Ici, le panneau ne montre que ce
/// que le clavier libère : à chaque image, clavier + panneau font la même
/// hauteur, et la barre ne bouge pas. Même chose à l'envers quand le
/// clavier remonte (voir `_toggleEmoji` dans les écrans : le panneau reste
/// le temps que le clavier arrive).
///
/// Ouvert sans clavier, il monte depuis le bas au lieu d'apparaître.
///
/// L'encart du clavier se lit sur la VUE, et non dans `MediaQuery` : sous un
/// `Scaffold` qui se redimensionne, `MediaQuery` le remet à zéro.
class _KeyboardHandoff extends StatefulWidget {
  const _KeyboardHandoff({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  State<_KeyboardHandoff> createState() => _KeyboardHandoffState();
}

class _KeyboardHandoffState extends State<_KeyboardHandoff>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  /// Passé le temps de l'animation du clavier, le panneau prend TOUTE sa
  /// hauteur : certains téléphones continuent de signaler un encart de
  /// clavier après sa fermeture, et le panneau restait caché derrière la
  /// barre de saisie.
  bool _settled = false;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settleTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  void didChangeMetrics() {
    // Chaque image de l'animation du clavier.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
    return AnimatedBuilder(
      animation: _appear,
      builder: (context, child) {
        final freed = _settled
            ? widget.height
            : (widget.height - keyboard).clamp(0.0, widget.height);
        final rising =
            widget.height * Curves.easeOutCubic.transform(_appear.value);
        final visible = freed < rising ? freed : rising;
        return SizedBox(
          height: visible,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: widget.height,
              maxHeight: widget.height,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

enum ComposerPanelTab { emoji, stickers }

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icone,
    required this.label,
    required this.selectionne,
    required this.onTap,
  });

  final IconData icone;
  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = selectionne
        ? AppColors.accentPrimaryDark
        : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selectionne,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selectionne ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selectionne
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 19, color: couleur),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selectionne
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: couleur,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
