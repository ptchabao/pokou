import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/crypto/e2ee_outcome.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/l10n/l10n_provider.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/sync/media_upload_progress.dart';
import '../../../core/sync/media_sender.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../../core/ws/ws_client.dart';
import '../../contacts/presentation/discussions_controller.dart';
import '../data/direct_message_model.dart';
import '../data/messaging_repository.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(
    apiClient: ref.watch(apiClientProvider),
    e2ee: ref.watch(e2eeServiceProvider),
    // Le cache n'est pas un confort ici : un message chiffré ne s'ouvre
    // qu'une fois, et le clair obtenu est la seule copie lisible qui
    // subsiste. Sans lui, rouvrir une conversation la rendrait illisible.
    store: ref.watch(pokouMessageStoreProvider),
  );
});

class MessagingState {
  const MessagingState({
    required this.messages,
    this.pendingIds = const {},
    this.failedIds = const {},
    this.sending = false,
    this.uploading = false,
    this.initialCacheLoaded = false,
    this.hasOlder = false,
    this.loadingOlder = false,
    this.error,
  });

  final List<DirectMessage> messages;

  /// Le serveur connaît des messages plus anciens que ceux chargés. Seule
  /// la dernière page était demandée : au-delà, l'historique restait sur le
  /// serveur sans moyen de le relire.
  final bool hasOlder;
  final bool loadingOlder;

  /// Écrits sur cet appareil mais pas encore acceptés par le serveur —
  /// affichés avec une horloge, et renvoyés tout seuls au retour du réseau
  /// (voir core/sync/outbox_service.dart). Tenus à part du modèle
  /// `DirectMessage`, qui décrit ce que le serveur connaît.
  final Set<String> pendingIds;

  /// Refusés définitivement par le serveur : à renvoyer sur geste explicite.
  final Set<String> failedIds;

  final bool sending;
  final bool uploading;
  final bool initialCacheLoaded;
  final String? error;

  MessagingState copyWith({
    List<DirectMessage>? messages,
    Set<String>? pendingIds,
    Set<String>? failedIds,
    bool? sending,
    bool? uploading,
    bool? initialCacheLoaded,
    bool? hasOlder,
    bool? loadingOlder,
    String? error,
  }) {
    return MessagingState(
      messages: messages ?? this.messages,
      pendingIds: pendingIds ?? this.pendingIds,
      failedIds: failedIds ?? this.failedIds,
      sending: sending ?? this.sending,
      uploading: uploading ?? this.uploading,
      initialCacheLoaded: initialCacheLoaded ?? this.initialCacheLoaded,
      hasOlder: hasOlder ?? this.hasOlder,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      error: error,
    );
  }
}

class ConversationKey {
  const ConversationKey({
    required this.myUserId,
    required this.contactUserId,
    this.contactPhone,
  });

  final int myUserId;
  final int contactUserId;

  /// Numéro du correspondant, quand il n'est PAS dans le carnet.
  ///
  /// Le serveur refuse d'écrire à un identifiant qu'on n'a fait que deviner
  /// (les `user_id` sont séquentiels) ; présenter le numéro est la preuve
  /// qu'on désigne bien quelqu'un — voir `_require_reachable` côté API.
  /// Utile au PREMIER message seulement : ensuite l'historique suffit.
  ///
  /// Délibérément HORS de `==` et `hashCode` : deux clés ne doivent pas
  /// désigner deux conversations différentes selon qu'on connaît ou non le
  /// numéro. L'identité d'une conversation, c'est la paire de personnes ;
  /// le numéro n'est qu'un laissez-passer transporté à côté.
  final String? contactPhone;

  @override
  bool operator ==(Object other) =>
      other is ConversationKey &&
      other.myUserId == myUserId &&
      other.contactUserId == contactUserId;

  @override
  int get hashCode => Object.hash(myUserId, contactUserId);
}

