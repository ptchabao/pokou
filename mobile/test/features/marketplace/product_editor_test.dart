import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/marketplace/presentation/assime_publish.dart';
import 'package:pokou/features/marketplace/presentation/product_editor.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// Le formulaire d'annonce doit rendre des CODES (« XOF », « TELEPHONES »),
/// jamais les libellés affichés dans ses menus (« FCFA (XOF) »,
/// « Téléphones ») : le serveur refuse une devise qu'il ne connaît pas, et
/// une catégorie écrite autrement que son code n'apparaît sous aucun filtre.
Future<ProductDraft?> _publish(
  WidgetTester tester, {
  Future<void> Function()? before,
}) async {
  ProductDraft? draft;
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                draft = await Navigator.of(context).push<ProductDraft>(
                  MaterialPageRoute(builder: (_) => const ProductEditor()),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Titre'), 'Pagne wax');
  await tester.enterText(find.widgetWithText(TextField, 'Prix'), '5000');
  await tester.pump();
  if (before != null) await before();
  await tester.tap(find.text('Enregistrer'));
  await tester.pumpAndSettle();
  return draft;
}

void main() {
  testWidgets(
    'sans toucher aux menus, la devise et la catégorie sont des codes',
    (tester) async {
      final draft = await _publish(tester);
      expect(draft, isNotNull);
      expect(draft!.currency, 'XOF');
      expect(draft.category, 'AUTRE');
    },
  );

  testWidgets('une catégorie choisie dans le menu part sous son code', (
    tester,
  ) async {
    final draft = await _publish(
      tester,
      before: () async {
        await tester.tap(find.widgetWithText(TextField, 'Autre').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Téléphones').last);
        await tester.pumpAndSettle();
      },
    );
    expect(draft!.category, 'TELEPHONES');
    expect(draft.currency, 'XOF');
  });

  testWidgets(
    'un refus du serveur garde le formulaire ouvert, saisie intacte',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: ProductEditor(
              onSubmit: (_) async {
                attempts++;
                throw Exception('réseau');
              },
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Titre'),
        'Pagne wax',
      );
      // Assimé 5 → 6 : l'assistant passe aux prix, état et lieu.
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Prix'), '5 000');
      // Une nouvelle annonce passe par l'aperçu (Assimé 7) : rien ne part
      // avant l'engagement sur les produits interdits.
      await tester.tap(find.text('Voir l’aperçu'));
      await tester.pumpAndSettle();
      expect(find.byType(AssimePreviewScreen), findsOneWidget);
      await tester.tap(find.text('Publier l’annonce'));
      await tester.pumpAndSettle();
      expect(attempts, 0);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Publier l’annonce'));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(find.textContaining('Rien n\'est perdu'), findsOneWidget);
      // Le refus laisse l'aperçu ouvert ; au retour, la saisie est intacte.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ProductEditor), findsOneWidget);
      expect(find.text('5 000'), findsOneWidget);
      // Le retour ramène à l'étape 1, titre intact.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Pagne wax'), findsOneWidget);
    },
  );

  test('le prix saisi à la main devient un nombre que le serveur accepte', () {
    expect(ProductEditorState.normalizePrice('5000'), '5000');
    expect(ProductEditorState.normalizePrice('5 000'), '5000');
    expect(ProductEditorState.normalizePrice('5.000'), '5000');
    expect(ProductEditorState.normalizePrice('12 500 FCFA'), '12500');
    expect(ProductEditorState.normalizePrice('2,5'), '2.5');
    expect(ProductEditorState.normalizePrice('1.250,50'), '1250.50');
    expect(ProductEditorState.normalizePrice('gratuit'), isNull);
    expect(ProductEditorState.normalizePrice(''), isNull);
  });
}
