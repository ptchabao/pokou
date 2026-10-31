import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/calls/native_call_bridge.dart';
import 'package:pokou/features/calls/presentation/native_call_gate.dart';

/// Ce que ces tests protègent a coûté un appel perdu sur appareil réel.
///
/// `NativeCallBridge` était écrit, testé et complet — et AUCUN fichier de
/// l'application ne l'appelait. Répondre depuis la notification,
/// application fermée, ouvrait bien Pokou, mais sur l'écran d'accueil : le
/// natif avait accepté côté serveur, Flutter ne rejoignait jamais le salon.
///
/// Un pont non branché ne se voit ni à la compilation, ni à l'analyse, ni
/// dans les tests du pont lui-même. Ceux-ci vérifient la DÉCISION, qui est
/// la seule partie où des règles peuvent se tromper.
NativeCall _call(NativeCallState state, {String? room = 'salon-1'}) =>
    NativeCall(state: state, room: room, fromUserId: 42);

void main() {
  group('NativeCallGateDecision', () {
    test('un appel décroché se rejoint', () {
      // Le cas nominal : le natif a répondu, il passe la main.
      final decision = NativeCallGateDecision();

      expect(decision.roomToJoin(_call(NativeCallState.connecting)), 'salon-1');
    });

    test('RINGING appartient au natif, et à lui seul', () {
      // La sonnerie et la notification sont natives. Réagir aussi ici
      // afficherait DEUX écrans d'appel entrant quand l'application est
      // ouverte, puisque le WebSocket en pousse déjà un.
      final decision = NativeCallGateDecision();

      expect(decision.roomToJoin(_call(NativeCallState.ringing)), isNull);
    });

    test('un même appel ne se rejoint pas deux fois', () {
      // Le natif rejoue son état à chaque observateur, et émet ANSWERING
      // PUIS CONNECTING pour un seul décrochage. Sans garde-fou : deux
      // écrans d'appel et deux jetons LiveKit demandés.
      final decision = NativeCallGateDecision();

      expect(decision.roomToJoin(_call(NativeCallState.answering)), 'salon-1');
      expect(decision.roomToJoin(_call(NativeCallState.connecting)), isNull);
      expect(decision.roomToJoin(_call(NativeCallState.connected)), isNull);
    });

    test('un appel terminé libère le salon pour le suivant', () {
      // Sans cela, rappeler quelqu'un dans le même salon ne ferait plus
      // rien — le garde-fou anti-doublon se retournerait contre nous.
      final decision = NativeCallGateDecision();
      decision.roomToJoin(_call(NativeCallState.connecting));
      decision.roomToJoin(_call(NativeCallState.ended));

      expect(decision.roomToJoin(_call(NativeCallState.connecting)), 'salon-1');
    });

    test('un appel manqué ou échoué libère aussi', () {
      for (final fin in [NativeCallState.missed, NativeCallState.failed]) {
        final decision = NativeCallGateDecision();
        decision.roomToJoin(_call(NativeCallState.connecting));
        decision.roomToJoin(_call(fin));

        expect(
          decision.roomToJoin(_call(NativeCallState.connecting)),
          'salon-1',
          reason: '$fin doit rendre la main',
        );
      }
    });

    test('un appel sans salon ne mène nulle part', () {
      // Un push mal formé ne doit pas faire demander un jeton LiveKit pour
      // un salon inexistant.
      final decision = NativeCallGateDecision();

      expect(
        decision.roomToJoin(_call(NativeCallState.connecting, room: null)),
        isNull,
      );
    });

    test('release permet de réessayer après un échec', () {
      // Jeton refusé, réseau coupé, arbre Flutter pas encore prêt : la
      // transition suivante doit pouvoir reprendre l'appel, pas l'abandonner.
      final decision = NativeCallGateDecision();
      expect(decision.roomToJoin(_call(NativeCallState.connecting)), 'salon-1');

      decision.release();

      expect(decision.roomToJoin(_call(NativeCallState.connecting)), 'salon-1');
    });

    test('un nouveau salon se rejoint même si le précédent traîne', () {
      final decision = NativeCallGateDecision();
      decision.roomToJoin(_call(NativeCallState.connecting));

      expect(
        decision.roomToJoin(
          _call(NativeCallState.connecting, room: 'salon-2'),
        ),
        'salon-2',
      );
    });
  });
}
