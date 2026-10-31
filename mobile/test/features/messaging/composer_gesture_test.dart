import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/messaging/presentation/composer/composer_state.dart';
import 'package:pokou/features/messaging/presentation/composer/mic_button.dart';

/// Le geste de la note vocale, de bout en bout.
///
/// La machine à états était testée, le bouton ne l'était pas — et le défaut
/// vivait précisément entre les deux. Le bouton porte le `GestureDetector`
/// de l'appui long ; l'écran remplaçait TOUTE la rangée dès que
/// l'enregistrement démarrait, ce qui le démontait en plein geste. Plus
/// aucun mouvement ne lui parvenait : ni glissement pour annuler, ni
/// glissement pour verrouiller, et la corbeille restait éteinte faute de
/// pouvoir verrouiller.
///
/// Le harnais reproduit donc la structure de l'écran : un frère qui change
/// selon le mode, et le bouton qui, lui, reste en place.
class _Harness extends StatefulWidget {
  const _Harness({required this.onRelease});

  final ValueChanged<ComposerRelease> onRelease;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  static const _machine = ComposerMachine();
  ComposerState state = const ComposerState();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            // Le frère qui change de contenu selon le mode — la pilule dans
            // l'écran réel.
            Expanded(
              child: Text(state.isRecording ? 'enregistre' : 'écrire'),
            ),
            ComposerActionButton(
              state: state,
              machine: _machine,
              enabled: true,
              onSendText: () {},
              onSendRecording: () {},
              onRecordStart: () {},
              onStateChanged: (next) => setState(() => state = next),
              onRelease: widget.onRelease,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  Future<_HarnessState> pump(
    WidgetTester tester,
    List<ComposerRelease> released,
  ) async {
    await tester.pumpWidget(_Harness(onRelease: released.add));
    return tester.state<_HarnessState>(find.byType(_Harness));
  }

  testWidgets('maintenir le micro démarre l\'enregistrement', (tester) async {
    final released = <ComposerRelease>[];
    final harness = await pump(tester, released);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ComposerActionButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(harness.state.mode, ComposerMode.recording);
    expect(find.text('enregistre'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(released, [ComposerRelease.send]);
  });

  testWidgets('glisser vers la gauche annule, malgré le changement de mode',
      (tester) async {
    // Le cœur du défaut : entre le démarrage et le glissement, le frère a
    // changé de contenu et l'arbre s'est reconstruit. Si le bouton ne
    // survit pas à cette reconstruction, plus aucun mouvement ne lui
    // parvient et ce test échoue.
    final released = <ComposerRelease>[];
    final harness = await pump(tester, released);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ComposerActionButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();

    expect(harness.state.mode, ComposerMode.cancelling);

    await gesture.up();
    await tester.pump();
    expect(released, [ComposerRelease.cancel]);
  });

  testWidgets('glisser vers le haut verrouille, et lever le doigt ne fait rien',
      (tester) async {
    final released = <ComposerRelease>[];
    final harness = await pump(tester, released);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ComposerActionButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();

    expect(harness.state.mode, ComposerMode.locked);

    await gesture.up();
    await tester.pump();
    expect(released, [ComposerRelease.none],
        reason: 'c\'est tout l\'intérêt du verrou : le doigt peut partir');
    expect(harness.state.mode, ComposerMode.locked);
  });

  testWidgets('verrouillé, le bouton devient un envoi', (tester) async {
    final harness = await pump(tester, []);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ComposerActionButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(harness.state.showsSendButton, isTrue);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('un appui bref n\'enregistre rien', (tester) async {
    // Une note d'un dixième de seconde déclenchée par un effleurement n'a
    // aucune valeur, et l'envoyer serait pire que de l'ignorer.
    final released = <ComposerRelease>[];
    final harness = await pump(tester, released);

    await tester.tap(find.byType(ComposerActionButton));
    await tester.pump();

    expect(harness.state.mode, ComposerMode.empty);
    expect(released, isEmpty);
  });
}
