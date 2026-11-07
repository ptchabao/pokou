import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'état d'un appel, tel que la couche NATIVE le connaît.
///
/// Les noms correspondent exactement à `CallState` côté Kotlin — voir
/// android/app/src/main/kotlin/com/pokou/pokou/call/CallState.kt. Deux
/// vocabulaires pour la même chose finiraient par diverger.
enum NativeCallState {
  ringing,
  answering,
  connecting,
  connected,
  ended,
  missed,
  failed;

  /// Un état inconnu — couche native plus récente que ce Dart, ou canal
  /// absent — devient `ended` plutôt que de lever. Un écran d'appel bloqué
  /// sur un état illisible serait pire que la fin de l'appel.
  static NativeCallState parse(String? raw) => switch (raw) {
    'RINGING' => NativeCallState.ringing,
    'ANSWERING' => NativeCallState.answering,
    'CONNECTING' => NativeCallState.connecting,
    'CONNECTED' => NativeCallState.connected,
    'MISSED' => NativeCallState.missed,
    'FAILED' => NativeCallState.failed,
    _ => NativeCallState.ended,
  };

  bool get isActive =>
      this == NativeCallState.ringing ||
      this == NativeCallState.answering ||
      this == NativeCallState.connecting ||
      this == NativeCallState.connected;
}

/// Ce que la couche native dit d'un appel.
class NativeCall {
  const NativeCall({
    required this.state,
    this.room,
    this.fromUserId,
    this.callerName,
    this.isVideo = false,
    this.groupId,
    this.groupName,
  });

  final NativeCallState state;
  final String? room;
  final int? fromUserId;
  final String? callerName;
  final bool isVideo;
  final int? groupId;
  final String? groupName;

  static NativeCall fromMap(Map<dynamic, dynamic> map) => NativeCall(
    state: NativeCallState.parse(map['state'] as String?),
    room: map['room'] as String?,
    fromUserId: int.tryParse('${map['from_user_id']}'),
    callerName: map['caller_name'] as String?,
    isVideo: map['is_video'] == true,
    groupId: int.tryParse('${map['group_id']}'),
    groupName: map['group_name'] as String?,
  );
}

/// Une réponse rapide écrite depuis une notification, en attente de
/// chiffrement.
///
/// Le natif ne peut pas chiffrer — les clés vivent dans `E2EEStore`, côté
/// Dart. Il met donc le texte en file, et Flutter le reprend ici pour le
/// chiffrer puis l'envoyer par le chemin normal. Voir ReplyQueue.kt.
class PendingNativeReply {
  const PendingNativeReply({
    required this.contactUserId,
    required this.text,
    this.replyToken,
  });

  final int contactUserId;
  final String text;
  final String? replyToken;

  static PendingNativeReply? fromJson(Map<String, dynamic> json) {
    final contact = int.tryParse('${json['contact_user_id']}');
    final text = json['text'] as String?;
    if (contact == null || text == null || text.trim().isEmpty) return null;
    return PendingNativeReply(
      contactUserId: contact,
      text: text,
      replyToken: json['reply_token'] as String?,
    );
  }
}

/// Le pont vers la couche d'appel native.
///
/// ── Ce qu'il change ─────────────────────────────────────────────────
///
/// Jusqu'ici, Flutter était le MOTEUR de l'appel entrant : il construisait
/// la notification, jouait la sonnerie et décidait de l'état. Tout cela ne
/// pouvait donc commencer qu'une fois le moteur Dart réveillé — plusieurs
/// secondes sur un téléphone en veille, et rien du tout si le système
/// refusait de le réveiller.
///
/// Le natif est désormais la source de vérité. Flutter OBSERVE, et se
/// contente de ce qu'il est seul à savoir faire : l'interface, le média
/// LiveKit, et le chiffrement.
///
/// ── Le repli ────────────────────────────────────────────────────────
///
/// Sur iOS — où cette couche n'existe pas encore — les canaux sont absents.
/// Le pont renvoie alors un flux vide, et l'ancien chemin Flutter continue
/// de fonctionner. Ce repli est TRANSITOIRE : voir
/// docs/native-call-layer.md §7 pour son critère de suppression.
class NativeCallBridge {
  NativeCallBridge({EventChannel? events, MethodChannel? methods})
    : _events = events ?? const EventChannel('com.pokou.pokou/call_events'),
      _methods = methods ?? const MethodChannel('com.pokou.pokou/call'),
      // La couche d'appel native n'existe que sur Android. Écouter son
      // canal ailleurs (iOS) levait une MissingPluginException à chaque
      // lancement. Un canal injecté (tests) est toujours écouté.
      _hasNativeLayer =
          events != null || defaultTargetPlatform == TargetPlatform.android;

