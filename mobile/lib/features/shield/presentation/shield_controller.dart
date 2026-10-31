import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_provider.dart';
import '../../../core/providers.dart';
import '../../contacts/data/contact_model.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../data/local_redaction.dart';
import '../data/shield_preferences.dart';
import '../data/shield_repository.dart';

final shieldRepositoryProvider = Provider<ShieldRepository>((ref) {
  return ShieldRepository(apiClient: ref.watch(apiClientProvider));
});

final shieldPreferencesProvider = Provider<ShieldPreferences>(
  (ref) => ShieldPreferences(),
);

class DeferredMessage {
  const DeferredMessage({
    required this.senderId,
    required this.senderName,
    required this.count,
    required this.lastPreview,
  });

  final int senderId;
  final String senderName;
  final int count;
  final String lastPreview;
}

class DeferredCall {
  const DeferredCall({
    required this.room,
    required this.fromUserId,
    required this.fromName,
    required this.callType,
    required this.isVideo,
  });

  final String room;
  final int fromUserId;
  final String fromName;
  final String callType;
  final bool isVideo;
}

class ShieldState {
  const ShieldState({
    this.masterEnabled = true,
    this.active = false,
    this.deferredMessages = const [],
    this.deferredCall,
    this.lastFlushSummary,
  });

  // Interrupteur utilisateur (Réglages) — distinct de `active`, qui est
  // l'activation automatique par score de focus. Si l'utilisateur a tout
  // désactivé, on n'évalue même plus le contexte.
  final bool masterEnabled;
  final bool active;
  final List<DeferredMessage> deferredMessages;
  final DeferredCall? deferredCall;
  // Consommé une fois par ShieldOverlay pour afficher le résumé de fin de
  // session ("N messages mis en attente pendant votre réunion").
  final String? lastFlushSummary;

  int get totalDeferredCount =>
      deferredMessages.fold(0, (sum, m) => sum + m.count);

  ShieldState copyWith({
    bool? masterEnabled,
    bool? active,
    List<DeferredMessage>? deferredMessages,
    DeferredCall? deferredCall,
    bool clearDeferredCall = false,
    String? lastFlushSummary,
    bool clearFlushSummary = false,
  }) {
    return ShieldState(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      active: active ?? this.active,
      deferredMessages: deferredMessages ?? this.deferredMessages,
      deferredCall: clearDeferredCall
          ? null
          : (deferredCall ?? this.deferredCall),
      lastFlushSummary: clearFlushSummary
          ? null
          : (lastFlushSummary ?? this.lastFlushSummary),
    );
  }
}

const _kInactivityTimeout = Duration(minutes: 3);
const _kSpamWindow = Duration(minutes: 1);

/// Mode Bouclier — voir le cahier des charges (5 étapes). Global et
/// persistant pour la durée de vie de l'app (comme callSignalingProvider) :
/// les messages/appels d'autres conversations peuvent arriver à tout
/// moment, pas seulement quand une conversation précise est à l'écran.
///
/// Limite assumée : Pokou n'a pas de messagerie de groupe (seulement des
/// appels de groupe) — la règle "groupe de plus de 20 personnes" existe
/// côté API pour coller au cahier des charges mais n'a actuellement aucun
/// déclencheur côté client, faute de fonctionnalité de groupe de discussion.
class ShieldController extends StateNotifier<ShieldState> {
  ShieldController(this._ref) : super(const ShieldState()) {
    _subscription = _ref.read(wsClientProvider).events.listen(_onWsEvent);
    _loadMasterEnabled();
  }

  final Ref _ref;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _inactivityTimer;
  int? _activeContactUserId;
  final Map<int, List<DateTime>> _recentSenderTimestamps = {};

  ShieldRepository get _repo => _ref.read(shieldRepositoryProvider);
  ShieldPreferences get _prefs => _ref.read(shieldPreferencesProvider);

  Future<void> _loadMasterEnabled() async {
    final enabled = await _prefs.readEnabled();
    if (mounted) state = state.copyWith(masterEnabled: enabled);
  }

