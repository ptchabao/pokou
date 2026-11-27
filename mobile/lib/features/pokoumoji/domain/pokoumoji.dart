/// Pokoumoji : catalogue, recherche, variantes, messages.
///
/// Transposition en Dart de l'implémentation de référence fournie par la
/// marque (`POKOUMOJI_Dossier_Developpeurs_V1.3/03_Integration/reference/
/// pokoumoji_reference.mjs`, contrat V1.3). Les noms et les règles suivent
/// la référence à la lettre : c'est une spécification exécutable, et ses
/// tests sont repris dans `test/pokoumoji/pokoumoji_test.dart`.
///
/// ── Ce qu'il faut garder en tête ───────────────────────────────────────
///
/// * Un identifiant est IMMUABLE. Un ancien identifiant se résout par
///   `aliases.json` ; un identifiant inconnu s'affiche par son `fallback`,
///   jamais par une erreur.
/// * Un client de production ne montre que les entrées `approved`. Le
///   catalogue V1.3 n'en contient aucune : tant que la marque n'a pas
///   validé de visuels, le clavier Pokoumoji reste masqué en production.
/// * Le message ne porte JAMAIS d'URL ni de chemin : seulement des
///   identifiants, résolus localement dans un pack signé.
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Limites proposées par le contrat (§1), à confirmer.
abstract final class PokoumojiLimits {
  static const maxSegments = 100;
  static const maxTextChars = 4000;
  static const maxEmojis = 50;
  static const maxFallbackChars = 64;
}

final _idRe = RegExp(r'^[a-z0-9_]{1,64}$');

/// Les chemins de fichiers qu'un pack peut contenir — rien d'autre.
final packPathRe = RegExp(r'^(64|128|256)/assets/[a-z0-9_]+/[a-z0-9_]+\.webp$');

bool isPokoumojiId(Object? id) => id is String && _idRe.hasMatch(id);

final _marks = RegExp(r'\p{M}+', unicode: true);
final _apostrophes = RegExp('[\'’‘`´]');
final _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Normalisation de recherche (§5) : NFD, sans diacritiques, minuscules,
/// œ/æ dépliés, sans apostrophes ni ponctuation.
String pokoumojiNormalize(String? input) {
  final s = (input ?? '')
      .replaceAll('œ', 'oe')
      .replaceAll('Œ', 'Oe')
      .replaceAll('æ', 'ae')
      .replaceAll('Æ', 'Ae');
  return unorm
      .nfd(s)
      .replaceAll(_marks, '')
      .toLowerCase()
      .replaceAll(_apostrophes, '')
      .replaceAll(_separators, ' ')
      .trim();
}

List<String> _words(String? s) =>
    pokoumojiNormalize(s).split(' ').where((w) => w.isNotEmpty).toList();

enum PokoumojiType { inlineEmoji, sticker }

class PokoumojiEntry {
  const PokoumojiEntry({
    required this.id,
    required this.category,
    required this.labelFr,
    required this.keywords,
    required this.fallback,
    required this.asset,
    required this.status,
    required this.type,
    this.character = '',
    this.variantOf = '',
    this.gender = '',
    this.skinTone = '',
  });

  final String id;
  final String category;
  final String labelFr;
  final List<String> keywords;
  final String fallback;

  /// Chemin LOGIQUE (`assets/<catégorie>/<id>.webp`) ; le fichier physique
  /// est `<taille>/<asset>` dans le pack.
  final String asset;
  final String status;
  final PokoumojiType type;
  final String character;
  final String variantOf;
  final String gender;
  final String skinTone;

  bool get isSticker => type == PokoumojiType.sticker;
  bool get isVariant => variantOf.isNotEmpty;

  factory PokoumojiEntry.fromJson(Map<String, dynamic> j) => PokoumojiEntry(
    id: j['id'] as String,
    category: (j['category'] ?? '') as String,
    labelFr: (j['label_fr'] ?? '') as String,
    keywords: [for (final k in (j['keywords'] as List? ?? const [])) '$k'],
    fallback: (j['fallback'] ?? '') as String,
    asset: (j['asset'] ?? '') as String,
    status: (j['status'] ?? '') as String,
    type: j['type'] == 'sticker'
        ? PokoumojiType.sticker
        : PokoumojiType.inlineEmoji,
    character: (j['character'] ?? '') as String,
    variantOf: (j['variant_of'] ?? '') as String,
    gender: (j['gender'] ?? '') as String,
    skinTone: (j['skin_tone'] ?? '') as String,
  );
}

/// Un onglet du clavier (`collections.json`).
class PokoumojiCategory {
  const PokoumojiCategory({
    required this.id,
    required this.labelFr,
    required this.group,
    required this.iconId,
    this.featuredFirst = const [],
  });

