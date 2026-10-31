import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../providers.dart';
import '../storage/pokou_message_store.dart';
import '../ws/ws_client.dart';
import '../../features/groups/data/group_model.dart';
import '../../features/messaging/data/direct_message_model.dart';
import '../../features/messaging/data/messaging_repository.dart';
import '../../features/messaging/presentation/messaging_controller.dart'
    show messagingRepositoryProvider;

enum PokouSyncState { offline, reconnecting, syncing, online }

/// Shared transport coordinator. Feature controllers keep their existing
/// realtime subscriptions; this service durably records replayable events
/// and catches up the local inbox from the server cursor after reconnect.
class PokouSyncEngine extends StateNotifier<PokouSyncState> {
  PokouSyncEngine({
    required PokouMessageStore store,
    required ApiClient api,
    required WsClient ws,
    required MessagingRepository messaging,
  }) : _store = store,
       _api = api,
       _ws = ws,
       _messaging = messaging,
       super(ws.isConnected ? PokouSyncState.syncing : PokouSyncState.offline) {
    _connectionSubscription = ws.connectionChanges.listen(_onConnectionChanged);
    _eventSubscription = ws.events.listen(_recordRealtimeEvent);
    if (ws.isConnected) unawaited(_synchronize());
  }

  static const _scope = 'pokou';
  static const _pageSize = 200;

  final PokouMessageStore _store;
  final ApiClient _api;
  final WsClient _ws;
  final MessagingRepository _messaging;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  bool _synchronizing = false;
  final _caughtUpTypes = StreamController<Set<String>>.broadcast();

  /// Les types d'événements rattrapés après une coupure — ceux que le
  /// socket n'a pas pu pousser pendant qu'on était hors ligne.
  ///
  /// Les listes (groupes, chaînes, statuts, discussions) se tiennent à jour
  /// en écoutant le socket ; un `group:updated` arrivé pendant la coupure
  /// ne passait donc jamais par elles, et la liste restait fausse jusqu'au
  /// prochain tirer-pour-rafraîchir. Voir `listenDurableEventTypes`.
  Stream<Set<String>> get caughtUpTypes => _caughtUpTypes.stream;

  static const _projectedTypes = [
    'message:new',
    'message:status',
    'message:deleted',
    'group:message:new',
  ];

  void _onConnectionChanged(bool connected) {
    if (!connected) {
      state = PokouSyncState.reconnecting;
      return;
    }
    unawaited(_synchronize());
  }

  Future<void> _recordRealtimeEvent(Map<String, dynamic> event) async {
    final id = event['sync_event_id'];
    final type = event['type'];
    if (id == null || type is! String) return;
    final payload = Map<String, dynamic>.from(event)
      ..remove('sync_event_id')
      ..remove('type');
    await _store.saveSyncBatch(
      scope: _scope,
      events: [SyncInboxEvent(id: id.toString(), type: type, payload: payload)],
      cursor: null,
    );
    await _applyInbox();
  }

  Future<void> _synchronize() async {
    if (_synchronizing || !_ws.isConnected) return;
    _synchronizing = true;
    state = PokouSyncState.syncing;
    try {
      var cursor = await _store.syncCursor(_scope) ?? '0';
      var hasMore = true;
      final caughtUp = <String>{};
      while (hasMore && _ws.isConnected) {
        final response =
            await _api.get(
                  '/sync/events?cursor=${Uri.encodeQueryComponent(cursor)}&limit=$_pageSize',
                )
                as Map<String, dynamic>;
        final rawEvents = response['events'] as List<dynamic>? ?? const [];
        final events = <SyncInboxEvent>[];
        for (final raw in rawEvents) {
          final event = raw as Map<String, dynamic>;
          caughtUp.add(event['type'] as String);
          events.add(
            SyncInboxEvent(
              id: event['id'].toString(),
              type: event['type'] as String,
              payload: Map<String, dynamic>.from(
                event['payload'] as Map<String, dynamic>,
              ),
            ),
          );
        }
        final nextCursor = response['next_cursor']?.toString() ?? cursor;
        await _store.saveSyncBatch(
          scope: _scope,
          events: events,
          cursor: nextCursor,
        );
        cursor = nextCursor;
        hasMore = response['has_more'] == true;
        if (rawEvents.isEmpty) break;
      }
      await _applyInbox();
      await _settleUnprojected();
      if (caughtUp.isNotEmpty) _caughtUpTypes.add(caughtUp);
      state = _ws.isConnected
          ? PokouSyncState.online
          : PokouSyncState.reconnecting;
    } catch (_) {
      state = _ws.isConnected
          ? PokouSyncState.online
          : PokouSyncState.reconnecting;
    } finally {
      _synchronizing = false;
    }
  }

