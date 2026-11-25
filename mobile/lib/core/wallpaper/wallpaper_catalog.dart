import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le catalogue des fonds d'écran des discussions, lu depuis le manifeste
/// du kit de l'équipe design (`assets/wallpapers/wallpapers.json`), embarqué
/// tel quel.
///
/// Le manifeste reste la seule source : ajouter un fond, c'est déposer ses
/// fichiers et sa ligne dans le JSON, sans toucher au code. Les chemins du
/// manifeste (`png/tiles/kete.png`, `webp/scenes/ge.webp`…) décrivent le
/// kit ; ils sont ramenés ici à la disposition des ressources de l'app
/// (`assets/wallpapers/tiles/kete.png`…) par leur seul nom de fichier.
enum WallpaperType { color, tile, scene }

enum WallpaperTone { light, dark }

/// Les quatre familles, dans l'ordre du manifeste. Leurs libellés sont
/// traduits par l'app (`wallpaperFamily…`), pas lus dans le manifeste.
enum WallpaperFamily { unis, motifs, paysages, fetes }

class WallpaperAvailability {
  const WallpaperAvailability.dates({required this.from, required this.to})
    : remote = false;
  const WallpaperAvailability.remote() : from = null, to = null, remote = true;

  /// `MM-JJ`, heure locale. `from` après `to` : la période chevauche le
  /// Nouvel An (« Fin d'année », 15 décembre → 7 janvier).
  final String? from;
  final String? to;

  /// Fêtes au calendrier lunaire : dates envoyées par configuration
  /// distante, qui n'existe pas encore — le fond n'est donc pas proposé.
  final bool remote;

  bool isOpenOn(DateTime day) {
    if (remote || from == null || to == null) return false;
    final today = _mmdd(day.month, day.day);
    final start = _parse(from!);
    final end = _parse(to!);
    if (start <= end) return today >= start && today <= end;
    return today >= start || today <= end;
  }

  static int _mmdd(int month, int day) => month * 100 + day;

  static int _parse(String raw) {
    final parts = raw.split('-');
    return _mmdd(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class Wallpaper {
  const Wallpaper({
    required this.id,
    required this.name,
    required this.meaning,
    required this.family,
    required this.type,
    required this.base,
    required this.tone,
    required this.intensityDefault,
    required this.intensityAdjustable,
    required this.thumbnail,
    this.tileAsset,
    this.tileSize,
    this.sceneAsset,
    this.availability,
  });

  final String id;

  /// Nom propre (Ŋdi, Kente, Takienta…), affiché tel quel dans toutes les
  /// langues.
  final String name;

  /// Le sens du nom, tel que l'équipe design l'a écrit.
  final String meaning;
  final WallpaperFamily family;
  final WallpaperType type;
  final Color base;
  final WallpaperTone tone;
  final int intensityDefault;
  final bool intensityAdjustable;
  final String thumbnail;

  /// Tuile PNG (variantes 2.0x/3.0x à côté) et sa taille LOGIQUE.
  final String? tileAsset;
  final Size? tileSize;

  /// Scène plein écran, en WebP.
  final String? sceneAsset;

  /// Fonds de fête : quand ils apparaissent dans l'écran de choix.
  final WallpaperAvailability? availability;

  bool get isDark => tone == WallpaperTone.dark;

  /// Proposé dans l'écran de choix ce jour-là ? Un fond déjà choisi reste
  /// affiché même hors de sa période (voir l'écran de choix).
  bool isOfferedOn(DateTime day) => availability?.isOpenOn(day) ?? true;

  static const _root = 'assets/wallpapers';

  static String _file(String path) => path.split('/').last;

  factory Wallpaper.fromJson(Map<String, dynamic> json) {
    final type = WallpaperType.values.byName(json['type'] as String);
    final tile = json['tile'] as Map<String, dynamic>?;
    final scene = json['scene'] as Map<String, dynamic>?;
    final size = tile?['size'] as List<dynamic>?;
    final availability = json['availability'] as Map<String, dynamic>?;
    return Wallpaper(
      id: json['id'] as String,
      name: json['name'] as String,
      meaning: json['meaning'] as String? ?? '',
      family: WallpaperFamily.values.byName(json['family'] as String),
      type: type,
      base: _color(json['base'] as String),
      tone: json['tone'] == 'dark' ? WallpaperTone.dark : WallpaperTone.light,
      intensityDefault: (json['intensity_default'] as num?)?.toInt() ?? 100,
      intensityAdjustable: json['intensity_adjustable'] as bool? ?? false,
      thumbnail: '$_root/thumbnails/${_file(json['thumbnail'] as String)}',
      tileAsset: tile == null
          ? null
          : '$_root/tiles/${_file(tile['png'] as String)}',
      tileSize: size == null
          ? null
          : Size((size[0] as num).toDouble(), (size[1] as num).toDouble()),
      sceneAsset: scene == null
          ? null
          : '$_root/scenes/${_file(scene['webp'] as String)}',
      availability: availability == null
          ? null
          : availability['mode'] == 'dates'
          ? WallpaperAvailability.dates(
              from: availability['from'] as String,
              to: availability['to'] as String,
            )
          : const WallpaperAvailability.remote(),
    );
  }

  static Color _color(String hex) =>
      Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
}

class WallpaperCatalog {
  const WallpaperCatalog({required this.wallpapers, required this.defaultId});

  final List<Wallpaper> wallpapers;
  final String defaultId;

  static const manifestAsset = 'assets/wallpapers/wallpapers.json';

  factory WallpaperCatalog.fromJson(Map<String, dynamic> json) =>
      WallpaperCatalog(
        wallpapers: [
          for (final raw in json['wallpapers'] as List<dynamic>)
            Wallpaper.fromJson(raw as Map<String, dynamic>),
        ],
        defaultId: json['default'] as String,
      );

  static Future<WallpaperCatalog> load(AssetBundle bundle) async {
    final raw = await bundle.loadString(manifestAsset);
    return WallpaperCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Wallpaper get fallback => wallpapers.firstWhere(
    (w) => w.id == defaultId,
    orElse: () => wallpapers.first,
  );

  /// Un identifiant inconnu (fond retiré d'une version ultérieure, réglage
  /// abîmé) retombe sur le fond par défaut plutôt que de lever.
  Wallpaper byId(String? id) =>
      wallpapers.where((w) => w.id == id).firstOrNull ?? fallback;

  List<Wallpaper> family(WallpaperFamily family) =>
      wallpapers.where((w) => w.family == family).toList();
}

/// Chargé une fois pour toute la vie de l'app : chaque ouverture de
/// conversation le relit sans refaire le décodage du JSON.
final wallpaperCatalogProvider = FutureProvider<WallpaperCatalog>(
  (ref) => WallpaperCatalog.load(rootBundle),
);

/// L'horloge de l'écran de choix (fonds de fête). Remplaçable en test.
final wallpaperClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
