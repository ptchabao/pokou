import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/calls/presentation/call_session.dart';

/// La décision « quitter l'appel ? » et « à qui dire que je raccroche ? »,
/// isolées de LiveKit pour pouvoir être vérifiées.
///
/// Audit du 23 octobre 2026, A4 : dans un appel de groupe, le PREMIER refus
/// faisait quitter l'appelant alors que d'autres invités sonnaient encore.
void main() {
  group('quitter sur un refus ou un départ', () {
    test('A appelle B et C, C refuse : A reste, B sonne encore', () {
      expect(
        shouldLeaveOnRemoteSignal(
          someoneJoined: false,
          fromUserId: 3,
          remoteInRoom: const [],
          invitees: const [2, 3],
          gone: {3},
        ),
        isFalse,
      );
    });

    test('A appelle B et C, les deux refusent : A quitte', () {
      expect(
        shouldLeaveOnRemoteSignal(
          someoneJoined: false,
          fromUserId: 2,
          remoteInRoom: const [],
          invitees: const [2, 3],
          gone: {2, 3},
        ),
        isTrue,
      );
    });

    test('en 1:1, le refus de l\'unique invité termine l\'appel', () {
      expect(
        shouldLeaveOnRemoteSignal(
          someoneJoined: false,
          fromUserId: 2,
          remoteInRoom: const [],
          invitees: const [2],
          gone: {2},
        ),
        isTrue,
      );
    });

    test(
      'appel établi : un départ ne fait pas quitter s\'il reste quelqu\'un',
      () {
        expect(
          shouldLeaveOnRemoteSignal(
            someoneJoined: true,
            fromUserId: 3,
            remoteInRoom: const [2, 3],
            invitees: const [2, 3],
            gone: {3},
          ),
          isFalse,
        );
      },
    );

    test('appel établi : le dernier départ fait quitter', () {
      expect(
        shouldLeaveOnRemoteSignal(
          someoneJoined: true,
          fromUserId: 2,
          // LiveKit n'a pas encore retiré le partant de la liste.
          remoteInRoom: const [2],
          invitees: const [2],
          gone: {2},
        ),
        isTrue,
      );
    });

    test('une identité illisible ne fait pas rester pour rien', () {
      expect(
        shouldLeaveOnRemoteSignal(
          someoneJoined: true,
          fromUserId: null,
          remoteInRoom: const [],
          invitees: const [2],
          gone: const {},
        ),
        isTrue,
      );
    });
  });

  group('à qui envoyer `end` en raccrochant', () {
    test('en 1:1, à l\'autre', () {
      expect(
        endSignalTargets(
          participantIds: const [2],
          inRoom: const [2],
          isGroup: false,
        ),
        [2],
      );
    });

    test('groupe qui continue sans moi : pas à ceux qui sonnent encore', () {
      expect(
        endSignalTargets(
          participantIds: const [2, 3, 4],
          inRoom: const [2, 3],
          isGroup: true,
        ),
        [2, 3],
      );
    });

    test(
      'groupe qui se termine avec moi : à tout le monde, pour faire taire les sonneries',
      () {
        expect(
          endSignalTargets(
            participantIds: const [2, 3, 4],
            inRoom: const [2],
            isGroup: true,
          ),
          [2, 3, 4],
        );
      },
    );

    test('personne n\'a encore décroché : à tous les invités', () {
      expect(
        endSignalTargets(
          participantIds: const [2, 3],
          inRoom: const [],
          isGroup: true,
        ),
        [2, 3],
      );
    });
  });
}
