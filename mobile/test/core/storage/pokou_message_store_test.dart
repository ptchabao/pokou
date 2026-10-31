import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pokou/core/media/media_repository.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/features/groups/data/group_model.dart';
import 'package:pokou/features/messaging/data/direct_message_model.dart';

DirectMessage _direct({
  required String id,
  int senderId = 1,
  int recipientId = 2,
  String? content = 'bonjour',
  DateTime? createdAt,
  DirectMessageStatus status = DirectMessageStatus.sent,
}) {
  return DirectMessage(
    id: id,
    senderId: senderId,
    recipientId: recipientId,
    messageType: 'TEXT',
    content: content,
    mediaAssetId: null,
    media: null,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 9, 4, 10),
  );
}

GroupMessage _group({
  required String id,
  int groupId = 7,
  int senderId = 1,
  String content = 'salut le groupe',
  DateTime? createdAt,
}) {
  return GroupMessage(
    id: id,
    groupId: groupId,
    senderId: senderId,
    senderName: 'Kodjo',
    messageType: 'TEXT',
    content: content,
    mediaAssetId: null,
    media: null,
    createdAt: createdAt ?? DateTime(2026, 9, 4, 10),
  );
}

void main() {
  late PokouMessageStore store;
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    // Base isolée par test : sqflite traite `inMemoryDatabasePath` comme une
    // connexion singleton par défaut, donc les lignes d'un test fuiteraient
    // dans le suivant.
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await PokouMessageStore.createSchema(db);
    store = PokouMessageStore(database: db);
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  group('conversation directe', () {
    test('un message enregistré se relit à l\'identique', () async {
      await store.saveDirect([_direct(id: 'm1', content: 'devis 250000 FCFA')]);

      final cached = await store.directConversation(
        myUserId: 2,
        contactUserId: 1,
      );

      expect(cached.messages.length, 1);
      expect(cached.messages.single.id, 'm1');
      expect(cached.messages.single.content, 'devis 250000 FCFA');
      expect(cached.pendingIds, isEmpty);
    });

    test('la conversation est rendue du plus ancien au plus récent', () async {
      await store.saveDirect([
        _direct(id: 'recent', createdAt: DateTime(2026, 9, 4, 12)),
        _direct(id: 'ancien', createdAt: DateTime(2026, 9, 4, 8)),
      ]);

      final cached = await store.directConversation(
        myUserId: 2,
        contactUserId: 1,
      );

      expect(cached.messages.map((m) => m.id), ['ancien', 'recent']);
    });

    test('les deux sens de la conversation sont rendus', () async {
      await store.saveDirect([
        _direct(id: 'recu', senderId: 1, recipientId: 2),
        _direct(id: 'envoye', senderId: 2, recipientId: 1),
      ]);

      final cached = await store.directConversation(
        myUserId: 2,
        contactUserId: 1,
      );

      expect(cached.messages.length, 2);
    });

    test('une conversation avec un tiers n\'y apparaît pas', () async {
      await store.saveDirect([
        _direct(id: 'ailleurs', senderId: 3, recipientId: 4),
      ]);

      final cached = await store.directConversation(
        myUserId: 2,
        contactUserId: 1,
      );

      expect(cached.messages, isEmpty);
    });

    test('un message réenregistré écrase sa version précédente', () async {
      await store.saveDirect([_direct(id: 'm1')]);
      await store.saveDirect([
        _direct(id: 'm1', status: DirectMessageStatus.read),
      ]);

      final cached = await store.directConversation(
        myUserId: 2,
        contactUserId: 1,
      );

      // Un statut qui passe à READ ne doit pas créer un doublon.
      expect(cached.messages.length, 1);
      expect(cached.messages.single.status, DirectMessageStatus.read);
    });
  });

  group('file d\'attente', () {
    test(
      'un message en attente est signalé comme tel et listé pour renvoi',
      () async {
        final pending = _direct(id: store.newLocalId());
        await store.saveDirect([pending], pending: true);

        final cached = await store.directConversation(
          myUserId: 1,
          contactUserId: 2,
        );
        expect(cached.pendingIds, {pending.id});
        // Il s'affiche dans la conversation : hors ligne, l'expéditeur doit
        // voir son message, pas un vide.
        expect(cached.messages.single.id, pending.id);

        expect((await store.pendingDirect()).map((m) => m.id), [pending.id]);
      },
    );

    test(
      'la confirmation remplace la ligne provisoire par l\'identifiant du serveur',
      () async {
        final localId = store.newLocalId();
        await store.saveDirect([_direct(id: localId)], pending: true);

        await store.confirmDirect(localId, _direct(id: 'serveur-1'));

        final cached = await store.directConversation(
          myUserId: 1,
          contactUserId: 2,
        );
        // Un seul message : sans la suppression de la ligne provisoire dans la
        // même transaction, il apparaîtrait en double.
        expect(cached.messages.map((m) => m.id), ['serveur-1']);
        expect(cached.pendingIds, isEmpty);
        expect(await store.pendingDirect(), isEmpty);
      },
    );

    test('la confirmation est annoncée aux écrans ouverts', () async {
      final localId = store.newLocalId();
      await store.saveDirect([_direct(id: localId)], pending: true);

      final updates = store.updates.take(1).toList();
      await store.confirmDirect(localId, _direct(id: 'serveur-1'));

      final update = (await updates).single;
      expect(update.localId, localId);
      expect(update.direct?.id, 'serveur-1');
      expect(update.failed, isFalse);
    });

    test(
      'un échec définitif sort de la file sans disparaître de l\'écran',
      () async {
        final localId = store.newLocalId();
        await store.saveDirect([_direct(id: localId)], pending: true);

        await store.markDirectFailed(localId);

        final cached = await store.directConversation(
          myUserId: 1,
          contactUserId: 2,
        );
        expect(cached.failedIds, {localId});
        expect(cached.pendingIds, isEmpty);
        // Toujours affiché : l'utilisateur doit pouvoir le renvoyer.
        expect(cached.messages.single.id, localId);
        // Mais plus réessayé automatiquement, sinon il échouerait sans fin.
        expect(await store.pendingDirect(), isEmpty);
      },
    );

    test(
      'les messages en attente partent dans l\'ordre où ils ont été écrits',
      () async {
        await store.saveDirect([
          _direct(id: 'l2', createdAt: DateTime(2026, 9, 4, 11)),
        ], pending: true);
        await store.saveDirect([
          _direct(id: 'l1', createdAt: DateTime(2026, 9, 4, 10)),
        ], pending: true);

        expect((await store.pendingDirect()).map((m) => m.id), ['l1', 'l2']);
      },
    );

    test('un identifiant local est reconnaissable', () {
      expect(PokouMessageStore.isLocalId(store.newLocalId()), isTrue);
      expect(
        PokouMessageStore.isLocalId('7c9e6679-7425-40de-944b-e07fc1f90ae7'),
        isFalse,
      );
    });
  });

  group('alignement sur le serveur', () {
    test(
      'un message supprimé pendant une coupure disparaît du cache',
      () async {
        await store.saveDirect([
          _direct(id: 'garde', createdAt: DateTime(2026, 9, 4, 10)),
          _direct(id: 'supprime-ailleurs', createdAt: DateTime(2026, 9, 4, 11)),
        ]);

        // Le serveur ne renvoie plus que l'un des deux : l'autre a été
        // supprimé et l'événement WS `message:deleted` a été manqué.
        await store.reconcileDirect(
          myUserId: 2,
          contactUserId: 1,
          serverMessages: [
            _direct(id: 'garde', createdAt: DateTime(2026, 9, 4, 10)),
          ],
        );

        final cached = await store.directConversation(
          myUserId: 2,
          contactUserId: 1,
        );
        expect(cached.messages.map((m) => m.id), ['garde']);
      },
    );

    test('un message en attente survit à l\'alignement', () async {
      final localId = store.newLocalId();
      await store.saveDirect([
        _direct(
          id: localId,
          senderId: 2,
          recipientId: 1,
          createdAt: DateTime(2026, 9, 4, 12),
        ),
      ], pending: true);

      await store.reconcileDirect(
        myUserId: 2,
        contactUserId: 1,
        serverMessages: [
          _direct(id: 'serveur', createdAt: DateTime(2026, 9, 4, 10)),
        ],
      );

      // Le serveur ne peut pas le connaître : il n'est jamais parti.
      expect((await store.pendingDirect()).map((m) => m.id), [localId]);
    });

    test(
      'l\'historique plus ancien que la fenêtre du serveur est conservé',
      () async {
        await store.saveDirect([
          _direct(id: 'tres-ancien', createdAt: DateTime(2026, 8, 1, 9)),
        ]);

        // Même enchaînement que le contrôleur : on enregistre ce que le
        // serveur renvoie, PUIS on aligne. Le serveur ne renvoie que les 100
        // derniers messages : ce qui est plus ancien n'est pas supprimé, il
        // est seulement hors fenêtre.
        final serverWindow = [
          _direct(id: 'recent', createdAt: DateTime(2026, 9, 4, 10)),
        ];
        await store.saveDirect(serverWindow);
        await store.reconcileDirect(
          myUserId: 2,
          contactUserId: 1,
          serverMessages: serverWindow,
        );

        final cached = await store.directConversation(
          myUserId: 2,
          contactUserId: 1,
        );
        expect(cached.messages.map((m) => m.id), ['tres-ancien', 'recent']);
      },
    );

    test('une réponse serveur vide ne vide pas le cache', () async {
      await store.saveDirect([_direct(id: 'm1')]);

      // Sinon une réponse vide due à une erreur transitoire effacerait toute
      // la conversation stockée.
      await store.reconcileDirect(
        myUserId: 2,
        contactUserId: 1,
        serverMessages: [],
      );

      final cached = await store.directConversation(
        myUserId: 2,
        contactUserId: 1,
      );
      expect(cached.messages.length, 1);
    });
  });

  group('conversation de groupe', () {
    test('les messages sont rendus par groupe et dans l\'ordre', () async {
      await store.saveGroup([
        _group(id: 'g2', createdAt: DateTime(2026, 9, 4, 11)),
        _group(id: 'g1', createdAt: DateTime(2026, 9, 4, 10)),
        _group(id: 'autre-groupe', groupId: 99),
      ]);

      final cached = await store.groupConversation(7);

      expect(cached.messages.map((m) => m.id), ['g1', 'g2']);
    });

    test('la confirmation remplace la ligne provisoire', () async {
      final localId = store.newLocalId();
      await store.saveGroup([_group(id: localId)], pending: true);

      await store.confirmGroup(localId, _group(id: 'serveur-g1'));

      final cached = await store.groupConversation(7);
      expect(cached.messages.map((m) => m.id), ['serveur-g1']);
      expect(await store.pendingGroup(), isEmpty);
    });

    test('un échec de groupe reste affiché et sort de la file', () async {
      final localId = store.newLocalId();
      await store.saveGroup([_group(id: localId)], pending: true);

      await store.markGroupFailed(localId);

      final cached = await store.groupConversation(7);
      expect(cached.failedIds, {localId});
      expect(await store.pendingGroup(), isEmpty);
    });
  });

  test('la déconnexion efface les conversations', () async {
    await store.saveDirect([_direct(id: 'm1')]);
    await store.saveGroup([_group(id: 'g1')]);

    await store.clear();

    expect(
      (await store.directConversation(myUserId: 2, contactUserId: 1)).messages,
      isEmpty,
    );
    expect((await store.groupConversation(7)).messages, isEmpty);
  });

  group('socle de synchronisation partagé', () {
    test(
      'les événements et le curseur sont enregistrés ensemble et dédupliqués',
      () async {
        const event = SyncInboxEvent(
          id: 'event-1',
          type: 'PROFILE_UPDATED',
          payload: {'name': 'Ama'},
        );

        await store.saveSyncBatch(
          scope: 'account:1',
          events: [event],
          cursor: 'cursor-10',
        );
        await store.saveSyncBatch(
          scope: 'account:1',
          events: [event],
          cursor: 'cursor-10',
        );
        await store.saveSyncBatch(
          scope: 'account:1',
          events: [
            const SyncInboxEvent(
              id: 'event-realtime',
              type: 'PRESENCE_CHANGED',
              payload: {'user_id': 2},
            ),
          ],
          cursor: null,
        );

        expect(await store.syncCursor('account:1'), 'cursor-10');
        final pending = await store.pendingSyncEvents();
        expect(pending, hasLength(2));
        expect(pending.first.payload['name'], 'Ama');

        for (final queuedEvent in pending) {
          await store.markSyncEventProcessed(queuedEvent.id);
        }
        expect(await store.pendingSyncEvents(), isEmpty);
      },
    );

    test(
      'les opérations sont persistantes et dédupliquées par idempotence',
      () async {
        await store.enqueueSyncOperation(
          operationId: 'op-1',
          idempotencyRef: 'profile:update:1',
          type: 'PROFILE_UPDATE',
          payload: {'name': 'Ama'},
        );
        await store.enqueueSyncOperation(
          operationId: 'op-2',
          idempotencyRef: 'profile:update:1',
          type: 'PROFILE_UPDATE',
          payload: {'name': 'Ama'},
        );

        final queued = await store.pendingSyncOperations();
        expect(queued, hasLength(1));
        expect(queued.single.id, 'op-1');

        await store.recordSyncOperationAttempt('op-1');
        expect((await store.pendingSyncOperations()).single.attempts, 1);

        await store.completeSyncOperation('op-1');
        expect(await store.pendingSyncOperations(), isEmpty);
      },
    );

    test('un événement inbox met à jour le cache une seule fois', () async {
      const event = SyncInboxEvent(
        id: 'event-message-1',
        type: 'message:new',
        payload: {
          'message': {'id': 'server-message-1'},
        },
      );
      final message = _direct(id: 'server-message-1');
      await store.saveSyncBatch(
        scope: 'account:1',
        events: [event],
        cursor: 'cursor-1',
      );

      expect(
        await store.applySyncEvent(event: event, directMessage: message),
        isTrue,
      );
      expect(
        await store.applySyncEvent(event: event, directMessage: message),
        isFalse,
      );
      final cached = await store.directConversation(
        myUserId: 1,
        contactUserId: 2,
      );
      expect(cached.messages.map((item) => item.id), ['server-message-1']);
      expect(await store.pendingSyncEvents(), isEmpty);
    });

    test(
      'un accusé de lecture ne remplace pas le texte local déchiffré',
      () async {
        final cachedMessage = _direct(
          id: 'encrypted-message',
          content: 'texte clair',
        );
        await store.saveDirect([cachedMessage]);
        const event = SyncInboxEvent(
          id: 'event-read-1',
          type: 'message:status',
          payload: {
            'message': {'id': 'encrypted-message'},
          },
        );
        await store.saveSyncBatch(
          scope: 'account:1',
          events: [event],
          cursor: 'cursor-read',
        );
        final serverStatus = _direct(
          id: 'encrypted-message',
          content: null,
          status: DirectMessageStatus.read,
        );

        expect(
          await store.applySyncEvent(event: event, directMessage: serverStatus),
          isTrue,
        );
        final cached = await store.directConversation(
          myUserId: 1,
          contactUserId: 2,
        );
        expect(cached.messages.single.content, 'texte clair');
        expect(cached.messages.single.status, DirectMessageStatus.read);
      },
    );
  });

  test('une pièce jointe survit à l\'aller-retour par le cache', () async {
    final withMedia = DirectMessage(
      id: 'm-media',
      senderId: 1,
      recipientId: 2,
      messageType: 'IMAGE',
      content: 'la facture',
      mediaAssetId: 42,
      media: const MediaMeta(
        id: 42,
        mimeType: 'image/jpeg',
        sizeBytes: 4603,
        originalFilename: 'facture.jpg',
      ),
      status: DirectMessageStatus.sent,
      createdAt: DateTime(2026, 9, 4, 10),
    );
    await store.saveDirect([withMedia]);

    final cached = await store.directConversation(
      myUserId: 2,
      contactUserId: 1,
    );
    final media = cached.messages.single.media;
    expect(media, isNotNull);
    expect(media!.id, 42);
    expect(media.mimeType, 'image/jpeg');
    expect(media.sizeBytes, 4603);
    expect(media.originalFilename, 'facture.jpg');
  });

  // ─── La liste d'accueil hors ligne ──────────────────────────────────────

  group('Liste des discussions en cache', () {
    test('la dernière liste connue se relit telle quelle', () async {
      final items = [
        {
          'kind': 'contact',
          'id': 7,
          'name': 'Ama',
          'unread_count': 2,
          'is_pinned': true,
        },
        {'kind': 'community', 'id': 3, 'name': 'Quartier', 'group_count': 4},
      ];
      await store.saveConversations('inbox', items);

      final cached = await store.cachedConversations('inbox');
      // Le JSON BRUT : c'est le serveur qui compose et trie cette liste, et
      // la redécouper ici reviendrait à recopier son tri sur l'appareil.
      expect(cached, isNotNull);
      expect(cached!.length, 2);
      expect((cached[0] as Map)['name'], 'Ama');
      expect((cached[1] as Map)['group_count'], 4);
    });

    test('sans cache, on répond « je ne sais pas » et non « rien »', () async {
      // Deux situations qui demandent deux écrans différents : une liste
      // vide est une réponse, l'absence de cache n'en est pas une.
      expect(await store.cachedConversations('inbox'), isNull);
    });

    test('une seconde écriture remplace la première', () async {
      await store.saveConversations('inbox', [
        {'kind': 'contact', 'id': 1, 'name': 'Ancien'},
      ]);
      await store.saveConversations('inbox', [
        {'kind': 'contact', 'id': 2, 'name': 'Nouveau'},
      ]);

      final cached = await store.cachedConversations('inbox');
      expect(cached!.length, 1);
      expect((cached.single as Map)['name'], 'Nouveau');
    });

    test('les portées ne se mélangent pas', () async {
      await store.saveConversations('inbox', [
        {'kind': 'contact', 'id': 1},
      ]);
      expect(await store.cachedConversations('archived'), isNull);
    });
  });
}