  final String id;
  final String labelFr;

  /// `visages`, `pokoumoji` ou `stickers`.
  final String group;
  final String iconId;

  /// Les drapeaux africains, en tête de l'onglet Drapeaux.
  final List<String> featuredFirst;

  factory PokoumojiCategory.fromJson(Map<String, dynamic> j) =>
      PokoumojiCategory(
        id: j['id'] as String,
        labelFr: (j['label_fr'] ?? '') as String,
        group: (j['group'] ?? '') as String,
        iconId: (j['icon_id'] ?? '') as String,
        featuredFirst: [
          for (final f in (j['featured_first'] as List? ?? const [])) '$f',
        ],
      );
}

/// Préférences LOCALES (§4 bis) : la carnation choisie librement (brun
/// chaud par défaut), et le genre mémorisé métier par métier — jamais un
/// genre global.
class PokoumojiPrefs {
  const PokoumojiPrefs({this.skinTone, this.genderByBase = const {}});

  final String? skinTone;
  final Map<String, String> genderByBase;
}

class _Indexed {
  _Indexed(this.entry)
    : label = pokoumojiNormalize(entry.labelFr),
      labelWords = _words(entry.labelFr),
      kwWords = {for (final k in entry.keywords) ..._words(k)}.toList();

  final PokoumojiEntry entry;
  final String label;
  final List<String> labelWords;
  final List<String> kwWords;
}

class PokoumojiCatalogue {
  PokoumojiCatalogue(
    List<PokoumojiEntry> entries, {
    Map<String, String> aliases = const {},
    this.categories = const [],
    this.version = '',
    this.includeUnapproved = false,
  }) : entries = List.unmodifiable(entries),
       _aliases = aliases {
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      _byId[e.id] = e;
      _position[e.id] = i;
      if (e.isVariant) (_variants[e.variantOf] ??= []).add(e);
    }
    _index = [for (final e in entries) _Indexed(e)];
  }

  final List<PokoumojiEntry> entries;
  final List<PokoumojiCategory> categories;
  final String version;

  /// `true` seulement en build de développement (contrat §4) : montre les
  /// entrées qui ne sont pas encore `approved`.
  final bool includeUnapproved;

  final Map<String, String> _aliases;
  final _byId = <String, PokoumojiEntry>{};
  final _position = <String, int>{};
  final _variants = <String, List<PokoumojiEntry>>{};
  late final List<_Indexed> _index;

  int get size => entries.length;

  bool isVisible(PokoumojiEntry e) =>
      includeUnapproved || e.status == 'approved';

  /// Y a-t-il au moins une entrée à montrer ? Sinon, l'onglet n'existe pas.
  late final bool hasVisible = entries.any(isVisible);

  /// Rang stable de l'entrée dans le catalogue (sert au champ de saisie).
  int? positionOf(String id) => _position[id];

  /// Résout un identifiant, alias compris (§3). `null` si inconnu.
  PokoumojiEntry? resolve(Object? id) {
    if (!isPokoumojiId(id)) return null;
    final s = id as String;
    return _byId[s] ?? _byId[_aliases[s]];
  }

  /// Recherche insensible aux accents (§5). Les variantes ne sortent pas,
  /// sauf `includeVariants`.
  List<PokoumojiEntry> search(
    String query, {
    PokoumojiType? type,
    String? character,
    String? category,
    int limit = 200,
    bool includeVariants = false,
  }) {
    final q = _words(query);
    if (q.isEmpty) return const [];
    final qn = q.join(' ');
    final hits = <(double, int, PokoumojiEntry)>[];
    for (var i = 0; i < _index.length; i++) {
      final it = _index[i];
      final e = it.entry;
      if (!isVisible(e)) continue;
      if (e.isVariant && !includeVariants) continue;
      if (type != null && e.type != type) continue;
      if (character != null && e.character != character) continue;
      if (category != null && e.category != category) continue;
      final all = [...it.labelWords, ...it.kwWords];
      if (!q.every((w) => all.any((k) => k.startsWith(w)))) continue;
      final score = it.label == qn
          ? 3.0
          : it.label.startsWith(qn)
          ? 2.0
          : q.every((w) => it.labelWords.any((k) => k.startsWith(w)))
          ? 1.5
          : 1.0;
      hits.add((score, i, e));
    }
    // Tri STABLE, comme Array.prototype.sort : à score égal, l'ordre du
    // catalogue.
    hits.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return [for (final h in hits.take(limit)) h.$3];
  }

  /// Variantes visibles d'une entrée (appui long), base comprise en tête.
  List<PokoumojiEntry> variantsOf(String id) {
    final base = resolve(id);
    if (base == null) return const [];
    final b = base.isVariant ? (resolve(base.variantOf) ?? base) : base;
    return [b, ...?_variants[b.id]].where(isVisible).toList();
  }

  /// La variante qui correspond aux préférences locales, sinon la base.
  PokoumojiEntry? applyPreferences(
    String id, [
    PokoumojiPrefs prefs = const PokoumojiPrefs(),
  ]) {
    final base = resolve(id);
    if (base == null) return null;
    final b = base.isVariant ? (resolve(base.variantOf) ?? base) : base;
    final tone = prefs.skinTone ?? b.skinTone;
    final gender = prefs.genderByBase[b.id] ?? b.gender;
    for (final v in variantsOf(b.id)) {
      if (v.skinTone == (b.skinTone.isNotEmpty ? tone : '') &&
          v.gender == gender) {
        return v;
      }
    }
    return b;
  }

  /// Les entrées de BASE visibles d'une catégorie, dans l'ordre du
  /// catalogue — les drapeaux mis en avant d'abord.
  List<PokoumojiEntry> basesOf(String categoryId) {
    final list = [
      for (final e in entries)
        if (e.category == categoryId && !e.isVariant && isVisible(e)) e,
    ];
    final cat = categories.where((c) => c.id == categoryId).firstOrNull;
    if (cat == null || cat.featuredFirst.isEmpty) return list;
    final first = cat.featuredFirst.toSet();
    return [
      for (final id in cat.featuredFirst)
        ?list.where((e) => e.id == id).firstOrNull,
      for (final e in list)
        if (!first.contains(e.id)) e,
    ];
  }

  /// Les stickers d'expressions, filtrés par personnage (`''` = bulle seule).
  List<PokoumojiEntry> stickers({String? character}) => [
    for (final e in entries)
      if (e.isSticker &&
          isVisible(e) &&
          (character == null || e.character == character))
        e,
  ];
}

