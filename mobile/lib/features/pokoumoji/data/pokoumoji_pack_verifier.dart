/// Vérification d'un pack Pokoumoji (contrat §6) — sans E/S, pour être
/// testée telle quelle.
///
/// Un pack n'est JAMAIS utilisé sans ces contrôles :
/// 1. la signature Ed25519 des octets EXACTS de `manifest.json`, avec une
///    clé embarquée dans l'application — échec = pack entier refusé ;
/// 2. un pack `placeholder` (vignettes de développement) refusé hors build
///    de développement (T25) ;
/// 3. pour chaque fichier : chemin autorisé, taille en octets, SHA-256,
///    100 Ko au plus, WebP aux dimensions annoncées — sinon le fichier est
///    rejeté et l'emoji s'affiche par son fallback.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

import '../domain/pokoumoji.dart';

const pokoumojiMaxFileBytes = 100 * 1024;

/// Les clés publiques de signature des packs (Ed25519, 32 octets bruts).
abstract final class PokoumojiKeys {
  /// Clé de PRODUCTION. La clé privée est gardée hors du dépôt.
  static const production = 'UnwXY/9bfCKroBxQmRTmobXdomO8YWTU8hKrb24L+Fg=';

  /// Clé de DÉVELOPPEMENT fournie avec le pack de vignettes provisoires
  /// (`pokoumoji-dev-2026-11`). Sa clé privée est publique : elle n'est
  /// acceptée qu'en build de développement.
  static const development = 'pcsz8rU8s+j1AZFynQVDlATe2jOKr9tgLAjtrimh47Y=';
}

class PokoumojiPackFile {
  const PokoumojiPackFile({
    required this.id,
    required this.size,
    required this.path,
    required this.sha256,
    required this.bytes,
  });

  final String id;
  final int size;
  final String path;
  final String sha256;
  final int bytes;
}

class PokoumojiManifest {
  const PokoumojiManifest({
    required this.packId,
    required this.packVersion,
    required this.status,
    required this.files,
  });

  final String packId;
  final String packVersion;
  final String status;

  /// Par chemin (`128/assets/kimia/kimia_joie.webp`) : seulement les
  /// entrées dont le chemin est autorisé.
  final Map<String, PokoumojiPackFile> files;

  bool get isPlaceholder => status == 'placeholder';
}

sealed class ManifestCheck {
  const ManifestCheck();
}

class ManifestAccepted extends ManifestCheck {
  const ManifestAccepted(this.manifest, {this.rejectedPaths = const []});
  final PokoumojiManifest manifest;

  /// Lignes du manifeste écartées (chemin refusé) : le reste du pack sert.
  final List<String> rejectedPaths;
}

class ManifestRefused extends ManifestCheck {
  const ManifestRefused(this.reason);
  final String reason;
}

abstract final class PokoumojiPackVerifier {
  /// Vérifie la signature puis lit le manifeste.
  ///
  /// [publicKeys] : clés acceptées (base64 de 32 octets). [allowPlaceholder]
  /// n'est vrai qu'en build de développement.
  static Future<ManifestCheck> checkManifest({
    required Uint8List manifestBytes,
    required String signatureBase64,
    required List<String> publicKeys,
    required bool allowPlaceholder,
  }) async {
    final Uint8List signature;
    try {
      signature = base64.decode(signatureBase64.trim());
    } on FormatException {
      return const ManifestRefused('signature du manifeste illisible');
    }
    var signed = false;
    for (final key in publicKeys) {
      try {
        signed = await Ed25519().verify(
          manifestBytes,
          signature: Signature(
            signature,
            publicKey: SimplePublicKey(
              base64.decode(key),
              type: KeyPairType.ed25519,
            ),
          ),
        );
      } catch (_) {
        signed = false;
      }
      if (signed) break;
    }
    if (!signed) {
      return const ManifestRefused(
        'signature du manifeste invalide : pack refusé',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(manifestBytes));
    } on FormatException {
      return const ManifestRefused('manifeste illisible');
    }
    if (decoded is! Map<String, dynamic>) {
      return const ManifestRefused('manifeste illisible');
    }
    final status = '${decoded['status'] ?? ''}';
    if (status == 'placeholder' && !allowPlaceholder) {
      return const ManifestRefused(
        'pack de développement (placeholder) refusé hors build de '
        'développement',
      );
    }
    final files = <String, PokoumojiPackFile>{};
    final rejected = <String>[];
    for (final raw in (decoded['files'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final path = raw['path'];
      final size = raw['size'];
      if (path is! String ||
          size is! int ||
          !packPathRe.hasMatch(path) ||
          !path.startsWith('$size/')) {
        rejected.add('$path');
        continue;
      }
      final bytes = raw['bytes'];
      final sha = raw['sha256'];
      if (bytes is! int || sha is! String || bytes > pokoumojiMaxFileBytes) {
        rejected.add(path);
        continue;
      }
      files[path] = PokoumojiPackFile(
        id: '${raw['id']}',
        size: size,
        path: path,
        sha256: sha.toLowerCase(),
        bytes: bytes,
      );
    }
    return ManifestAccepted(
      PokoumojiManifest(
        packId: '${decoded['pack_id'] ?? ''}',
        packVersion: '${decoded['pack_version'] ?? ''}',
        status: status,
        files: files,
      ),
      rejectedPaths: rejected,
    );
  }

  /// Un fichier du pack : octets, empreinte, format et dimensions. `null`
  /// si tout est bon, sinon la raison du refus.
  static String? checkFile(PokoumojiPackFile file, Uint8List data) {
    if (data.length != file.bytes || data.length > pokoumojiMaxFileBytes) {
      return '${file.path}: taille incorrecte';
    }
    if (hash.sha256.convert(data).toString() != file.sha256) {
      return '${file.path}: empreinte SHA-256 incorrecte';
    }
    final dim = webpSize(data);
    if (dim == null || dim.$1 != file.size || dim.$2 != file.size) {
      return '${file.path}: format ou dimensions refusés';
    }
    return null;
  }

  /// Dimensions d'un WebP (VP8, VP8L ou VP8X), ou `null`.
  static (int, int)? webpSize(Uint8List b) {
    if (b.length < 30) return null;
    String ascii(int from, int to) => String.fromCharCodes(b.sublist(from, to));
    if (ascii(0, 4) != 'RIFF' || ascii(8, 12) != 'WEBP') return null;
    final d = ByteData.sublistView(b);
    int u24(int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);
    switch (ascii(12, 16)) {
      case 'VP8X':
        return (1 + u24(24), 1 + u24(27));
      case 'VP8L':
        final bits = d.getUint32(21, Endian.little);
        return (1 + (bits & 0x3fff), 1 + ((bits >> 14) & 0x3fff));
      case 'VP8 ':
        return (
          d.getUint16(26, Endian.little) & 0x3fff,
          d.getUint16(28, Endian.little) & 0x3fff,
        );
    }
    return null;
  }
}
