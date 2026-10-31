import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/groups/presentation/group_controller.dart';
import '../../features/groups/data/group_model.dart';
import '../../features/messaging/data/direct_message_model.dart';
import '../../features/messaging/presentation/messaging_controller.dart';
import '../api/api_exceptions.dart';
import '../providers.dart';
import '../storage/pokou_message_store.dart';
import 'media_sender.dart';
import 'queued_mutation.dart';
import '../ws/ws_client.dart';

/// File d'attente des messages composés sans réseau — le « ils partent tout
/// seuls quand ça revient » de WhatsApp.
///
/// Vit pour toute la durée de l'app (surveillée depuis main.dart) et non dans
/// l'écran de conversation : un message écrit dans une conversation puis
/// quittée doit partir quand même, et un message resté en attente d'une
/// session précédente doit partir au démarrage suivant.
///
/// C'est le SEUL endroit qui réémet les messages en attente. Les écrans, eux,
/// n'écrivent que la ligne en attente et tentent l'envoi immédiat ; sans ce
/// propriétaire unique, un écran ouvert et ce service pourraient renvoyer le
/// même message en double.
class OutboxService {
  OutboxService({
    required PokouMessageStore store,
    required WsClient ws,
    required Future<DirectMessage> Function(DirectMessage pending) sendDirect,
    required Future<void> Function(String localId) sendGroup,
    required Future<bool> Function(DirectMessage pending) sendMedia,
    required Future<bool> Function(GroupMessage pending) sendGroupMedia,
    required Future<void> Function(PendingAction action) applyAction,
    required Future<void> Function(QueuedMutation mutation) sendMutation,
  }) : _store = store,
       _ws = ws,
       _sendDirect = sendDirect,
       _sendGroup = sendGroup,
       _sendMedia = sendMedia,
       _sendGroupMedia = sendGroupMedia,
       _applyAction = applyAction,
       _sendMutation = sendMutation;

  final PokouMessageStore _store;
  final WsClient _ws;
  final Future<DirectMessage> Function(DirectMessage pending) _sendDirect;
  final Future<void> Function(String localId) _sendGroup;

  /// Une pièce jointe en attente : son fichier est encore sur l'appareil, il
  /// reste à le téléverser puis à envoyer le message. Le MÊME chemin que
  /// celui de l'écran de conversation (voir `MediaSender`), pour que les
  /// deux ne puissent pas diverger.
  final Future<bool> Function(DirectMessage pending) _sendMedia;
  final Future<bool> Function(GroupMessage pending) _sendGroupMedia;

  /// Rejoue un geste posé hors ligne — réaction, suppression. La file ne
  /// sait pas ce que chacun veut dire ; elle sait seulement qu'il faut le
  /// rejouer une fois, et l'oublier ensuite.
  final Future<void> Function(PendingAction action) _applyAction;

  /// Rejoue un réglage posé hors ligne (voir `QueuedMutation`) : suivre une
  /// chaîne, épingler une discussion, compter une vue.
  final Future<void> Function(QueuedMutation mutation) _sendMutation;

  /// Au-delà, une opération que le serveur refuse en 5xx à chaque
  /// reconnexion est abandonnée : un réglage vieux de vingt tentatives ne
  /// dit plus grand-chose de ce que la personne veut aujourd'hui, et il
  /// bloquerait la file pour rien.
  static const maxMutationAttempts = 20;

  StreamSubscription<bool>? _subscription;
  bool _flushing = false;
  final _replayed = StreamController<String>.broadcast();

  /// La clé de chaque réglage que le serveur vient d'accepter au rejeu.
  ///
  /// Les listes concernées s'y relisent. Sans ce signal, une liste relue au
  /// retour du réseau AVANT le rejeu recevait l'ancien état du serveur, et
  /// plus rien ne la corrigeait ensuite : l'épingle posée hors ligne
  /// semblait perdue alors qu'elle venait d'être enregistrée.
  Stream<String> get replayedMutations => _replayed.stream;

  void start() {
    _subscription = _ws.connectionChanges.listen((connected) {
      if (connected) flush();
    });
    // Le socket peut déjà être ouvert quand ce service démarre (l'ordre
    // d'initialisation des providers n'est pas garanti) : on ne veut pas
    // attendre la prochaine coupure pour vider une file héritée du
    // lancement précédent.
    if (_ws.isConnected) flush();
  }

