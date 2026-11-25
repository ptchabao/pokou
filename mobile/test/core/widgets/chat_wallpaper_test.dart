import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/wallpaper/wallpaper_catalog.dart';
import 'package:pokou/core/wallpaper/wallpaper_settings.dart';
import 'package:pokou/core/wallpaper/wallpaper_view.dart';
import 'package:pokou/core/widgets/chat_wallpaper.dart';

import '../wallpaper/memory_storage.dart';

/// Le papier peint est une décoration : rien ne casse s'il disparaît, l'écran
/// reste parfaitement fonctionnel — juste nu. C'est exactement pour ça qu'il
/// mérite un test : une régression ici ne se signale d'aucune façon.
void main() {
  Future<void> pump(WidgetTester tester, {Size? body}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatWallpaperProvider.overrideWith(
            (ref) => ChatWallpaperController(storage: MemoryStorage()),
          ),
          wallpaperCatalogProvider.overrideWith((ref) => readTestCatalog()),
        ],
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topCenter,
            child: SizedBox.fromSize(
              size: body,
              child: const ChatWallpaper(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sans choix, le fond par défaut du catalogue (Sable)', (
    tester,
  ) async {
    await pump(tester);
    final view = tester.widget<WallpaperView>(find.byType(WallpaperView));
    expect(view.wallpaper.id, 'sable');
    expect(view.isDefault, isTrue);
    expect(view.wallpaper.type, WallpaperType.color);
  });

  testWidgets('le fond garde la hauteur de l’écran quand le clavier s’ouvre', (
    tester,
  ) async {
    // Corps de page raccourci, comme sous un clavier ouvert.
    await pump(tester, body: const Size(800, 300));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getSize(find.byType(WallpaperView)).height, screen.height);
  });

  testWidgets('en sombre, Sable prend la couleur de conversation sombre', (
    tester,
  ) async {
    AppColors.applyBrightness(Brightness.dark);
    addTearDown(() => AppColors.applyBrightness(Brightness.light));
    await pump(tester);
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(WallpaperView),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, AppColors.chatBackground);
  });
}
