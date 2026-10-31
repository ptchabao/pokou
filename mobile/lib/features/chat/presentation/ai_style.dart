import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Les jetons de l'assistant : peu d'éléments, chacun très lisible et très
/// tactile. Blanc et gris très clair, un seul accent — le vert de Pokou — pour
/// ce qui se touche et pour l'identité de l'assistant ; des rayons larges,
/// des ombres à peine visibles, aucune bordure appuyée.
///
/// Une variante sombre, parce que l'application en a une : un écran blanc
/// au milieu d'une application sombre éblouit, la nuit, précisément quand
/// on parle à l'assistant dans le noir.
class AiStyle {
  const AiStyle._({
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.border,
    required this.userBubble,
    required this.codeBackground,
    required this.codeText,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color border;
  final Color userBubble;
  final Color codeBackground;
  final Color codeText;

  /// L'accent : le vert de l'application, celui des conversations et du
  /// bouton d'envoi. Baba fait partie de Pokou, il en porte la couleur.
  static const accent = AppColors.accentPrimary;
  static const onAccent = Colors.white;

  /// Le même vert, éclairci : lisible sur le fond sombre des blocs de code.
  static const accentOnDark = Color(0xFFE39A6B);

  static const radiusSmall = 12.0;
  static const radiusMedium = 18.0;
  static const radiusLarge = 24.0;
  static const screenPadding = 20.0;

  static const _light = AiStyle._(
    background: Color(0xFFF5F5F3),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF111111),
    textSecondary: Color(0xFF777777),
    border: Color(0xFFEAEAEA),
    userBubble: Color(0xFFEAEAE6),
    codeBackground: Color(0xFF16171A),
    codeText: Color(0xFFE8E8E3),
  );

  static const _dark = AiStyle._(
    background: Color(0xFF101112),
    surface: Color(0xFF1B1C1F),
    text: Color(0xFFF2F2EF),
    textSecondary: Color(0xFF9B9B98),
    border: Color(0xFF2A2B2F),
    userBubble: Color(0xFF26272B),
    codeBackground: Color(0xFF0B0B0D),
    codeText: Color(0xFFE8E8E3),
  );

  static AiStyle of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  /// L'ombre des surfaces : une diffusion, pas un relief.
  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];
}