/// Hors ligne, la conversation reste lisible et on peut continuer à écrire :
/// tout passe par le cache local (voir core/storage/pokou_message_store.dart),
/// que le réseau alimente au lieu de le remplacer.
class MessagingController extends StateNotifier<MessagingState> {
  MessagingController(
    this._repository,
    this._store,
    this._ws,
    this._key,
    this._onConversationChanged,
    this._l,
    this._sender,
    this._progress,
    this._media,
  ) : super(
        _recentConversations.containsKey(_key)
            ? MessagingState(
                messages: _recentConversations[_key]!.messages,
                pendingIds: _recentConversations[_key]!.pendingIds,
                failedIds: _recentConversations[_key]!.failedIds,
                initialCacheLoaded: true,
              )
            : const MessagingState(messages: [], initialCacheLoaded: false),
      ) {
    _loadHistory();
    _subscription = _ws.events.listen(_onEvent);
    // La file d'attente renvoie les messages en attente depuis l'extérieur
    // de cet écran : elle prévient ici pour qu'une conversation ouverte voie
    // son horloge se changer en coche sans recharger.
    _outboxSubscription = _store.updates.listen(_onOutboxUpdate);
    _syncSubscription = _store.syncUpdates.listen(_onSyncUpdate);
  }

  /// Cache mémoire des conversations récentes pour afficher les messages
  /// dès la trame 0 à la réouverture sans clignotement ni temps d'attente.
  static final Map<ConversationKey, CachedConversation> _recentConversations =
      {};

  /// Les traductions, injectées : un contrôleur n'a pas de `BuildContext`,
  /// et ses messages d'erreur finissent pourtant à l'écran.
  final L _l;

  final MessagingRepository _repository;
  final MediaRepository _media;

  /// Le chemin d'envoi d'une pièce jointe, PARTAGÉ avec la file d'attente :
  /// l'écran et la reprise après coupure doivent faire exactement la même
  /// chose, sinon elles divergent — et la divergence ne se voit qu'après
  /// une coupure réseau, c'est-à-dire chez l'utilisateur.
  final MediaSender _sender;
  final MediaUploadProgress _progress;
  final PokouMessageStore _store;
  final WsClient _ws;
  final ConversationKey _key;

  /// Appelé quand cette conversation vient de changer d'une façon qui rend
  /// la liste des discussions fausse : des messages reçus marqués lus (la
  /// pastille doit disparaître) ou un message envoyé (la conversation doit
  /// remonter en tête).
  ///
  /// Le second cas manquait, et c'est ce qui obligeait à tirer pour
  /// rafraîchir en revenant de la conversation. Le serveur prévient
  /// désormais aussi l'expéditeur (`conversation:updated`), mais ce rappel
  /// reste utile : il rend la liste juste dès l'accusé du serveur, sans
  /// attendre un aller-retour par le WebSocket.
  ///
  /// Un rappel et non un `Ref` : ce contrôleur n'a pas à connaître quel
  /// écran s'intéresse à l'information.
  final void Function() _onConversationChanged;
  StreamSubscription? _subscription;
  StreamSubscription<OutboxUpdate>? _outboxSubscription;
  StreamSubscription<SyncInboxEvent>? _syncSubscription;

  Future<void> _onSyncUpdate(SyncInboxEvent event) async {
    final raw = event.payload['message'];
    if (raw is Map<String, dynamic>) {
      final message = DirectMessage.fromJson(raw);
      if (!_belongsToConversation(message)) return;
      // Pas de préchargement pour un message encore CHIFFRÉ : sa clé n'est
      // pas encore connue, et le fichier téléchargé ne serait qu'un bloc
      // illisible. Il sera chargé une fois le message ouvert.
      if (message.media != null &&
          !message.isEncrypted &&
          (message.messageType == 'IMAGE' || message.messageType == 'VIDEO')) {
        unawaited(
          _media.resolveLocalFile(
            message.media!.id,
            extension: mediaExtension(message.media!),
          ),
        );
      }
    } else if (event.type != 'message:deleted') {
      return;
    }
    if (!mounted) return;
    _applyCache(await _readCache());
  }

