/// Le Pokoumoji vivant de l'application : catalogue embarqué, pack signé
/// téléchargé à la demande, préférences et récents locaux.
///
/// ── Distribution (cahier des charges §07) ──────────────────────────────
///
/// Le catalogue (textes, identifiants, statuts) est EMBARQUÉ : il dit ce
/// qui existe, il ne contient aucune image. Les images viennent d'un pack
/// servi en HTTPS par l'API (`/pokoumoji/packs/<canal>/`), dont le
/// manifeste est signé en Ed25519. Le manifeste est gardé sur l'appareil
/// (mode hors ligne) et revérifié à chaque lecture ; chaque fichier est
/// téléchargé à la demande, vérifié, puis rangé sous son empreinte.
///
/// Deux canaux :
/// * `prod` — clé de production, statut `placeholder` refusé ;
/// * `dev`  — vignettes provisoires, clé de développement. Seulement en
///   build de développement : `flutter run` (debug) ou une build lancée
///   avec `--dart-define=POKOUMOJI_DEV=true`. Jamais en production (T25).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/pokoumoji.dart';
import 'pokoumoji_pack_verifier.dart';

/// Build de développement : montre les entrées non approuvées et accepte
/// le pack de vignettes provisoires.
const bool kPokoumojiDev = kDebugMode || bool.fromEnvironment('POKOUMOJI_DEV');

/// Cache local borné (§07).
const _maxCacheBytes = 60 * 1024 * 1024;

class PokoumojiRuntime {
  PokoumojiRuntime._();

  static final PokoumojiRuntime instance = PokoumojiRuntime._();

  /// Le catalogue, une fois chargé. Le champ de saisie et les bulles le
  /// lisent sans attendre : tant qu'il est nul, tout s'affiche en fallback.
  final ValueNotifier<PokoumojiCatalogue?> catalogue = ValueNotifier(null);

  /// Le manifeste vérifié du pack, s'il y en a un.
  final ValueNotifier<PokoumojiManifest?> manifest = ValueNotifier(null);

  /// Préférences et récents : locaux, jamais envoyés (§07).
  final ValueNotifier<PokoumojiPrefs> prefs = ValueNotifier(
    const PokoumojiPrefs(),
  );
  final ValueNotifier<List<String>> recents = ValueNotifier(const []);

  String _apiRoot = '';
  Future<void>? _loading;
  Directory? _dir;
  final _files = <String, Future<File?>>{};
  http.Client _http = http.Client();

  String get channel => kPokoumojiDev ? 'dev' : 'prod';

  /// Pour les tests et les rendus d'aperçu : un catalogue, un dossier de
  /// cache et un client HTTP donnés, sans plateforme.
  @visibleForTesting
  Future<void> debugLoad({
    required PokoumojiCatalogue catalogue,
    required Directory directory,
    required http.Client client,
    String apiRoot = 'https://pack.test',
  }) async {
    this.catalogue.value = catalogue;
    _dir = directory;
    _http = client;
    _apiRoot = apiRoot;
    _loading = Future.value();
    _files.clear();
    await _loadManifest();
  }

