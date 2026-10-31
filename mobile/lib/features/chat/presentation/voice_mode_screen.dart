import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../messaging/presentation/composer/voice_recording.dart';
import '../../messaging/presentation/composer/waveform.dart';
import 'ai_style.dart';
import 'chat_controller.dart';

enum _VoicePhase { listening, transcribing, ready, failed }

/// Le mode écoute : on parle à l'assistant au lieu de lui écrire.
///
/// L'écran laisse le fil de côté le temps de la commande vocale. Ce qu'on
/// dit s'affiche en grand, comme un paragraphe, avec la forme d'onde du
/// micro dessous ; en bas, trois boutons ronds :
///
/// ```text
///        ✕            ●            🎙
///     annuler   l'action du     recommencer
///               moment
/// ```
///
/// Le gros bouton vert fait ce qui vient ensuite : arrêter l'écoute, puis
/// envoyer le texte reconnu. On relit avant d'envoyer — une transcription
/// se trompe, et un message parti ne se rattrape pas.
///
/// Rend le texte à envoyer, ou `null` si l'on a annulé.
class VoiceModeScreen extends ConsumerStatefulWidget {
  const VoiceModeScreen({super.key});

  static Future<String?> open(BuildContext context) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const VoiceModeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            ),
      ),
    );
  }

  @override
  ConsumerState<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends ConsumerState<VoiceModeScreen> {
  final _voice = VoiceRecordingController();
  _VoicePhase _phase = _VoicePhase.listening;
  String _text = '';

  @override
  void initState() {
    super.initState();
    unawaited(_listen());
  }

  @override
  void dispose() {
    // Quitter en pleine écoute ne doit jamais laisser le micro ouvert, ni
    // un enregistrement de la voix sur le disque.
    unawaited(_voice.cancel());
    _voice.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    setState(() {
      _phase = _VoicePhase.listening;
      _text = '';
    });
    final started = await _voice.start();
    if (!mounted) return;
    if (started) {
      HapticFeedback.mediumImpact();
    } else {
      setState(() => _phase = _VoicePhase.failed);
    }
  }

  Future<void> _stopAndTranscribe() async {
    final file = await _voice.stop();
    if (!mounted) return;
    if (file == null) {
      setState(() => _phase = _VoicePhase.failed);
      return;
    }
    setState(() => _phase = _VoicePhase.transcribing);
    try {
      final text = await ref
          .read(chatRepositoryProvider)
          .transcribe(
            file,
            language: Localizations.localeOf(context).languageCode,
          );
      if (!mounted) return;
      setState(() {
        _text = text;
        _phase = text.isEmpty ? _VoicePhase.failed : _VoicePhase.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _VoicePhase.failed);
    }
  }

  Future<void> _restart() async {
    await _voice.cancel();
    await _listen();
  }

  void _primary() {
    switch (_phase) {
      case _VoicePhase.listening:
        unawaited(_stopAndTranscribe());
      case _VoicePhase.ready:
        Navigator.of(context).pop(_text);
      case _VoicePhase.failed:
        unawaited(_restart());
      case _VoicePhase.transcribing:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = AiStyle.of(context);
    final l = L.of(context);

    final (headline, headlineColor) = switch (_phase) {
      _VoicePhase.listening => (l.aiVoiceListening, style.textSecondary),
      _VoicePhase.transcribing => (l.aiVoiceTranscribing, style.textSecondary),
      _VoicePhase.ready => (_text, style.text),
      _VoicePhase.failed => (l.aiVoiceFailed, style.textSecondary),
    };

    return Scaffold(
      backgroundColor: style.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AiStyle.screenPadding,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Ce qu'on a dit, en grand : c'est un paragraphe à relire, pas
              // une ligne de journal.
              Flexible(
                flex: 6,
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      headline,
                      key: ValueKey(headline),
                      style: TextStyle(
                        fontSize: _phase == _VoicePhase.ready ? 28 : 30,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: headlineColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 56,
                child: ListenableBuilder(
                  listenable: _voice,
                  builder: (context, _) => AnimatedOpacity(
                    opacity: _phase == _VoicePhase.listening ? 1 : 0.35,
                    duration: const Duration(milliseconds: 200),
                    child: Waveform(
                      levels: _voice.levels.isEmpty
                          ? List.filled(40, 0.08)
                          : _voice.levels,
                      playedColor: style.text,
                      remainingColor: style.text,
                      barWidth: 3,
                      gap: 3,
                      height: 56,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundButton(
                    size: 56,
                    background: style.surface,
                    foreground: style.text,
                    icon: Icons.close_rounded,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).cancelButtonLabel,
                    shadow: style.softShadow,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  _PrimaryButton(phase: _phase, onPressed: _primary),
                  _RoundButton(
                    size: 56,
                    background: style.surface,
                    foreground: style.text,
                    icon: Icons.mic_none_rounded,
                    tooltip: l.aiVoiceRestart,
                    shadow: style.softShadow,
                    onPressed: _phase == _VoicePhase.transcribing
                        ? null
                        : () => unawaited(_restart()),
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le gros bouton vert : son icône dit l'action du moment.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.phase, required this.onPressed});

  final _VoicePhase phase;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final (icon, label) = switch (phase) {
      _VoicePhase.listening => (Icons.graphic_eq_rounded, l.aiVoiceStop),
      _VoicePhase.ready => (Icons.arrow_upward_rounded, l.aiVoiceSend),
      _VoicePhase.failed => (Icons.mic_rounded, l.aiVoiceRestart),
      _VoicePhase.transcribing => (
        Icons.hourglass_top_rounded,
        l.aiVoiceTranscribing,
      ),
    };
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AiStyle.accent,
            boxShadow: [
              BoxShadow(
                color: AiStyle.accent.withValues(alpha: 0.45),
                blurRadius: phase == _VoicePhase.listening ? 36 : 20,
                spreadRadius: phase == _VoicePhase.listening ? 4 : 0,
              ),
            ],
          ),
          child: phase == _VoicePhase.transcribing
              ? const Padding(
                  padding: EdgeInsets.all(34),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AiStyle.onAccent,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    size: 38,
                    color: AiStyle.onAccent,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.shadow,
  });

  final double size;
  final Color background;
  final Color foreground;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: shadow,
            ),
            child: Icon(
              icon,
              color: onPressed == null
                  ? foreground.withValues(alpha: 0.3)
                  : foreground,
            ),
          ),
        ),
      ),
    );
  }
}