  /// Renvoie tout ce qui attend, du plus ancien au plus récent. Le drapeau
  /// `_flushing` évite qu'une reconnexion instable (socket qui bat) lance
  /// plusieurs vidages concurrents sur les mêmes lignes.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      for (final pending in await _store.pendingDirect()) {
        if (!_ws.isConnected) return; // reparti hors ligne : on garde le reste
        if (pending.pendingMedia != null) {
          // Une pièce jointe suit son propre chemin — téléverser d'abord,
          // envoyer ensuite — et `MediaSender` gère lui-même l'échec
          // définitif (fichier disparu, refus 4xx) comme la mise en
          // attente. Rien à envelopper ici : le faire doublerait le
          // traitement d'erreur, et les deux finiraient par se contredire.
          await _sendMedia(pending);
          continue;
        }
        await _flushOne(
          localId: pending.id,
          send: () async =>
              _store.confirmDirect(pending.id, await _sendDirect(pending)),
          markFailed: () => _store.markDirectFailed(pending.id),
        );
      }
      // Les GESTES — réactions, suppressions — après les messages.
      //
      // L'ordre compte : une réaction à un message qui n'est pas encore
      // parti n'aurait aucune cible côté serveur. Les messages d'abord
      // garantit que la cible existe quand le geste arrive.
      for (final action in await _store.pendingActions()) {
        if (!_ws.isConnected) return;
        await _flushOne(
          localId: action.id,
          send: () async {
            await _applyAction(action);
            await _store.removeAction(action.id);
          },
          // Un geste refusé ne se réessaie pas : le message a pu être
          // supprimé entre-temps, et insister le ferait échouer sans fin.
          markFailed: () => _store.removeAction(action.id),
        );
      }

      for (final pending in await _store.pendingGroup()) {
        if (!_ws.isConnected) return;
        if (pending.pendingMedia != null) {
          // Même traitement qu'en tête-à-tête : `MediaSender` gère
          // lui-même l'échec définitif comme la mise en attente.
          await _sendGroupMedia(pending);
          continue;
        }
        await _flushOne(
          localId: pending.id,
          send: () => _sendGroup(pending.id),
          markFailed: () => _store.markGroupFailed(pending.id),
        );
      }

      // Les réglages en dernier : aucun ne dépend d'un message, et un
      // message qui attend compte plus qu'une épingle.
      for (final operation in await _store.pendingSyncOperations()) {
        if (!_ws.isConnected) return;
        await _flushOperation(operation);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flushOne({
    required String localId,
    required Future<void> Function() send,
    required Future<void> Function() markFailed,
  }) async {
    try {
      await send();
    } on NetworkException {
      // Toujours hors ligne : la ligne reste en attente, on retentera à la
      // prochaine reconnexion. Surtout pas un échec définitif.
    } on ApiException catch (exc) {
      // 5xx : le serveur est en peine, pas la requête — on garde en attente.
      // 4xx : il refuse ce message (plus un contact, groupe quitté…), le
      // retenter indéfiniment ne le fera jamais passer.
      if (exc.statusCode < 500) await markFailed();
    } catch (_) {
      // Panne inattendue (délai dépassé, réponse illisible) : traitée comme
      // une coupure réseau, donc réessayée plus tard.
    }
  }

  Future<void> _flushOperation(SyncOutboxOperation operation) async {
    final mutation = QueuedMutation.fromOperation(operation);
    if (mutation == null) {
      // Type inconnu : écrit par une version plus récente de l'application.
      // Même règle que pour les gestes — on ne bloque pas la file dessus.
      await _store.completeSyncOperation(operation.id);
      return;
    }
    try {
      await _sendMutation(mutation);
      await _store.completeSyncOperation(operation.id);
      if (!_replayed.isClosed) _replayed.add(mutation.key);
    } on NetworkException {
      // Toujours hors ligne : rien à compter, on retentera.
    } on ApiException catch (exc) {
      if (exc.statusCode < 500 ||
          operation.attempts + 1 >= maxMutationAttempts) {
        // Refusé (plus abonné, limite d'épingles atteinte…) : le retenter
        // ne le fera jamais passer. La prochaine lecture de la liste
        // remettra l'écran d'accord avec le serveur.
        await _store.completeSyncOperation(operation.id);
      } else {
        await _store.recordSyncOperationAttempt(operation.id);
      }
    } catch (_) {
      await _store.recordSyncOperationAttempt(operation.id);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _replayed.close();
  }
}

/// Gardé en vie pour toute la durée de l'app — voir main.dart, qui le
/// surveille au même titre que les notifications push et la signalisation
/// d'appel.
final outboxServiceProvider = Provider<OutboxService>((ref) {
  final store = ref.watch(pokouMessageStoreProvider);
  final messaging = ref.watch(messagingRepositoryProvider);
  final groups = ref.watch(groupRepositoryProvider);

  final service = OutboxService(
    store: store,
    ws: ref.watch(wsClientProvider),
    sendDirect: (pending) => messaging.send(
      recipientId: pending.recipientId,
      content: pending.content ?? '',
    ),
    sendMedia: (pending) => ref.read(mediaSenderProvider).envoyer(pending),
    sendGroupMedia: (pending) =>
        ref.read(mediaSenderProvider).envoyerGroupe(pending),
    applyAction: (action) => _rejouer(ref, action),
    sendMutation: (mutation) => mutation.send(ref.read(apiClientProvider)),
    sendGroup: (localId) async {
      // Le message de groupe en attente est relu au moment de l'envoi : son
      // contenu et son groupe vivent dans le cache, pas dans la fermeture.
      final queued = await store.pendingGroup();
      final message = queued.where((m) => m.id == localId).firstOrNull;
      if (message == null) return;
      final sent = await groups.send(
        groupId: message.groupId,
        content: message.content ?? '',
      );
      await store.confirmGroup(localId, sent);
    },
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

/// Rejouer un geste que la file a gardé.
///
/// Un `switch` et non une table de fonctions : il y en a trois, ils sont
/// courts, et une table obligerait à lire deux fichiers pour savoir ce que
/// « reaction:set » fait vraiment.
Future<void> _rejouer(Ref ref, PendingAction action) async {
  final messaging = ref.read(messagingRepositoryProvider);
  switch (action.kind) {
    case 'reaction:set':
      await messaging.setReaction(
        messageId: action.targetId,
        emoji: action.payload?['emoji'] as String? ?? '👍',
      );
    case 'reaction:remove':
      await messaging.removeReaction(action.targetId);
    case 'message:delete':
      await messaging.delete(action.targetId);
    default:
      // Un type inconnu vient d'une version PLUS RÉCENTE de l'application
      // dont la base a survécu à une réinstallation. On l'ignore plutôt que
      // de bloquer toute la file dessus.
      return;
  }
}