  /// Appelé depuis l'écran Profil — Réglages > Confidentialité & Sécurité.
  Future<void> setMasterEnabled(bool enabled) async {
    await _prefs.writeEnabled(enabled);
    if (!mounted) return;
    state = state.copyWith(masterEnabled: enabled);
    if (!enabled) _deactivate();
  }

  /// Appelé par ConversationScreen à l'ouverture/fermeture d'une conversation.
  void setActiveConversation(int? contactUserId) {
    _activeContactUserId = contactUserId;
    if (contactUserId == null) _deactivate();
  }

  /// Appelé par ConversationScreen quand les derniers messages de la
  /// conversation active changent (envoi ou réception) — étape 1.
  Future<void> evaluateActiveConversation(List<String> lastMessages) async {
    if (!state.masterEnabled) return;
    _resetInactivityTimer();
    if (lastMessages.isEmpty) return;
    try {
      final redacted = lastMessages.map(redactForShield).toList();
      final score = await _repo.evaluateContext(redacted);
      if (!mounted) return;
      final shouldBeActive = score >= 7;
      if (shouldBeActive != state.active) {
        state = state.copyWith(active: shouldBeActive);
        if (shouldBeActive) {
          // Design silencieux et sombre : le retour physique prolonge le
          // signal visuel discret plutôt que de compter sur une couleur.
          HapticFeedback.lightImpact();
        } else {
          _flush();
        }
      }
    } catch (_) {
      // Échec silencieux — le bouclier garde son état courant plutôt que de
      // bloquer l'envoi/réception de messages sur une conversation normale.
    }
  }

  /// Étape 3 pour un appel entrant — appelé par callSignalingProvider avant
  /// de pousser IncomingCallScreen. Renvoie true si l'appel doit être mis en
  /// attente (une bulle flottante est alors affichée, voir DeferredCallBubble).
  Future<bool> shouldDeferIncomingCall({
    required int fromUserId,
    required String callType,
    required bool isVideo,
    required String room,
  }) async {
    if (!state.active || fromUserId == _activeContactUserId) return false;

    final contact = await _findContact(fromUserId);
    try {
      final decision = await _repo.evaluateEvent(
        contextScore:
            9, // le bouclier est déjà actif ; le score exact n'est pas re-demandé ici
        eventType: 'call',
        senderTag: contact?.priorityTag,
        senderKnown: contact != null,
      );
      if (decision != 'DEFER') return false;
    } catch (_) {
      return false; // échec réseau — on laisse sonner normalement (failsafe ALLOW)
    }

    state = state.copyWith(
      deferredCall: DeferredCall(
        room: room,
        fromUserId: fromUserId,
        fromName:
            contact?.displayName ??
            _ref.read(appL10nProvider).shieldUnknownNumber,
        callType: callType,
        isVideo: isVideo,
      ),
    );
    return true;
  }

  void dismissDeferredCall() => state = state.copyWith(clearDeferredCall: true);

  /// "Swipe to override" — révèle immédiatement les messages en attente
  /// sans désactiver le bouclier (les événements futurs restent filtrés).
  List<DeferredMessage> revealDeferredMessages() {
    final deferred = state.deferredMessages;
    state = state.copyWith(deferredMessages: const []);
    return deferred;
  }

  void consumeFlushSummary() => state = state.copyWith(clearFlushSummary: true);

