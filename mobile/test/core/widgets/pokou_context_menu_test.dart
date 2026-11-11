import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/widgets/pokou_context_menu.dart';
import 'package:pokou/l10n/app_localizations.dart';

void main() {
  testWidgets('« Coller » est proposé même si Flutter croit le presse-papiers vide, et colle', (tester) async {
    // Flutter interroge `hasStrings` pour décider d'afficher « Coller ».
    // On lui répond « vide » ; le presse-papiers contient pourtant du texte
    // (copié dans l'app, par exemple).
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.hasStrings' => {'value': false},
        'Clipboard.getData' => {'text': 'Rendez-vous à 15h'},
        _ => null,
      },
    );
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: Center(
            child: TextField(
              controller: controller,
              contextMenuBuilder: pokouContextMenuBuilder,
            ),
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();

    final paste = find.text('Coller');
    expect(paste, findsOneWidget);
    await tester.tap(paste);
    await tester.pumpAndSettle();
    expect(controller.text, 'Rendez-vous à 15h');
  });
}
