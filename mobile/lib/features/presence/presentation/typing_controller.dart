import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_provider.dart';
import '../../../core/providers.dart';
import '../data/presence_repository.dart';

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepository(apiClient: ref.watch(apiClientProvider));
});

/// Qui est en train d'écrire, et où.
///
/// La clé est `"contact:12"` ou `"group:3"` — la même forme que le serveur
/// envoie. Un seul état pour toute l'application, écouté globalement : la
/// liste d'accueil doit pouvoir afficher « écrit… » sur une conversation
/// qu'on n'a pas ouverte, sinon l'indicateur ne sert qu'à celui qui regarde
/// déjà la personne écrire.
class TypingState {
  const TypingState(this.byConversation);

  /// clé → nom de la personne qui écrit.
  final Map<String, String> byConversation;

  static String keyFor(String kind, int id) => '$kind:$id';

  String? nameFor(String kind, int id) => byConversation[keyFor(kind, id)];

  bool isTyping(String kind, int id) =>
      byConversation.containsKey(keyFor(kind, id));
}

/// Au-delà, on oublie.
///
/// Indispensable : le signal « je n'écris plus » peut ne jamais arriver —
/// application fermée, réseau coupé, batterie vide. Sans expiration, un
/// « écrit… » resterait affiché indéfiniment, ce qui est pire que de ne rien
/// afficher : il donnerait l'impression d'attendre une réponse qui ne vient
/// pas.
const _typingTtl = Duration(seconds: 6);

class TypingNotifier extends StateNotifier<TypingState> {
  TypingNotifier(this._events, this._someoneLabel)
    : super(const TypingState({})) {
    _subscription = _events.listen(_onEvent);
  }

  final Stream<Map<String, dynamic>> _events;

  /// Comment nommer quelqu'un dont le serveur n'a pas donné le nom.
  final String _someoneLabel;
  StreamSubscription? _subscription;
  final Map<String, Timer> _expiries = {};

  void _onEvent(Map<String, dynamic> event) {
    if (event['type'] != 'typing') return;
    final kind = event['kind'] as String?;
    final id = event['id'] as int?;
    if (kind == null || id == null) return;

    // En 1:1, le serveur envoie l'identifiant de la conversation vu de
    // l'expéditeur : c'est LUI qui écrit, donc la conversation est la sienne.
    final key = TypingState.keyFor(
      kind,
      kind == 'contact' ? (event['user_id'] as int? ?? id) : id,
    );
    final typing = event['typing'] as bool? ?? false;

    if (!typing) {
      _forget(key);
      return;
    }

    final name = event['user_name'] as String? ?? _someoneLabel;
    state = TypingState({...state.byConversation, key: name});
    _expiries[key]?.cancel();
    _expiries[key] = Timer(_typingTtl, () => _forget(key));
  }

  void _forget(String key) {
    _expiries.remove(key)?.cancel();
    if (!state.byConversation.containsKey(key)) return;
    final next = {...state.byConversation}..remove(key);
    state = TypingState(next);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final timer in _expiries.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// Écoute GLOBALE, comme discussionsRealtimeProvider : montée dans main.dart
/// pour que l'état survive au changement d'onglet.
final typingProvider = StateNotifierProvider<TypingNotifier, TypingState>((
  ref,
) {
  return TypingNotifier(
    ref.watch(wsClientProvider).events,
    // Le repli quand le serveur n'a pas nommé qui écrit : traduit, comme le
    // reste de ce que l'utilisateur lit.
    ref.watch(appL10nProvider).presenceSomeone,
  );
});

/// L'émetteur : prévient qu'on écrit, sans inonder le réseau.
///
/// Un appel par frappe enverrait une requête par lettre. On en envoie un au
/// début, puis au plus un toutes les trois secondes tant que la frappe
/// continue, et un dernier « j'ai fini » après un silence.
class TypingSignal {
  TypingSignal(this._repository, this._kind, this._id);

  final PresenceRepository _repository;
  final String _kind;
  final int _id;

  static const _throttle = Duration(seconds: 3);
  static const _idle = Duration(seconds: 4);

  DateTime? _lastSent;
  Timer? _stopTimer;
  bool _active = false;

  void onChanged() {
    final now = DateTime.now();
    if (!_active ||
        _lastSent == null ||
        now.difference(_lastSent!) > _throttle) {
      _active = true;
      _lastSent = now;
      unawaited(_repository.setTyping(kind: _kind, id: _id, typing: true));
    }
    _stopTimer?.cancel();
    _stopTimer = Timer(_idle, stop);
  }

  /// À appeler à l'envoi et à la fermeture de l'écran. Sans ce signal, le
  /// correspondant voit « écrit… » jusqu'à l'expiration côté réception —
  /// six secondes de trop juste après avoir reçu le message.
  void stop() {
    _stopTimer?.cancel();
    if (!_active) return;
    _active = false;
    unawaited(_repository.setTyping(kind: _kind, id: _id, typing: false));
  }

  void dispose() {
    _stopTimer?.cancel();
    if (_active) stop();
  }
}
