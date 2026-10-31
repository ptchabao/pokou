import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../media/media_repository.dart' show MediaMeta;
import 'e2ee_primitives.dart';

/// Ce qu'il faut pour relire UNE pièce jointe chiffrée — et rien d'autre.
///
/// ── Le principe ──────────────────────────────────────────────────────
///
/// Le fichier est chiffré une fois, avec une clé tirée pour lui seul, et
/// c'est cette CLÉ — quelques dizaines d'octets — qui voyage dans le message
/// chiffré de bout en bout. Le serveur stocke un bloc opaque qu'il ne peut
/// ni ouvrir ni décrire : pas de type, pas de nom, pas de vignette.
///
/// C'est le schéma de Signal et de WhatsApp, et il a une raison simple : le
/// cliquet ne chiffre que de petits messages, et une vidéo de vingt
/// méga-octets n'a rien à faire dans une enveloppe.
///
/// ── Ce que chaque champ protège ──────────────────────────────────────
///
/// - [key] et [nonce] : AES-256-GCM, une clé par fichier — jamais réutilisée,
///   donc le nonce aléatoire ne risque aucune collision.
/// - [digest] : l'empreinte SHA-256 du bloc TÉLÉVERSÉ. GCM détecte déjà
///   toute altération ; l'empreinte permet en plus de refuser un bloc
///   substitué AVANT de tenter de le déchiffrer, et de dire « fichier
///   altéré » plutôt que « échec ».
/// - [mimeType], [filename], [size] : ce que le serveur connaissait avant et
///   ne connaît plus. Ils voyagent chiffrés, avec la clé.
/// - [caption] : la légende, qui partait en clair à côté de la photo.
class MediaKey {
  const MediaKey({
    required this.key,
    required this.nonce,
    required this.digest,
    required this.mimeType,
    required this.filename,
    required this.size,
    this.caption,
    this.assetId,
  });

  final Uint8List key;
  final Uint8List nonce;
  final Uint8List digest;
  final String mimeType;
  final String filename;
  final int size;
  final String? caption;

  /// Le fichier téléversé que cette clé ouvre. Scellé avec elle, il lie la
  /// clé à CE fichier : le destinataire refuse une clé qui annoncerait un
  /// autre identifiant que celui du message — sans quoi le serveur, maître
  /// de `media_asset_id`, pourrait présenter le fichier d'un autre (déjà en
  /// cache) dans un message authentique.
  final int? assetId;

  /// La même clé, rattachée au fichier une fois son identifiant connu.
  MediaKey withAssetId(int id) => MediaKey(
    key: key,
    nonce: nonce,
    digest: digest,
    mimeType: mimeType,
    filename: filename,
    size: size,
    caption: caption,
    assetId: id,
  );

  /// Marque de format : un texte chiffré qui commencerait par hasard comme
  /// du JSON ne doit pas être pris pour une clé de pièce jointe.
  static const format = 'pokou-media-v1';

  Map<String, dynamic> toJson() => {
    'pokou': format,
    'k': base64.encode(key),
    'n': base64.encode(nonce),
    'h': base64.encode(digest),
    'm': mimeType,
    'f': filename,
    's': size,
    if (caption != null && caption!.trim().isNotEmpty) 'c': caption,
    if (assetId != null) 'i': assetId,
  };

  /// Le texte scellé dans l'enveloppe de bout en bout.
  String seal() => jsonEncode(toJson());

