import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pokou/core/wallpaper/wallpaper_catalog.dart';

/// Le catalogue lu directement sur le disque : dans un `testWidgets`, le
/// `rootBundle` passe par l'horloge simulée et n'aboutit pas toujours.
WallpaperCatalog readTestCatalog() => WallpaperCatalog.fromJson(
  jsonDecode(File(WallpaperCatalog.manifestAsset).readAsStringSync())
      as Map<String, dynamic>,
);

/// Un coffre en mémoire, pour relire un réglage comme au prochain lancement.
class MemoryStorage extends FlutterSecureStorage {
  MemoryStorage([Map<String, String>? values]) : values = values ?? {};

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
