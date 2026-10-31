import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/sync/offline_list.dart';
import '../../../core/media/media_repository.dart'
    show MediaRepository, mediaExtension;
import '../../../core/l10n/l10n_provider.dart';
import '../../../core/providers.dart';
import '../../../core/sync/media_upload_progress.dart';
import '../../../core/sync/media_sender.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../../core/ws/ws_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../messaging/data/direct_message_model.dart'
    show MessageReplyPreview, PendingMedia;
import '../data/group_model.dart';
import '../data/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(apiClient: ref.watch(apiClientProvider));
});

/// Liste des groupes de l'utilisateur. `FutureProvider` (et non un
/// StateNotifier) : c'est une lecture simple, rafraîchie par `ref.invalidate`
/// après création/ajout/départ.
final myGroupsProvider = StreamProvider<List<Group>>((ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return offlineList(
    store: ref.watch(pokouMessageStoreProvider),
    scope: 'groups',
    fetch: repository.listMyGroupsRaw,
    parse: Group.fromJson,
  );
});

class GroupChatState {
  const GroupChatState({
    required this.messages,
    this.group,
    this.pendingIds = const {},
    this.failedIds = const {},
    this.sending = false,
    this.uploading = false,
    this.initialCacheLoaded = false,
    this.hasOlder = false,
    this.loadingOlder = false,
    this.error,
  });

  final List<GroupMessage> messages;
  final Group? group;

  /// Voir MessagingState.hasOlder — même manque, même correctif.
  final bool hasOlder;
  final bool loadingOlder;

  /// Écrits ici mais pas encore acceptés par le serveur — voir
  /// MessagingState.pendingIds, même mécanique.
  final Set<String> pendingIds;
  final Set<String> failedIds;

  final bool sending;
  final bool uploading;
  final bool initialCacheLoaded;
  final String? error;