// ── Messages (§2) ─────────────────────────────────────────────────────────

/// Valide un message Pokoumoji (structure et limites). Liste vide = valide.
/// Avec [catalogue], vérifie aussi qu'un emoji inline n'est pas un sticker
/// et inversement (T20).
List<String> validatePokoumojiMessage(
  Object? msg, {
  PokoumojiCatalogue? catalogue,
}) {
  final errors = <String>[];
  void onlyKeys(Map m, List<String> keys, String where) {
    for (final k in m.keys) {
      if (!keys.contains(k))
        errors.add('$where: propriété non autorisée « $k »');
    }
  }

  void checkFallback(Object? fb, String where) {
    if (fb is! String ||
        fb.isEmpty ||
        fb.runes.length > PokoumojiLimits.maxFallbackChars) {
      errors.add('$where: fallback invalide');
    }
  }

  if (msg is! Map) return ['message: objet attendu'];
  if (msg['schema_version'] != 1) {
    errors.add('message: schema_version doit valoir 1');
  }
  final type = msg['type'];
  if (type == 'rich_text') {
    onlyKeys(msg, ['schema_version', 'type', 'segments'], 'message');
    final segs = msg['segments'];
    if (segs is! List || segs.isEmpty) {
      return [...errors, 'message: segments manquants'];
    }
    if (segs.length > PokoumojiLimits.maxSegments) {
      errors.add('message: plus de ${PokoumojiLimits.maxSegments} segments');
    }
    var chars = 0;
    var emojis = 0;
    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      final w = 'segments[$i]';
      if (s is! Map) {
        errors.add('$w: objet attendu');
        continue;
      }
      if (s['type'] == 'text') {
        onlyKeys(s, ['type', 'text'], w);
        final t = s['text'];
        if (t is! String || t.isEmpty) {
          errors.add('$w: text vide');
        } else {
          chars += t.runes.length;
        }
      } else if (s['type'] == 'emoji') {
        onlyKeys(s, ['type', 'id', 'fallback'], w);
        emojis += 1;
        if (!isPokoumojiId(s['id'])) errors.add('$w: id invalide');
        checkFallback(s['fallback'], w);
        final e = catalogue?.resolve(s['id']);
        if (e != null && e.isSticker) {
          errors.add("$w: ${s['id']} n'est pas un emoji inline");
        }
      } else {
        errors.add('$w: type inconnu');
      }
    }
    if (chars > PokoumojiLimits.maxTextChars) {
      errors.add(
        'message: plus de ${PokoumojiLimits.maxTextChars} caractères de texte',
      );
    }
    if (emojis > PokoumojiLimits.maxEmojis) {
      errors.add('message: plus de ${PokoumojiLimits.maxEmojis} emojis');
    }
  } else if (type == 'sticker') {
    onlyKeys(msg, [
      'schema_version',
      'type',
      'asset_id',
      'fallback',
    ], 'message');
    if (!isPokoumojiId(msg['asset_id']))
      errors.add('message: asset_id invalide');
    checkFallback(msg['fallback'], 'message');
    final e = catalogue?.resolve(msg['asset_id']);
    if (e != null && !e.isSticker) {
      errors.add("message: ${msg['asset_id']} n'est pas un sticker");
    }
  } else {
    errors.add('message: type inconnu');
  }
  return errors;
}

