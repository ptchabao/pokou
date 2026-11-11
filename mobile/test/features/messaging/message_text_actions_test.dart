import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/messaging/presentation/message_text_actions.dart';
import 'package:pokou/l10n/app_localizations.dart';

void main() {
  test('seul un texte lisible se copie', () {
    expect(copyableText('  Bonjour  '), 'Bonjour');
    expect(copyableText(''), isNull);
    expect(copyableText(null), isNull);
    expect(copyableText('Bonjour', deleted: true), isNull);
    expect(copyableText('Bonjour', locked: true), isNull);
  });

  testWidgets('« Copier » met le message dans le presse-papiers', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: messageTextActionTiles(
                context: context,
                text: 'Rendez-vous à 15h',
                close: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Sélectionner le texte'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);

    await tester.tap(find.text('Copier'));
    await tester.pumpAndSettle();
    expect(clipboard, 'Rendez-vous à 15h');
    expect(find.text('Message copié'), findsOneWidget);

    await tester.tap(find.text('Sélectionner le texte'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Tout copier'), findsOneWidget);
  });
}
