import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'e2ee_primitives.dart';
import 'e2ee_session.dart';

/// Où vivent les clés privées — et pourquoi précisément là.
///
/// `flutter_secure_storage` s'appuie sur le Keychain (iOS) et le Keystore
/// matériel (Android). C'est la différence entre « le serveur ne peut pas
/// lire » et « personne ne peut lire » : une clé rangée dans la base sqflite
/// de l'application partirait dans une sauvegarde cloud, et l'historique
/// chiffré avec.
///
/// Rien de ce qui est ici ne doit JAMAIS être envoyé au serveur, journalisé,
/// ni inclus dans un rapport d'erreur. C'est la seule règle du fichier, et
/// elle n'a pas de garde-fou technique — d'où ce paragraphe.
class E2EEStore {
  E2EEStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _identityKey = 'e2ee_identity_v1';
  static const _deviceIdKey = 'e2ee_device_id_v1';
  static const _prekeyCounterKey = 'e2ee_prekey_counter_v1';
  static String _sessionsKey(int peerUserId) => 'e2ee_sessions_$peerUserId';
  static String _oneTimeKey(int keyId) => 'e2ee_otp_$keyId';

  // ── Identité ────────────────────────────────────────────────────────────

  /// Charge l'identité de l'appareil, ou la crée au premier appel.
  ///
  /// Générée UNE FOIS et conservée : la régénérer à chaque démarrage
  /// invaliderait toutes les sessions en cours, et le correspondant verrait
  /// un avertissement de changement de clé à chaque fois — ce qui finit par
  /// apprendre aux gens à ignorer cet avertissement, exactement le contraire
  /// du but.
  Future<E2EEIdentity> loadOrCreateIdentity() async {
    final stored = await _storage.read(key: _identityKey);
    if (stored != null) {
      return E2EEIdentity.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    }

    final identity = await E2EEPrimitives.generateExchangeKeyPair();
    final signing = await E2EEPrimitives.generateSigningKeyPair();
    final signedPrekey = await E2EEPrimitives.generateExchangeKeyPair();

    final created = E2EEIdentity(
      identityKeyPair: identity,
      signingKeyPair: signing,
      signedPrekeyPair: signedPrekey,
    );
    await _storage.write(key: _identityKey, value: jsonEncode(await created.toJson()));
    return created;
  }