  GroupChatState copyWith({
    List<GroupMessage>? messages,
    Group? group,
    Set<String>? pendingIds,
    Set<String>? failedIds,
    bool? sending,
    bool? uploading,
    bool? initialCacheLoaded,
    bool? hasOlder,
    bool? loadingOlder,
    String? error,
  }) {
    return GroupChatState(
      messages: messages ?? this.messages,
      group: group ?? this.group,
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

/// Pendant de MessagingController pour un groupe. Même forme : chargement de
/// l'historique à la construction, abonnement au flux WS partagé, état en
/// mémoire jeté à la fermeture de l'écran (autoDispose).
class GroupChatController extends StateNotifier<GroupChatState> {
  GroupChatController(
    this._repository,
    this._media,
    this._store,
    this._ws,
    this.groupId,
    this._myUserId,
    this._sender,
    this._progress,
    this._l,
  ) : super(
        _recentGroupConversations.containsKey(groupId)
            ? GroupChatState(
                messages: _recentGroupConversations[groupId]!.messages,
                pendingIds: _recentGroupConversations[groupId]!.pendingIds,
                failedIds: _recentGroupConversations[groupId]!.failedIds,
                initialCacheLoaded: true,
              )
            : const GroupChatState(messages: [], initialCacheLoaded: false),
      ) {
    _load();
    _subscription = _ws.events.listen(_onEvent);
    _outboxSubscription = _store.updates.listen(_onOutboxUpdate);
    _syncSubscription = _store.syncUpdates.listen(_onSyncUpdate);
  }

  /// Cache mémoire des conversations de groupe récentes pour afficher les
  /// messages dès la trame 0 à la réouverture sans clignotement ni temps d'attente.
  static final Map<int, CachedGroupConversation> _recentGroupConversations = {};

  /// Les traductions, injectées : un contrôleur n'a pas de `BuildContext`,
  /// et ses messages d'erreur finissent pourtant à l'écran.
  final L _l;

  final GroupRepository _repository;
  final MediaRepository _media;

  /// Le chemin d'envoi d'une pièce jointe, PARTAGÉ avec les conversations à
  /// deux et avec la file d'attente.
  final MediaSender _sender;
  final MediaUploadProgress _progress;
  final PokouMessageStore _store;
  final WsClient _ws;
  final int groupId;

  /// Nécessaire pour attribuer un message composé hors ligne à son auteur —
  /// c'est ce qui décide de quel côté la bulle s'affiche avant que le
  /// serveur ne confirme.
  final int? _myUserId;

  StreamSubscription? _subscription;
  StreamSubscription<OutboxUpdate>? _outboxSubscription;
  StreamSubscription<SyncInboxEvent>? _syncSubscription;

  Future<void> _onSyncUpdate(SyncInboxEvent event) async {
    if (event.type != 'group:message:new') return;
    final raw = event.payload['message'];
    if (raw is! Map<String, dynamic> || raw['group_id'] != groupId) return;
    final mediaId = raw['media_asset_id'] as int?;
    final mediaType = raw['message_type'] as String?;
    if (mediaId != null && (mediaType == 'IMAGE' || mediaType == 'VIDEO')) {
      unawaited(_media.resolveLocalFile(mediaId));
    }
    if (!mounted) return;
    _applyCache(await _store.groupConversation(groupId));
  }

  /// Cache d'abord, réseau ensuite — voir MessagingController._loadHistory.
  /// Le détail du groupe (liste des membres) n'est pas mis en cache : sans
  /// lui les bulles reçues perdent seulement l'étiquette d'auteur, alors
  /// qu'un cache de composition de groupe périmé afficherait des membres
  /// partis comme présents.
  Future<void> _load() async {
    final cached = await _store.groupConversation(groupId);
    if (!mounted) return;
    _applyCache(cached);

    try {
      final group = await _repository.getGroup(groupId);
      final page = await _repository.getMessagesPage(groupId);
      final messages = page.items;
      _oldestFetched = messages.isEmpty ? null : messages.first.createdAt;
      await _store.saveGroup(messages);
      await _store.reconcileGroup(groupId: groupId, serverMessages: messages);
      if (!mounted) return;
      state = state.copyWith(group: group, hasOlder: page.hasMore);
      _applyCache(await _store.groupConversation(groupId));

      // Pré-téléchargement silencieux des médias en arrière-plan comme WhatsApp
      for (final m in messages) {
        if (m.media != null &&
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
      if (mounted && cached.isEmpty) {
        state = state.copyWith(
          error: _l.groupOfflineNotCached,
          initialCacheLoaded: true,
        );
      }
    } catch (_) {
      if (mounted && cached.isEmpty) {
        state = state.copyWith(
          error: _l.groupLoadFailed,
          initialCacheLoaded: true,
        );
      }
    }
  }

  /// Le plus ancien message reçu DU SERVEUR, curseur de la page suivante.
  /// Pas le plus ancien du cache : un vieux cache avec un trou au milieu
  /// ferait reprendre la pagination après le trou.
  DateTime? _oldestFetched;

  /// La page précédente — jamais réconciliée, voir
  /// MessagingController.loadOlder.
  Future<void> loadOlder() async {
    final cursor = _oldestFetched;
    if (cursor == null || !state.hasOlder || state.loadingOlder) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repository.getMessagesPage(groupId, before: cursor);
      if (page.items.isNotEmpty) _oldestFetched = page.items.first.createdAt;
      await _store.saveGroup(page.items);
      if (!mounted) return;
      _applyCache(await _store.groupConversation(groupId));
      state = state.copyWith(
        loadingOlder: false,
        hasOlder: page.items.isNotEmpty && page.hasMore,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(loadingOlder: false);
    }
  }

  void _applyCache(CachedGroupConversation cached) {
    _recentGroupConversations[groupId] = cached;
    state = state.copyWith(
      messages: cached.messages,
      pendingIds: cached.pendingIds,
      failedIds: cached.failedIds,
      initialCacheLoaded: true,
    );
  }

  void _onOutboxUpdate(OutboxUpdate update) {
    final confirmed = update.group;
    if (confirmed != null) {
      if (confirmed.groupId != groupId) return;
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

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'];

    if (type == 'group:message:new') {
      final message = GroupMessage.fromJson(
        event['message'] as Map<String, dynamic>,
      );
      if (message.groupId != groupId) return;
      _store.saveGroup([message]);
      state = state.copyWith(messages: [...state.messages, message]);
      if (message.media != null &&
          (message.messageType == 'IMAGE' || message.messageType == 'VIDEO')) {
        unawaited(
          _media.resolveLocalFile(
            message.media!.id,
            extension: mediaExtension(message.media!),
          ),
        );
      }
      return;
    }

    // Nom ou photo changés par un admin, ou rôle modifié : on recharge le
    // détail, qui porte aussi `my_role`/`can_manage` — un membre promu doit
    // voir apparaître les actions d'administration sans rouvrir l'écran.
    if (type == 'group:updated' || type == 'group:member:role') {
      final eventGroupId =
          event['group_id'] as int? ??
          (event['group'] as Map<String, dynamic>?)?['id'] as int?;
      if (eventGroupId != groupId) return;
      _refreshGroup();
      return;
    }

    // Un membre ajouté/retiré change les étiquettes d'auteur affichées et le
    // compteur de membres : on recharge le détail du groupe.
    if (type == 'group:member:added' || type == 'group:member:removed') {
      final eventGroupId =
          event['group_id'] as int? ??
          (event['group'] as Map<String, dynamic>?)?['id'] as int?;
      if (eventGroupId != groupId) return;
      _refreshGroup();
    }
  }

  Future<void> _refreshGroup() async {
    try {
      state = state.copyWith(group: await _repository.getGroup(groupId));
    } catch (_) {
      // Retiré du groupe entre-temps : l'écran se ferme via l'événement WS
      // côté UI, inutile de polluer l'état avec une erreur ici.
    }
  }

  /// Optimiste et durable — voir MessagingController.send. `senderName` est
  /// laissé vide : la bulle est la nôtre, l'étiquette d'auteur ne s'affiche
  /// que sur les messages reçus.
  Future<void> send(String text, {GroupMessage? replyTo}) async {
    if (text.trim().isEmpty) return;

    final optimistic = GroupMessage(
      id: _store.newLocalId(),
      groupId: groupId,
      senderId: _myUserId ?? 0,
      senderName: '',
      messageType: 'TEXT',
      content: text,
      mediaAssetId: null,
      media: null,
      createdAt: DateTime.now(),
      replyToId: replyTo?.id,
      replyTo: replyTo == null
          ? null
          : MessageReplyPreview(
              id: replyTo.id,
              senderId: replyTo.senderId,
              senderName: replyTo.senderName,
              messageType: replyTo.messageType,
              content: replyTo.content,
            ),
    );
    await _store.saveGroup([optimistic], pending: true);
    if (!mounted) return;
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      pendingIds: {...state.pendingIds, optimistic.id},
      error: null,
    );

    await _attemptSend(optimistic);
  }

  Future<void> createPoll({
    required String question,
    required List<String> options,
    required bool allowsMultiple,
  }) async {
    if (state.sending) return;
    state = state.copyWith(sending: true, error: null);
    try {
      final message = await _repository.createPoll(
        groupId: groupId,
        question: question,
        options: options,
        allowsMultiple: allowsMultiple,
      );
      await _store.saveGroup([message]);
      if (!mounted) return;
      state = state.copyWith(
        messages: [...state.messages, message],
        sending: false,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(sending: false);
      rethrow;
    }
  }

  Future<void> retry(String localId) async {
    final message = state.messages.where((m) => m.id == localId).firstOrNull;
    if (message == null) return;
    await _store.saveGroup([message], pending: true);
    if (!mounted) return;
    state = state.copyWith(
      pendingIds: {...state.pendingIds, localId},
      failedIds: state.failedIds.difference({localId}),
      error: null,
    );
    await _attemptSend(message);
  }

  Future<void> _attemptSend(GroupMessage optimistic) async {
    try {
      final confirmed = await _repository.send(
        groupId: groupId,
        content: optimistic.content ?? '',
        replyToId: optimistic.replyToId,
      );
      await _store.confirmGroup(optimistic.id, confirmed);
      if (!mounted) return;
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == optimistic.id) confirmed else m,
        ],
        pendingIds: state.pendingIds.difference({optimistic.id}),
      );
    } on NetworkException {
      // Reste en attente, part à la reconnexion.
    } on ApiException catch (exc) {
      if (exc.statusCode >= 500) return;
      await _store.markGroupFailed(optimistic.id);
      if (!mounted) return;
      state = state.copyWith(
        pendingIds: state.pendingIds.difference({optimistic.id}),
        failedIds: {...state.failedIds, optimistic.id},
        error: exc.message,
      );
    } catch (_) {}
  }

  /// Envoyer une pièce jointe — la bulle apparaît AVANT le téléversement.
  ///
  /// Exactement le même chemin qu'en tête-à-tête (voir
  /// `messaging_controller.dart::sendMedia` et `core/sync/media_sender.dart`).
  /// Les deux conversations ne doivent pas se comporter différemment pour
  /// une photo : c'est le genre d'écart qui fait dire qu'une application a
  /// été faite en plusieurs fois.
  Future<void> sendMedia({
    required String path,
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String messageType,
    String? caption,
  }) async {
    final localId = _store.newLocalId();
    final enAttente = GroupMessage(
      id: localId,
      groupId: groupId,
      senderId: _myUserId ?? 0,
      senderName: '',
      messageType: messageType,
      content: caption,
      mediaAssetId: null,
      media: null,
      createdAt: DateTime.now(),
      pendingMedia: PendingMedia(
        path: path,
        filename: filename,
        mimeType: mimeType,
        caption: caption,
      ),
    );

    await _store.saveGroup([enAttente], pending: true);
    state = state.copyWith(
      messages: [...state.messages, enAttente],
      pendingIds: {...state.pendingIds, localId},
      error: null,
    );
    _progress.set(localId, MediaSendPhase.preparation);

    // Rien à faire du résultat : la confirmation passe par le flux de mises
    // à jour du magasin, et une coupure laisse la ligne en file — sans
    // message d'erreur, puisqu'il n'y a rien à corriger et rien de perdu.
    await _sender.envoyerGroupe(enAttente);
  }

  /// Envoyer un média qui EXISTE DÉJÀ sur le serveur — un sticker.
  ///
  /// Même raison qu'en tête-à-tête (voir
  /// `MessagingController.sendExistingMedia`) : l'image du sticker
  /// appartient au pack, pas à l'expéditeur. La re-téléverser à chaque
  /// envoi créerait une copie par sticker envoyé.
  Future<void> sendExistingMedia({
    required int mediaAssetId,
    required String messageType,
  }) async {
    if (state.sending) return;
    state = state.copyWith(sending: true, error: null);
    try {
      final sent = await _repository.sendMedia(
        groupId: groupId,
        messageType: messageType,
        mediaAssetId: mediaAssetId,
      );
      await _store.saveGroup([sent]);
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

  Future<void> rename(String name) async {
    try {
      state = state.copyWith(
        group: await _repository.updateGroup(groupId: groupId, name: name),
      );
    } catch (_) {
      state = state.copyWith(error: _l.groupRenameFailed);
    }
  }

  Future<void> changePhoto({
    required List<int> bytes,
    required String filename,
  }) async {
    state = state.copyWith(uploading: true, error: null);
    try {
      final uploaded = await _media.upload(
        bytes: bytes,
        // Le recadrage rend du PNG (voir core/media/image_cropper.dart) :
        // annoncer le type réel, pas celui du fichier d'origine.
        filename: '$filename.png',
        mimeType: 'image/png',
        messageType: 'IMAGE',
      );
      final group = await _repository.updateGroup(
        groupId: groupId,
        avatarMediaId: uploaded.id,
      );
      state = state.copyWith(group: group, uploading: false);
    } catch (_) {
      state = state.copyWith(uploading: false, error: _l.groupPhotoFailed);
    }
  }

  Future<void> clearPhoto() async {
    try {
      final group = await _repository.updateGroup(
        groupId: groupId,
        clearAvatar: true,
      );
      state = state.copyWith(group: group);
    } catch (_) {
      state = state.copyWith(error: _l.groupClearPhotoFailed);
    }
  }

  Future<void> setMemberRole({
    required int userId,
    required String role,
  }) async {
    try {
      await _repository.setMemberRole(
        groupId: groupId,
        userId: userId,
        role: role,
      );
      await _refreshGroup();
    } catch (_) {
      state = state.copyWith(error: _l.groupRoleFailed);
    }
  }

  /// Renvoie le code créé, ou null en cas d'échec — l'écran en a besoin pour
  /// afficher le lien tout de suite.
  Future<String?> createInviteLink() async {
    try {
      final code = await _repository.createInviteLink(groupId);
      await _refreshGroup();
      return code;
    } catch (_) {
      state = state.copyWith(error: _l.groupInviteCreateFailed);
      return null;
    }
  }

  Future<void> revokeInviteLink() async {
    try {
      await _repository.revokeInviteLink(groupId);
      await _refreshGroup();
    } catch (_) {
      state = state.copyWith(error: _l.groupInviteRevokeFailed);
    }
  }

  Future<bool> leave(int myUserId) async {
    try {
      await _repository.removeMember(groupId: groupId, userId: myUserId);
      return true;
    } catch (_) {
      state = state.copyWith(error: _l.groupLeaveFailed);
      return false;
    }
  }

  Future<bool> removeMember(int userId) async {
    try {
      await _repository.removeMember(groupId: groupId, userId: userId);
      await _refreshGroup();
      return true;
    } catch (_) {
      state = state.copyWith(error: _l.groupRemoveMemberFailed);
      return false;
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

final groupChatControllerProvider = StateNotifierProvider.autoDispose
    .family<GroupChatController, GroupChatState, int>((ref, groupId) {
      return GroupChatController(
        ref.watch(groupRepositoryProvider),
        ref.watch(mediaRepositoryProvider),
        ref.watch(pokouMessageStoreProvider),
        ref.watch(wsClientProvider),
        groupId,
        ref.watch(authControllerProvider).user?.id,
        ref.watch(mediaSenderProvider),
        ref.watch(mediaUploadProgressProvider.notifier),
        ref.watch(appL10nProvider),
      );
    });