  Future<void> _onWsEvent(Map<String, dynamic> event) async {
    // Appel mis en attente par le Mode Bouclier, puis abandonné par
    // l'appelant : la bulle flottante doit disparaître, sinon elle propose
    // de rappeler un appel qui n'existe plus.
    if (event['type'] == 'call:end' || event['type'] == 'call:decline') {
      if (state.deferredCall?.room == event['room']) dismissDeferredCall();
      return;
    }

    if (event['type'] != 'message:new') return;

    final message = event['message'] as Map<String, dynamic>?;
    final senderId = message?['sender_id'] as int?;
    if (message == null || senderId == null || senderId == _activeContactUserId)
      return;

    _recordActivity(senderId);
    if (!state.active) return;

    final contact = await _findContact(senderId);
    final messageType = message['message_type'] as String? ?? 'TEXT';
    final rawText = message['content'] as String?;

    String decision;
    try {
      decision = await _repo.evaluateEvent(
        contextScore: 9,
        eventType: 'message',
        senderTag: contact?.priorityTag,
        hashedText: rawText != null ? redactForShield(rawText) : null,
        senderKnown: contact != null,
        senderMessageCountLastMinute: _countRecentMessages(senderId),
      );
    } catch (_) {
      return; // échec réseau — pas de mise en attente, comportement normal
    }
    if (decision != 'DEFER') return;

    final senderName =
        contact?.displayName ?? _ref.read(appL10nProvider).shieldUnknownNumber;
    final preview = messageType == 'TEXT' ? (rawText ?? '') : '[$messageType]';
    final existingIndex = state.deferredMessages.indexWhere(
      (m) => m.senderId == senderId,
    );
    final updated = [...state.deferredMessages];
    if (existingIndex >= 0) {
      final existing = updated[existingIndex];
      updated[existingIndex] = DeferredMessage(
        senderId: senderId,
        senderName: senderName,
        count: existing.count + 1,
        lastPreview: preview,
      );
    } else {
      updated.add(
        DeferredMessage(
          senderId: senderId,
          senderName: senderName,
          count: 1,
          lastPreview: preview,
        ),
      );
    }
    state = state.copyWith(deferredMessages: updated);
  }

  Future<PokouContact?> _findContact(int userId) async {
    try {
      final contacts = await _ref.read(contactsProvider.future);
      for (final contact in contacts) {
        if (contact.contactUserId == userId) return contact;
      }
    } catch (_) {
      // liste de contacts indisponible — traité comme expéditeur inconnu
    }
    return null;
  }

  void _recordActivity(int senderId) {
    final now = DateTime.now();
    final timestamps = _recentSenderTimestamps.putIfAbsent(senderId, () => []);
    timestamps.add(now);
    timestamps.removeWhere((t) => now.difference(t) > _kSpamWindow);
  }

  int _countRecentMessages(int senderId) =>
      _recentSenderTimestamps[senderId]?.length ?? 0;

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_kInactivityTimeout, _deactivate);
  }

  void _deactivate() {
    _inactivityTimer?.cancel();
    if (!state.active) return;
    state = state.copyWith(active: false);
    _flush();
  }

  void _flush() {
    final count = state.totalDeferredCount;
    if (count == 0) return;
    HapticFeedback.lightImpact();
    _recordDeferredForToday(count);
    state = state.copyWith(
      lastFlushSummary: _ref.read(appL10nProvider).shieldFlushSummary(count),
    );
  }

  DateTime _dailyTotalDate = DateTime.now();
  int _dailyTotal = 0;

  void _recordDeferredForToday(int count) {
    final now = DateTime.now();
    if (now.year != _dailyTotalDate.year ||
        now.month != _dailyTotalDate.month ||
        now.day != _dailyTotalDate.day) {
      _dailyTotalDate = now;
      _dailyTotal = 0;
    }
    _dailyTotal += count;
  }

  /// Total des messages mis en attente aujourd'hui, toutes sessions Bouclier
  /// confondues — lu par le récap de fin de journée de Mahizu (état
  /// purement client, jamais remonté au serveur, voir daily_digest_service.dart).
  int get todayDeferredCount {
    final now = DateTime.now();
    if (now.year != _dailyTotalDate.year ||
        now.month != _dailyTotalDate.month ||
        now.day != _dailyTotalDate.day) {
      return 0;
    }
    return _dailyTotal;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _inactivityTimer?.cancel();
    super.dispose();
  }
}

final shieldControllerProvider =
    StateNotifierProvider<ShieldController, ShieldState>((ref) {
      return ShieldController(ref);
    });
