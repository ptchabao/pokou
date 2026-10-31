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
          bottomNavigationBar: PokouBottomNav(currentIndex: index, onTap: (_) {}),
        ),
      ),
    );
  }

  testWidgets('barre blanche, actif distinct des inactifs', (tester) async {
    await pump(tester);
    final nav = navOf(tester);

    expect(nav.backgroundColor, AppColors.navBackground);
    expect(nav.backgroundColor, Colors.white);

    // L'onglet actif dit « vous êtes là ». Le teal de marque et non le vert
    // d'action : sur une barre blanche, le vert plafonne à 1,8:1 de
    // contraste (voir app_colors.dart), illisible à cette taille d'icône.
    expect(nav.selectedItemColor, AppColors.accentPrimaryDark);

    // Les inactifs au gris froid, pas au noir : du noir plein mettrait tous
    // les onglets au même niveau d'appel visuel, et l'actif n'aurait plus
    // rien à distinguer.
    expect(nav.unselectedItemColor, AppColors.navIconInactive);
    expect(nav.unselectedItemColor, const Color(0xFF64748B));
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

  testWidgets('le type « fixed » garde les quatre onglets visibles', (tester) async {
    await pump(tester);
    // Au-delà de trois destinations, le défaut de Flutter (`shifting`)
    // masque le libellé des onglets inactifs et les fait bouger au toucher.
    // Sur cinq onglets dont « Marketplace » et « Actualités », des icônes
    // seules ne suffisent pas à savoir où l'on va.
    expect(navOf(tester).type, BottomNavigationBarType.fixed);
  });

  test('Kory n\'apparaît que là où le pays l\'ouvre (NAV-01)', () {
    expect(pokouTabsFor({'discussions'}), [
      PokouTab.home,
      PokouTab.discussions,
      PokouTab.more,
    ]);
    expect(pokouTabsFor({'discussions', 'kory'}), [
      PokouTab.home,
      PokouTab.discussions,
      PokouTab.kory,
      PokouTab.more,
    ]);
  });

  testWidgets("l'onglet actif suit l'index demandé", (tester) async {
    await pump(tester, index: 3);
    expect(navOf(tester).currentIndex, 3);
  });
}
