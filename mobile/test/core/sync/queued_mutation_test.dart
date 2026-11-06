import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/core/sync/outbox_service.dart';
import 'package:pokou/core/sync/queued_mutation.dart';
import 'package:pokou/core/ws/ws_client.dart';
import 'package:pokou/features/channels/data/channel_model.dart';
import 'package:pokou/features/contacts/presentation/discussions_controller.dart';

/// Un ApiClient qui ne sort pas de la machine. Chaque appel est noté, et
/// `failure` décide de ce que le « serveur » répond.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'https://inutilise');

  final calls = <String>[];
  Object? failure;

  Future<dynamic> _answer(String method, String path) async {
    calls.add('$method $path');
    final error = failure;
    if (error != null) throw error;
    return {'ok': true};
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) => _answer('POST', path);

  @override
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _answer('PUT', path);

  @override
  Future<dynamic> delete(String path, {Map<String, dynamic>? body, bool authenticated = true}) =>
      _answer('DELETE', path);
}

/// Toujours connecté : on déclenche le vidage à la main.
class _ConnectedWs implements WsClient {
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionChanges => _changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late PokouMessageStore store;
  late _FakeApi api;
  late MutationQueue queue;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await PokouMessageStore.createSchema(db);
    store = PokouMessageStore(database: db);
    api = _FakeApi();
    queue = MutationQueue(api: api, store: store);
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  QueuedMutation follow(bool following) => QueuedMutation(
    key: 'channel:follow:12',
    method: following ? 'POST' : 'DELETE',
    path: '/channels/12/follow',
  );

  OutboxService outbox() => OutboxService(
    store: store,
    ws: _ConnectedWs(),
    sendDirect: (_) => throw UnimplementedError(),
    sendGroup: (_) => throw UnimplementedError(),
    sendMedia: (_) => throw UnimplementedError(),
    sendGroupMedia: (_) => throw UnimplementedError(),
    applyAction: (_) => throw UnimplementedError(),
    sendMutation: (mutation) => mutation.send(api),
  );

