import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Une forme d'onde : des barres verticales dont la hauteur suit le son.
///
/// Elle sert à deux endroits et ce n'est pas un hasard : pendant
/// l'enregistrement, elle montre que le micro capte quelque chose ; sur un
/// message reçu, elle distingue ce qui a déjà été écouté du reste. Dans les
/// deux cas, elle répond à la même question — où en est-on.
///
/// Les barres sont dessinées, pas empilées en widgets : une note vocale en
/// affiche une quarantaine, qui se redessinent à chaque image pendant la
/// lecture. Quarante widgets reconstruits soixante fois par seconde se
/// sentent sur les téléphones auxquels cette application est destinée.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.levels,
    this.progress = 0,
    required this.playedColor,
    required this.remainingColor,
    this.barWidth = 3,
    this.gap = 2,
    this.height = 28,
  });

  /// Les niveaux, entre 0 et 1, du plus ancien au plus récent.
  final List<double> levels;

  /// La part déjà écoutée, entre 0 et 1. Zéro pendant l'enregistrement :
  /// tout est « à venir », rien n'a encore été lu.
  final double progress;

  final Color playedColor;
  final Color remainingColor;
  final double barWidth;
  final double gap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WaveformPainter(
          levels: levels,
          progress: progress.clamp(0, 1),
          playedColor: playedColor,
          remainingColor: remainingColor,
          barWidth: barWidth,
          gap: gap,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.levels,
    required this.progress,
    required this.playedColor,
    required this.remainingColor,
    required this.barWidth,
    required this.gap,
  });

  final List<double> levels;
  final double progress;
  final Color playedColor;
  final Color remainingColor;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0) return;

    final slot = barWidth + gap;
    final capacity = math.max(1, (size.width / slot).floor());
    // On garde les DERNIÈRES barres quand il y en a trop : pendant un
    // enregistrement, c'est le son de maintenant qui intéresse, pas celui
    // d'il y a trente secondes.
    final visible = levels.length <= capacity
        ? levels
        : levels.sublist(levels.length - capacity);

    final playedUntil = visible.length * progress;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final centerY = size.height / 2;

    for (var i = 0; i < visible.length; i++) {
      // Une hauteur minimale : une barre de hauteur nulle fait un trou dans
      // la ligne, et un silence au milieu d'une note vocale ressemble alors
      // à un défaut d'affichage.
      final amplitude = (visible[i].clamp(0.0, 1.0) * size.height * 0.9).clamp(
        barWidth,
        size.height,
      );
      paint.color = i < playedUntil ? playedColor : remainingColor;
      final x = i * slot + barWidth / 2;
      canvas.drawLine(
        Offset(x, centerY - amplitude / 2),
        Offset(x, centerY + amplitude / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.levels.length != levels.length ||
      old.playedColor != playedColor ||
      old.remainingColor != remainingColor;
}

/// Transforme une amplitude du micro en niveau affichable.
///
/// Le paquet `record` renvoie des décibels : autour de -160 dans le silence,
/// proche de 0 au plus fort. L'échelle est logarithmique et négative, donc
/// inutilisable telle quelle comme hauteur de barre — sans cette conversion,
/// la forme d'onde reste plate puis saute au maximum.
double normalizeAmplitude(double decibels, {double floor = -45}) {
  if (decibels.isNaN || decibels.isInfinite) return 0;
  if (decibels <= floor) return 0;
  return ((decibels - floor) / -floor).clamp(0.0, 1.0);
}

/// Une forme d'onde stable pour un message donné, faute de l'avoir mesurée.
///
/// Les notes vocales déjà envoyées n'ont pas de niveaux enregistrés : le
/// serveur ne stocke que le fichier. Plutôt qu'une ligne plate, on dérive
/// une silhouette de l'identifiant du message — arbitraire, mais TOUJOURS la
/// même pour le même message. Une forme aléatoire à chaque reconstruction
/// donnerait l'impression que l'audio change tout seul.
List<double> silhouetteFor(String seed, {int bars = 40}) {
  final random = math.Random(seed.hashCode);
  return List<double>.generate(
    bars,
    // Jamais en dessous de 0,25 : une silhouette n'est pas une mesure, et
    // faire croire à un silence qu'on n'a pas constaté serait mentir.
    (_) => 0.25 + random.nextDouble() * 0.75,
  );
}
