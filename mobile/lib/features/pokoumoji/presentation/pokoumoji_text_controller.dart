import 'package:flutter/material.dart';

import '../data/pokoumoji_runtime.dart';
import '../domain/pokoumoji.dart';
import 'pokoumoji_widgets.dart';

/// Le Pokoumoji dans le champ de saisie.
///
/// ── Un caractère par emoji ─────────────────────────────────────────────
///
/// Chaque Pokoumoji posé dans le champ y occupe UN caractère de la zone
/// à usage privé d'Unicode (U+E000 + son rang dans le catalogue), dessiné
/// en image par [PokoumojiTextController]. C'est ce qui donne gratuitement
/// ce que demande le cahier des charges (§05) : suppression atomique,
/// curseur avant/après, sélection, couper-coller dans le champ.
///
/// Ces caractères ne quittent jamais l'appareil : à l'envoi,
/// [PokoumojiComposer.encode] les remplace par des segments `emoji`
/// (identifiant + fallback), et le texte visible ailleurs — notification,
/// liste des discussions, citation — est le texte de repli.
abstract final class PokoumojiComposer {
  static const _base = 0xE000;
  static const _end = 0xF8FF;

  static String charFor(PokoumojiCatalogue catalogue, PokoumojiEntry entry) {
    final pos = catalogue.positionOf(entry.id);
    if (pos == null || _base + pos > _end) return entry.fallback;
    return String.fromCharCode(_base + pos);
  }

  static PokoumojiEntry? entryAt(PokoumojiCatalogue catalogue, int codeUnit) {
    if (codeUnit < _base || codeUnit > _end) return null;
    final i = codeUnit - _base;
    if (i >= catalogue.entries.length) return null;
    final e = catalogue.entries[i];
    return e.isSticker ? null : e;
  }

  static bool containsPokoumoji(String text, PokoumojiCatalogue? catalogue) {
    if (catalogue == null) return false;
    for (final u in text.codeUnits) {
      if (entryAt(catalogue, u) != null) return true;
    }
    return false;
  }

  /// Le texte avec les Pokoumoji remplacés par leur fallback.
  static String plainText(String text, PokoumojiCatalogue? catalogue) {
    if (catalogue == null) return text;
    final b = StringBuffer();
    for (final u in text.codeUnits) {
      final e = entryAt(catalogue, u);
      b.write(e?.fallback ?? String.fromCharCode(u));
    }
    return b.toString();
  }

  /// Le message `rich_text` du brouillon, ou `null` s'il ne contient aucun
  /// Pokoumoji (il part alors comme un texte ordinaire).
  static ({
    Map<String, dynamic> message,
    String plainText,
    List<String> errors,
  })?
  encode(String text, PokoumojiCatalogue? catalogue) {
    if (!containsPokoumoji(text, catalogue)) return null;
    final segments = <Map<String, dynamic>>[];
    final run = StringBuffer();
    void flush() {
      if (run.isEmpty) return;
      segments.add({'type': 'text', 'text': run.toString()});
      run.clear();
    }

    for (final u in text.codeUnits) {
      final e = entryAt(catalogue!, u);
      if (e == null) {
        run.writeCharCode(u);
        continue;
      }
      flush();
      segments.add({'type': 'emoji', 'id': e.id, 'fallback': e.fallback});
    }
    flush();
    final message = pokoumojiRichText(segments);
    return (
      message: message,
      plainText: pokoumojiPlainText(message),
      errors: validatePokoumojiMessage(message, catalogue: catalogue),
    );
  }

  /// Le brouillon qui correspond à un message reçu (pour le citer ou le
  /// modifier).
  static String draftOf(Map<String, dynamic> message, PokoumojiCatalogue cat) {
    final segs = message['segments'];
    if (segs is! List) return pokoumojiPlainText(message);
    final b = StringBuffer();
    for (final s in segs) {
      if (s is! Map) continue;
      if (s['type'] == 'text') {
        b.write(s['text']);
      } else {
        final e = cat.resolve(s['id']);
        b.write(e == null || e.isSticker ? s['fallback'] : charFor(cat, e));
      }
    }
    return b.toString();
  }
}

/// Champ de saisie qui dessine les Pokoumoji en image.
class PokoumojiTextController extends TextEditingController {
  PokoumojiTextController({super.text});

  /// Insère [entry] à la position du curseur (ou à la place de la sélection).
  void insertPokoumoji(PokoumojiEntry entry) {
    final cat = PokoumojiRuntime.instance.catalogue.value;
    if (cat == null) return;
    final ch = PokoumojiComposer.charFor(cat, entry);
    final sel = selection;
    final t = text;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    value = TextEditingValue(
      text: t.replaceRange(start, end, ch),
      selection: TextSelection.collapsed(offset: start + ch.length),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final cat = PokoumojiRuntime.instance.catalogue.value;
    if (!PokoumojiComposer.containsPokoumoji(text, cat)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final size = (style?.fontSize ?? 16) * 1.45;
    final children = <InlineSpan>[];
    final run = StringBuffer();
    void flush() {
      if (run.isEmpty) return;
      children.add(TextSpan(text: run.toString()));
      run.clear();
    }

    for (final u in text.codeUnits) {
      final e = PokoumojiComposer.entryAt(cat!, u);
      if (e == null) {
        run.writeCharCode(u);
        continue;
      }
      flush();
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: PokoumojiGlyph(entry: e, size: size),
        ),
      );
    }
    flush();
    return TextSpan(style: style, children: children);
  }
}
