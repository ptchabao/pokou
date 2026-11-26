import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/e2ee_outcome.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/core/crypto/e2ee_store.dart';

// Ajouter quelqu'un à un appel (26 novembre 2026) : la clé d'appel scellée
// pour lui pouvait être le PREMIER message d'une session. S'il ne
// décrochait pas, ce message n'arrivait jamais, et tous les suivants
// devenaient illisibles chez lui. D'où la règle « il faut déjà avoir reçu un
// message de lui », qui bloquait l'ajout de presque tout le monde.
//
// Désormais, tant qu'il n'a pas répondu, chacun de nos messages porte le
// préambule de la session : le premier peut se perdre sans conséquence.

class _Memory extends FlutterSecureStorage {
  _Memory();
  final Map<String, String> values = {};
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

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.remove(key);
}

/// Un annuaire de clés en mémoire, comme /e2ee/bundle du serveur.
class _Directory {
  final Map<int, Map<String, dynamic>> bundles = {};
}

class _Api extends ApiClient {
  _Api(this.me, this.directory) : super(baseUrl: 'https://inutilise');
  final int me;
  final _Directory directory;

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) async {
    if (path == '/e2ee/prekeys/count') return {'published': false};
    final id = int.parse(path.split('/').last);
    final stored = directory.bundles[id]!;
    final prekeys = (stored['one_time_prekeys'] as List)
        .cast<Map<String, dynamic>>();
    return {
      ...stored,
      'one_time_prekey': prekeys.isEmpty ? null : prekeys.removeAt(0),
    };
  }

  @override
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    directory.bundles[me] = {
      ...body!,
      'one_time_prekeys': List.of(body['one_time_prekeys'] as List),
    };
    return {'ok': true};
  }
}

void main() {
  test('le premier message perdu ne rend pas la session illisible', () async {
    final directory = _Directory();
    final alice = E2EEService(
      apiClient: _Api(1, directory),
      store: E2EEStore(storage: _Memory()),
    );
    final bob = E2EEService(
      apiClient: _Api(2, directory),
      store: E2EEStore(storage: _Memory()),
    );
    await alice.publishKeys();
    await bob.publishKeys();

    // 1. La clé d'appel pour Bob : il ne décroche pas, il ne la lira jamais.
    final lost = await alice.seal(peerUserId: 2, plaintext: 'clé d\'appel');
    expect(lost, isA<SealEncrypted>());

    // 2. Le message suivant d'Alice porte encore le préambule…
    final next =
        await alice.seal(peerUserId: 2, plaintext: 'Tu es là ?')
            as SealEncrypted;
    expect(
      next.envelope['ik'],
      isNotNull,
      reason: 'préambule renvoyé tant que Bob n\'a pas répondu',
    );

    // … et Bob l'ouvre sans avoir jamais vu le premier.
    expect(
      await bob.open(
        peerUserId: 1,
        envelope: next.envelope,
        ciphertext: next.ciphertext,
      ),
      'Tu es là ?',
    );

    // 3. Bob répond sur la même session ; Alice la sait détenue : plus de préambule.
    final reply =
        await bob.seal(peerUserId: 1, plaintext: 'Oui !') as SealEncrypted;
    expect(
      await alice.open(
        peerUserId: 2,
        envelope: reply.envelope,
        ciphertext: reply.ciphertext,
      ),
      'Oui !',
    );
    final after =
        await alice.seal(peerUserId: 2, plaintext: 'Super') as SealEncrypted;
    expect(after.envelope['ik'], isNull);
    expect(
      await bob.open(
        peerUserId: 1,
        envelope: after.envelope,
        ciphertext: after.ciphertext,
      ),
      'Super',
    );
  });

  test(
    'un préambule répété sur une session déjà connue est simplement ignoré',
    () async {
      final directory = _Directory();
      final alice = E2EEService(
        apiClient: _Api(1, directory),
        store: E2EEStore(storage: _Memory()),
      );
      final bob = E2EEService(
        apiClient: _Api(2, directory),
        store: E2EEStore(storage: _Memory()),
      );
      await alice.publishKeys();
      await bob.publishKeys();

      final first =
          await alice.seal(peerUserId: 2, plaintext: 'un') as SealEncrypted;
      final second =
          await alice.seal(peerUserId: 2, plaintext: 'deux') as SealEncrypted;
      expect(
        await bob.open(
          peerUserId: 1,
          envelope: first.envelope,
          ciphertext: first.ciphertext,
        ),
        'un',
      );
      expect(
        await bob.open(
          peerUserId: 1,
          envelope: second.envelope,
          ciphertext: second.ciphertext,
        ),
        'deux',
      );
    },
  );
}