  final bool _hasNativeLayer;

  final EventChannel _events;
  final MethodChannel _methods;

  Stream<NativeCall>? _stream;

  /// Les transitions annoncées par le natif.
  ///
  /// Diffusé et mis en cache : plusieurs écrans peuvent l'observer, et
  /// ouvrir deux abonnements au canal en poserait deux au `CallManager`.
  Stream<NativeCall> get calls => _stream ??= !_hasNativeLayer
      ? const Stream<NativeCall>.empty()
      : _events
            .receiveBroadcastStream()
            .map((event) => NativeCall.fromMap(event as Map<dynamic, dynamic>))
            .handleError((Object _) {
              // Canal absent : on n'en fait pas une erreur que chaque écran
              // devrait traiter pour ne rien en faire.
            })
            .asBroadcastStream();

  /// L'appel en cours au moment où Flutter démarre.
  ///
  /// Indispensable : le natif peut avoir décroché AVANT que Flutter existe,
  /// et un écran qui n'écouterait que les transitions futures n'apprendrait
  /// jamais qu'un appel est en cours.
  Future<NativeCall?> currentCall() async {
    try {
      final result = await _methods.invokeMethod<Map<dynamic, dynamic>>(
        'getCurrentCall',
      );
      if (result == null) return null;
      final call = NativeCall.fromMap(result);
      return call.state.isActive ? call : null;
    } catch (_) {
      return null;
    }
  }

  /// Le média est établi — le natif peut passer à `CONNECTED`.
  Future<void> reportConnected() => _invoke('onConnected');

  /// L'appel est terminé côté Flutter.
  Future<void> reportEnded() => _invoke('onEnded');

  /// Le média d'un appel est établi : le natif démarre le service de premier
  /// plan qui garde le micro (et la caméra) quand l'application passe en
  /// arrière-plan. Sans lui, Android coupe le micro d'une application en
  /// arrière-plan, et l'autre cesse d'entendre l'utilisateur.
  Future<void> startOngoingCall({required bool isVideo}) =>
      _invoke('startOngoingCall', isVideo);

  /// L'appel est fini : le service et sa notification « Appel en cours »
  /// disparaissent.
  Future<void> stopOngoingCall() => _invoke('stopOngoingCall');

  /// Un appel vidéo est à l'écran : quitter l'application le réduit en
  /// fenêtre flottante (Picture-in-Picture) au lieu de le cacher.
  Future<void> setPipEligible(bool eligible) =>
      _invoke('setPipEligible', eligible);

  /// Récupère les réponses rapides écrites depuis une notification, et VIDE
  /// la file native.
  ///
  /// À appeler au démarrage : c'est le seul moment où Flutter peut les
  /// chiffrer, puisqu'il est seul à détenir les clés.
  Future<List<PendingNativeReply>> drainPendingReplies() async {
    try {
      final raw = await _methods.invokeMethod<String>('drainPendingReplies');
      if (raw == null || raw.isEmpty) return const [];
      final items = jsonDecode(raw) as List<dynamic>;
      return items
          .whereType<Map<String, dynamic>>()
          .map(PendingNativeReply.fromJson)
          .whereType<PendingNativeReply>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Dit au natif où joindre l'API.
  ///
  /// L'URL se change par `--dart-define` au build : la coder une seconde
  /// fois en Kotlin donnerait deux constantes à tenir d'accord, donc une
  /// divergence un jour.
  Future<void> setApiBaseUrl(String url) async {
    try {
      await _methods.invokeMethod<void>('setApiBaseUrl', url);
    } catch (_) {
      // Le natif retombe sur son défaut compilé.
    }
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _methods.invokeMethod<void>(method, arguments);
    } catch (_) {
      // Canal absent (iOS, ancienne installation) : l'ancien chemin Flutter
      // reste en place, il n'y a rien à signaler.
    }
  }
}

final nativeCallBridgeProvider = Provider<NativeCallBridge>(
  (ref) => NativeCallBridge(),
);
