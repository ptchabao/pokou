import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/core/crypto/e2ee_store.dart';
import 'package:pokou/features/messaging/presentation/encryption_banner.dart';

/// Le changement de clé d'identité : le seul évènement par lequel une
/// interposition devienne visible.
///
/// `identityChanged()` existait depuis le début du chiffrement et n'était
/// appelé de NULLE PART. Une clé qui change — réinstallation légitime, ou
/// quelqu'un qui s'insère — passait donc entièrement inaperçue. Ces tests
/// vérifient le branchement, pas seulement la fonction.

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

class _Api extends ApiClient {
  _Api(this.onGet) : super(baseUrl: 'https://inutilise');

  final Future<dynamic> Function(String path) onGet;

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) => onGet(path);
}

/// Une session enregistrée avec une clé d'identité connue.
///
/// Écrite directement dans le magasin, au format que `E2EESession.fromJson`
/// relit : monter une vraie poignée de main demanderait deux appareils, et
/// ce qu'on teste ici est la COMPARAISON, pas le protocole.
const _knownKey = 'AAECAwQFBgcICQoLDA0ODw==';

Map<String, String> _storageWithSession(int peerId, String identityKey) {
  final session = {
    'sid': 'session-1',
    'pik': identityKey,
    'sc': base64.encode(List.filled(32, 2)),
    'rc': base64.encode(List.filled(32, 3)),
    'sn': 0,
    'rn': 0,
  };
  return {'e2ee_sessions_$peerId': jsonEncode({'session-1': session})};
}

void main() {
  E2EEService serviceFor(
    Map<String, String> storage,
    Future<dynamic> Function(String) onGet,
  ) =>
      E2EEService(
        apiClient: _Api(onGet),
        store: E2EEStore(storage: _MemoryStorage(storage)),
      );

  group('checkPeerIdentity', () {
    test('sans session, il n\'y a rien à comparer', () async {
      final service = serviceFor({}, (_) async => {'identity_key': _knownKey});

      expect(
        await service.checkPeerIdentity(peerUserId: 7),
        PeerIdentity.noSessionYet,
      );
    });

    test('même clé qu\'en session → inchangée', () async {
      final service = serviceFor(
        _storageWithSession(7, _knownKey),
        (_) async => {'identity_key': _knownKey},
      );

      expect(
        await service.checkPeerIdentity(peerUserId: 7),
        PeerIdentity.unchanged,
      );
    });

    test('clé différente → CHANGÉE', () async {
      // Le cœur du sujet. C'est ce que WhatsApp et Signal annoncent par
      // « les informations de sécurité ont changé », et que Pokou taisait.
      final service = serviceFor(
        _storageWithSession(7, _knownKey),
        (_) async => {'identity_key': base64.encode(List.filled(16, 9))},
      );

      expect(
        await service.checkPeerIdentity(peerUserId: 7),
        PeerIdentity.changed,
      );
    });

    test('contrôle impossible → on n\'affirme RIEN', () async {
      // Ni « tout va bien » ni « alerte » : un réseau coupé ne prouve rien
      // dans un sens ni dans l'autre. Répondre « inchangée » serait une
      // affirmation qu'un attaquant voudrait nous voir faire à sa place.
      final service = serviceFor(
        _storageWithSession(7, _knownKey),
        (_) => Future<dynamic>.error(NetworkException('hors ligne')),
      );

      expect(
        await service.checkPeerIdentity(peerUserId: 7),
        PeerIdentity.unknown,
      );
    });

    test('réponse sans clé d\'identité → on n\'affirme rien', () async {
      final service = serviceFor(
        _storageWithSession(7, _knownKey),
        (_) async => <String, dynamic>{},
      );

      expect(
        await service.checkPeerIdentity(peerUserId: 7),
        PeerIdentity.unknown,
      );
    });
  });

  group('accepter la nouvelle identité', () {
    test('efface la session, et l\'alerte retombe', () async {
      final storage = _storageWithSession(7, _knownKey);
      final service = serviceFor(
        storage,
        (_) async => {'identity_key': base64.encode(List.filled(16, 9))},
      );
      expect(await service.checkPeerIdentity(peerUserId: 7), PeerIdentity.changed);

      await service.acceptPeerIdentity(peerUserId: 7);

      expect(storage.containsKey('e2ee_sessions_7'), isFalse,
          reason: 'la session qui portait l\'ancienne clé est oubliée');
      expect(await service.checkPeerIdentity(peerUserId: 7),
          PeerIdentity.noSessionYet);
    });

    test('n\'efface QUE ce correspondant', () async {
      final storage = {
        ..._storageWithSession(7, _knownKey),
        ..._storageWithSession(8, _knownKey),
        'e2ee_identity_v1': '{}',
      };
      final service = serviceFor(storage, (_) async => <String, dynamic>{});

      await service.acceptPeerIdentity(peerUserId: 7);

      expect(storage.containsKey('e2ee_sessions_8'), isTrue);
      expect(storage.containsKey('e2ee_identity_v1'), isTrue,
          reason: 'ce n\'est pas une déconnexion');
    });
  });

  group('ce que l\'écran en conclut', () {
    test('une identité changée devient une alerte visible', () {
      expect(
        encryptionFromIdentity(PeerIdentity.changed),
        ConversationEncryption.identityChanged,
      );
    });

    test('un contrôle raté n\'affiche PAS « chiffré »', () {
      // Le piège exact : par commodité, `unknown` aurait pu retomber sur
      // « chiffré ». L'écran affirmerait alors une garantie qu'il n'a pas
      // vérifiée.
      expect(
        encryptionFromIdentity(PeerIdentity.unknown),
        ConversationEncryption.unknown,
      );
    });

    test('une première conversation s\'affiche comme chiffrée', () {
      expect(
        encryptionFromIdentity(PeerIdentity.noSessionYet),
        ConversationEncryption.encrypted,
      );
    });
  });
}
