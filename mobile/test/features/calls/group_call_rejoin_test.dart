import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/call_keys.dart';
import 'package:pokou/core/crypto/e2ee_outcome.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/features/calls/data/call_repository.dart';

// Quitter un appel de groupe puis y revenir.
//
// En production (11 novembre 2026) : après avoir quitté l'appel du groupe,
// plus personne ne pouvait y revenir. L'enveloppe de la clé ne s'ouvre
// qu'une fois, la session oubliait la clé en raccrochant, et chaque retour
// échouait sur « clé d'appel impossible à ouvrir ».

class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => values[key];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    values.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      values.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(values);
}

class _Api extends ApiClient {
  _Api({this.asCaller = false}) : super(baseUrl: 'https://unused');

  /// Vrai : je suis l'appelant — le serveur ne me rend aucune enveloppe.
  final bool asCaller;

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) async {
    if (path.startsWith('/calls/active')) return {'active': false};
    if (path.startsWith('/groups/')) {
      return {
        'members': [
          {'user_id': 1},
          {'user_id': 2},
          {'user_id': 3},
        ],
      };
    }
    throw StateError('unexpected GET $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (path != '/calls/token') throw StateError('unexpected POST $path');
    final joining = body?.containsKey('room') ?? false;
    return {
      'room': 'group-room',
      'token': 'jwt',
      'livekit_url': 'wss://livekit.invalid',
      'participant_ids': [2, 3],
      'joined_existing': joining,
      'e2ee': true,
      if (joining && !asCaller)
        'sealed_key': {
          'encryption': 'v1',
          'ciphertext': 'opaque',
          'envelope': {'sid': 'session'},
          'from_user_id': 2,
        },
    };
  }
}

/// Comme le vrai cliquet : une enveloppe ne s'ouvre qu'UNE fois.
class _E2EE extends E2EEService {
  _E2EE({this.openedPlaintext})
    : super(apiClient: ApiClient(baseUrl: 'https://unused'));

  final String? openedPlaintext;
  int opened = 0;

  @override
  Future<PeerCrypto> peerCrypto(int peerUserId, {bool fresh = false}) async =>
      PeerCrypto(
        capabilities: {E2EEService.callCapability},
        identityKey: 'identity-$peerUserId',
      );

  @override
  Future<PeerSessionState> sessionState(
    int peerUserId, {
    required String? publishedIdentityKey,
  }) async => PeerSessionState.established;

  @override
  Future<SealOutcome> seal({
    required int peerUserId,
    required String plaintext,
  }) async => const SealEncrypted(
    encryption: 'v1',
    ciphertext: 'opaque',
    envelope: {'sid': 'session'},
  );

  @override
  Future<String> open({
    required int peerUserId,
    required Map<String, dynamic> envelope,
    required String ciphertext,
  }) async {
    if (opened++ > 0) throw StateError('message déjà reçu');
    return openedPlaintext!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _InMemorySecureStorage storage;

  setUp(() {
    storage = _InMemorySecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    CallKeys.forget('group-room');
  });

  test('a member who left a group call can come back', () async {
    final key = CallKey.generate();
    final e2ee = _E2EE(openedPlaintext: key.seal(from: 2, to: 1));
    final calls = CallRepository(
      apiClient: _Api(),
      e2ee: e2ee,
      vault: CallKeyVault(),
      myUserId: () => 1,
    );

    await calls.joinCall('group-room', inviter: 2);
    expect(CallKeys.of('group-room')?.bytes, key.bytes);

    // Raccrocher : la session oublie la clé (CallSession._end).
    CallKeys.forget('group-room');

    await calls.joinCall('group-room');
    expect(CallKeys.of('group-room')?.bytes, key.bytes);
    expect(e2ee.opened, 1, reason: 'l\'enveloppe ne se rouvre pas');
  });

  test('coming back still works after the app was restarted', () async {
    final key = CallKey.generate();
    await CallRepository(
      apiClient: _Api(),
      e2ee: _E2EE(openedPlaintext: key.seal(from: 2, to: 1)),
      vault: CallKeyVault(),
      myUserId: () => 1,
    ).joinCall('group-room', inviter: 2);
    CallKeys.forget('group-room');

    // Un autre dépôt, un autre coffre, le même stockage : l'app relancée.
    final afterRestart = CallRepository(
      apiClient: _Api(),
      e2ee: _E2EE(), // ouvrir lèverait : rien à ouvrir
      vault: CallKeyVault(),
      myUserId: () => 1,
    );
    await afterRestart.joinCall('group-room');
    expect(CallKeys.of('group-room')?.bytes, key.bytes);
  });

  test('the caller can come back to their own group call', () async {
    final calls = CallRepository(
      apiClient: _Api(asCaller: true),
      e2ee: _E2EE(),
      vault: CallKeyVault(),
      myUserId: () => 1,
    );

    final started = await calls.startGroupCall(9, memberUserIds: [2, 3]);
    final key = CallKeys.of(started.room)!;
    CallKeys.forget(started.room);

    // Aucune enveloppe n'est destinée à l'appelant : sans le coffre, il
    // restait dehors (« aucune clé pour cet appel »).
    await calls.joinCall(started.room);
    expect(CallKeys.of(started.room)?.bytes, key.bytes);
  });

  test(
    'a kept key expires with the call, and expired keys are erased',
    () async {
      var now = DateTime(2026, 11, 11, 16);
      final vault = CallKeyVault(now: () => now);
      final key = CallKey.generate();

      await vault.keep('group-room', key);
      expect((await vault.restore('group-room'))?.bytes, key.bytes);

      now = now.add(CallKeyVault.lifetime + const Duration(minutes: 1));
      expect(await vault.restore('group-room'), isNull);
      expect(storage.values, isEmpty, reason: 'rien ne reste sur le téléphone');
    },
  );

  test('a one-to-one call key is never kept on the phone', () async {
    final key = CallKey.generate();
    final calls = CallRepository(
      apiClient: _OneToOneApi(),
      e2ee: _E2EE(openedPlaintext: key.seal(from: 2, to: 1)),
      vault: CallKeyVault(),
      myUserId: () => 1,
    );

    await calls.joinCall('direct-room', inviter: 2);
    expect(CallKeys.of('direct-room')?.bytes, key.bytes);
    expect(storage.values, isEmpty);
    CallKeys.forget('direct-room');
  });
}

class _OneToOneApi extends ApiClient {
  _OneToOneApi() : super(baseUrl: 'https://unused');

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async => {
    'room': 'direct-room',
    'token': 'jwt',
    'livekit_url': 'wss://livekit.invalid',
    'participant_ids': [2],
    'joined_existing': true,
    'e2ee': true,
    'sealed_key': {
      'encryption': 'v1',
      'ciphertext': 'opaque',
      'envelope': {'sid': 'session'},
      'from_user_id': 2,
    },
  };
}
