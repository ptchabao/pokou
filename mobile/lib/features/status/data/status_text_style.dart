import 'package:flutter/material.dart';

/// L'habillage d'un statut en texte : un fond et une police, choisis par
/// l'auteur et revus à l'identique par ses contacts.
///
/// Le style voyage DANS le texte chiffré, en caractères invisibles placés
/// devant lui (voir [encode]). Deux raisons :
///
/// - le serveur n'a rien à savoir d'un statut, pas même sa couleur ;
/// - une version de l'app qui ne connaît pas ce codage affiche le texte tel
///   quel — les caractères invisibles ne se voient pas — au lieu d'un
///   marqueur illisible.
class StatusTextStyle {
  const StatusTextStyle({this.background = 0, this.font = 0});

  final int background;
  final int font;

  static const plain = StatusTextStyle();

  StatusBackground get look => statusBackgrounds[background];

  StatusTextStyle copyWith({int? background, int? font}) => StatusTextStyle(
    background: background ?? this.background,
    font: font ?? this.font,
  );

  static const _mark = '⁣'; // séparateur invisible
  static const _backgroundUnit = '​';
  static const _fontUnit = '‌';

  /// Le texte tel qu'il part chiffré. Le style par défaut ne marque rien :
  /// un statut simple reste un texte simple.
  static String encode(StatusTextStyle style, String text) {
    if (style.background == 0 && style.font == 0) return text;
    return '$_mark${_backgroundUnit * style.background}$_mark'
        '${_fontUnit * style.font}$_mark$text';
  }

  /// Le style et le texte visible d'un statut reçu. Tout ce qui ne suit pas
  /// exactement le codage est rendu comme du texte, avec le style simple.
  static (StatusTextStyle, String) decode(String raw) {
    if (!raw.startsWith(_mark)) return (plain, raw);
    final second = raw.indexOf(_mark, 1);
    if (second == -1) return (plain, raw);
    final third = raw.indexOf(_mark, second + 1);
    if (third == -1) return (plain, raw);
    final backgrounds = raw.substring(1, second);
    final fonts = raw.substring(second + 1, third);
    if (backgrounds.replaceAll(_backgroundUnit, '').isNotEmpty ||
        fonts.replaceAll(_fontUnit, '').isNotEmpty) {
      return (plain, raw);
    }
    return (
      StatusTextStyle(
        // Un indice inconnu (palette plus riche dans une version future)
        // retombe sur le premier plutôt que de planter.
        background: backgrounds.length < statusBackgrounds.length
            ? backgrounds.length
            : 0,
        font: fonts.length < statusFonts.length ? fonts.length : 0,
      ),
      raw.substring(third + 1),
    );
  }

  /// Un mot court s'écrit en grand, un long paragraphe reste lisible.
  static double fontSizeFor(String text) {
    final length = text.runes.length;
    if (length <= 40) return 34;
    if (length <= 100) return 28;
    if (length <= 220) return 22;
    return 18;
  }

  TextStyle textStyle(String text) {
    final face = statusFonts[font];
    return TextStyle(
      color: look.ink,
      fontSize: fontSizeFor(text),
      height: 1.25,
      fontFamily: face.family,
      fontFamilyFallback: face.fallback,
      fontWeight: face.weight,
      fontStyle: face.italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: face.letterSpacing,
    );
  }
}

class StatusBackground {
  const StatusBackground(this.top, this.bottom, {this.ink = Colors.white});

  final Color top;
  final Color bottom;

  /// La couleur du texte posé dessus.
  final Color ink;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [top, bottom],
  );
}

/// La palette : les couleurs de Pokou d'abord, puis de quoi changer d'humeur.
/// L'ORDRE est un format : l'indice est ce qui voyage. On ajoute à la fin,
/// on ne réordonne jamais.
const statusBackgrounds = <StatusBackground>[
  StatusBackground(Color(0xFFB85F35), Color(0xFF7F3D1E)), // terre cuite
  StatusBackground(Color(0xFF3A2F2A), Color(0xFF1A1615)), // ébène
  StatusBackground(
    Color(0xFFF2CF63),
    Color(0xFFD4A82A),
    ink: Color(0xFF1A1615),
  ), // or
  StatusBackground(Color(0xFF2C8C57), Color(0xFF14532F)), // forêt
  StatusBackground(Color(0xFF3B5BA9), Color(0xFF1B2B57)), // indigo
  StatusBackground(Color(0xFF9A3B73), Color(0xFF4A1838)), // prune
  StatusBackground(Color(0xFF1B8C8C), Color(0xFF0B4F55)), // lagune
  StatusBackground(
    Color(0xFFFFFBF5),
    Color(0xFFF3EAE1),
    ink: Color(0xFF1A1615),
  ), // crème
];

class StatusFont {
  const StatusFont({
    required this.family,
    this.fallback,
    this.weight = FontWeight.w600,
    this.italic = false,
    this.letterSpacing,
  });

  final String? family;
  final List<String>? fallback;
  final FontWeight weight;
  final bool italic;
  final double? letterSpacing;
}

/// Même règle que la palette : l'indice voyage, on ajoute à la fin.
const statusFonts = <StatusFont>[
  StatusFont(family: 'Outfit', weight: FontWeight.w700, letterSpacing: -0.3),
  // Une sérif du système : Georgia sur iPhone, Noto Serif sur Android.
  StatusFont(
    family: 'Georgia',
    fallback: ['Noto Serif', 'serif'],
    weight: FontWeight.w400,
    italic: true,
  ),
  StatusFont(family: 'Inter', weight: FontWeight.w500),
];

/// Le texte d'un statut sur son fond — le MÊME widget à l'écriture et à la
/// lecture, pour que l'auteur voie exactement ce que verront ses contacts.
class StatusTextCanvas extends StatelessWidget {
  const StatusTextCanvas({super.key, required this.style, required this.child});

  final StatusTextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(gradient: style.look.gradient),
      child: child,
    );
  }
}
