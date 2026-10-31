import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'composer_state.dart';
import 'waveform.dart';

/// La PILULE pendant l'enregistrement d'une note vocale.
///
/// Elle remplace le champ de saisie et rien d'autre : le bouton de droite,
/// lui, reste en place et reste MONTÉ.
///
/// Ce n'est pas un détail de mise en page. C'est ce bouton qui tient le
/// doigt — il porte le `GestureDetector` de l'appui long. En remplaçant
/// toute la rangée au démarrage de l'enregistrement, on le démontait en
/// plein geste : plus aucun mouvement ne lui parvenait, donc ni glissement
/// pour annuler, ni glissement pour verrouiller, donc une corbeille qui
/// restait désactivée faute de verrouillage possible. Le geste et le widget
/// qui l'écoute doivent survivre ensemble.
///
/// Trois états y sont visibles : on enregistre, on s'apprête à annuler, ou
/// c'est verrouillé et le doigt peut partir.
class RecordingBar extends StatelessWidget {
  const RecordingBar({
    super.key,
    required this.state,
    required this.elapsed,
    required this.levels,
    required this.onCancel,
  });

  final ComposerState state;
  final Duration elapsed;

  /// Les niveaux captés au micro, du plus ancien au plus récent.
  final List<double> levels;

  /// La corbeille. N'a de sens qu'une fois verrouillé : tant que le doigt
  /// tient le micro, il ne peut pas venir la toucher.
  final VoidCallback onCancel;

  bool get _locked => state.mode == ComposerMode.locked;
  bool get _cancelling => state.mode == ComposerMode.cancelling;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Transform.translate(
      // La pilule suit le doigt vers la gauche : le geste doit se VOIR,
      // sinon rien ne dit qu'on est en train d'annuler.
      offset: Offset(_locked ? 0 : state.dragOffset.clamp(-56.0, 0.0), 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.chatComposerBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _cancelling
                ? AppColors.semanticError
                : AppColors.chatComposerBorder,
            width: _cancelling ? 1.4 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            // La corbeille n'est touchable qu'une fois verrouillé :
            // tant que le doigt tient le micro, il ne peut pas être
            // ici, et un bouton qu'on ne peut pas atteindre ne doit
            // pas prétendre le contraire.
            IconButton(
              onPressed: _locked ? onCancel : null,
              icon: Icon(
                Icons.delete_outline,
                color: _cancelling
                    ? AppColors.semanticError
                    : AppColors.chatIconMuted,
              ),
              tooltip: l.recDelete,
            ),
            _RecordingDot(cancelling: _cancelling),
            const SizedBox(width: 8),
            Text(
              _format(elapsed),
              style: TextStyle(
                color: AppColors.textPrimary,
                // Chiffres de largeur fixe : sans eux, le minuteur
                // tressaute à chaque seconde et attire l'œil pour
                // rien.
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _cancelling
                  ? _Hint(text: l.recReleaseToCancel, alert: true)
                  : Waveform(
                      levels: levels,
                      playedColor: AppColors.chatActionGreen,
                      remainingColor: AppColors.chatActionGreen,
                      height: 24,
                    ),
            ),
            const SizedBox(width: 10),
            if (!_cancelling)
              _Hint(
                text: _locked ? l.recLocked : l.recSlideToCancel,
                icon: _locked ? Icons.lock_outline : Icons.chevron_left,
              ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Le point rouge qui clignote — le signe le plus universel de « ça tourne ».
class _RecordingDot extends StatefulWidget {
  const _RecordingDot({required this.cancelling});

  final bool cancelling;

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(_controller),
      child: const Icon(
        Icons.fiber_manual_record,
        color: AppColors.semanticError,
        size: 14,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, this.icon, this.alert = false});

  final String text;
  final IconData? icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.semanticError : AppColors.chatIconMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 16, color: color),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// L'indicateur de verrouillage, au-dessus du micro pendant le geste.
///
/// Il n'apparaît QUE pendant l'enregistrement non verrouillé : afficher en
/// permanence un cadenas qu'on ne peut pas atteindre n'apprend rien, et
/// l'afficher après verrouillage répéterait une information déjà donnée
/// dans la barre.
class LockAffordance extends StatelessWidget {
  const LockAffordance({super.key, required this.progress});

  /// De 0 (le doigt n'a pas bougé) à 1 (le seuil est atteint).
  final double progress;

  @override
  Widget build(BuildContext context) {
    final reached = progress >= 1;
    return AnimatedOpacity(
      opacity: 0.55 + 0.45 * progress.clamp(0, 1),
      duration: const Duration(milliseconds: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.chatComposerBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: reached
                ? AppColors.chatActionGreen
                : AppColors.chatComposerBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reached ? Icons.lock : Icons.lock_open_outlined,
              size: 18,
              color: reached
                  ? AppColors.chatActionGreen
                  : AppColors.chatIconMuted,
            ),
            const SizedBox(height: 4),
            Icon(
              Icons.keyboard_arrow_up,
              size: 16,
              color: AppColors.chatIconMuted,
            ),
          ],
        ),
      ),
    );
  }
}
