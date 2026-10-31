import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/call_keys.dart';
import '../../../core/calls/native_call_bridge.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import 'call_controller.dart';
import 'call_screen.dart';

/// Ce qui relie la couche d'appel NATIVE à l'interface Flutter.
///
/// ── Le défaut qu'il corrige ─────────────────────────────────────────
///
/// `NativeCallBridge` existait, testé, complet — et AUCUN fichier de
/// l'application ne l'appelait. Conséquence observée sur appareil réel :
/// répondre depuis la notification, application fermée, ouvrait bien Pokou,
/// mais sur l'écran d'accueil. Flutter ne demandait jamais « y a-t-il un
/// appel en cours ? », donc il n'en rejoignait aucun, et l'appel était
/// perdu alors que le natif avait déjà accepté côté serveur.
///
/// Un pont non branché ne se voit ni à la compilation, ni à l'analyse, ni
/// dans les tests unitaires du pont lui-même — ils passaient tous.
///
/// ── Pourquoi il ignore RINGING ──────────────────────────────────────
///
/// La sonnerie et la notification appartiennent au natif. Quand
/// l'application est OUVERTE, le WebSocket livre déjà `call:invite` et
/// `callSignalingProvider` pousse `IncomingCallScreen` : réagir aussi à
/// RINGING ici afficherait deux écrans d'appel entrant pour une seule
/// sonnerie.
///
/// Ce pont ne s'occupe donc que de l'APRÈS-décrochage — le moment précis
/// où le natif a fini son travail et passe la main.
final nativeCallGateProvider = Provider<void>((ref) {
  final bridge = ref.watch(nativeCallBridgeProvider);

  // Le natif a besoin de l'URL de l'API pour accepter ou refuser sans
  // Flutter. Elle est définie au build par --dart-define ; la coder une
  // seconde fois en Kotlin donnerait deux constantes à tenir d'accord.
  unawaited(bridge.setApiBaseUrl(ref.read(apiClientProvider).baseUrl));

  final gate = _NativeCallGate(ref, bridge);

  // L'état COURANT d'abord, les transitions ensuite — et dans cet ordre.
  // Le natif a pu décrocher AVANT que Flutter n'existe : c'est même le cas
  // nominal, application fermée. Un pont qui n'écouterait que les
  // transitions futures n'apprendrait jamais qu'un appel l'attend.
  unawaited(bridge.currentCall().then(gate.onCall));
  final subscription = bridge.calls.listen(gate.onCall);

  ref.onDispose(subscription.cancel);
});

/// La décision — « faut-il rejoindre cet appel, et lequel ? ».
///
/// Séparée du reste parce que c'est la seule partie qui porte des règles,
/// et donc la seule qui puisse se tromper. Le reste (jeton LiveKit,
/// navigation) n'est que de la plomberie, qu'un test ne pourrait vérifier
/// qu'en simulant un arbre Flutter entier.
class NativeCallGateDecision {
  /// Le salon déjà pris en charge.
  ///
  /// Le natif rejoue son état à chaque nouvel observateur, et émet
  /// ANSWERING puis CONNECTING pour un même appel. Sans ce garde-fou, on
  /// ouvrirait deux écrans d'appel et on demanderait deux jetons LiveKit
  /// pour un seul décrochage.
  String? _handledRoom;

  /// Le salon à rejoindre, ou `null` s'il n'y a rien à faire.
  String? roomToJoin(NativeCall? call) {
    if (call == null) return null;

    if (!call.state.isActive) {
      // L'appel est fini : on oublie, pour que le suivant dans le même
      // salon soit bien pris en charge.
      _handledRoom = null;
      return null;
    }

    // RINGING appartient au natif — voir l'en-tête.
    if (call.state == NativeCallState.ringing) return null;

    final room = call.room;
    if (room == null || room == _handledRoom) return null;
    _handledRoom = room;
    return room;
  }

  /// Rend la main sur ce salon — après un échec, pour que la transition
  /// suivante puisse réessayer plutôt que de perdre l'appel en silence.
  void release() => _handledRoom = null;
}

class _NativeCallGate {
  _NativeCallGate(this._ref, this._bridge);

  final Ref _ref;
  final NativeCallBridge _bridge;
  final _decision = NativeCallGateDecision();

  Future<void> onCall(NativeCall? call) async {
    final room = _decision.roomToJoin(call);
    if (room == null || call == null) return;
    await _join(call, room);
  }

  Future<void> _join(NativeCall call, String room) async {
    try {
      // Le jeton LiveKit : le natif a accepté l'appel côté serveur, mais il
      // ne sait pas parler média — c'est la frontière exacte entre les deux
      // couches.
      final token = await _ref
          .read(callRepositoryProvider)
          .joinCall(room, inviter: call.fromUserId);
      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) {
        // Flutter n'a pas encore d'arbre : très tôt au démarrage à froid.
        // On relâche le verrou pour que la prochaine transition réessaie,
        // plutôt que de perdre l'appel en silence.
        _decision.release();
        return;
      }

      unawaited(_bridge.reportConnected());

      navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            livekitUrl: token.livekitUrl,
            token: token.token,
            room: token.room,
            otherParticipantIds: token.participantIds.isEmpty
                ? [if (call.fromUserId != null) call.fromUserId!]
                : token.participantIds,
            startWithVideo: call.isVideo,
            groupId: call.groupId,
            // On REJOINT : le correspondant est déjà dans le salon, il ne
            // faut pas jouer de tonalité d'appel sortant.
            joiningExistingCall: true,
          ),
        ),
      );
    } on CallEncryptionException {
      // Voir IncomingCallScreen._accept : l'appelant doit l'apprendre, et le
      // natif ne doit pas croire à un appel en cours.
      final from = call.fromUserId;
      if (from != null) {
        unawaited(
          _ref
              .read(callRepositoryProvider)
              .signal(room: room, targetUserId: from, event: 'decline')
              .catchError((_) {}),
        );
      }
      _decision.release();
      unawaited(_bridge.reportEnded());
    } catch (_) {
      // Jeton refusé, réseau coupé, appel déjà clos : on dit au natif que
      // c'est terminé plutôt que de le laisser croire à un appel en cours,
      // ce qui garderait une notification affichée pour rien.
      _decision.release();
      unawaited(_bridge.reportEnded());
    }
  }
}