  /// Identifiant d'installation — pas un identifiant d'appareil fourni par
  /// le système. Ceux-là survivent à une désinstallation sur certaines
  /// plateformes et se partagent entre applications : ce qu'on veut désigner
  /// ici, c'est CETTE installation, celle qui détient CES clés.
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null) return existing;
    final generated = base64Url.encode(E2EEPrimitives.randomBytes(16));
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  // ── Pré-clés à usage unique ─────────────────────────────────────────────

  /// Génère un lot de pré-clés et conserve leurs PRIVÉES.
  ///
  /// Le compteur ne repart jamais de zéro : réutiliser un numéro ferait
  /// répondre le serveur avec une pré-clé publique dont on aurait écrasé la
  /// privée — un message qu'on ne pourrait plus jamais ouvrir, sans erreur
  /// visible nulle part.
  Future<List<({int keyId, List<int> publicKey})>> generateOneTimePrekeys(int count) async {
    final start = int.tryParse(await _storage.read(key: _prekeyCounterKey) ?? '0') ?? 0;
    final generated = <({int keyId, List<int> publicKey})>[];

    for (var i = 0; i < count; i++) {
      final keyId = start + i;
      final pair = await E2EEPrimitives.generateExchangeKeyPair();
      await _storage.write(key: _oneTimeKey(keyId), value: await _encodeKeyPair(pair));
      generated.add((keyId: keyId, publicKey: (await pair.extractPublicKey()).bytes));
    }

    await _storage.write(key: _prekeyCounterKey, value: '${start + count}');
    return generated;
  }

  /// Récupère la privée d'une pré-clé citée par un message entrant, et
  /// l'EFFACE — elle est à usage unique des deux côtés, pas seulement sur le
  /// serveur.
  Future<SimpleKeyPair?> takeOneTimePrekey(int keyId) async {
    final stored = await _storage.read(key: _oneTimeKey(keyId));
    if (stored == null) return null;
    await _storage.delete(key: _oneTimeKey(keyId));
    return _decodeKeyPair(stored);
  }

  // ── Sessions ────────────────────────────────────────────────────────────

  /// Toutes les sessions avec quelqu'un.
  ///
  /// Plusieurs, et pas une : quand deux personnes s'écrivent en même temps
  /// sans session préalable, chacune ouvre la sienne. Les deux restent
  /// valides — celle qu'on utilise pour écrire, et celle par laquelle on
  /// reçoit. N'en garder qu'une rendrait la moitié des messages illisibles.
  Future<Map<String, E2EESession>> sessionsWith(int peerUserId) async {
    final stored = await _storage.read(key: _sessionsKey(peerUserId));
    if (stored == null) return {};
    final decoded = jsonDecode(stored) as Map<String, dynamic>;
    return decoded.map(
      (sid, json) => MapEntry(sid, E2EESession.fromJson(json as Map<String, dynamic>)),
    );
  }

  Future<void> saveSession(int peerUserId, E2EESession session) async {
    final sessions = await sessionsWith(peerUserId);
    sessions[session.sessionId] = session;
    await _storage.write(
      key: _sessionsKey(peerUserId),
      value: jsonEncode(sessions.map((sid, s) => MapEntry(sid, s.toJson()))),
    );
  }

  /// Oublie les sessions ouvertes avec UNE personne.
  ///
  /// Sert quand l'utilisateur accepte la nouvelle identité d'un
  /// correspondant : la session qui portait l'ancienne clé n'a plus de sens,
  /// et la prochaine poignée de main repart du trousseau publié.
  ///
  /// Ne touche ni à l'identité locale, ni aux pré-clés : ce n'est pas une
  /// déconnexion, c'est un correspondant qui a changé de téléphone.
  Future<void> forgetSessions(int peerUserId) =>
      _storage.delete(key: _sessionsKey(peerUserId));

  /// Efface tout — déconnexion, ou suppression de compte.
  ///
  /// Sans ça, les clés d'un compte survivraient à sa déconnexion sur un
  /// téléphone partagé, ce qui est exactement le scénario que le chiffrement
  /// est censé couvrir.
  Future<void> wipe(List<int> knownPeerIds) async {
    await _storage.delete(key: _identityKey);
    await _storage.delete(key: _deviceIdKey);
    await _storage.delete(key: _prekeyCounterKey);
    for (final peerId in knownPeerIds) {
      await _storage.delete(key: _sessionsKey(peerId));
    }
  }

  static Future<String> _encodeKeyPair(SimpleKeyPair pair) async {
    return jsonEncode({
      'priv': base64.encode(await pair.extractPrivateKeyBytes()),
      'pub': base64.encode((await pair.extractPublicKey()).bytes),
    });
  }

  static SimpleKeyPair _decodeKeyPair(String encoded, {bool signing = false}) {
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    return SimpleKeyPairData(
      base64.decode(json['priv'] as String),
      publicKey: SimplePublicKey(
        base64.decode(json['pub'] as String),
        type: signing ? KeyPairType.ed25519 : KeyPairType.x25519,
      ),
      type: signing ? KeyPairType.ed25519 : KeyPairType.x25519,
    );
  }
}

/// Les clés longue durée de cet appareil.
class E2EEIdentity {
  const E2EEIdentity({
    required this.identityKeyPair,
    required this.signingKeyPair,
    required this.signedPrekeyPair,
  });

  final SimpleKeyPair identityKeyPair;
  final SimpleKeyPair signingKeyPair;
  final SimpleKeyPair signedPrekeyPair;

  Future<Map<String, dynamic>> toJson() async => {
        'ik': jsonDecode(await E2EEStore._encodeKeyPair(identityKeyPair)),
        'sk': jsonDecode(await E2EEStore._encodeKeyPair(signingKeyPair)),
        'spk': jsonDecode(await E2EEStore._encodeKeyPair(signedPrekeyPair)),
      };

  factory E2EEIdentity.fromJson(Map<String, dynamic> json) => E2EEIdentity(
        identityKeyPair: E2EEStore._decodeKeyPair(jsonEncode(json['ik'])),
        signingKeyPair: E2EEStore._decodeKeyPair(jsonEncode(json['sk']), signing: true),
        signedPrekeyPair: E2EEStore._decodeKeyPair(jsonEncode(json['spk'])),
      );

  /// Le trousseau PUBLIC à publier — et rien d'autre. La signature lie la
  /// pré-clé à l'identité : sans elle, l'annuaire pourrait substituer la
  /// sienne.
  Future<Map<String, dynamic>> publicBundle({required String deviceId}) async {
    final signedPrekeyPublic = (await signedPrekeyPair.extractPublicKey()).bytes;
    return {
      'device_id': deviceId,
      'identity_key': base64.encode((await identityKeyPair.extractPublicKey()).bytes),
      'signing_key': base64.encode((await signingKeyPair.extractPublicKey()).bytes),
      'signed_prekey': base64.encode(signedPrekeyPublic),
      'signed_prekey_signature':
          base64.encode(await E2EEPrimitives.sign(signedPrekeyPublic, signingKeyPair)),
    };
  }
}
