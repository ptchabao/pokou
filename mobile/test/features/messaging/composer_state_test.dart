import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/messaging/presentation/composer/composer_state.dart';

/// Les transitions de la barre d'écriture.
///
/// Sans widget ni micro : c'est la logique des gestes qu'on veut pouvoir
/// relire, et c'est précisément elle qui se perd quand tout vit dans des
/// booléens éparpillés au milieu d'un écran de 1 800 lignes.
void main() {
  const machine = ComposerMachine();
  const empty = ComposerState();

  group('écrire', () {
    test('taper du texte remplace le micro par le bouton d\'envoi', () {
      // La règle la plus visible de la barre : un seul bouton à droite,
      // dont la fonction dépend du contenu.
      final typing = machine.onTextChanged(empty, 'Bonjour');
      expect(typing.mode, ComposerMode.typing);
      expect(typing.showsSendButton, isTrue);
    });

    test('tout effacer rend le micro', () {
      final typing = machine.onTextChanged(empty, 'Bonjour');
      final back = machine.onTextChanged(typing, '');
      expect(back.mode, ComposerMode.empty);
      expect(back.showsSendButton, isFalse);
    });

    test('des espaces seuls ne comptent pas comme du texte', () {
      expect(machine.onTextChanged(empty, '   ').mode, ComposerMode.empty);
    });

    test('un événement de texte n\'interrompt pas un enregistrement', () {
      // Un collage ou une suggestion du clavier peut arriver pendant que le
      // micro tourne. Couper la capture à ce moment-là ferait perdre ce
      // qu'on vient de dire.
      final recording = machine.onRecordStart(empty);
      expect(
        machine.onTextChanged(recording, 'texte surgi de nulle part').mode,
        ComposerMode.recording,
      );
    });
  });

  group('enregistrer', () {
    test('poser le doigt sur le micro démarre l\'enregistrement', () {
      final state = machine.onRecordStart(empty);
      expect(state.mode, ComposerMode.recording);
      expect(state.isRecording, isTrue);
      expect(state.dragOffset, 0);
    });

    test('relâcher sans avoir glissé envoie', () {
      final recording = machine.onRecordStart(empty);
      final released = machine.onRecordRelease(recording);
      expect(released.action, ComposerRelease.send);
      expect(released.state, empty, reason: 'la barre revient à son repos');
    });
  });

  group('glisser vers la gauche pour annuler', () {
    test('un petit déplacement ne bascule pas encore en annulation', () {
      final state = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: -20,
        dy: 0,
      );
      expect(state.mode, ComposerMode.recording);
      expect(state.dragOffset, -20, reason: 'la barre suit le doigt');
    });

    test('passé le seuil, relâcher annule', () {
      final state = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: -90,
        dy: 0,
      );
      expect(state.mode, ComposerMode.cancelling);
      expect(machine.onRecordRelease(state).action, ComposerRelease.cancel);
    });

    test('revenir en arrière avant de relâcher sauve l\'enregistrement', () {
      // Le geste doit être réversible : on doit pouvoir changer d'avis tant
      // que le doigt est posé.
      var state = machine.onRecordStart(empty);
      state = machine.onRecordDrag(state, dx: -90, dy: 0);
      state = machine.onRecordDrag(state, dx: -10, dy: 0);
      expect(state.mode, ComposerMode.recording);
      expect(machine.onRecordRelease(state).action, ComposerRelease.send);
    });

    test('tirer vers la droite ne déplace pas la barre', () {
      // Ce geste n'existe pas : laisser la barre s'y déplacer laisserait
      // croire le contraire.
      final state = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: 120,
        dy: 0,
      );
      expect(state.dragOffset, 0);
    });
  });

  group('glisser vers le haut pour verrouiller', () {
    test('passé le seuil, l\'enregistrement se verrouille', () {
      final state = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: 0,
        dy: -70,
      );
      expect(state.mode, ComposerMode.locked);
    });

    test('lever le doigt après verrouillage ne fait rien', () {
      // C'est tout l'intérêt du verrou : on repose son téléphone et
      // l'enregistrement continue.
      final locked = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: 0,
        dy: -70,
      );
      final released = machine.onRecordRelease(locked);
      expect(released.action, ComposerRelease.none);
      expect(released.state.mode, ComposerMode.locked);
    });

    test('verrouillé, la barre offre le bouton d\'envoi', () {
      final locked = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: 0,
        dy: -70,
      );
      expect(locked.showsSendButton, isTrue);
      expect(locked.isRecording, isTrue);
    });

    test('un geste en diagonale verrouille plutôt qu\'il n\'annule', () {
      // Se tromper dans ce sens fait perdre ce qu'on vient de dire, et c'est
      // irrattrapable. Dans l'autre, on garde un enregistrement de trop.
      final state = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: -120,
        dy: -70,
      );
      expect(state.mode, ComposerMode.locked);
    });

    test('un enregistrement verrouillé ne s\'annule plus par glissement', () {
      var state = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: 0,
        dy: -70,
      );
      state = machine.onRecordDrag(state, dx: -200, dy: 0);
      expect(state.mode, ComposerMode.locked);
    });

    test('la corbeille et l\'envoi ramènent la barre au repos', () {
      final locked = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: 0,
        dy: -70,
      );
      expect(machine.onCancel(locked), empty);
      expect(machine.onSend(locked), empty);
    });
  });

  group('l\'indication de verrouillage', () {
    test('se renforce à mesure que le doigt monte', () {
      // Un geste qu'on ne devine pas n'est jamais découvert : le cadenas
      // doit s'allumer progressivement, pas apparaître une fois le seuil
      // franchi.
      var state = machine.onRecordStart(empty);
      expect(state.lockProgress, 0);

      state = machine.onRecordDrag(state, dx: 0, dy: -30);
      expect(state.lockProgress, closeTo(0.5, 0.01));

      state = machine.onRecordDrag(state, dx: 0, dy: -70);
      expect(state.lockProgress, 1);
    });

    test('reste à zéro quand le doigt descend', () {
      final state = machine.onRecordDrag(
        machine.onRecordStart(empty),
        dx: 0,
        dy: 40,
      );
      expect(state.lockProgress, 0);
    });
  });

  group('les seuils', () {
    test('sont réglables sans toucher à la logique', () {
      const patient = ComposerMachine(
        geometry: ComposerGeometry(cancelThreshold: 200, lockThreshold: 200),
      );
      final state = patient.onRecordDrag(
        patient.onRecordStart(empty),
        dx: -90,
        dy: -70,
      );
      expect(state.mode, ComposerMode.recording,
          reason: 'aucun des deux seuils n\'est atteint');
    });
  });
}
