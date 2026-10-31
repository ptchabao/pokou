import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import 'composer_state.dart';

/// Le bouton de droite : micro quand il n'y a rien à envoyer, envoi sinon.
///
/// Un seul bouton, dont la fonction dépend du contenu — c'est la règle qui
/// rend cette barre lisible sans notice. Deux boutons côte à côte
/// obligeraient à choisir entre eux à chaque message.
///
/// Il porte aussi les deux gestes de l'enregistrement, et c'est pour cela
/// qu'il n'est pas un simple `InkWell` : maintenir démarre, glisser vers la
/// gauche annule, glisser vers le haut verrouille. Un `GestureDetector`
/// unique, parce que ces trois gestes sont UN seul contact continu — les
/// répartir entre plusieurs reconnaisseurs les ferait se disputer le doigt.
class ComposerActionButton extends StatefulWidget {
  const ComposerActionButton({
    super.key,
    required this.state,
    required this.machine,
    required this.enabled,
    required this.onSendText,
    required this.onSendRecording,
    required this.onRecordStart,
    required this.onStateChanged,
    required this.onRelease,
    this.busyChild,
  });

  final ComposerState state;
  final ComposerMachine machine;
  final bool enabled;

  /// Appuyer alors qu'il y a du texte.
  final VoidCallback onSendText;

  /// Appuyer alors qu'un enregistrement VERROUILLÉ est en cours. Le bouton
  /// affiche « envoyer » dans les deux cas, mais ce n'est pas la même
  /// chose qu'on envoie — les confondre enverrait le champ texte (souvent
  /// vide) et laisserait la note tourner.
  final VoidCallback onSendRecording;

  /// Le doigt vient de se poser et l'enregistrement doit démarrer.
  final VoidCallback onRecordStart;

  final ValueChanged<ComposerState> onStateChanged;

  /// Le doigt s'est levé : envoyer la note, l'annuler, ou ne rien faire
  /// (verrouillé).
  final ValueChanged<ComposerRelease> onRelease;

  /// Remplace l'icône pendant un envoi en cours.
  final Widget? busyChild;

  @override
  State<ComposerActionButton> createState() => _ComposerActionButtonState();
}

class _ComposerActionButtonState extends State<ComposerActionButton>
    with SingleTickerProviderStateMixin {
  /// La pulsation de l'envoi : le bouton s'enfonce puis revient. C'est le
  /// « c'est parti » qu'on sent sous le doigt, avant même que la bulle
  /// apparaisse.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _pulseScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 0.82), weight: 1),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.82,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 2,
    ),
  ]).animate(_pulse);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _withPulse(VoidCallback action) {
    _pulse.forward(from: 0);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final machine = widget.machine;
    final enabled = widget.enabled;
    final onStateChanged = widget.onStateChanged;
    final onRelease = widget.onRelease;
    final showSend = state.showsSendButton;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Un appui simple n'envoie que s'il y a du texte. Sur le micro, il ne
      // fait rien : un enregistrement d'un dixième de seconde déclenché par
      // un effleurement n'a aucune valeur, et l'envoyer serait pire que de
      // l'ignorer.
      onTap: enabled && showSend
          ? () => _withPulse(
              state.mode == ComposerMode.locked
                  ? widget.onSendRecording
                  : widget.onSendText,
            )
          : null,
      onLongPressStart: enabled && !showSend
          ? (_) {
              // Une vibration au démarrage : sans retour, on ne sait pas si
              // l'appui a été pris en compte avant de voir la barre changer.
              HapticFeedback.mediumImpact();
              onStateChanged(machine.onRecordStart(state));
              widget.onRecordStart();
            }
          : null,
      onLongPressMoveUpdate: state.isRecording
          ? (details) {
              final next = machine.onRecordDrag(
                state,
                dx: details.offsetFromOrigin.dx,
                dy: details.offsetFromOrigin.dy,
              );
              if (next.mode == ComposerMode.locked &&
                  state.mode != ComposerMode.locked) {
                HapticFeedback.mediumImpact();
              }
              if (next != state) onStateChanged(next);
            }
          : null,
      onLongPressEnd: state.isRecording
          ? (_) {
              final result = machine.onRecordRelease(state);
              onStateChanged(result.state);
              onRelease(result.action);
            }
          : null,
      // Un geste annulé par le système (appel entrant, notification qui
      // vole le doigt) doit être traité comme un relâchement, pas ignoré :
      // sinon le micro reste ouvert indéfiniment.
      onLongPressCancel: state.isRecording
          ? () {
              final result = machine.onRecordRelease(state);
              onStateChanged(result.state);
              onRelease(result.action);
            }
          : null,
      // Pendant l'enregistrement, le micro grossit et suit le doigt vers la
      // corbeille (et monte vers le cadenas) : c'est ce qui montre que le
      // geste existe, et jusqu'où il faut aller.
      child: AnimatedSlide(
        offset: Offset(
          state.isRecording && state.mode != ComposerMode.locked
              ? state.dragOffset / 52
              : 0,
          state.isRecording && state.mode != ComposerMode.locked
              ? -state.lockProgress * 0.4
              : 0,
        ),
        duration: Duration.zero,
        child: AnimatedScale(
          scale: state.isRecording && state.mode != ComposerMode.locked
              ? 1.3
              : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: ScaleTransition(
            scale: _pulseScale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Rouge quand relâcher annulera : le doigt est sur la
                // corbeille.
                color: state.mode == ComposerMode.cancelling
                    ? AppColors.semanticError
                    : AppColors.chatActionGreen,
              ),
              child:
                  widget.busyChild ??
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInCubic,
                    // L'avion arrive en grandissant et en tournant un peu ;
                    // le micro revient de même quand le champ se vide.
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween<double>(
                        begin: -0.12,
                        end: 0,
                      ).animate(animation),
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      showSend ? Icons.send_rounded : Icons.mic,
                      key: ValueKey(showSend),
                      color: Colors.white,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