  /// Le cache d'abord — instantané et seul disponible hors ligne — puis le
  /// serveur, qui le met à jour. Toute lecture repasse par le cache : un
  /// seul chemin, donc un seul ordre de tri, et les messages en attente
  /// apparaissent au bon endroit sans logique de fusion à part.
  Future<void> _loadHistory() async {
    final cached = await _readCache();
    if (!mounted) return;
    _applyCache(cached);

    try {
      final page = await _repository.getConversationPage(_key.contactUserId);
      final history = page.items;
      _serverLoaded = history.length;
      await _store.saveDirect(history);
      // Un message supprimé pendant qu'on était hors ligne doit disparaître :
      // l'événement WS `message:deleted` a été manqué.
      await _store.reconcileDirect(
        myUserId: _key.myUserId,
        contactUserId: _key.contactUserId,
        serverMessages: history,
      );
      if (!mounted) return;
      _applyCache(await _readCache());
      state = state.copyWith(hasOlder: _serverLoaded < page.total);
      _markIncomingAsRead(history);
      // Pré-téléchargement silencieux en tâche de fond comme WhatsApp
      for (final m in history) {
        // Pas un message resté chiffré (clé illisible) : son fichier n'est
        // qu'un bloc opaque, qu'il ne faut ni télécharger ni afficher.
        if (m.media != null &&
            !m.isEncrypted &&
            (m.messageType == 'IMAGE' || m.messageType == 'VIDEO')) {
          unawaited(
            _media.resolveLocalFile(
              m.media!.id,
              extension: mediaExtension(m.media!),
            ),
          );
        }
      }
    } on NetworkException {
      // Hors ligne : le cache EST la réponse. Une erreur ne se justifie que
      // s'il n'y a rien à montrer du tout.
      if (mounted && cached.isEmpty) {
        state = state.copyWith(
          error: _l.convOfflineNotCached,
          initialCacheLoaded: true,
        );
      }
    } catch (_) {
      if (mounted && cached.isEmpty) {
        state = state.copyWith(
          error: _l.convLoadFailed,
          initialCacheLoaded: true,
        );
      }
    }
  }

  /// Combien de messages du serveur ont été chargés, depuis le plus récent.
  /// Compté côté SERVEUR et non dans le cache : un vieux cache avec un trou
  /// au milieu ferait sinon reprendre la pagination après le trou.
  int _serverLoaded = 0;

