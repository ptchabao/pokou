import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';

/// Un graphème emoji : pictogramme, drapeau, ou touche (« 1️⃣ », « #️⃣ »).
///
/// Les touches commencent par un chiffre, `#` ou `*` : elles échappaient au
/// test du pictogramme et un « 1️⃣ » envoyé seul restait en petit.
final _pictograph = RegExp(
  r'^(?:\p{Extended_Pictographic}|\p{Regional_Indicator}|[0-9#*]\uFE0F?\u20E3)',
  unicode: true,
);

/// Un pictogramme qui s'affiche par défaut comme un SYMBOLE de texte (❤, ☺,
/// ✌, ☀…), seul dans son graphème.
final _textDefault = RegExp(
  r'^(?!\p{Emoji_Presentation})\p{Extended_Pictographic}$',
  unicode: true,
);

/// Le nombre d'emoji d'un message qui n'est FAIT QUE d'emoji (1 à 3), sinon
/// `null`. Comme WhatsApp, un tel message s'affiche en grand.
int? emojiOnlyCount(String? text) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return null;
  final glyphs = t.characters.where((c) => c.trim().isNotEmpty).toList();
  if (glyphs.isEmpty || glyphs.length > 3) return null;
  for (final g in glyphs) {
    if (!_pictograph.hasMatch(g)) return null;
  }
  return glyphs.length;
}

/// [text] où chaque pictogramme « texte par défaut » reçoit le sélecteur
/// de présentation emoji (U+FE0F).
///
/// Un « ❤ » tapé sur certains claviers arrive SANS ce sélecteur : le moteur
/// le dessine alors avec une police de texte, en noir, plus petit que ses
/// voisins. Avec lui, il prend la police emoji, en couleur, comme chez
/// WhatsApp. Rien d'autre ne change — ni les lettres, ni un emoji déjà
/// complet.
String withEmojiPresentation(String text) {
  if (text.isEmpty) return text;
  final out = StringBuffer();
  var changed = false;
  for (final g in text.characters) {
    if (_textDefault.hasMatch(g)) {
      out
        ..write(g)
        ..write('\uFE0F');
      changed = true;
    } else {
      out.write(g);
    }
  }
  return changed ? out.toString() : text;
}

/// Le style d'un message tout en emoji : 48 pour un seul, 40 pour deux,
/// 32 pour trois.
TextStyle emojiOnlyStyle(TextStyle base, int count) => base.copyWith(
  fontSize: switch (count) {
    1 => 48,
    2 => 40,
    _ => 32,
  },
  height: 1.15,
);
