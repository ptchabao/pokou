import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/core/crypto/e2ee_outcome.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/core/crypto/e2ee_store.dart';

/// **Si Pokou ne peut pas garantir le chiffrement, Pokou n'envoie pas le
/// message.**
///
/// Toute la valeur du chiffrement de bout en bout tient à cette règle, et
/// elle n'était respectée nulle part : `catch (_)` renvoyait « envoie en
/// clair » pour n'importe quel échec de récupération de clé. Un serveur
/// n'avait qu'à cesser de servir les trousseaux — ou simplement tomber en
/// panne — pour que tout le trafic repasse en clair, sans un signe.
///
/// Chaque test ci-dessous est un scénario d'échec, et chacun doit se
/// terminer par un REFUS. Le seul cas qui laisse passer du clair est le 404,
/// qui est une réponse et non une panne.

/// Un magasin en mémoire : pas de Keystore dans un test unitaire, et on veut
/// contrôler exactement ce qu'il y a en session.
class _MemoryStorage extends FlutterSecureStorage {
  const _MemoryStorage(this.values);

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
  }) async =>
      values[key];

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

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

E2EEStore _memoryStore() => E2EEStore(storage: _MemoryStorage({}));

/// Un ApiClient dont on choisit l'échec — c'est tout l'objet de ces tests.
class _Api extends ApiClient {
  _Api(this.onGet) : super(baseUrl: 'https://inutilise');

  final Future<dynamic> Function(String path) onGet;

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) => onGet(path);
}

E2EEService _serviceThatFails(Object error) => E2EEService(
      apiClient: _Api((_) => Future<dynamic>.error(error)),
      store: _memoryStore(),
    );

void main() {
  group('un trousseau qu\'on ne peut pas récupérer arrête l\'envoi', () {
    test('500 → refus, jamais de clair', () async {
      final outcome = await _serviceThatFails(ApiException(500, 'boom'))
          .seal(peerUserId: 7, plaintext: 'secret');

      expect(outcome, isA<SealRefused>());
      expect((outcome as SealRefused).reason, SealFailure.keyLookupFailed);
    });

    test('403 → refus', () async {
      final outcome = await _serviceThatFails(ApiException(403, 'non'))
          .seal(peerUserId: 7, plaintext: 'secret');

      expect(outcome, isA<SealRefused>());
    });

    test('délai dépassé → refus', () async {
      final outcome = await _serviceThatFails(TimeoutException('trop long'))
          .seal(peerUserId: 7, plaintext: 'secret');

      expect(outcome, isA<SealRefused>());
      expect((outcome as SealRefused).reason, SealFailure.keyLookupFailed);
    });

    test('coupure réseau → refus', () async {
      final outcome = await _serviceThatFails(NetworkException('hors ligne'))
          .seal(peerUserId: 7, plaintext: 'secret');

      expect(outcome, isA<SealRefused>());
      expect((outcome as SealRefused).reason, SealFailure.keyLookupFailed);
    });

    test('404 → la SEULE issue qui autorise le clair', () async {
      // Une réponse du serveur, pas une panne : cette personne n'a jamais
      // publié de trousseau. Lui refuser le message couperait la messagerie
      // en deux — mais l'écran doit le dire (EncryptionBanner).
      final outcome = await _serviceThatFails(ApiException(404, 'inconnu'))
          .seal(peerUserId: 7, plaintext: 'secret');

      expect(outcome, isA<SealPeerHasNoKeys>());
    });
  });

  group('un trousseau illisible arrête l\'envoi', () {
    Future<SealOutcome> sealAgainst(dynamic body) => E2EEService(
          apiClient: _Api((_) async => body),
          store: _memoryStore(),
        ).seal(peerUserId: 7, plaintext: 'secret');

    test('champs manquants → refus', () async {
      final outcome = await sealAgainst(<String, dynamic>{'identity_key': 'AAAA'});

      expect(outcome, isA<SealRefused>());
      expect((outcome as SealRefused).reason, SealFailure.invalidBundle);
    });

    test('base64 invalide → refus', () async {
      final outcome = await sealAgainst(<String, dynamic>{
        'identity_key': '!!! pas du base64 !!!',
        'signing_key': 'AAAA',
        'signed_prekey': 'AAAA',
        'signed_prekey_signature': 'AAAA',
      });

      expect(outcome, isA<SealRefused>());
      expect((outcome as SealRefused).reason, SealFailure.invalidBundle);
    });

    test('réponse vide → refus', () async {
      final outcome = await sealAgainst(<String, dynamic>{});

      expect(outcome, isA<SealRefused>());
      expect((outcome as SealRefused).reason, SealFailure.invalidBundle);
    });

    test('clés syntaxiquement valides mais cryptographiquement fausses → refus',
        () async {
      // Lisible par `PeerBundle.fromJson`, mais la poignée de main échoue :
      // ce sont des octets quelconques, pas des points de courbe. C'est la
      // dernière barrière, et elle ne doit pas non plus laisser passer du
      // clair.
      final outcome = await sealAgainst(<String, dynamic>{
        'identity_key': 'AAAAAAAA',
        'signing_key': 'AAAAAAAA',
        'signed_prekey': 'AAAAAAAA',
        'signed_prekey_signature': 'AAAAAAAA',
      });

      expect(outcome, isA<SealRefused>());
      expect((outcome as SealRefused).reason, SealFailure.cryptoFailure);
    });
  });

  group('aucune issue ne ressemble à « envoie en clair »', () {
    test('un refus ne porte ni texte chiffré ni enveloppe', () async {
      // Le type l'interdit déjà — c'est tout l'intérêt d'avoir remplacé un
      // enregistrement de champs nullables par une classe scellée. Ce test
      // fige l'intention : aucune branche de refus ne doit un jour gagner un
      // champ que l'appelant pourrait envoyer.
      final outcome = await _serviceThatFails(ApiException(500, 'boom'))
          .seal(peerUserId: 7, plaintext: 'secret');

      expect(outcome, isNot(isA<SealEncrypted>()));
      expect(outcome, isNot(isA<SealPeerHasNoKeys>()));
    });
  });
}
