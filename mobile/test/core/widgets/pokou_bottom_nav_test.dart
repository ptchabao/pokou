import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/widgets/pokou_bottom_nav.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// La barre de navigation basse.
///
/// Ce test décrivait auparavant une pilule flottante à bords arrondis. Le
/// design est passé à une barre PLEINE LARGEUR, collée au bord, et l'onglet
/// actif au teal de marque plutôt qu'au vert d'action. Les assertions
/// suivent ce changement, mais les propriétés VÉRIFIÉES restent les mêmes :
/// ce sont elles qui comptent, pas la forme.
void main() {
  BottomNavigationBar navOf(WidgetTester tester) =>
      tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));

  Future<void> pump(WidgetTester tester, {int index = 0, Locale? locale}) {
    return tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: L.supportedLocales,
        localizationsDelegates: L.localizationsDelegates,
        home: Scaffold(
          bottomNavigationBar: PokouBottomNav(
            currentIndex: index,
            onTap: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('barre blanche, actif distinct des inactifs', (tester) async {
    await pump(tester);
    final nav = navOf(tester);

    expect(nav.backgroundColor, AppColors.navBackground);
    expect(nav.backgroundColor, Colors.white);

    // L'onglet actif utilise l'encre de marque, distincte de la couleur
    // réservée aux actions.
    expect(nav.selectedItemColor, AppColors.accentPrimaryDark);

    // Les inactifs utilisent le ton atténué de la palette.
    expect(nav.unselectedItemColor, AppColors.navIconInactive);
    expect(nav.selectedItemColor, isNot(nav.unselectedItemColor));
  });

  testWidgets('les destinations sont toutes rendues', (tester) async {
    await pump(tester);
    // Le compte a déjà divergé une fois : la barre déclarait cinq
    // destinations quand la coquille n'avait que quatre écrans, rendant le
    // dernier onglet injoignable. Le lien entre les deux se vérifie ici.
    final context = tester.element(find.byType(BottomNavigationBar));
    final destinations = pokouNavDestinationsOf(context);
    expect(navOf(tester).items.length, destinations.length);
    expect(destinations.length, PokouTab.values.length);
    for (final destination in destinations) {
      expect(find.text(destination.label), findsOneWidget);
    }
  });

  testWidgets('les libellés suivent la langue', (tester) async {
    // La liste était `const`, donc figée en français à la compilation. Une
    // barre de navigation qui reste en français dans une application
    // traduite est ce qui se remarque en premier.
    await pump(tester, locale: const Locale('en'));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    await pump(tester, locale: const Locale('ru'));
    expect(find.text('Чаты'), findsOneWidget);
  });

  testWidgets('le type « fixed » garde les libellés visibles', (tester) async {
    await pump(tester);
    // Le défaut de Flutter (`shifting`) masque les libellés inactifs et fait
    // bouger la barre au toucher.
    expect(navOf(tester).type, BottomNavigationBarType.fixed);
  });

  test('le lot 1 affiche les onglets de messagerie (NAV-10)', () {
    expect(pokouTabsFor({'discussions'}), [
      PokouTab.discussions,
      PokouTab.statuses,
      PokouTab.calls,
      PokouTab.settings,
    ]);
  });

  test('les onglets suivent les modules configurés', () {
    expect(pokouTabsFor({'discussions', 'kory'}), [
      PokouTab.home,
      PokouTab.discussions,
      PokouTab.kory,
      PokouTab.more,
    ]);
    // L'ordre du cahier des charges : Accueil | Discussions | Kory | Honam | Plus.
    expect(pokouTabsFor({'discussions', 'kory', 'honam'}), [
      PokouTab.home,
      PokouTab.discussions,
      PokouTab.kory,
      PokouTab.honam,
      PokouTab.more,
    ]);
  });

  test('Kory et Honam actifs affichent les onglets de service partout', () {
    expect(pokouTabsFor({'discussions', 'kory', 'honam'}), [
      PokouTab.home,
      PokouTab.discussions,
      PokouTab.kory,
      PokouTab.honam,
      PokouTab.more,
    ]);
  });

  testWidgets("l'onglet actif suit l'index demandé", (tester) async {
    await pump(tester, index: 3);
    expect(navOf(tester).currentIndex, 3);
  });
}
