import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/mahizu/mahizu_session.dart';
import '../data/chat_local_store.dart';
import '../data/chat_message_model.dart';
import '../data/chat_repository.dart';
import '../data/minou_repository.dart';

final chatLocalStoreProvider = Provider<ChatLocalStore>(
  (ref) => ChatLocalStore(),
);

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    apiClient: ref.watch(mahizuApiClientProvider),
    localStore: ref.watch(chatLocalStoreProvider),
  );
});

final minouRepositoryProvider = Provider<MinouRepository>((ref) {
  return MinouRepository(apiClient: ref.watch(mahizuApiClientProvider));
});

/// Dans quel monde se trouve l'utilisateur — alertes de moniteur, ou
/// messagerie Minou. C'est le SERVEUR qui tranche, sur son numéro (voir
/// MinouRepository) : l'application ne fait que suivre.
final minouStatusProvider = FutureProvider.autoDispose<MinouStatus>((ref) {
  return ref.watch(minouRepositoryProvider).status();
});

/// Identifiant de moniteur signifiant « aucun » — la conversation Minou
/// elle-même. Sentinelle purement locale (clé de regroupement SQLite),
/// jamais envoyée au serveur.
const kNoMonitor = 0;

class ChatState {
  const ChatState({required this.messages, this.sending = false, this.error});

