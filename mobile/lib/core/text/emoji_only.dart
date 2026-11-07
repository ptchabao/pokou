import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';

final _pictograph = RegExp(
  r'^(?:\p{Extended_Pictographic}|\p{Regional_Indicator})',
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
