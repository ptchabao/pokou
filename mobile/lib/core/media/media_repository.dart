import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../crypto/media_cipher.dart';

class MediaMeta {
  const MediaMeta({
    required this.id,
    required this.mimeType,
    required this.sizeBytes,
    required this.originalFilename,
  });

  final int id;
  final String mimeType;
  final int sizeBytes;
  final String? originalFilename;

  factory MediaMeta.fromJson(Map<String, dynamic> json) => MediaMeta(
    id: json['id'] as int,
    mimeType: json['mime_type'] as String,
    sizeBytes: json['size_bytes'] as int,
    originalFilename: json['original_filename'] as String?,
  );

  /// Même forme que la charge utile de l'API — c'est ce qui permet au cache
  /// local de réutiliser `fromJson` à la relecture (voir
  /// core/storage/pokou_message_store.dart) plutôt qu'un second format.
  Map<String, dynamic> toJson() => {
    'id': id,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'original_filename': originalFilename,
  };
}

/// Extension probable d'un média (pour nommer le fichier mis en cache
/// localement) — dérivée du nom d'origine s'il est connu, sinon du MIME type.
String mediaExtension(MediaMeta media) {
  final name = media.originalFilename;
  if (name != null && name.contains('.')) return name.split('.').last;
  return media.mimeType.split('/').last;
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.id,
    required this.mimeType,
    required this.sizeBytes,
  });

  final int id;
  final String mimeType;
  final int sizeBytes;

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) =>
      MediaUploadResult(
        id: json['id'] as int,
        mimeType: json['mime_type'] as String,
        sizeBytes: json['size_bytes'] as int,
      );
}

class MediaCacheStats {
  const MediaCacheStats({required this.fileCount, required this.totalBytes});

  final int fileCount;
  final int totalBytes;
}

/// Taille lisible — Ko/Mo décimaux (1000 et non 1024), comme les réglages
/// Android eux-mêmes, pour ne pas afficher un chiffre en désaccord avec ce
/// que le système annonce pour la même app.
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes o';
  if (bytes < 1000 * 1000) return '${(bytes / 1000).toStringAsFixed(0)} Ko';
  return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} Mo';
}

/// Upload/téléchargement des pièces jointes Pokou (notes vocales, documents,
/// images, vidéos). Le téléchargement passe systématiquement par l'API
/// authentifiée (`GET /media/{id}`) — pas d'URL statique publique — donc les
/// lecteurs média (just_audio/video_player) ont besoin d'un fichier local :
/// on met en cache le résultat sous le répertoire temporaire de l'app,
/// nommé par l'id du média (jamais de contenu utilisateur dans le nom).
class MediaRepository {
  MediaRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  static const _cachePrefix = 'pokou_media_';

  /// Les largeurs de vignette que le serveur sait produire
  /// (api/app/services/thumbnail_service.py). Toute autre valeur lui fait
  /// servir l'original — ce n'est pas une erreur, juste un gâchis.
  static const largeursVignette = <int>[96, 320, 1080];

  /// La vignette la plus petite qui couvre [largeurAffichee] points
  /// logiques à la densité de l'écran.
  ///
  /// Demander en dessous de ses besoins donnerait une image floue, donc on
  /// arrondit au palier supérieur. Au-delà du plus grand palier, on le
  /// garde quand même plutôt que de réclamer l'original : sur un écran très
  /// dense, une image pleine largeur demande 1 260 points quand le plus
  /// grand palier en fait 1 080 — l'écart ne se voit pas sur une photo,
  /// alors que l'original pèse trois à cinq méga-octets.
  ///
  /// Un appelant qui veut VRAIMENT l'original ne passe simplement pas de
  /// `decodeWidth` (visionneuse plein écran, téléchargement).
  static int vignettePour(double largeurAffichee, double densite) {
    final besoin = largeurAffichee * densite;
    for (final palier in largeursVignette) {
      if (palier >= besoin) return palier;
    }
    return largeursVignette.last;
  }