  group('MutationQueue', () {
    test('en ligne, le geste part et rien ne reste en file', () async {
      final result = await queue.send(follow(true));

      expect(result.queued, isFalse);
      expect(result.response, {'ok': true});
      expect(api.calls, ['POST /channels/12/follow']);
      expect(await store.pendingSyncOperations(), isEmpty);
    });

    test('hors ligne, le geste attend au lieu d\'échouer', () async {
      api.failure = NetworkException('coupure');

      final result = await queue.send(follow(true));

      expect(result.queued, isTrue);
      final queued = (await store.pendingSyncOperations()).single;
      expect(queued.idempotencyRef, 'channel:follow:12');
      expect(QueuedMutation.fromOperation(queued)!.method, 'POST');
    });

    test(
      'se raviser hors ligne ne laisse partir que le dernier choix',
      () async {
        api.failure = NetworkException('coupure');

        await queue.send(follow(true));
        await queue.send(follow(false));

        final queued = await store.pendingSyncOperations();
        expect(queued, hasLength(1));
        expect(QueuedMutation.fromOperation(queued.single)!.method, 'DELETE');
      },
    );

    test(
      'un geste qui passe en direct efface l\'intention plus ancienne',
      () async {
        // Sans ça, « suivre » resté en file repartirait à la reconnexion et
        // défairait le « ne plus suivre » qu'on vient de réussir.
        api.failure = NetworkException('coupure');
        await queue.send(follow(true));

        api.failure = null;
        await queue.send(follow(false));

        expect(await store.pendingSyncOperations(), isEmpty);
      },
    );

    test('un refus du serveur remonte, et n\'est pas mis en file', () async {
      api.failure = ApiException(403, 'interdit');

      await expectLater(queue.send(follow(true)), throwsA(isA<ApiException>()));
      expect(await store.pendingSyncOperations(), isEmpty);
    });

    test('sans magasin, l\'absence de réseau remonte comme avant', () async {
      api.failure = NetworkException('coupure');

      await expectLater(
        MutationQueue(api: api).send(follow(true)),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('OutboxService rejoue les réglages', () {
    Future<void> queueOffline(QueuedMutation mutation) async {
      api.failure = NetworkException('coupure');
      await queue.send(mutation);
      api.calls.clear();
    }

    test('à la reconnexion, le réglage part puis quitte la file', () async {
      await queueOffline(follow(true));
      api.failure = null;

      await outbox().flush();

      expect(api.calls, ['POST /channels/12/follow']);
      expect(await store.pendingSyncOperations(), isEmpty);
    });

    test('seul un réglage accepté est annoncé aux listes', () async {
      await queueOffline(follow(true));
      final service = outbox();
      final announced = <String>[];
      final subscription = service.replayedMutations.listen(announced.add);

      await service.flush(); // toujours hors ligne : rien à annoncer
      api.failure = null;
      await service.flush();
      await Future<void>.delayed(Duration.zero);

      expect(announced, ['channel:follow:12']);
      await subscription.cancel();
      service.dispose();
    });

    test('toujours hors ligne : il reste, sans tentative comptée', () async {
      await queueOffline(follow(true));

      await outbox().flush();

      final queued = (await store.pendingSyncOperations()).single;
      expect(queued.attempts, 0);
    });

    test('panne serveur : il reste, et la tentative est comptée', () async {
      await queueOffline(follow(true));
      api.failure = ApiException(503, 'indisponible');

      await outbox().flush();

      expect((await store.pendingSyncOperations()).single.attempts, 1);
    });

    test(
      'refus du serveur : il est abandonné, pas réessayé sans fin',
      () async {
        await queueOffline(follow(true));
        api.failure = ApiException(404, 'chaîne introuvable');

        await outbox().flush();

        expect(await store.pendingSyncOperations(), isEmpty);
      },
    );

    test('un type inconnu ne bloque pas la file', () async {
      await store.enqueueSyncOperation(
        operationId: 'op-futur',
        idempotencyRef: 'futur:1',
        type: 'type-d-une-version-plus-recente',
        payload: const {},
      );
      await queueOffline(follow(true));
      api.failure = null;

      await outbox().flush();

      expect(api.calls, ['POST /channels/12/follow']);
      expect(await store.pendingSyncOperations(), isEmpty);
    });
  });

  group('ce que l\'écran montre pendant l\'attente', () {
    test(
      'ma réaction remplace l\'ancienne, et une pastille à zéro disparaît',
      () {
        final post = ChannelPost.fromJson({
          'id': 'p1',
          'channel_id': 1,
          'author_id': 7,
          'created_at': '2026-09-29T10:00:00Z',
          'view_count': 0,
          'reactions': [
            {'emoji': '👍', 'count': 1, 'mine': true},
            {'emoji': '❤️', 'count': 2, 'mine': false},
          ],
        });

        final changed = post.withMyReaction('❤️');
        expect(changed.reactions.map((r) => (r.emoji, r.count, r.mine)), [
          ('❤️', 3, true),
        ]);

        final removed = changed.withMyReaction(null);
        expect(removed.reactions.map((r) => (r.emoji, r.count, r.mine)), [
          ('❤️', 2, false),
        ]);

        final added = removed.withMyReaction('🔥');
        expect(added.myReaction?.emoji, '🔥');
      },
    );

    test('suivre hors ligne compte déjà l\'abonné', () {
      final channel = PokouChannel.fromJson({
        'id': 12,
        'name': 'Marché',
        'created_by': 7,
        'follower_count': 4,
        'is_following': false,
      });

      expect(channel.withFollowing(true).followerCount, 5);
      expect(channel.withFollowing(true).withFollowing(false).followerCount, 4);
      expect(channel.withFollowing(false).followerCount, 4);
    });

    test(
      'la liste d\'accueil gardée reflète épingle, sourdine et archive',
      () async {
        await store.saveConversations('inbox', [
          {'kind': 'contact', 'id': 1, 'name': 'Awa', 'is_pinned': false},
          {'kind': 'group', 'id': 2, 'name': 'Famille', 'is_muted': false},
          {'kind': 'contact', 'id': 2, 'name': 'Kodjo', 'is_pinned': false},
        ]);

        await applyQueuedDiscussionSetting(
          store,
          kind: 'contact',
          id: 2,
          fields: {'is_pinned': true},
        );
        await applyQueuedDiscussionSetting(
          store,
          kind: 'group',
          id: 2,
          fields: {'is_muted': true},
        );
        await applyQueuedDiscussionSetting(
          store,
          kind: 'contact',
          id: 1,
          remove: true,
        );

        final items = (await store.cachedConversations(
          'inbox',
        ))!.cast<Map<String, dynamic>>();
        expect(items.map((item) => item['name']), ['Kodjo', 'Famille']);
        expect(items.first['is_pinned'], isTrue);
        expect(items.last['is_muted'], isTrue);
      },
    );
  });

  test(
    'le moteur peut solder les événements sans projection sans toucher aux autres',
    () async {
      await store.saveSyncBatch(
        scope: 'pokou',
        events: const [
          SyncInboxEvent(id: '1', type: 'group:updated', payload: {}),
          SyncInboxEvent(id: '2', type: 'message:new', payload: {}),
          SyncInboxEvent(id: '3', type: 'status:new', payload: {}),
        ],
        cursor: '3',
      );

      final leftovers = await store.pendingSyncEvents(
        excludeTypes: const ['message:new'],
      );

      expect(leftovers.map((event) => event.id), ['1', '3']);
    },
  );
}
