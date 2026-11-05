import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/crypto/e2ee_outcome.dart';
import 'package:pokou/core/crypto/media_cipher.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/core/sync/queued_mutation.dart';
import 'package:pokou/features/status/data/status_repository.dart';

class _MemoryStore extends PokouMessageStore {
  final Map<String, List<dynamic>> values = {};

  @override
  Future<List<dynamic>?> cachedConversations(String scope) async =>
      values[scope];

  @override
  Future<void> saveConversations(String scope, List<dynamic> items) async {
    values[scope] = items;
  }

  @override
  Future<void> updateCachedConversations(
    String scope,
    List<dynamic> Function(List<dynamic> items) transform,
  ) async {
    final current = values[scope];
    if (current != null) values[scope] = transform(current);
  }
}

class _Api extends ApiClient {
  _Api({this.feed}) : super(baseUrl: 'https://unused');

  final Map<String, dynamic>? feed;
  final List<Map<String, dynamic>> posts = [];

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) async {
    if (path == '/status/audience') {
      return {
        'recipient_ids': [2],
      };
    }
    if (path == '/status/feed') {
      return {
        'items': [feed!],
      };
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    posts.add({'path': path, ...?body});
    return {
      'id': 'mine',
      'user_id': 1,
      'content_type': body?['content_type'] ?? 'TEXT',
      'text_content': null,
      'media': null,
      'created_at': '2026-11-05T12:00:00',
      'expires_at': '2026-11-06T12:00:00',
      'viewed_by_me': false,
      'view_count': 0,
    };
  }
}

class _E2EE implements StatusCrypto {
  _E2EE(this.outcome);

  final SealOutcome outcome;
  int openCount = 0;
  int sealCount = 0;

  @override
  Future<SealOutcome> seal({
    required int peerUserId,
    required String plaintext,
  }) async {
    sealCount++;
    return outcome;
  }

  @override
  Future<String> open({
    required int peerUserId,
    required Map<String, dynamic> envelope,
    required String ciphertext,
  }) async {
    openCount++;
    return 'decrypted once';
  }

  @override
  Future<Set<String>> capabilitiesOf(int peerUserId) async => {'media-v1'};
}

StatusRepository _repository({
  required _Api api,
  required _E2EE e2ee,
  required _MemoryStore store,
}) => StatusRepository(
  apiClient: api,
  crypto: e2ee,
  store: store,
  mutations: MutationQueue(api: api),
);

void main() {
  test(
    'status payload never sends clear text and fails closed on missing keys',
    () async {
      final api = _Api();
      final e2ee = _E2EE(const SealPeerHasNoKeys());
      final repository = _repository(
        api: api,
        e2ee: e2ee,
        store: _MemoryStore(),
      );

      await expectLater(
        repository.createText('secret'),
        throwsA(isA<EncryptionUnavailableException>()),
      );
      expect(api.posts, isEmpty);
      expect(e2ee.sealCount, 1);
    },
  );

  test(
    'opened status is cached before feed reuse, avoiding ratchet replay',
    () async {
      final store = _MemoryStore();
      final api = _Api(
        feed: {
          'user_id': 2,
          'display_name': 'Bob',
          'statuses': [
            {
              'id': 'status-1',
              'user_id': 2,
              'content_type': 'TEXT',
              'text_content': null,
              'encrypted_content': {
                'encryption': 'v1',
                'ciphertext': 'opaque',
                'envelope': {'sid': 'ratchet-session'},
              },
              'media': null,
              'created_at': '2026-11-05T12:00:00',
              'expires_at': '2026-11-06T12:00:00',
              'viewed_by_me': false,
              'view_count': 0,
            },
          ],
        },
      );
      final e2ee = _E2EE(
        const SealEncrypted(
          encryption: 'v1',
          ciphertext: 'ignored',
          envelope: {'sid': 'unused'},
        ),
      );
      final repository = _repository(api: api, e2ee: e2ee, store: store);

      final first = await repository.getFeedRaw();
      final second = await repository.getFeedRaw();

      expect(first.single['statuses'][0]['text_content'], 'decrypted once');
      expect(second.single['statuses'][0]['text_content'], 'decrypted once');
      expect(e2ee.openCount, 1);
    },
  );

  test('successful post contains only recipient ciphertext', () async {
    final api = _Api();
    final e2ee = _E2EE(
      const SealEncrypted(
        encryption: 'v1',
        ciphertext: 'ciphertext',
        envelope: {'sid': 'session'},
      ),
    );
    final repository = _repository(api: api, e2ee: e2ee, store: _MemoryStore());

    await repository.createText('secret');
    final body = api.posts.single;
    expect(body.containsKey('text_content'), isFalse);
    expect(body['recipients'], [
      {
        'user_id': 2,
        'encryption': 'v1',
        'ciphertext': 'ciphertext',
        'envelope': {'sid': 'session'},
      },
    ]);
  });

  test(
    'author sees their own locally cached status without a self-ratchet replay',
    () async {
      final store = _MemoryStore();
      final api = _Api(
        feed: {
          'user_id': 1,
          'display_name': 'Me',
          'statuses': [
            {
              'id': 'mine',
              'user_id': 1,
              'content_type': 'TEXT',
              'text_content': null,
              'encrypted_content': null,
              'media': null,
              'created_at': '2026-11-05T12:00:00',
              'expires_at': '2026-11-06T12:00:00',
              'viewed_by_me': false,
              'view_count': 0,
            },
          ],
        },
      );
      final e2ee = _E2EE(
        const SealEncrypted(
          encryption: 'v1',
          ciphertext: 'opaque',
          envelope: {'sid': 'session'},
        ),
      );
      final repository = _repository(api: api, e2ee: e2ee, store: store);

      await repository.createText('my local status');
      final feed = await repository.getFeedRaw();

      expect(feed.single['statuses'][0]['text_content'], 'my local status');
      expect(e2ee.openCount, 0);
    },
  );

  test(
    'media status wraps only its MediaCipher key, never caption or bytes',
    () async {
      final api = _Api();
      final e2ee = _E2EE(
        const SealEncrypted(
          encryption: 'v1',
          ciphertext: 'media-key-ciphertext',
          envelope: {'sid': 'session'},
        ),
      );
      final repository = _repository(
        api: api,
        e2ee: e2ee,
        store: _MemoryStore(),
      );
      final encrypted = await MediaCipher.encrypt(
        [1, 2, 3, 4],
        mimeType: 'image/jpeg',
        filename: 'private.jpg',
        caption: 'private caption',
      );
      await repository.createMedia(
        contentType: 'IMAGE',
        mediaAssetId: 7,
        mediaKey: encrypted.key.withAssetId(7),
      );

      final body = api.posts.single;
      expect(body['media_asset_id'], 7);
      expect(body.toString(), isNot(contains('private caption')));
      expect(body.toString(), isNot(contains('private.jpg')));
      expect(body.containsKey('text_content'), isFalse);
      expect(body['recipients'].single['ciphertext'], 'media-key-ciphertext');
      expect(e2ee.sealCount, 1);
    },
  );
}
