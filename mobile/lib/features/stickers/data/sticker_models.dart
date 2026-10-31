/// Les stickers, côté client.
///
/// ── Un sticker n'est pas une image ─────────────────────────────────────
///
/// Il s'affiche sans cadre ni fond, ne s'ouvre pas en plein écran, ne se
/// télécharge pas dans la galerie et ne compte pas dans les « photos » de
/// la conversation. C'est pourquoi il a son propre `MessageType` côté
/// serveur, et pourquoi il a ses propres modèles ici plutôt qu'un drapeau
/// posé sur `MediaMeta` : un drapeau aurait obligé chaque écran à
/// redécouvrir ces règles, et l'un d'eux aurait fini par l'oublier.
library;

class Sticker {
  const Sticker({
    required this.id,
    required this.packId,
    required this.mediaId,
    this.emojiTags = const [],
    this.keywords = '',
  });

  final int id;
  final int packId;

  /// L'image se télécharge par le chemin média ORDINAIRE
  /// (`MediaRepository.resolveLocalFile`) : pas de second cache à
  /// maintenir, et la purge « vider le cache » des réglages les emporte
  /// avec le reste.
  final int mediaId;

  /// Les emojis qui déclenchent la SUGGESTION de ce sticker — distincts
  /// des mots-clés, qui servent à la recherche écrite.
  final List<String> emojiTags;
  final String keywords;

  factory Sticker.fromJson(Map<String, dynamic> json) => Sticker(
    id: json['id'] as int,
    packId: json['pack_id'] as int,
    mediaId: json['media_id'] as int,
    emojiTags: (json['emoji_tags'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    keywords: (json['keywords'] ?? '').toString(),
  );
}

class StickerPack {
  const StickerPack({
    required this.id,
    required this.slug,
    required this.name,
    this.authorName,
    this.coverMediaId,
    this.isAnimated = false,
    this.isPersonal = false,
    this.installed = false,
    this.stickerCount = 0,
    this.stickers = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String? authorName;

  /// La vignette de l'onglet. Absente, on retombe sur le premier sticker —
  /// un onglet vide serait pire qu'une vignette approximative.
  final int? coverMediaId;
  final bool isAnimated;

  /// Un pack personnel ne s'installe ni ne se désinstalle : son
  /// propriétaire l'a créé, il l'a déjà.
  final bool isPersonal;
  final bool installed;
  final int stickerCount;
  final List<Sticker> stickers;

  int? get thumbnailMediaId =>
      coverMediaId ?? (stickers.isEmpty ? null : stickers.first.mediaId);

  factory StickerPack.fromJson(Map<String, dynamic> json) => StickerPack(
    id: json['id'] as int,
    slug: (json['slug'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    authorName: json['author_name'] as String?,
    coverMediaId: json['cover_media_id'] as int?,
    isAnimated: json['is_animated'] == true,
    isPersonal: json['is_personal'] == true,
    installed: json['installed'] == true,
    stickerCount: json['sticker_count'] as int? ?? 0,
    stickers: (json['stickers'] as List<dynamic>? ?? const [])
        .map((e) => Sticker.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
