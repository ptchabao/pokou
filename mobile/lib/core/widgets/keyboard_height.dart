import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// La hauteur du clavier système, pour le panneau emoji et stickers qui le
/// remplace.
///
/// Retenue pour TOUTE l'application, pas par conversation : avant, chaque
/// conversation repartait d'une hauteur fixe de 280 points tant que le
/// clavier n'y avait pas été ouvert. Toucher directement le bouton emoji
/// donnait alors un panneau plus bas qu'un vrai clavier — la plainte « le
/// clavier des emojis est trop bas ».
abstract final class KeyboardHeight {
  static double? _measured;

  /// À appeler quand le clavier est visible (l'encart du bas est sa hauteur,
  /// barre de navigation comprise).
  static void remember(double inset) {
    if (inset > 120) _measured = inset;
  }

  /// La hauteur à donner au panneau : celle du dernier vrai clavier, sinon
  /// une estimation réaliste (≈ 38 % de l'écran, plus la barre du bas).
  static double of(BuildContext context) {
    final measured = _measured;
    if (measured != null) return measured;
    final media = MediaQuery.of(context);
    return math.max(300.0, media.size.height * 0.38) + media.viewPadding.bottom;
  }

  @visibleForTesting
  static void reset() => _measured = null;
}