  /// Charge le catalogue puis le pack. Idempotent ; [apiBaseUrl] est la
  /// base de l'API (`https://api.pokou.app/api/v1`).
  Future<void> ensureLoaded(String apiBaseUrl) {
    _apiRoot = apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      catalogue.value = await loadBundledCatalogue(
        includeUnapproved: kPokoumojiDev,
      );
    } catch (e) {
      debugPrint('Pokoumoji : catalogue illisible ($e)');
      return;
    }
    // Rien à montrer (aucune entrée approuvée en production) : inutile de
    // télécharger quoi que ce soit.
    if (!(catalogue.value?.hasVisible ?? false)) return;
    try {
      _dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/pokoumoji/$channel',
      );
      await _dir!.create(recursive: true);
      await _loadPrefs();
      await _loadManifest();
    } catch (e) {
      debugPrint('Pokoumoji : pack indisponible ($e)');
    }
  }

  static Future<PokoumojiCatalogue> loadBundledCatalogue({
    required bool includeUnapproved,
  }) async {
    final raw = await Future.wait([
      rootBundle.loadString('assets/pokoumoji/catalogue.json'),
      rootBundle.loadString('assets/pokoumoji/aliases.json'),
      rootBundle.loadString('assets/pokoumoji/collections.json'),
    ]);
    return parseCatalogue(
      catalogueJson: raw[0],
      aliasesJson: raw[1],
      collectionsJson: raw[2],
      includeUnapproved: includeUnapproved,
    );
  }

  static PokoumojiCatalogue parseCatalogue({
    required String catalogueJson,
    required String aliasesJson,
    required String collectionsJson,
    required bool includeUnapproved,
  }) {
    final cat = jsonDecode(catalogueJson) as Map<String, dynamic>;
    final ali = jsonDecode(aliasesJson) as Map<String, dynamic>;
    final col = jsonDecode(collectionsJson) as Map<String, dynamic>;
    return PokoumojiCatalogue(
      [
        for (final e in cat['entries'] as List)
          PokoumojiEntry.fromJson(e as Map<String, dynamic>),
      ],
      aliases: {
        for (final a in (ali['aliases'] as Map).entries)
          '${a.key}': '${a.value}',
      },
      categories: [
        for (final c in col['categories'] as List)
          PokoumojiCategory.fromJson(c as Map<String, dynamic>),
      ],
      version: '${cat['version'] ?? ''}',
      includeUnapproved: includeUnapproved,
    );
  }

  // ── Manifeste ──────────────────────────────────────────────────────────

  String _url(String path) => '$_apiRoot/pokoumoji/packs/$channel/$path';

  List<String> get _keys => [
    PokoumojiKeys.production,
    if (kPokoumojiDev) PokoumojiKeys.development,
  ];

  Future<void> _loadManifest() async {
    final mFile = File('${_dir!.path}/manifest.json');
    final sFile = File('${_dir!.path}/manifest.sig');
    // D'abord la copie locale (hors ligne), revérifiée.
    if (await mFile.exists() && await sFile.exists()) {
      await _accept(await mFile.readAsBytes(), await sFile.readAsString());
    }
    // Puis le serveur, sans bloquer l'affichage.
    try {
      final responses = await Future.wait([
        _http.get(Uri.parse(_url('manifest.json'))),
        _http.get(Uri.parse(_url('manifest.sig'))),
      ]).timeout(const Duration(seconds: 20));
      if (responses.any((r) => r.statusCode != 200)) return;
      final ok = await _accept(responses[0].bodyBytes, responses[1].body);
      if (ok) {
        await mFile.writeAsBytes(responses[0].bodyBytes, flush: true);
        await sFile.writeAsString(responses[1].body, flush: true);
      }
    } catch (_) {
      // Hors ligne : la copie locale, s'il y en a une, suffit.
    }
  }

  Future<bool> _accept(Uint8List bytes, String signature) async {
    final check = await PokoumojiPackVerifier.checkManifest(
      manifestBytes: bytes,
      signatureBase64: signature,
      publicKeys: _keys,
      allowPlaceholder: kPokoumojiDev,
    );
    switch (check) {
      case ManifestAccepted(:final manifest):
        if (this.manifest.value?.packVersion != manifest.packVersion) {
          _files.clear();
        }
        this.manifest.value = manifest;
        return true;
      case ManifestRefused(:final reason):
        debugPrint('Pokoumoji : $reason');
        return false;
    }
  }

  /// Le pack connaît-il un fichier pour cette entrée ?
  bool hasAsset(PokoumojiEntry entry) =>
      manifest.value?.files.containsKey(pokoumojiPackPath(entry, 128)) ?? false;

  // ── Fichiers ───────────────────────────────────────────────────────────

  /// Le fichier vérifié de [entry] à [size] px, ou `null` (→ fallback).
  Future<File?> fileFor(PokoumojiEntry entry, int size) {
    final path = pokoumojiPackPath(entry, size);
    return _files[path] ??= _fetch(path).then((f) {
      if (f == null) _files.remove(path);
      return f;
    });
  }

  Future<File?> _fetch(String path) async {
    final info = manifest.value?.files[path];
    final dir = _dir;
    if (info == null || dir == null || !packPathRe.hasMatch(path)) return null;
    final local = File('${dir.path}/${info.sha256}.webp');
    if (await local.exists()) {
      final data = await local.readAsBytes();
      if (PokoumojiPackVerifier.checkFile(info, data) == null) {
        unawaited(local.setLastModified(DateTime.now()).catchError((_) {}));
        return local;
      }
      await local.delete().catchError((_) => local);
    }
    try {
      final r = await _http
          .get(Uri.parse(_url(path)))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final refusal = PokoumojiPackVerifier.checkFile(info, r.bodyBytes);
      if (refusal != null) {
        debugPrint('Pokoumoji : $refusal');
        return null;
      }
      await local.writeAsBytes(r.bodyBytes, flush: true);
      unawaited(_trimCache());
      return local;
    } catch (_) {
      return null;
    }
  }

  bool _trimming = false;

  Future<void> _trimCache() async {
    final dir = _dir;
    if (dir == null || _trimming) return;
    _trimming = true;
    try {
      final files = <(File, int, DateTime)>[];
      var total = 0;
      await for (final f in dir.list()) {
        if (f is! File || !f.path.endsWith('.webp')) continue;
        final st = await f.stat();
        files.add((f, st.size, st.modified));
        total += st.size;
      }
      if (total <= _maxCacheBytes) return;
      files.sort((a, b) => a.$3.compareTo(b.$3));
      for (final (f, size, _) in files) {
        if (total <= _maxCacheBytes * 0.8) break;
        await f.delete().catchError((_) => f);
        total -= size;
      }
    } finally {
      _trimming = false;
    }
  }

  // ── Préférences et récents ─────────────────────────────────────────────

  File? get _prefsFile =>
      _dir == null ? null : File('${_dir!.parent.path}/preferences.json');

  Future<void> _loadPrefs() async {
    final f = _prefsFile;
    if (f == null || !await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      prefs.value = PokoumojiPrefs(
        skinTone: j['skin_tone'] as String?,
        genderByBase: {
          for (final e in (j['gender_by_base'] as Map? ?? const {}).entries)
            '${e.key}': '${e.value}',
        },
      );
      recents.value = [
        for (final r in (j['recents'] as List? ?? const [])) '$r',
      ];
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    final f = _prefsFile;
    if (f == null) return;
    await f.writeAsString(
      jsonEncode({
        'skin_tone': prefs.value.skinTone,
        'gender_by_base': prefs.value.genderByBase,
        'recents': recents.value,
      }),
    );
  }

  /// La carnation préférée (`'1'`…`'5'`), choisie librement.
  void setSkinTone(String tone) {
    prefs.value = PokoumojiPrefs(
      skinTone: tone,
      genderByBase: prefs.value.genderByBase,
    );
    unawaited(_savePrefs());
  }

  /// Retient le choix fait à l'appui long : la carnation devient la
  /// préférence, le genre est mémorisé POUR CE MÉTIER seulement.
  void rememberVariant(PokoumojiEntry chosen) {
    final base = chosen.variantOf.isEmpty ? chosen.id : chosen.variantOf;
    prefs.value = PokoumojiPrefs(
      skinTone: chosen.skinTone.isEmpty
          ? prefs.value.skinTone
          : chosen.skinTone,
      genderByBase: {
        ...prefs.value.genderByBase,
        if (chosen.gender.isNotEmpty) base: chosen.gender,
      },
    );
    unawaited(_savePrefs());
  }

  void markUsed(PokoumojiEntry entry) {
    recents.value = [
      entry.id,
      for (final r in recents.value)
        if (r != entry.id) r,
    ].take(40).toList();
    unawaited(_savePrefs());
  }
}