  final List<ChatMessage> messages;
  final bool sending;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      error: error,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repository, this._minou, this.monitorId, this._l)
    : super(const ChatState(messages: [])) {
    _loadHistory();
  }

  /// Les traductions, injectées : un contrôleur n'a pas de `BuildContext`.
  final L _l;

  final ChatRepository _repository;
  final MinouRepository _minou;
  final int monitorId;

  /// Vrai pour LA conversation Minou (aucun moniteur choisi). C'est le seul
  /// cas où le fil et l'envoi passent par /minou : un moniteur choisi
  /// explicitement se discute avec /mahizu/chat, qui porte son quota et son
  /// RBAC.
  bool get _isMinouThread => monitorId == kNoMonitor;

  ChatMessage _asMessage(MinouThreadItem item) => ChatMessage(
    monitorId: monitorId,
    role: item.isMine ? ChatRole.user : ChatRole.assistant,
    content: item.displayBody,
    createdAt: item.createdAt,
  );

  /// Le cache local d'abord (instantané, et seul disponible hors ligne), puis
  /// le serveur qui le remplace.
  ///
  /// Pour Minou, le serveur est la SOURCE DE VÉRITÉ et non un complément :
  /// la même conversation vit sur WhatsApp, donc l'historique local peut être
  /// en retard de tout ce qui s'y est dit entre-temps. Il est donc réécrit
  /// depuis le fil serveur — pas fusionné, ce qui dupliquerait chaque
  /// message (le cache ne garde pas les identifiants serveur).
  ///
  /// Pour un moniteur, le fil serveur n'est pas une conversation mais ses
  /// ALERTES : elles s'intercalent chronologiquement dans les échanges
  /// locaux, comme sur WhatsApp où alertes et questions se suivent dans la
  /// même discussion.
  Future<void> _loadHistory() async {
    final local = await _repository.loadHistory(monitorId);
    if (!mounted) return;
    state = state.copyWith(messages: local);

    try {
      final thread = await _minou.thread();
      if (!mounted) return;
      final fromServer = thread.items.map(_asMessage).toList();
      if (_isMinouThread) {
        state = state.copyWith(messages: fromServer);
        await _repository.replaceHistory(monitorId, fromServer);
      } else {
        final alerts = [
          for (var index = 0; index < thread.items.length; index++)
            if (thread.items[index].isAlert) fromServer[index],
        ];
        final merged = [...local, ...alerts]
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
        if (mounted) state = state.copyWith(messages: merged);
      }
    } catch (_) {
      // Hors ligne, ou serveur muet : le cache local EST la réponse. Aucune
      // erreur affichée — une conversation lisible vaut mieux qu'un bandeau.
    }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.sending) return;
    state = state.copyWith(sending: true, error: null);

    final optimisticUser = ChatMessage(
      monitorId: monitorId,
      role: ChatRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, optimisticUser]);

    try {
      if (_isMinouThread) {
        // Minou renvoie TOUT ce qui vient de s'ajouter, l'écho de mon
        // message compris : on retire donc l'optimiste plutôt que de
        // l'afficher deux fois.
        final added = await _minou.send(text);
        if (!mounted) return;
        final withoutOptimistic = [...state.messages]..removeLast();
        final messages = [...withoutOptimistic, ...added.map(_asMessage)];
        state = state.copyWith(messages: messages, sending: false);
        await _repository.replaceHistory(monitorId, messages);
      } else {
        final reply = await _repository.sendMessage(
          monitorId: monitorId,
          text: text,
        );
        if (!mounted) return;
        state = state.copyWith(
          messages: [...state.messages, reply],
          sending: false,
        );
      }
      // Prolonge le signal visuel silencieux de l'Orb dans le physique —
      // voir assistant_orb.dart et le brief "design sombre et silencieux".
      HapticFeedback.lightImpact();
    } catch (error) {
      // Un échec côté client ne veut pas dire que le serveur n'a rien fait :
      // Minou appelle un modèle de langage, et une réponse lente ou un
      // réseau qui coupe pendant le retour laissaient « non envoyé » sur un
      // message pourtant enregistré ET répondu. On va donc VÉRIFIER auprès
      // du serveur avant d'annoncer l'échec.
      if (_isMinouThread && await _recoverSentMessage(text)) return;
      if (!mounted) return;
      state = state.copyWith(sending: false, error: _errorMessageFor(error));
    }
  }

  /// Redemande le fil après un envoi qui a échoué côté client. Si mon message
  /// y figure, il est bel et bien parti : on adopte la version du serveur
  /// (avec les réponses qu'il a pu produire) et aucune erreur n'est affichée.
  ///
  /// Renvoie faux quand le message ne s'y trouve pas — l'échec est alors réel
  /// et doit être dit.
  Future<bool> _recoverSentMessage(String text) async {
    try {
      final thread = await _minou.thread();
      final target = text.trim();
      final arrived = thread.items.any(
        (item) => item.isMine && item.body.trim() == target,
      );
      if (!arrived) return false;
      if (!mounted) return true;
      final messages = thread.items.map(_asMessage).toList();
      state = state.copyWith(messages: messages, sending: false);
      await _repository.replaceHistory(monitorId, messages);
      HapticFeedback.lightImpact();
      return true;
    } catch (_) {
      // Hors ligne pour de bon : on ne peut rien confirmer, l'échec sera dit.
      return false;
    }
  }

  /// Le message du serveur quand il en donne un (« ce numéro est rattaché à
  /// un moniteur », un quota atteint…) : plus utile qu'un « non envoyé »
  /// uniforme qui laisse chercher la cause.
  String _errorMessageFor(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty)
      return error.message;
    return _l.aiSendFailed;
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory(monitorId);
    state = state.copyWith(messages: []);
  }

  Future<void> regenerate() async {
    if (state.sending || state.messages.isEmpty) return;
    if (state.messages.last.role != ChatRole.assistant) return;

    final lastUserIndex = state.messages.lastIndexWhere(
      (m) => m.role == ChatRole.user,
    );
    if (lastUserIndex == -1) return;
    final promptText = state.messages[lastUserIndex].content;

    // La question est retirée AVEC sa réponse : `send` la réécrit, et pour
    // Minou c'est indispensable — le serveur renvoie l'écho du message, qui
    // apparaîtrait deux fois si on laissait l'ancien.
    final withoutLastExchange = List<ChatMessage>.from(state.messages)
      ..removeRange(lastUserIndex, state.messages.length);
    state = state.copyWith(messages: withoutLastExchange, error: null);
    // Repasse par `send` plutôt que d'appeler le dépôt : c'est lui qui sait
    // vers quel Minou envoyer (messagerie ou moniteur).
    await send(promptText);
  }
}

final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, ChatState, int>((ref, monitorId) {
      return ChatController(
        ref.watch(chatRepositoryProvider),
        ref.watch(minouRepositoryProvider),
        monitorId,
        ref.watch(appL10nProvider),
      );
    });
