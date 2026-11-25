import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/wallpaper/wallpaper_catalog.dart';
import 'package:pokou/core/wallpaper/wallpaper_settings.dart';
import 'package:pokou/core/wallpaper/wallpaper_view.dart';
import 'package:pokou/core/widgets/chat_wallpaper.dart';
import 'package:pokou/features/settings/presentation/chat_wallpaper_screen.dart';
import 'package:pokou/l10n/app_localizations.dart';

import 'memory_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catalogue', () {
    test('chargé depuis le manifeste embarqué', () async {
      final catalog = await WallpaperCatalog.load(rootBundle);
      expect(catalog.wallpapers, hasLength(24));
      expect(catalog.defaultId, 'sable');
      expect(catalog.fallback.type, WallpaperType.color);
      for (final family in WallpaperFamily.values) {
        expect(catalog.family(family), isNotEmpty, reason: family.name);
      }
      // Les noms propres restent tels quels.
      expect(catalog.byId('ndi').name, 'Ŋdi');
      final kente = catalog.byId('kete');
      expect(kente.type, WallpaperType.tile);
      expect(kente.tileSize, const Size(96, 96));
      expect(kente.tileAsset, 'assets/wallpapers/tiles/kete.png');
      expect(catalog.byId('ge').sceneAsset, 'assets/wallpapers/scenes/ge.webp');
      expect(catalog.byId('za').isDark, isTrue);
      expect(catalog.byId('sable').intensityAdjustable, isFalse);
      // Un identifiant inconnu retombe sur le défaut.
      expect(catalog.byId('disparu').id, 'sable');
    });

    test('chaque fichier cité existe, avec ses variantes de densité', () {
      final json =
          jsonDecode(File(WallpaperCatalog.manifestAsset).readAsStringSync())
              as Map<String, dynamic>;
      final catalog = WallpaperCatalog.fromJson(json);
      for (final w in catalog.wallpapers) {
        expect(File(w.thumbnail).existsSync(), isTrue, reason: w.thumbnail);
        if (w.tileAsset != null) {
          final file = w.tileAsset!.split('/').last;
          for (final path in [
            w.tileAsset!,
            'assets/wallpapers/tiles/2.0x/$file',
            'assets/wallpapers/tiles/3.0x/$file',
          ]) {
            expect(File(path).existsSync(), isTrue, reason: path);
          }
        }
        if (w.sceneAsset != null) {
          expect(File(w.sceneAsset!).existsSync(), isTrue, reason: w.id);
        }
      }
    });

    test('les fonds de fête n’apparaissent que pendant leur période', () async {
      final catalog = await WallpaperCatalog.load(rootBundle);
      final finAnnee = catalog.byId('finannee');
      expect(finAnnee.isOfferedOn(DateTime(2026, 11, 22)), isFalse);
      expect(finAnnee.isOfferedOn(DateTime(2026, 12, 20)), isTrue);
      expect(finAnnee.isOfferedOn(DateTime(2027, 1, 7)), isTrue);
      expect(finAnnee.isOfferedOn(DateTime(2027, 1, 8)), isFalse);
      expect(catalog.byId('togo').isOfferedOn(DateTime(2026, 4, 27)), isTrue);
      // Ramadan et Tabaski : dates distantes, pas encore servies.
      expect(
        catalog.byId('tabaski').isOfferedOn(DateTime(2026, 5, 27)),
        isFalse,
      );
      expect(catalog.byId('kete').isOfferedOn(DateTime(2026, 11, 22)), isTrue);
    });
  });

  group('réglage', () {
    test('le choix est enregistré, puis relu au lancement suivant', () async {
      final storage = MemoryStorage();
      final first = ChatWallpaperController(storage: storage);
      await first.choose(
        null,
        const WallpaperChoice(id: 'kete', intensity: 60),
      );
      await first.choose(
        scopeForGroup(7),
        const WallpaperChoice(id: 'ge', intensity: 80),
      );

      final next = ChatWallpaperController(storage: storage);
      await next.loaded;
      expect(
        next.state.global,
        const WallpaperChoice(id: 'kete', intensity: 60),
      );
      expect(
        next.state.perChat['group:7'],
        const WallpaperChoice(id: 'ge', intensity: 80),
      );
    });

    test('le fond d’une discussion l’emporte sur le défaut', () async {
      final controller = ChatWallpaperController(storage: MemoryStorage());
      await controller.choose(null, const WallpaperChoice(id: 'kete'));
      await controller.choose(
        scopeForContact(42),
        const WallpaperChoice(id: 'adinkra'),
      );
      final s = controller.state;
      expect(s.resolve('contact:42')!.id, 'adinkra');
      expect(s.resolve('contact:43')!.id, 'kete');
      expect(s.resolve(null)!.id, 'kete');

      await controller.useDefault('contact:42');
      expect(controller.state.resolve('contact:42')!.id, 'kete');
    });

    test('un réglage abîmé ne casse rien', () async {
      final controller = ChatWallpaperController(
        storage: MemoryStorage({ChatWallpaperController.storageKey: '{oups'}),
      );
      await controller.loaded;
      expect(controller.state.resolve('contact:1'), isNull);
    });
  });

  group('affichage', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      Widget child,
      ChatWallpaperController controller,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final catalog = readTestCatalog();
      final container = ProviderContainer(
        overrides: [
          chatWallpaperProvider.overrideWith((ref) => controller),
          wallpaperCatalogProvider.overrideWith((ref) => catalog),
          wallpaperClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 22),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: child,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return container;
    }

    testWidgets('la conversation montre son fond, sinon le défaut', (
      tester,
    ) async {
      final controller = ChatWallpaperController(storage: MemoryStorage());
      await controller.choose(null, const WallpaperChoice(id: 'kete'));
      await controller.choose('group:3', const WallpaperChoice(id: 'ge'));

      await pump(
        tester,
        const Row(
          children: [
            Expanded(
              child: ChatWallpaper(scope: 'group:3', child: SizedBox.expand()),
            ),
            Expanded(
              child: ChatWallpaper(scope: 'group:4', child: SizedBox.expand()),
            ),
          ],
        ),
        controller,
      );
      final shown = tester
          .widgetList<WallpaperView>(find.byType(WallpaperView))
          .map((v) => v.wallpaper.id)
          .toList();
      expect(shown, ['ge', 'kete']);
    });

    testWidgets('choisir une vignette enregistre le fond de la discussion', (
      tester,
    ) async {
      final controller = ChatWallpaperController(storage: MemoryStorage());
      await pump(
        tester,
        const ChatWallpaperScreen(scope: 'contact:9', chatName: 'Ama'),
        controller,
      );

      await tester.tap(find.text('Motifs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kente'));
      await tester.pump();
      expect(controller.state.perChat['contact:9']!.id, 'kete');
      expect(controller.state.global, isNull);
      // Fond réglable : le curseur d'intensité apparaît.
      expect(find.byType(Slider), findsOneWidget);

      await tester.tap(find.text('Utiliser le fond par défaut'));
      await tester.pump();
      expect(controller.state.perChat.containsKey('contact:9'), isFalse);
    });

    testWidgets('hors période, l’onglet Fêtes explique son absence', (
      tester,
    ) async {
      final controller = ChatWallpaperController(storage: MemoryStorage());
      await pump(tester, const ChatWallpaperScreen(), controller);
      await tester.tap(find.text('Fêtes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('apparaissent ici'), findsOneWidget);
    });
  });
}