  // ── Ce que la session garde en mémoire ────────────────────────────────
  //
  // `resolveLocalFile` faisait DEUX sauts asynchrones à chaque appel : un
  // aller-retour de canal de plateforme pour `getTemporaryDirectory`, puis
  // un `exists()` sur le disque. Les écrans l'appelaient depuis leur
  // `build`, donc à chaque reconstruction — c'est-à-dire à chaque image de
  // défilement. Entre-temps le `FutureBuilder` affichait son indicateur de
  // chargement : les vignettes CLIGNOTAIENT en permanence sur une liste
  // qu'on fait défiler, alors que les fichiers étaient déjà sur l'appareil.
  //
  // Trois caches, et trois problèmes distincts :
  //
  // - `_dossier` : le répertoire temporaire ne change pas de la vie du
  //   processus. Le redemander était un aller-retour natif pour rien.
  // - `_resolus` : les fichiers déjà localisés. Permet surtout
  //   `fichierEnCache`, qui répond SANS `Future` — un écran peut alors
  //   afficher l'image dès sa première image de rendu, sans indicateur.
  // - `_enCours` : les résolutions en vol. Une grille de vingt vignettes
  //   qui montre deux fois le même média lançait deux téléchargements de
  //   la même image, en parallèle, écrivant dans le même fichier.
  //
  // Ils sont statiques parce que le cache appartient au PROCESSUS, pas à
  // l'instance : la portée du provider peut changer, les fichiers sur le
  // disque, non.
  static Future<Directory>? _dossier;
  static Directory? _dossierSynchrone;
  static final Map<String, File> _resolus = {};
  static final Map<String, Future<File>> _enCours = {};

  /// Préchauffe la localisation du répertoire de cache dès le démarrage de
  /// l'application pour permettre la résolution synchrone des médias sur disque.
  static Future<void> warmup() async {
    await _repertoire();
  }

  static Future<Directory> _repertoire() async {
    if (_dossierSynchrone != null) return _dossierSynchrone!;
    final dir = await (_dossier ??= getTemporaryDirectory());
    _dossierSynchrone = dir;
    return dir;
  }

  /// La clé de cache inclut la LARGEUR, sinon la vignette de 96 points
  /// servirait aussi pour la fiche produit et la visionneuse plein écran —
  /// une image de 96 points étirée sur tout l'écran.
  static String _cle(int mediaAssetId, String extension, [int? largeur]) =>
      largeur == null
      ? '$_cachePrefix$mediaAssetId${_extensionSuffix(extension)}'
      // Extension forcée : le serveur renvoie toujours du JPEG pour une
      // vignette, quel que soit le format d'origine.
      : '${_cachePrefix}w${largeur}_$mediaAssetId.jpg';

  /// Le fichier s'il a DÉJÀ été résolu pendant cette session — sans `Future`,
  /// donc utilisable pendant un `build`.
  ///
  /// C'est ce qui permet à une vignette de s'afficher dès la première image
  /// de rendu au lieu de passer par un indicateur de chargement qu'elle
  /// n'a aucune raison de montrer.
  ///
  /// `null` ne veut pas dire « absent de l'appareil » : seulement « pas
  /// encore demandé dans cette session ». L'appelant enchaîne alors sur
  /// [resolveLocalFile].
  File? fichierEnCache(
    int mediaAssetId, {
    String extension = '',
    int? largeur,
  }) {
    final cle = _cle(mediaAssetId, extension, largeur);
    final deja = _resolus[cle];
    if (deja != null) return deja;

    // Si on connaît le répertoire de cache, on vérifie l'existence sur disque
    // de manière SYNCHRONE. Les images déjà téléchargées s'affichent ainsi
    // immédiatement au démarrage sans écran ni rond de chargement.
    final dir = _dossierSynchrone;
    if (dir != null) {
      final file = File('${dir.path}/$cle');
      if (file.existsSync()) {
        _resolus[cle] = file;
        return file;
      }
      if (extension.isNotEmpty && largeur == null) {
        final fallback = File('${dir.path}/${_cle(mediaAssetId, '', null)}');
        if (fallback.existsSync()) {
          _resolus[cle] = fallback;
          return fallback;
        }
      }
    }
    return null;
  }

  /// Un fichier mis en cache sous une clé LIBRE, dont l'appelant fournit le
  /// téléchargement.
  ///
  /// Les pièces jointes ont un identifiant de média ; l'illustration d'un
  /// aperçu de lien, non — elle vit chez un tiers et n'est désignée que par
  /// son URL. Elle a pourtant exactement les mêmes besoins : ne pas être
  /// retéléchargée à chaque défilement, ne pas partir deux fois en
  /// parallèle, et disparaître quand on vide le cache.
  ///
  /// [cle] doit être un nom de fichier sûr et STABLE entre deux lancements
  /// (une empreinte, pas un `hashCode`, qui change d'une exécution à
  /// l'autre).
  Future<File> fichierSousCle(
    String cle,
    Future<List<int>> Function() telecharger,
  ) {
    final complete = '$_cachePrefix$cle';
    final deja = _resolus[complete];
    if (deja != null) return SynchronousFuture<File>(deja);
    return _enCours[complete] ??= _resoudreSousCle(
      complete,
      telecharger,
    ).whenComplete(() => _enCours.remove(complete));
  }

  /// La variante pour les fichiers sous clé libre — mêmes raisons.
  Future<void> oublierLaCle(String cle) async {
    final complete = '$_cachePrefix$cle';
    final fichier = _resolus.remove(complete);
    try {
      if (fichier != null && await fichier.exists()) await fichier.delete();
    } on FileSystemException {
      // Déjà parti.
    }
  }