  /// La page précédente de l'historique. Jamais réconciliée avec le cache :
  /// la réconciliation retire les messages absents de la fenêtre reçue, et
  /// une page ANCIENNE ferait disparaître tous les messages récents.
  Future<void> loadOlder() async {
    if (!state.hasOlder || state.loadingOlder) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repository.getConversationPage(
        _key.contactUserId,
        skip: _serverLoaded,
      );
      _serverLoaded += page.items.length;
      await _store.saveDirect(page.items);
      if (!mounted) return;
      _applyCache(await _readCache());
      state = state.copyWith(
        loadingOlder: false,
        hasOlder: page.items.isNotEmpty && _serverLoaded < page.total,
      );
    } catch (_) {
      // Hors ligne ou panne : on garde ce qu'on a, le prochain geste vers
      // le haut réessaiera.
      if (mounted) state = state.copyWith(loadingOlder: false);
    }
  }

  Future<CachedConversation> _readCache() => _store.directConversation(
    myUserId: _key.myUserId,
    contactUserId: _key.contactUserId,
  );

  void _applyCache(CachedConversation cached) {
    _recentConversations[_key] = cached;
    state = state.copyWith(
      messages: cached.messages,
      pendingIds: cached.pendingIds,
      failedIds: cached.failedIds,
      initialCacheLoaded: true,
    );
  }

  void _onOutboxUpdate(OutboxUpdate update) {
    final confirmed = update.direct;
    if (confirmed != null) {
      if (!_belongsToConversation(confirmed)) return;
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == update.localId) confirmed else m,
        ],
        pendingIds: state.pendingIds.difference({update.localId}),
      );
      return;
    }
    if (update.failed && state.pendingIds.contains(update.localId)) {
      state = state.copyWith(
        pendingIds: state.pendingIds.difference({update.localId}),
        failedIds: {...state.failedIds, update.localId},
      );
    }
  }

  /// Marque comme lus les messages reçus, puis prévient la liste des
  /// discussions. Ce second temps est indispensable : le serveur ne pousse
  /// l'accusé de lecture qu'à l'EXPÉDITEUR (c'est lui que ça intéresse), donc
  /// notre propre pastille « non lus » n'apprend rien de l'événement
  /// `message:status` et restait affichée jusqu'à un tiré-pour-rafraîchir.
  ///
  /// Les accusés sont ATTENDUS avant de prévenir : lancer les deux en
  /// parallèle laisserait le rafraîchissement repartir avant que le serveur
  /// ait enregistré les lectures — et rapporter exactement le compteur qu'on
  /// cherche à effacer.
  Future<void> _markIncomingAsRead(List<DirectMessage> messages) async {
    final unread = [
      for (final message in messages)
        if (message.senderId == _key.contactUserId &&
            message.status != DirectMessageStatus.read)
          message,
    ];
    // Aucun non-lu : pas de requête, et surtout pas de rafraîchissement de la
    // liste — ouvrir une conversation déjà lue ne doit rien coûter.
    if (unread.isEmpty) return;
    try {
      await Future.wait(
        unread.map((message) => _repository.markRead(message.id)),
      );
    } catch (_) {
      // Best-effort : un accusé perdu (hors ligne) se rejouera à la
      // prochaine ouverture de la conversation.
    }
    if (mounted) _onConversationChanged();
  }

  bool _belongsToConversation(DirectMessage message) =>
      (message.senderId == _key.contactUserId &&
          message.recipientId == _key.myUserId) ||
      (message.senderId == _key.myUserId &&
          message.recipientId == _key.contactUserId);

  Future<void> _onEvent(Map<String, dynamic> event) async {
    final type = event['type'];

    // Suppression poussée par l'expéditeur : l'événement ne porte qu'un id
    // (le message n'existe plus côté serveur), pas un message sérialisé —
    // il se traite donc avant le parsing commun ci-dessous.
    if (type == 'message:deleted') {
      final deletedId = event['message_id'] as String?;
      if (deletedId == null) return;
      if (event['proof'] == true) {
        // Mode preuve : le message reste ici, barré, avec le texte que cet
        // appareil a déjà ouvert.
        final at = DateTime.now().toUtc();
        await _store.markDirectDeleted(deletedId, at);
        state = state.copyWith(
          messages: [
            for (final m in state.messages)
              if (m.id == deletedId) m.copyWith(deletedAt: at) else m,
          ],
        );
        return;
      }
      // Retiré aussi du cache, sinon il réapparaîtrait à la réouverture.
      _store.deleteDirect(deletedId);
      state = state.copyWith(
        messages: state.messages
            .where((message) => message.id != deletedId)
            .toList(),
      );
      return;
    }

    if (type != 'message:new' && type != 'message:status') return;

    final received = DirectMessage.fromJson(
      event['message'] as Map<String, dynamic>,
    );
    if (!_belongsToConversation(received)) return;

    // Un accusé (distribué, lu) ne change QUE le statut. Le traiter comme un
    // message reçu faisait tenter d'ouvrir notre propre enveloppe — ce qui
    // échoue toujours, la chaîne d'envoi n'étant pas celle de réception —
    // puis réécrire la ligne avec sa version chiffrée : la photo qu'on
    // venait d'envoyer perdait sa clé et sa légende.
    if (type == 'message:status') {
      final current = state.messages
          .where((m) => m.id == received.id)
          .firstOrNull;
      if (current == null) return;
      final updated = current.copyWith(status: received.status);
      _store.saveDirect([updated]);
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == updated.id) updated else m,
        ],
      );
      return;
    }

    // Déchiffré AVANT toute autre chose. Un message poussé par le WebSocket
    // ne passe par aucune des méthodes du dépôt : sans cette ligne, le
    // chiffré partirait tel quel dans le cache local et la conversation
    // afficherait du base64 — en direct seulement, pas après rechargement,
    // ce qui rend la panne particulièrement pénible à reproduire.
    final message = await _repository.decryptIncoming(
      received,
      _key.contactUserId,
    );

    // Écrit dans le cache dans les deux cas : l'app doit pouvoir être tuée
    // juste après avoir reçu un message sans le perdre.
    _store.saveDirect([message]);

    if (type == 'message:new') {
      state = state.copyWith(messages: [...state.messages, message]);
      // Pré-téléchargement immédiat des images reçues (expérience WhatsApp)
      if (message.media != null &&
          !message.isEncrypted &&
          (message.messageType == 'IMAGE' || message.messageType == 'VIDEO')) {
        unawaited(
          _media.resolveLocalFile(
            message.media!.id,
            extension: mediaExtension(message.media!),
          ),
        );
      }
      // Passe par le même chemin que l'historique : marquer lu ET faire
      // retirer la pastille, sinon un message arrivé pendant qu'on lit la
      // conversation en laisserait une derrière lui.
      if (message.senderId == _key.contactUserId) {
        _markIncomingAsRead([message]);
      }
    } else {
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == message.id) message else m,
        ],
      );
    }
  }

  /// Le message apparaît tout de suite et est écrit sur l'appareil AVANT
  /// toute tentative réseau : c'est ce qui permet d'écrire hors ligne et de
  /// retrouver ses messages en attente après un redémarrage de l'app.
  Future<void> send(String text, {String? replyToId}) async {
    if (text.trim().isEmpty) return;

    final optimistic = DirectMessage(
      id: _store.newLocalId(),
      senderId: _key.myUserId,
      recipientId: _key.contactUserId,
      messageType: 'TEXT',
      content: text,
      mediaAssetId: null,
      media: null,
      status: DirectMessageStatus.sent,
      createdAt: DateTime.now(),
      replyToId: replyToId,
    );
    await _store.saveDirect([optimistic], pending: true);
    if (!mounted) return;
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      pendingIds: {...state.pendingIds, optimistic.id},
      error: null,
    );

    await _attemptSend(optimistic);
  }

  /// Renvoi manuel d'un message que le serveur a refusé (plus un contact,
  /// contenu rejeté…) — la file d'attente ne réessaie pas ceux-là toute
  /// seule, justement parce qu'ils échoueraient indéfiniment.
  Future<void> retry(String localId) async {
    final message = state.messages.where((m) => m.id == localId).firstOrNull;
    if (message == null) return;
    await _store.saveDirect([message], pending: true);
    if (!mounted) return;
    state = state.copyWith(
      pendingIds: {...state.pendingIds, localId},
      failedIds: state.failedIds.difference({localId}),
      error: null,
    );
    // Une pièce jointe repart par le même chemin qu'à l'envoi : fichier,
    // chiffrement, téléversement. `_attemptSend` ne sait envoyer que du
    // texte — il expédiait la légende seule et perdait le fichier.
    if (message.pendingMedia != null) {
      _progress.set(localId, MediaSendPhase.preparation);
      await _sender.envoyer(message);
      return;
    }
    await _attemptSend(message);
  }

  Future<void> _attemptSend(DirectMessage optimistic) async {
    try {
      final confirmed = await _repository.send(
        recipientId: _key.contactUserId,
        content: optimistic.content ?? '',
        recipientPhone: _key.contactPhone,
        replyToId: optimistic.replyToId,
      );
      await _store.confirmDirect(optimistic.id, confirmed);
      if (!mounted) return;
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == optimistic.id) confirmed else m,
        ],
        pendingIds: state.pendingIds.difference({optimistic.id}),
      );
      // La conversation vient de remonter en tête de la liste d'accueil.
      _onConversationChanged();
    } on EncryptionUnavailableException {
      // AVANT les autres, et surtout avant le `catch` final qui traite
      // l'inconnu comme une coupure : un message refusé faute de
      // chiffrement ne doit NI rester en attente NI être réessayé. La file
      // le représenterait indéfiniment au même mur, et l'horloge affichée
      // laisserait croire qu'il est parti.
      //
      // On retire donc l'entrée optimiste — l'écran remet le texte dans le
      // champ et affiche pourquoi — puis on relance l'exception : c'est
      // l'écran qui parle à l'utilisateur, pas ce contrôleur.
      await _store.deleteDirect(optimistic.id);
      if (mounted) {
        state = state.copyWith(
          messages: [
            for (final m in state.messages)
              if (m.id != optimistic.id) m,
          ],
          pendingIds: state.pendingIds.difference({optimistic.id}),
        );
      }
      rethrow;
    } on NetworkException {
      // Hors ligne : le message RESTE en attente et part tout seul à la
      // reconnexion. Pas d'erreur affichée — WhatsApp montre une horloge,
      // pas un échec, et c'est ce que l'horloge signifie ici aussi.
    } on ApiException catch (exc) {
      // 5xx : le serveur est en peine, la file réessaiera. 4xx : il refuse
      // ce message, le garder en attente ne servirait à rien.
      if (exc.statusCode >= 500) return;
      await _store.markDirectFailed(optimistic.id);
      if (!mounted) return;
      state = state.copyWith(
        pendingIds: state.pendingIds.difference({optimistic.id}),
        failedIds: {...state.failedIds, optimistic.id},
        error: exc.message,
      );
    } catch (_) {
      // Délai dépassé, réponse illisible : traité comme une coupure, donc
      // réessayé plus tard plutôt que perdu.
    }
  }

  /// Fenêtre de modification, côté client.
  ///
  /// Doit rester alignée sur `MESSAGE_EDIT_WINDOW` côté serveur. Elle n'est
  /// PAS la règle — le serveur refuse, quoi qu'affiche l'application, et
  /// c'est très bien : l'horloge d'un téléphone se règle à la main. Elle
  /// sert seulement à ne pas proposer un geste voué à échouer.
  static const editWindow = Duration(minutes: 3);

  /// Ce message peut-il encore être modifié ?
  ///
  /// Trois conditions, et chacune correspond à un refus du serveur :
  /// c'est le mien, c'est du TEXTE (remplacer la légende d'une photo
  /// mentirait sur un fichier déjà téléchargé), et la fenêtre n'est pas
  /// passée.
  bool canEdit(DirectMessage message) {
    if (message.senderId != _key.myUserId) return false;
    if (message.messageType != 'TEXT') return false;
    if (PokouMessageStore.isLocalId(message.id)) return false;
    return DateTime.now().difference(message.createdAt) < editWindow;
  }

  /// Applique une correction, en optimiste puis confirmée.
  ///
  /// Renvoie le motif du refus, ou `null` si c'est passé. Le serveur peut
  /// refuser alors que l'écran proposait le geste — décalage d'horloge,
  /// message envoyé il y a juste trois minutes — et il faut le DIRE plutôt
  /// que de laisser le texte revenir à sa version d'avant sans explication.
  Future<String?> editMessage(String messageId, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return _l.convEmptyEdit;

    try {
      var updated = await _repository.edit(
        messageId: messageId,
        recipientId: _key.contactUserId,
        content: trimmed,
      );
      if (updated.proofMode && updated.originalContent == null) {
        // Mode preuve : la version d'origine reste lisible de tous.
        final before = state.messages.where((m) => m.id == messageId).firstOrNull;
        final original = before?.originalContent ?? before?.content;
        if (original != null) updated = updated.copyWith(originalContent: original);
      }
      await _store.saveDirect([updated]);
      if (!mounted) return null;
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == messageId) updated else m,
        ],
      );
      return null;
    } on ApiException catch (exc) {
      // 409 : la fenêtre est passée. C'est le cas courant, et le message du
      // serveur porte déjà la durée exacte.
      return exc.message;
    } catch (_) {
      return _l.convEditFailed;
    }
  }

  /// Fait avancer une commande — le geste du vendeur.
  ///
  /// Renvoie le motif du refus, ou `null`. Le serveur refuse si
  /// l'expéditeur n'est pas le vendeur du produit : c'est lui qui fait foi,
  /// l'écran ne masque les boutons que par courtoisie.
  Future<String?> sendOrderUpdate({
    required int productId,
    required String status,
  }) async {
    try {
      final message = await _repository.sendOrderUpdate(
        recipientId: _key.contactUserId,
        productId: productId,
        status: status,
      );
      await _store.saveDirect([message]);
      if (!mounted) return null;
      state = state.copyWith(messages: [...state.messages, message]);
      return null;
    } on ApiException catch (exc) {
      return exc.message;
    } catch (_) {
      return _l.convOrderUpdateFailed;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    // Un message jamais parti n'existe que localement : rien à demander au
    // serveur, qui répondrait 404.
    if (PokouMessageStore.isLocalId(messageId)) {
      await _store.deleteDirect(messageId);
      // Les gestes qui le visaient n'ont plus d'objet : une réaction en
      // file repartirait vers un message effacé et échouerait sans fin.
      await _store.dropActionsFor(messageId);
      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages
            .where((message) => message.id != messageId)
            .toList(),
        pendingIds: state.pendingIds.difference({messageId}),
        failedIds: state.failedIds.difference({messageId}),
      );
      return;
    }

    try {
      if (await _repository.delete(messageId)) {
        final at = DateTime.now().toUtc();
        await _store.markDirectDeleted(messageId, at);
        if (!mounted) return;
        state = state.copyWith(
          messages: [
            for (final m in state.messages)
              if (m.id == messageId) m.copyWith(deletedAt: at) else m,
          ],
        );
        return;
      }
      await _store.deleteDirect(messageId);
      await _store.dropActionsFor(messageId);
      state = state.copyWith(
        messages: state.messages
            .where((message) => message.id != messageId)
            .toList(),
      );
    } on NetworkException {
      // ── Hors ligne : la suppression est GARDÉE ─────────────────────
      //
      // Elle échouait avec « suppression impossible », et le message
      // restait — alors que la personne venait de décider qu'il ne devait
      // plus être là. C'est le geste où l'échec silencieux coûte le plus
      // cher : on croit avoir retiré quelque chose qui reste visible chez
      // l'autre.
      //
      // Le message disparaît d'ici tout de suite, et la file le supprimera
      // côté serveur. Les autres gestes qui le visaient partent avec :
      // réagir à un message qu'on supprime est contradictoire, et c'est la
      // suppression qui gagne.
      // L'ORDRE compte : `dropActionsFor` efface TOUT ce qui vise cette
      // cible. Mettre la suppression en file avant l'aurait emportée avec
      // les réactions — et le message serait resté chez l'autre.
      await _store.deleteDirect(messageId);
      await _store.dropActionsFor(messageId);
      await _store.enqueueAction(kind: 'message:delete', targetId: messageId);
      if (!mounted) return;
      state = state.copyWith(
        messages: state.messages
            .where((message) => message.id != messageId)
            .toList(),
      );
    } catch (_) {
      state = state.copyWith(error: _l.convDeleteFailed);
    }
  }

  /// Transfère vers un AUTRE contact : la copie créée appartient à la
  /// conversation du destinataire, pas à celle affichée ici — on ne l'ajoute
  /// donc pas à `state.messages` (elle y apparaîtrait comme un message envoyé
  /// au contact courant, ce qui est faux). Le destinataire la reçoit en direct
  /// via l'événement WS `message:new` que le backend lui pousse.
  Future<bool> forwardMessage(String messageId, int recipientId) async {
    try {
      await _repository.forward(messageId: messageId, recipientId: recipientId);
      return true;
    } on ApiException catch (exc) {
      // 409 : message chiffré de bout en bout. Le serveur ne détient que le
      // chiffré, scellé pour le destinataire d'ORIGINE ; c'est l'appareil,
      // qui a le clair, qui le renvoie.
      if (exc.statusCode == 409) {
        // Son propre try : une exception levée dans une clause `on` ne
        // serait pas rattrapée par le `catch` voisin, et remonterait jusqu'à
        // l'écran sans message.
        try {
          if (await _forwardFromDevice(messageId, recipientId)) return true;
        } catch (_) {
          // Destinataire dont l'identité a changé, hors ligne, fichier
          // illisible : le transfert n'a pas eu lieu, on le dit.
        }
      }
    } catch (_) {
      // Voir ci-dessous.
    }
    state = state.copyWith(error: _l.convForwardFailedMsg);
    return false;
  }

  /// Renvoie un message chiffré à [recipientId] depuis ce qu'on en a ici.
  ///
  /// Un texte repart scellé pour lui. Un fichier repart du fichier déchiffré
  /// local, par le même chemin qu'un envoi ordinaire (MediaSender) : clé
  /// neuve, chiffré si le destinataire sait l'ouvrir, et la bulle attend
  /// dans sa conversation tant que le réseau manque.
  Future<bool> _forwardFromDevice(String messageId, int recipientId) async {
    final local = state.messages.where((m) => m.id == messageId).firstOrNull;
    if (local == null || local.isEncrypted) return false;

    final media = local.media;
    if (local.mediaAssetId != null && media != null) {
      final file = await _media.resolveLocalFile(
        media.id,
        extension: mediaExtension(media),
      );
      final copy = DirectMessage(
        id: _store.newLocalId(),
        senderId: _key.myUserId,
        recipientId: recipientId,
        messageType: local.messageType,
        content: local.content,
        mediaAssetId: null,
        media: null,
        status: DirectMessageStatus.sent,
        createdAt: DateTime.now(),
        pendingMedia: PendingMedia(
          path: file.path,
          filename: media.originalFilename ?? file.uri.pathSegments.last,
          mimeType: media.mimeType,
          caption: local.content,
        ),
      );
      await _store.saveDirect([copy], pending: true);
      await _sender.envoyer(copy);
      // Parti, ou resté en file faute de réseau (il repartira) : dans les
      // deux cas le geste est gardé. Seul un refus définitif est un échec.
      final failed = await _store.isDirectFailed(copy.id);
      return !failed;
    }

    final text = local.content;
    if (text == null || text.trim().isEmpty) return false;
    final sent = await _repository.send(recipientId: recipientId, content: text);
    await _store.saveDirect([sent]);
    return true;
  }

  /// Envoyer une pièce jointe — la bulle apparaît AVANT le téléversement.
  ///
  /// ── Ce que ça change ────────────────────────────────────────────────
  ///
  /// L'ancienne version téléversait, puis envoyait, et n'écrivait rien
  /// entre les deux. Une coupure au mauvais moment effaçait le geste : ni
  /// bulle, ni fichier, ni trace, juste un message d'erreur. Sur un réseau
  /// mobile, « au mauvais moment » arrive souvent — et l'utilisateur
  /// renvoie, ce qui en fait deux quand le premier avait fini par passer.
  ///
  /// Le commentaire d'origine invoquait une raison : « il faudrait recopier
  /// ses octets sur le disque pour survivre à un redémarrage ». Elle ne
  /// tenait pas — le fichier EST déjà sur le disque, on n'en garde que le
  /// chemin. Le seul cas perdu est celui où il disparaît entre-temps, et il
  /// se traite comme un échec définitif plutôt que comme une raison de ne
  /// rien mettre en file.
  Future<void> sendMedia({
    required String path,
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String messageType,
    String? caption,
    bool viewOnce = false,
  }) async {
    final localId = _store.newLocalId();
    final enAttente = DirectMessage(
      id: localId,
      senderId: _key.myUserId,
      recipientId: _key.contactUserId,
      messageType: messageType,
      content: caption,
      mediaAssetId: null,
      media: null,
      status: DirectMessageStatus.sent,
      createdAt: DateTime.now(),
      viewOnce: viewOnce,
      pendingMedia: PendingMedia(
        path: path,
        filename: filename,
        mimeType: mimeType,
        caption: caption,
      ),
    );

    // Écrite d'abord, envoyée ensuite : c'est tout l'objet du changement.
    await _store.saveDirect([enAttente], pending: true);
    state = state.copyWith(
      messages: [...state.messages, enAttente],
      pendingIds: {...state.pendingIds, localId},
      error: null,
    );
    _progress.set(localId, MediaSendPhase.preparation);

    // Rien à faire du résultat : `confirmDirect` émet une mise à jour que
    // `_onOutboxUpdate` transforme déjà en bulle confirmée. Et si ça n'est
    // pas parti, la ligne reste en attente et la file reprendra — sans
    // message d'erreur, puisqu'il n'y a rien à corriger et rien de perdu.
    await _sender.envoyer(enAttente);
  }

  /// Envoyer un média qui EXISTE DÉJÀ sur le serveur — un sticker.
  ///
  /// ── Pourquoi `sendMedia` ne convenait pas ──────────────────────────
  ///
  /// `sendMedia` téléverse d'abord. Un sticker, lui, appartient au pack :
  /// son image est déjà là, partagée par tous ceux qui l'ont installé. La
  /// re-téléverser à chaque envoi créerait une copie du même fichier par
  /// sticker envoyé, et ferait payer un aller-retour de plusieurs dizaines
  /// de kilo-octets à un geste censé être instantané.
  ///
  /// C'est aussi pourquoi `POST /messages` a dû recevoir une exception à sa
  /// règle « la pièce jointe doit venir de l'expéditeur » : voir
  /// `sticker_service.sender_may_attach`.
  Future<void> sendExistingMedia({
    required int mediaAssetId,
    required String messageType,
  }) async {
    if (state.sending) return;
    state = state.copyWith(sending: true, error: null);
    try {
      final sent = await _repository.sendMedia(
        recipientId: _key.contactUserId,
        recipientPhone: _key.contactPhone,
        messageType: messageType,
        mediaAssetId: mediaAssetId,
      );
      await _store.saveDirect([sent]);
      state = state.copyWith(
        messages: [...state.messages, sent],
        sending: false,
      );
    } on NetworkException {
      state = state.copyWith(sending: false, error: _l.convOfflineAttachment);
    } catch (_) {
      state = state.copyWith(sending: false, error: _l.stickerSendFailed);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _outboxSubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }
}

final messagingControllerProvider = StateNotifierProvider.autoDispose
    .family<MessagingController, MessagingState, ConversationKey>((ref, key) {
      return MessagingController(
        ref.watch(messagingRepositoryProvider),
        ref.watch(pokouMessageStoreProvider),
        ref.watch(wsClientProvider),
        key,
        () => ref.invalidate(discussionsProvider),
        ref.watch(appL10nProvider),
        ref.watch(mediaSenderProvider),
        ref.watch(mediaUploadProgressProvider.notifier),
        ref.watch(mediaRepositoryProvider),
      );
    });
