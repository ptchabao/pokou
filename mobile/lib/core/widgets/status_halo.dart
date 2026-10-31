import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// L'auréole autour d'une photo qui porte des statuts.
///
/// Peinte, et non posée en `Border` : un `Border` ne sait pas porter de
/// dégradé, et l'écart entre l'anneau et la photo doit rester transparent —
/// la même auréole sert sur une liste blanche, sur un fond sombre et sur le
/// noir du lecteur de statuts. Vu (`seen`), l'anneau redevient un simple
/// trait gris : il n'y a plus rien à regarder, il ne doit plus attirer l'œil.
class StatusHalo extends StatelessWidget {
  const StatusHalo({
    super.key,
    required this.size,
    required this.child,
    this.seen = false,
    this.thickness = 3,
    this.gap = 2,
    this.seenColor,
    this.onDark = false,
  });

  final double size;
  final Widget child;
  final bool seen;
  final double thickness;
  final double gap;
  final Color? seenColor;

  /// Posée sur un fond toujours sombre (le lecteur de statuts), quel que
  /// soit le thème.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HaloPainter(
        thickness: thickness,
        gradient: onDark
            ? AppColors.statusRingCopperOnDark
            : AppColors.statusRingCopper,
        seenColor: seen ? (seenColor ?? AppColors.statusRingViewed) : null,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(thickness + gap),
          // Contraintes serrées, pas de `Center` : une photo réseau doit
          // remplir le disque, pas prendre la taille de son fichier.
          child: child,
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({
    required this.thickness,
    required this.gradient,
    this.seenColor,
  });

  final double thickness;
  final Gradient gradient;

  /// Nul tant que les statuts ne sont pas vus : l'anneau est alors cuivré.
  final Color? seenColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..isAntiAlias = true;
    final seen = seenColor;
    if (seen == null) {
      paint.shader = gradient.createShader(rect);
    } else {
      paint.color = seen;
    }
    canvas.drawCircle(
      rect.center,
      (size.shortestSide - thickness) / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.thickness != thickness ||
      old.gradient != gradient ||
      old.seenColor != seenColor;
}