  Future<File> _resoudreSousCle(
    String complete,
    Future<List<int>> Function() telecharger,
  ) async {
    final dir = await _repertoire();
    final file = File('${dir.path}/$complete');
    if (!await file.exists()) {
      await file.writeAsBytes(await telecharger(), flush: true);
    }
    _resolus[complete] = file;
    return file;
  }

  /// Le fichier connu s'est révélé illisible — vidé par le système, ou
  /// tronqué par un téléchargement interrompu.
  ///
  /// On l'oublie ET on l'EFFACE. Le seul oublier ne suffisait pas : la
  /// résolution suivante retrouvait le fichier sur le disque, constatait
  /// qu'il existe, et le rendait tel quel. Un média téléchargé à moitié
  /// restait donc cassé jusqu'à ce qu'on vide tout le cache à la main.
  Future<void> oublier(
    int mediaAssetId, {
    String extension = '',
    int? largeur,
  }) async {
    final cle = _cle(mediaAssetId, extension, largeur);
    final fichier = _resolus.remove(cle);
    try {
      if (fichier != null && await fichier.exists()) await fichier.delete();
    } on FileSystemException {
      // Le fichier était déjà parti : c'est exactement ce qu'on voulait.
    }
  }

  @visibleForTesting
  static void viderLeCacheMemoire() {
    _resolus.clear();
    _enCours.clear();
    _dossier = null;
    _dossierSynchrone = null;
  }

  /// Injecte un répertoire de cache pour les tests unitaires, en remplacement
  /// de `getTemporaryDirectory()` qui n'est pas disponible dans cet environnement.
  @visibleForTesting
  static void setTestCacheDirectory(Directory dir) {
    _dossierSynchrone = dir;
    _dossier = Future.value(dir);
  }

  /// Enregistre un fichier local ou des octets dans le cache local sous
  /// l'identifiant [mediaAssetId].
  ///
  /// C'est ce qui évite le comportement où l'application téléverse
  /// une photo depuis l'appareil, confirme l'envoi, puis retélécharge cette
  /// MÊME photo depuis le serveur en affichant un indicateur de chargement.
  Future<File> memoriserDansCache(
    int mediaAssetId, {
    String? sourcePath,
    List<int>? bytes,
    String extension = '',
  }) async {
    final dir = await _repertoire();
    final cle = _cle(mediaAssetId, extension, null);
    final destination = File('${dir.path}/$cle');

    if (sourcePath != null && sourcePath != destination.path) {
      final source = File(sourcePath);
      if (await source.exists()) {
        try {
          await source.copy(destination.path);
        } catch (_) {
          if (bytes != null) {
            await destination.writeAsBytes(bytes, flush: true);
          } else {
            await destination.writeAsBytes(await source.readAsBytes(), flush: true);
          }
        }
      } else if (bytes != null) {
        await destination.writeAsBytes(bytes, flush: true);
      }
    } else if (bytes != null) {
      await destination.writeAsBytes(bytes, flush: true);
    }

    _resolus[cle] = destination;
    final cleSansExt = _cle(mediaAssetId, '', null);
    _resolus[cleSansExt] = destination;
    return destination;
  }