  /// `null` si [json] n'est pas une clé de pièce jointe — un message texte,
  /// ou un format que cette version ne connaît pas.
  static MediaKey? tryFromJson(Object? json) {
    if (json is! Map || json['pokou'] != format) return null;
    try {
      final key = base64.decode(json['k'] as String);
      final nonce = base64.decode(json['n'] as String);
      final digest = base64.decode(json['h'] as String);
      if (key.length != 32 ||
          nonce.length != E2EEPrimitives.nonceLength ||
          digest.length != 32) {
        return null;
      }
      return MediaKey(
        key: key,
        nonce: nonce,
        digest: digest,
        mimeType: json['m'] as String,
        filename: json['f'] as String,
        size: json['s'] as int,
        caption: json['c'] as String?,
        assetId: json['i'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Lit le clair d'une enveloppe ouverte.
  static MediaKey? tryParse(String plaintext) {
    if (!plaintext.startsWith('{')) return null;
    try {
      return tryFromJson(jsonDecode(plaintext));
    } catch (_) {
      return null;
    }
  }

  /// La description que le serveur fournissait avant, reconstituée depuis
  /// la clé — les bulles continuent de lire `message.media` sans savoir que
  /// le fichier était chiffré.
  MediaMeta toMeta(int mediaAssetId) => MediaMeta(
    id: mediaAssetId,
    mimeType: mimeType,
    sizeBytes: size,
    originalFilename: filename,
  );
}

/// Le fichier altéré, ou une clé qui ne lui correspond pas. Jamais affiché
/// à moitié : on ne montre pas un média dont on ne peut garantir l'origine.
class MediaIntegrityException implements Exception {
  const MediaIntegrityException(this.message);
  final String message;
  @override
  String toString() => 'MediaIntegrityException: $message';
}

/// Chiffre et déchiffre le CONTENU des pièces jointes.
abstract final class MediaCipher {
  /// Données authentifiées : lient le bloc à cet usage, pour qu'il ne puisse
  /// pas être rejoué comme un autre type d'objet chiffré.
  static final _aad = utf8.encode(MediaKey.format);

  /// Le type sous lequel le bloc est téléversé. Le serveur n'apprend rien :
  /// ni s'il s'agit d'une photo, ni d'un document.
  static const uploadMimeType = 'application/octet-stream';
  static const uploadFilename = 'pokou.bin';

  /// Le bloc à téléverser (chiffré, puis l'étiquette GCM de 16 octets), et
  /// la clé qui permettra de le relire.
  static Future<({Uint8List blob, MediaKey key})> encrypt(
    List<int> plaintext, {
    required String mimeType,
    required String filename,
    String? caption,
  }) async {
    final key = E2EEPrimitives.randomBytes(32);
    final nonce = E2EEPrimitives.randomBytes(E2EEPrimitives.nonceLength);
    final sealed = await E2EEPrimitives.encrypt(
      plaintext,
      key: key,
      nonce: nonce,
      aad: _aad,
    );
    final blob = Uint8List(sealed.ciphertext.length + sealed.mac.length)
      ..setAll(0, sealed.ciphertext)
      ..setAll(sealed.ciphertext.length, sealed.mac);
    return (
      blob: blob,
      key: MediaKey(
        key: key,
        nonce: nonce,
        digest: await _sha256(blob),
        mimeType: mimeType,
        filename: filename,
        size: plaintext.length,
        caption: caption,
      ),
    );
  }

  /// Lève [MediaIntegrityException] si le bloc n'est pas celui que
  /// l'expéditeur a chiffré.
  static Future<Uint8List> decrypt(List<int> blob, MediaKey key) async {
    const macLength = 16;
    if (blob.length < macLength) {
      throw const MediaIntegrityException('bloc tronqué');
    }
    final digest = await _sha256(blob);
    if (!_sameBytes(digest, key.digest)) {
      throw const MediaIntegrityException('empreinte différente');
    }
    try {
      final clear = await E2EEPrimitives.decrypt(
        blob.sublist(0, blob.length - macLength),
        mac: blob.sublist(blob.length - macLength),
        key: key.key,
        nonce: key.nonce,
        aad: _aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const MediaIntegrityException('authentification refusée');
    }
  }

  static Future<Uint8List> _sha256(List<int> bytes) async =>
      Uint8List.fromList((await Sha256().hash(bytes)).bytes);

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Les clés des pièces jointes chiffrées connues pendant cette session, par
/// identifiant de média.
///
/// Toute pièce jointe passe par `MediaRepository.resolveLocalFile`, appelé
/// depuis une dizaine d'endroits — bulles, visionneuse, export, préchargement
/// — qui ne connaissent que l'identifiant du fichier. Plutôt que de faire
/// descendre la clé jusqu'à chacun (et d'en oublier un, qui afficherait le
/// bloc chiffré), le message la dépose ici dès qu'il est lu, et le dépôt de
/// médias la retrouve seul.
///
/// En mémoire seulement : la clé durable vit dans le cache chiffré des
/// messages (DirectMessage.mediaKey), d'où elle revient à chaque lecture.
abstract final class MediaKeyRing {
  static final Map<int, MediaKey> _keys = {};

  /// La première clé connue pour un fichier fait foi : une clé DIFFÉRENTE
  /// annoncée plus tard pour le même identifiant ne la remplace pas — c'est
  /// la forme qu'aurait une substitution.
  static void remember(int mediaAssetId, MediaKey key) =>
      _keys.putIfAbsent(mediaAssetId, () => key);

  static MediaKey? of(int mediaAssetId) => _keys[mediaAssetId];

  /// Déconnexion : les clés du compte qu'on quitte n'ont rien à faire en
  /// mémoire sous le suivant.
  static void clear() => _keys.clear();
}
