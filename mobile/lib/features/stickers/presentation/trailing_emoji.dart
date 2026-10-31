import 'package:characters/characters.dart';

/// L'emoji sur lequel se termine un texte, ou `null`.
///
/// ── Pourquoi la fin, et pas n'importe où ───────────────────────────────
///
/// Les suggestions répondent à ce qu'on VIENT de taper. Chercher l'emoji
/// n'importe où dans le champ ferait ressurgir des propositions pour un 😂
/// écrit trois phrases plus tôt, longtemps après qu'on soit passé à autre
/// chose.
///
/// ── Pourquoi un `Characters` et pas `text[text.length - 1]` ────────────
///
/// Un emoji occupe plusieurs unités de code — jusqu'à sept pour une
/// famille avec teints de peau. Prendre le dernier caractère au sens de
/// Dart rendrait la moitié d'un sélecteur de variante, qui ne correspond à
/// aucun emoji connu.
///
/// ── La normalisation, elle, appartient au serveur ──────────────────────
///
/// 👍🏿 et 👍 doivent tomber sur les mêmes stickers. Ce repliage est fait
/// par `sticker_service.normalize_emoji`, une seule fois, côté serveur :
/// le refaire ici créerait deux règles à tenir d'accord, et elles
/// finiraient par diverger.
String? trailingEmoji(String text) {
  final caracteres = text.characters;
  if (caracteres.isEmpty) return null;

  final dernier = caracteres.last;
  return _estEmoji(dernier) ? dernier : null;
}

bool _estEmoji(String grapheme) {
  final premier = grapheme.runes.firstOrNull;
  if (premier == null) return false;

  return
  // Émoticônes, pictogrammes, transports, symboles supplémentaires —
  // le gros du répertoire moderne.
  (premier >= 0x1F300 && premier <= 0x1FAFF) ||
      // Les drapeaux, composés de deux lettres régionales.
      (premier >= 0x1F1E6 && premier <= 0x1F1FF) ||
      // Symboles divers et casseau (☀ ✂ ✅ ❤ …), hérités d'avant le bloc
      // Emoji : ils sont anciens, et parmi les plus utilisés.
      (premier >= 0x2600 && premier <= 0x27BF) ||
      // Symboles divers et flèches (⬅ ⭐ …).
      (premier >= 0x2B00 && premier <= 0x2BFF) ||
      // ‼ ⁉ — deux exceptions isolées, à leur propre place dans la norme.
      premier == 0x203C ||
      premier == 0x2049;
}
