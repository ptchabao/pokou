import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Les briques cryptographiques de Pokou, et RIEN d'autre.
///
/// Tout ce fichier délègue à `package:cryptography` (Apache-2.0), qui utilise
/// les implémentations natives de la plateforme quand elles existent. Aucune
/// primitive n'est réécrite ici : ce qui est écrit à la main, c'est
/// uniquement la façon de les ASSEMBLER, et c'est déjà bien assez pour se
/// tromper.
///
/// Pourquoi ne pas utiliser une bibliothèque du protocole Signal toute faite ?
/// Parce qu'elles sont toutes sous GPL-3.0 ou AGPL-3.0 en Dart
/// (`libsignal_protocol_dart`, `libsignal_dart`), ce qui obligerait à publier
/// le code source de Pokou entière. Le choix n'est donc pas « maison contre
/// éprouvé » mais « maison contre ouvrir tout le produit ».
///
/// Ce que cet assemblage donne, et ce qu'il ne donne pas — à lire avant de
/// promettre quoi que ce soit à un utilisateur :
///
/// - ✅ le serveur ne peut pas lire les messages ;
/// - ✅ **confidentialité persistante** : une clé de message est détruite
///   après usage, et la chaîne n'est pas réversible. Voler le téléphone
///   aujourd'hui ne donne pas les messages d'hier ;
/// - ✅ authentification mutuelle des identités, et détection d'un changement
///   de clé ;
/// - ❌ **pas de sécurité post-compromission.** Le vrai protocole Signal
///   ajoute un second cliquet, à échange Diffie-Hellman, qui permet à une
///   conversation de « se soigner » après un vol de clé. Ici, qui vole l'état
///   d'une session lit tout ce qui suit jusqu'à la prochaine session ;
/// - ❌ pas de déniabilité, pas de multi-appareil ;
/// - ❌ **pas d'audit externe.** Ce point n'est pas une limite technique,
///   c'est une limite de confiance, et c'est la plus importante.
class E2EEPrimitives {
  E2EEPrimitives._();

  static final _x25519 = X25519();
  static final _ed25519 = Ed25519();
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _hmac = Hmac.sha256();

  /// Taille d'un vecteur d'initialisation AES-GCM. 12 octets et pas 16 :
  /// c'est la taille pour laquelle GCM est spécifié, les autres passent par
  /// une dérivation supplémentaire qui réduit la marge avant collision.
  static const nonceLength = 12;

  // ── Génération de clés ──────────────────────────────────────────────────

  static Future<SimpleKeyPair> generateExchangeKeyPair() => _x25519.newKeyPair();

  static Future<SimpleKeyPair> generateSigningKeyPair() => _ed25519.newKeyPair();

  // ── Échange Diffie-Hellman ──────────────────────────────────────────────

  /// Secret partagé X25519. Renvoie les 32 octets bruts, destinés à être
  /// CONCATÉNÉS avec d'autres avant dérivation — jamais utilisés seuls comme
  /// clé : un secret Diffie-Hellman n'est pas uniformément distribué, c'est
  /// précisément le rôle de HKDF de corriger ça.
  static Future<List<int>> sharedSecret(SimpleKeyPair mine, List<int> theirPublic) async {
    final secret = await _x25519.sharedSecretKey(
      keyPair: mine,
      remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519),
    );
    return secret.extractBytes();
  }

  // ── Signatures ──────────────────────────────────────────────────────────

  static Future<List<int>> sign(List<int> message, SimpleKeyPair signingKey) async {
    final signature = await _ed25519.sign(message, keyPair: signingKey);
    return signature.bytes;
  }

  static Future<bool> verify(
    List<int> message,
    List<int> signature,
    List<int> signingPublicKey,
  ) {
    return _ed25519.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(signingPublicKey, type: KeyPairType.ed25519),
      ),
    );
  }

  // ── Dérivation ──────────────────────────────────────────────────────────

  /// HKDF-SHA256. `info` est une ÉTIQUETTE DE DOMAINE : deux dérivations du
  /// même secret avec des étiquettes différentes donnent des clés
  /// indépendantes. C'est ce qui permet d'avoir deux chaînes (aller et
  /// retour) issues d'un seul secret sans qu'elles se croisent.
  static Future<List<int>> derive(
    List<int> inputKeyMaterial, {
    required String info,
    List<int> salt = const [],
  }) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(inputKeyMaterial),
      nonce: salt,
      info: utf8.encode(info),
    );
    return key.extractBytes();
  }

  /// Un cran de cliquet symétrique : la clé de message, et la chaîne
  /// suivante.
  ///
  /// Les deux constantes distinctes (0x01 et 0x02) sont ce qui rend la clé de
  /// message et la chaîne suivante indépendantes l'une de l'autre. Sans cette
  /// séparation, connaître une clé de message donnerait la chaîne, donc tous
  /// les messages suivants.
  ///
  /// HMAC n'est pas inversible : effacer une chaîne après usage rend les
  /// messages passés irrécupérables. C'est la confidentialité persistante, et
  /// elle tient à ce seul fait.
  static Future<({List<int> messageKey, List<int> nextChainKey})> ratchet(
    List<int> chainKey,
  ) async {
    final messageKey = await _hmac.calculateMac(
      const [0x01],
      secretKey: SecretKey(chainKey),
    );
    final nextChainKey = await _hmac.calculateMac(
      const [0x02],
      secretKey: SecretKey(chainKey),
    );
    return (messageKey: messageKey.bytes, nextChainKey: nextChainKey.bytes);
  }

  // ── Chiffrement authentifié ─────────────────────────────────────────────

  /// AES-256-GCM. `aad` (données authentifiées additionnelles) transporte
  /// l'en-tête du message : il voyage en CLAIR mais ne peut pas être modifié
  /// sans faire échouer le déchiffrement. C'est ce qui empêche un serveur de
  /// rejouer un message en changeant son numéro dans la chaîne.
  static Future<({List<int> ciphertext, List<int> mac})> encrypt(
    List<int> plaintext, {
    required List<int> key,
    required List<int> nonce,
    required List<int> aad,
  }) async {
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    return (ciphertext: box.cipherText, mac: box.mac.bytes);
  }

  /// Lève `SecretBoxAuthenticationError` si le message a été altéré — d'où
  /// l'absence de valeur de retour « échec » : un déchiffrement qui échoue
  /// n'est pas un cas normal à ignorer, c'est un message qu'il ne faut PAS
  /// afficher.
  static Future<List<int>> decrypt(
    List<int> ciphertext, {
    required List<int> mac,
    required List<int> key,
    required List<int> nonce,
    required List<int> aad,
  }) {
    return _aes.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
      aad: aad,
    );
  }

  /// `Random.secure()` et non `Random()` : le second est un générateur
  /// pseudo-aléatoire prévisible, parfait pour mélanger une liste et
  /// catastrophique pour un vecteur d'initialisation. La distinction ne
  /// produit aucune différence visible — c'est bien le problème.
  static final _random = Random.secure();

  static Uint8List randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }
}