  /// Solde les événements qu'aucune projection locale ne consomme
  /// (`group:updated`, `status:new`…).
  ///
  /// Sans ça, ils restaient `processed = 0` pour toujours : la table
  /// grossissait à chaque événement, et chaque rattrapage relisait un peu
  /// plus de lignes mortes. Leur effet, lui, passe par `caughtUpTypes`.
  ///
  /// Uniquement ici, à la fin d'un rattrapage, et pas à l'arrivée de chaque
  /// événement en direct : un nettoyage lancé pendant qu'un autre chemin
  /// applique ses événements pourrait sinon solder l'un d'eux avant qu'il
  /// soit projeté — d'où aussi l'exclusion explicite des types projetés.
  Future<void> _settleUnprojected() async {
    while (true) {
      final leftovers = await _store.pendingSyncEvents(
        limit: 500,
        excludeTypes: _projectedTypes,
      );
      if (leftovers.isEmpty) return;
      for (final event in leftovers) {
        await _store.markSyncEventProcessed(event.id);
      }
    }
  }

  Future<void> _applyInbox() async {
    while (true) {
      final pending = await _store.pendingSyncEvents(
        limit: 500,
        types: _projectedTypes,
      );
      if (pending.isEmpty) break;
      var madeProgress = false;
      for (final event in pending) {
        switch (event.type) {
          case 'message:new':
            final raw = event.payload['message'];
            if (raw is! Map<String, dynamic>) continue;
            final message = DirectMessage.fromJson(raw);
            if (await _store.hasDirectMessage(message.id)) {
              await _store.markSyncEventProcessed(event.id);
              madeProgress = true;
              continue;
            }
            final opened = await _messaging.decryptIncoming(
              message,
              message.senderId,
            );
            madeProgress =
                await _store.applySyncEvent(
                  event: event,
                  directMessage: opened,
                ) ||
                madeProgress;
          case 'message:status':
            final raw = event.payload['message'];
            if (raw is! Map<String, dynamic>) continue;
            madeProgress =
                await _store.applySyncEvent(
                  event: event,
                  directMessage: DirectMessage.fromJson(raw),
                ) ||
                madeProgress;
          case 'message:deleted':
            madeProgress =
                await _store.applySyncEvent(event: event) || madeProgress;
          case 'group:message:new':
            final raw = event.payload['message'];
            if (raw is! Map<String, dynamic>) continue;
            madeProgress =
                await _store.applySyncEvent(
                  event: event,
                  groupMessage: GroupMessage.fromJson(raw),
                ) ||
                madeProgress;
        }
      }
      if (!madeProgress) break;
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _eventSubscription?.cancel();
    _caughtUpTypes.close();
    super.dispose();
  }
}

final pokouSyncEngineProvider =
    StateNotifierProvider<PokouSyncEngine, PokouSyncState>((ref) {
      return PokouSyncEngine(
        store: ref.watch(pokouMessageStoreProvider),
        api: ref.watch(apiClientProvider),
        ws: ref.watch(wsClientProvider),
        messaging: ref.watch(messagingRepositoryProvider),
      );
    });

/// Appelle [onType] pour chaque événement durable, qu'il arrive en direct
/// par le socket ou qu'il soit rattrapé après une coupure.
///
/// Les deux chemins, parce qu'une liste qui n'écoute que le socket rate
/// tout ce qui s'est passé pendant qu'on était hors ligne. Un type rattrapé
/// plusieurs fois n'est signalé qu'une fois par rattrapage : relire une
/// liste une fois suffit, quel que soit le nombre de changements.
void listenDurableEventTypes(Ref ref, void Function(String type) onType) {
  final live = ref.watch(wsClientProvider).events.listen((event) {
    final type = event['type'];
    if (type is String) onType(type);
  });
  final caughtUp = ref
      .watch(pokouSyncEngineProvider.notifier)
      .caughtUpTypes
      .listen((types) => types.forEach(onType));
  ref.onDispose(() {
    live.cancel();
    caughtUp.cancel();
  });
}
