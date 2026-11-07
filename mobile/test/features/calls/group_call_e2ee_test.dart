import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/call_keys.dart';
import 'package:pokou/core/crypto/e2ee_outcome.dart';
import 'package:pokou/core/crypto/e2ee_service.dart';
import 'package:pokou/features/calls/data/call_repository.dart';

class _Api extends ApiClient {
  _Api({this.active = false}) : super(baseUrl: 'https://unused');

  final bool active;
  final List<({String path, Map<String, dynamic> body})> posts = [];

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) async {
    if (path.startsWith('/calls/active')) {
      return active
          ? {
              'active': true,
              'room': 'active-room',
              'is_video': true,
              'caller_id': 2,
              'participant_ids': [2],
            }
          : {'active': false};
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
    final request = Map<String, dynamic>.from(body ?? const {});
    posts.add((path: path, body: request));
    if (path == '/calls/invite')
      return {
        'participant_ids': [2, 3],
      };
    if (path == '/calls/token' && request.containsKey('room')) {
      return {
        'room': request['room'],
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
    if (path == '/calls/token') {
      return {
        'room': 'new-room',
        'token': 'jwt',
        'livekit_url': 'wss://livekit.invalid',
        'participant_ids': [2, 3],
        'joined_existing': false,
        'e2ee': true,
      };
    }
    throw StateError('unexpected POST $path');
  }
}

class _E2EE extends E2EEService {
  _E2EE({this.unavailable = const {}, this.openedPlaintext})
    : super(apiClient: ApiClient(baseUrl: 'https://unused'));

  final Set<int> unavailable;
  final String? openedPlaintext;
  final List<({int peerId, String plaintext})> sealed = [];

  @override
  Future<PeerCrypto> peerCrypto(int peerUserId, {bool fresh = false}) async =>
      PeerCrypto(
        capabilities: unavailable.contains(peerUserId)
            ? const {}
            : {E2EEService.callCapability},
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
  }) async {
    sealed.add((peerId: peerUserId, plaintext: plaintext));
    return const SealEncrypted(
      encryption: 'v1',
      ciphertext: 'opaque',
      envelope: {'sid': 'session'},
    );
  }

  @override
  Future<String> open({
    required int peerUserId,
    required Map<String, dynamic> envelope,
    required String ciphertext,
  }) async => openedPlaintext!;
}

void main() {
  setUp(() {
    CallKeys.forget('new-room');
    CallKeys.forget('active-room');
    CallKeys.forget('incoming-room');
  });

  test(
    'group start seals one room key for every member before requesting a token',
    () async {
      final api = _Api();
      final e2ee = _E2EE();
      final calls = CallRepository(
        apiClient: api,
        e2ee: e2ee,
        myUserId: () => 1,
      );

      final token = await calls.startGroupCall(9, memberUserIds: [2, 3]);

      expect(token.e2ee, isTrue);
      expect(api.posts.single.body['sealed_keys'], hasLength(2));
      final first = CallKey.tryParse(e2ee.sealed[0].plaintext, from: 1, to: 2)!;
      final second = CallKey.tryParse(
        e2ee.sealed[1].plaintext,
        from: 1,
        to: 3,
      )!;
      expect(first.bytes, second.bytes);
      expect(CallKeys.of(token.room)?.bytes, first.bytes);
    },
  );

  test(
    'a member who cannot receive the key is skipped, the others are called',
    () async {
      final api = _Api();
      final calls = CallRepository(
        apiClient: api,
        e2ee: _E2EE(unavailable: {3}),
        myUserId: () => 1,
      );

      await calls.startGroupCall(9, memberUserIds: [1, 2, 3]);

      final sealed =
          api.posts.single.body['sealed_keys'] as Map<String, dynamic>;
      // Ni moi-même, ni le membre sans clé : seulement celui qui la reçoit.
      expect(sealed.keys, ['2']);
    },
  );

  test(
    'group start fails before the API when NO member can receive the key',
    () async {
      final api = _Api();
      final calls = CallRepository(
        apiClient: api,
        e2ee: _E2EE(unavailable: {2, 3}),
        myUserId: () => 1,
      );

      await expectLater(
        calls.startGroupCall(9, memberUserIds: [2, 3]),
        throwsA(isA<CallEncryptionException>()),
      );
      expect(api.posts, isEmpty);
    },
  );

  test(
    'a direct invite join opens and remembers its per-invitee key',
    () async {
      final key = CallKey.generate();
      final api = _Api();
      final calls = CallRepository(
        apiClient: api,
        e2ee: _E2EE(openedPlaintext: key.seal(from: 2, to: 1)),
        myUserId: () => 1,
      );

      await calls.joinCall('incoming-room', inviter: 2);

      expect(CallKeys.of('incoming-room')?.bytes, key.bytes);
    },
  );

  test(
    'joining an active group call opens its stored key and dynamic invites reseal it',
    () async {
      final key = CallKey.generate();
      final api = _Api(active: true);
      final calls = CallRepository(
        apiClient: api,
        e2ee: _E2EE(openedPlaintext: key.seal(from: 2, to: 1)),
        myUserId: () => 1,
      );

      final joined = await calls.startGroupCall(9, memberUserIds: [2, 3]);
      expect(joined.joinedExisting, isTrue);
      expect(CallKeys.of('active-room')?.bytes, key.bytes);

      final ids = await calls.inviteToCall(room: 'active-room', userIds: [3]);
      expect(ids, [2, 3]);
      final invite = api.posts.last;
      expect(invite.path, '/calls/invite');
      expect(invite.body['sealed_keys'], contains('3'));
      final wrapped = (invite.body['sealed_keys'] as Map)['3'] as Map;
      expect(wrapped['ciphertext'], 'opaque');
    },
  );
}