/// Texte de repli (§2) : notifications, export, copier-coller, citations.
String pokoumojiPlainText(Map msg) {
  if (msg['type'] == 'sticker') return '${msg['fallback'] ?? ''}';
  final segs = msg['segments'];
  if (segs is! List) return '';
  return [
    for (final s in segs)
      if (s is Map) s['type'] == 'text' ? '${s['text']}' : '${s['fallback']}',
  ].join();
}

sealed class PokoumojiPiece {
  const PokoumojiPiece();
}

class PokoumojiTextPiece extends PokoumojiPiece {
  const PokoumojiTextPiece(this.text);
  final String text;
}

class PokoumojiImagePiece extends PokoumojiPiece {
  const PokoumojiImagePiece(this.entry, this.fallback);
  final PokoumojiEntry entry;

  /// Montré tant que le fichier n'est pas là, ou s'il est refusé.
  final String fallback;
}

class PokoumojiFallbackPiece extends PokoumojiPiece {
  const PokoumojiFallbackPiece(this.text);
  final String text;
}

/// Plan de rendu (§3) : texte, image résolue, ou fallback. [hasAsset] dit
/// si un fichier vérifié peut exister pour l'entrée (le pack la connaît).
List<PokoumojiPiece> pokoumojiRenderPlan(
  Map msg,
  PokoumojiCatalogue catalogue, {
  bool Function(PokoumojiEntry entry)? hasAsset,
}) {
  PokoumojiPiece one(Object? id, Object? fallback) {
    final fb = '${fallback ?? ''}';
    final e = catalogue.resolve(id);
    if (e != null && catalogue.isVisible(e) && (hasAsset?.call(e) ?? false)) {
      return PokoumojiImagePiece(e, fb);
    }
    return PokoumojiFallbackPiece(fb);
  }

  if (msg['type'] == 'sticker') return [one(msg['asset_id'], msg['fallback'])];
  final segs = msg['segments'];
  if (segs is! List) return const [];
  return [
    for (final s in segs)
      if (s is Map)
        s['type'] == 'text'
            ? PokoumojiTextPiece('${s['text']}')
            : one(s['id'], s['fallback']),
  ];
}

enum PokoumojiSizeContext { inline, grid, single }

/// Taille physique (§6) : 64 en ligne, 128 en grille, 256 seul.
int pokoumojiPickSize(PokoumojiSizeContext context, [double pixelRatio = 1]) {
  final base = switch (context) {
    PokoumojiSizeContext.inline => 32,
    PokoumojiSizeContext.grid => 48,
    PokoumojiSizeContext.single => 96,
  };
  final px = base * pixelRatio;
  return px <= 64
      ? 64
      : px <= 128
      ? 128
      : 256;
}

String pokoumojiPackPath(PokoumojiEntry entry, int size) =>
    '$size/${entry.asset}';

/// Construit un message `rich_text`.
Map<String, dynamic> pokoumojiRichText(List<Map<String, dynamic>> segments) => {
  'schema_version': 1,
  'type': 'rich_text',
  'segments': segments,
};

/// Construit un message `sticker`.
Map<String, dynamic> pokoumojiSticker(PokoumojiEntry entry) => {
  'schema_version': 1,
  'type': 'sticker',
  'asset_id': entry.id,
  'fallback': entry.fallback,
};

// ── Transport dans Pokou ──────────────────────────────────────────────────

/// Le message Pokoumoji voyage DANS LE CHIFFRÉ, sous cette clé de la
/// charge utile (`payload`) d'un message TEXT. Le `content` du message est
/// son texte de repli : c'est lui que montrent la liste des discussions,
/// les notifications, les citations et la recherche — et c'est lui que
/// voit une version de l'application qui ne connaît pas Pokoumoji.
const pokoumojiPayloadKey = 'pokoumoji';

/// Le message Pokoumoji d'une charge utile, s'il est VALIDE (§7 : avec le
/// chiffrement de bout en bout, la validation se fait côté client, à
/// l'émission comme à la réception). Sinon `null` : la bulle affiche alors
/// le texte de repli.
Map<String, dynamic>? pokoumojiOf(Map<String, dynamic>? payload) {
  final m = payload?[pokoumojiPayloadKey];
  if (m is! Map<String, dynamic>) return null;
  return validatePokoumojiMessage(m).isEmpty ? m : null;
}
