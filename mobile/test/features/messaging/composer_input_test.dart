import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/messaging/presentation/composer/composer_input.dart';
import 'package:pokou/features/messaging/presentation/composer/composer_state.dart';
import 'package:pokou/features/messaging/presentation/composer/mic_button.dart';
import 'package:pokou/features/messaging/presentation/message_appear.dart';

/// La barre d'écriture : trombone, emoji, champ, appareil photo, et le
/// bouton micro / envoi.

class _Bar extends StatefulWidget {
  const _Bar({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  final controller = TextEditingController();
  final focus = FocusNode();
  final machine = const ComposerMachine();
  ComposerState composer = const ComposerState();
  bool emojiOpen = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() => composer = machine.onTextChanged(composer, controller.text));
    });
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ComposerInputPill(
          controller: controller,
          focusNode: focus,
          hintText: 'Message',
          emojiOpen: emojiOpen,
          enabled: true,
          onAttach: () {},
          onToggleEmoji: () => setState(() => emojiOpen = !emojiOpen),
          onCamera: () {},
          onSubmitted: (_) {},
          attachTooltip: 'Joindre',
          emojiTooltip: 'Emoji',
          cameraTooltip: 'Appareil photo',
        ),
      ),
      ComposerActionButton(
        state: composer,
        machine: machine,
        enabled: true,
        onSendText: () {
          widget.onSend(controller.text);
          controller.clear();
        },
        onSendRecording: () {},
        onRecordStart: () {},
        onStateChanged: (next) => setState(() => composer = next),
        onRelease: (_) {},
      ),
    ],
  );
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('l\'ordre : trombone, emoji, champ, appareil photo', (tester) async {
    await tester.pumpWidget(_app(_Bar(onSend: (_) {})));
    final attach = tester.getCenter(find.byIcon(Icons.attach_file)).dx;
    final emoji = tester.getCenter(find.byIcon(Icons.sentiment_satisfied_alt_outlined)).dx;
    final field = tester.getCenter(find.byType(TextField)).dx;
    final camera = tester.getCenter(find.byIcon(Icons.photo_camera_outlined)).dx;
    expect(attach < emoji && emoji < field && field < camera, isTrue);
  });

  testWidgets('l\'appareil photo se retire dès qu\'on écrit, et revient', (tester) async {
    await tester.pumpWidget(_app(_Bar(onSend: (_) {})));
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'B');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
    // Le micro a cédé la place à l'envoi.
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('envoyer vide le champ et ramène le micro', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_app(_Bar(onSend: sent.add)));
    await tester.enterText(find.byType(TextField), 'Bonjour');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(sent, ['Bonjour']);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('l\'emoji pivote vers le clavier', (tester) async {
    await tester.pumpWidget(_app(_Bar(onSend: (_) {})));
    await tester.tap(find.byIcon(Icons.sentiment_satisfied_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
  });

  testWidgets('le champ grandit jusqu\'à six lignes', (tester) async {
    await tester.pumpWidget(_app(_Bar(onSend: (_) {})));
    expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 6);
  });

  group('l\'arrivée d\'une bulle', () {
    Future<bool> animates(
      WidgetTester tester, {
      required String id,
      required bool isMine,
      required bool isLast,
    }) async {
      await tester.pumpWidget(
        _app(
          MessageAppear(
            // Comme dans la liste : une clé par message.
            key: ValueKey(id),
            messageId: id,
            isMine: isMine,
            isLast: isLast,
            child: const Text('bulle'),
          ),
        ),
      );
      return find
          .descendant(
            of: find.byType(MessageAppear),
            matching: find.byType(FadeTransition),
          )
          .evaluate()
          .isNotEmpty;
    }

    testWidgets('un message reçu en bas de la conversation s\'anime', (tester) async {
      expect(await animates(tester, id: 'srv-1', isMine: false, isLast: true), isTrue);
    });

    testWidgets('un message de l\'historique ne s\'anime pas', (tester) async {
      expect(await animates(tester, id: 'srv-2', isMine: false, isLast: false), isFalse);
    });

    testWidgets('son envoi optimiste s\'anime, sa confirmation non', (tester) async {
      expect(await animates(tester, id: 'local-1-2', isMine: true, isLast: true), isTrue);
      // Le même message revenu du serveur sous son identifiant définitif.
      expect(await animates(tester, id: 'srv-3', isMine: true, isLast: true), isFalse);
    });

    testWidgets('une bulle déjà montrée ne rejoue pas son entrée', (tester) async {
      expect(await animates(tester, id: 'srv-4', isMine: false, isLast: true), isTrue);
      await tester.pumpWidget(_app(const SizedBox()));
      expect(await animates(tester, id: 'srv-4', isMine: false, isLast: true), isFalse);
    });
  });
}