  /// [onProgress] reçoit une fraction entre 0 et 1 — voir
  /// `ApiClient.uploadFile` pour ce qu'elle mesure exactement.
  Future<MediaUploadResult> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String messageType,
    void Function(double fraction)? onProgress,
    bool memoriser = true,
  }) async {
    final response = await _api.uploadFile(
      '/media/upload',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      fields: {'message_type': messageType},
      onProgress: onProgress,
    );
    final result = MediaUploadResult.fromJson(response as Map<String, dynamic>);
    // `memoriser: false` pour un bloc CHIFFRÉ : le garder en cache sous cet
    // identifiant le ferait servir à la place du fichier en clair — une
    // photo illisible chez son propre expéditeur. L'appelant y range
    // lui-même le clair (voir MediaSender).
    if (memoriser) {
      final ext = filename.contains('.') ? filename.split('.').last : mimeType.split('/').last;
      await memoriserDansCache(result.id, bytes: bytes, extension: ext);
    }
    return result;
  }

  /// Le média est-il DÉJÀ sur l'appareil ? Sert au mode économie de données :
  /// une pièce jointe déjà téléchargée s'affiche sans attendre un second
  /// geste de l'utilisateur (voir media_bubble.dart).
  Future<bool> isCached(int mediaAssetId, {String extension = ''}) async {
    final deja = fichierEnCache(mediaAssetId, extension: extension);
    if (deja != null) return true;
    final dir = await _repertoire();
    final cle = _cle(mediaAssetId, extension, null);
    final f = File('${dir.path}/$cle');
    if (await f.exists()) {
      _resolus[cle] = f;
      return true;
    }
    if (extension.isNotEmpty) {
      final fFallback = File('${dir.path}/${_cle(mediaAssetId, '', null)}');
      if (await fFallback.exists()) {
        _resolus[cle] = fFallback;
        return true;
      }
    }
    return false;
  }

  static String _extensionSuffix(String extension) => extension.isEmpty
      ? ''
      : '.${extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';

  /// [largeur] demande une VIGNETTE plutôt que l'original.
  ///
  /// C'est la correction la plus lourde de conséquences sur la vitesse
  /// d'affichage : le serveur servait l'original quelle que soit la taille
  /// à laquelle l'image allait apparaître. Une photo prise au téléphone pèse
  /// deux à cinq méga-octets ; une pastille de contact fait 40 points de
  /// côté. Le cache local évitait de RECOMMENCER ce téléchargement, il ne
  /// pouvait pas éviter de le faire une première fois.
  ///
  /// Une largeur que le serveur ne connaît pas ne casse rien : il renvoie
  /// l'original. Voir [largeursVignette].
  ///
  /// [mediaKey] : la pièce jointe est chiffrée de bout en bout. Le bloc est
  /// alors téléchargé en entier — le serveur ne peut pas en tirer de
  /// vignette, il ne sait pas ce qu'il contient — puis vérifié et
  /// déchiffré avant d'être rangé. Lève [MediaIntegrityException] si le
  /// bloc n'est pas celui que l'expéditeur a chiffré.
  Future<File> resolveLocalFile(
    int mediaAssetId, {
    String extension = '',
    int? largeur,
    MediaKey? mediaKey,
  }) {
    mediaKey ??= MediaKeyRing.of(mediaAssetId);
    if (mediaKey != null) largeur = null;
    final deja = fichierEnCache(mediaAssetId, extension: extension, largeur: largeur);
    // `SynchronousFuture` et non `Future.value` : il se complète dans la
    // même image de rendu, donc un `FutureBuilder` déjà en place ne repasse
    // pas par son état de chargement.
    if (deja != null) return SynchronousFuture<File>(deja);
    final cle = _cle(mediaAssetId, extension, largeur);
    return _enCours[cle] ??= _resoudre(
      cle,
      mediaAssetId,
      largeur,
      mediaKey,
    ).whenComplete(() => _enCours.remove(cle));
  }

  Future<File> _resoudre(
    String cle,
    int mediaAssetId,
    int? largeur,
    MediaKey? mediaKey,
  ) async {
    final dir = await _repertoire();
    final file = File('${dir.path}/$cle');
    if (!await file.exists()) {
      final bytes = await _api.getBytes(
        largeur == null
            ? '/media/$mediaAssetId'
            : '/media/$mediaAssetId?w=$largeur',
      );
      // Déchiffré AVANT l'écriture : un bloc altéré ne doit jamais atterrir
      // dans le cache, où il serait relu tel quel au prochain affichage.
      final clear = mediaKey == null
          ? bytes
          : await MediaCipher.decrypt(bytes, mediaKey);
      await file.writeAsBytes(clear, flush: true);
    }
    _resolus[cle] = file;
    return file;
  }

  /// Réglages > Stockage et données — ce que le cache média occupe
  /// réellement, pour ne pas proposer de « vider » à l'aveugle.
  Future<MediaCacheStats> cacheStats() async {
    final dir = await _repertoire();
    if (!await dir.exists())
      return const MediaCacheStats(fileCount: 0, totalBytes: 0);
    var count = 0;
    var bytes = 0;
    await for (final entity in dir.list()) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith(_cachePrefix)) {
        count++;
        bytes += await entity.length();
      }
    }
    return MediaCacheStats(fileCount: count, totalBytes: bytes);
  }

  /// Réglages > Stockage et données — supprime uniquement les fichiers
  /// médias mis en cache localement (préfixe `pokou_media_`), pas
  /// d'éventuels autres fichiers temporaires (ex. notes vocales en cours
  /// d'enregistrement). Les fichiers rouverts seront simplement
  /// retéléchargés depuis l'API.
  Future<int> clearCache() async {
    // Les fichiers partent du disque : la mémoire ne doit plus prétendre
    // savoir où ils sont, sinon « vider le cache » laisse l'application
    // afficher des chemins morts jusqu'au redémarrage.
    _resolus.clear();
    final dir = await _repertoire();
    if (!await dir.exists()) return 0;
    var removed = 0;
    await for (final entity in dir.list()) {
      if (entity is File &&
          entity.uri.pathSegments.last.startsWith(_cachePrefix)) {
        await entity.delete();
        removed++;
      }
    }
    return removed;
  }
}
