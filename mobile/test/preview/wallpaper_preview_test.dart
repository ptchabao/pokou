// Rendus PNG des fonds d'écran des discussions, pour relire le design :
//
//   POKOU_PREVIEW=/chemin/de/sortie flutter test test/preview/wallpaper_preview_test.dart
//
// Sans la variable, le test ne fait rien. Aides recopiées de
// preview_test.dart.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/theme/app_theme.dart';
import 'package:pokou/core/wallpaper/wallpaper_catalog.dart';
import 'package:pokou/core/wallpaper/wallpaper_settings.dart';
import 'package:pokou/core/widgets/chat_wallpaper.dart';
import 'package:pokou/features/settings/presentation/chat_wallpaper_screen.dart';
import 'package:pokou/l10n/app_localizations.dart';

import '../core/wallpaper/memory_storage.dart';

final _out = Platform.environment['POKOU_PREVIEW'];

/// Échelle des rendus (POKOU_PREVIEW_SCALE=2 pour le site) ; 1 par défaut.
final _scale =
    double.tryParse(Platform.environment['POKOU_PREVIEW_SCALE'] ?? '') ?? 1;
final _key = GlobalKey();

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        File(f).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }

  await family('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  await family('Outfit', [
    'assets/fonts/Outfit-SemiBold.ttf',
    'assets/fonts/Outfit-Bold.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    await family('MaterialIcons', [icons.path]);
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget Function() build, {
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
  Future<void> Function()? after,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
  tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
  AppColors.applyBrightness(brightness);
  final screen = build();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('fr'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
          home: screen,
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (after != null) {
    await after();
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  final boundary =
      _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _scale);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$_out/$name.png').writeAsBytesSync(bytes!);
  print('PREVIEW $name');
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  AppColors.applyBrightness(Brightness.light);
}

/// Une conversation à deux, telle que l'écran la compose : barre opaque en
/// haut, bulles sur le fond, barre de saisie en bas — sur le vrai
/// [ChatWallpaper]. (Le vrai ConversationScreen demande la base locale, le
/// chiffrement et le réseau ; le fond, lui, est exactement celui de l'app.)
Widget _conversation() {
  Widget bubble(
    String text, {
    required bool mine,
    String time = '10:42',
  }) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxWidth: 290),
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
      decoration: BoxDecoration(
        color: mine ? AppColors.chatBubbleSent : AppColors.chatBubbleReceived,
        gradient: mine ? AppGradients.sentBubble : null,
        border: mine
            ? null
            : Border.all(color: AppColors.chatBubbleReceivedBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: mine ? AppColors.textPrimary : AppColors.chatTextReceived,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );

  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: ChatWallpaper(
        scope: scopeForContact(10),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.accentPrimary,
                        child: const Text(
                          'K',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kanle',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.videocam_outlined,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.call_outlined, color: AppColors.textPrimary),
                      const SizedBox(width: 16),
                      Icon(Icons.more_vert, color: AppColors.textPrimary),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Aujourd’hui',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    bubble('Bonjour ! Tu es déjà au marché ?', mine: false),
                    bubble('Oui, j’arrive au stand de tissus.', mine: true),
                    bubble(
                      'Prends-moi deux pagnes Kente, les verts si possible.',
                      mine: false,
                    ),
                    bubble('D’accord, je t’envoie une photo.', mine: true),
                    bubble('Merci beaucoup 🙏', mine: false, time: '10:45'),
                    bubble(
                      'Ils font 12 000 FCFA les deux. Ça te va ?',
                      mine: true,
                      time: '10:51',
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chatComposerBg,
                  border: Border.all(color: AppColors.chatComposerBorder),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_emotions_outlined,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Message',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    Icon(Icons.mic_none, color: AppColors.textMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('rendus des fonds d’écran', (tester) async {
    if (_out == null) return;
    Directory(_out!).createSync(recursive: true);
    await tester.runAsync(_loadFonts);
    final catalog = readTestCatalog();

    Future<List<Override>> withChoice(
      WallpaperChoice? global, {
      Map<String, WallpaperChoice> chats = const {},
      DateTime? today,
    }) async {
      late ChatWallpaperController controller;
      await tester.runAsync(() async {
        controller = ChatWallpaperController(storage: MemoryStorage());
        await controller.loaded;
        if (global != null) await controller.choose(null, global);
        for (final e in chats.entries) {
          await controller.choose(e.key, e.value);
        }
      });
      return [
        chatWallpaperProvider.overrideWith((ref) => controller),
        wallpaperCatalogProvider.overrideWith((ref) => catalog),
        wallpaperClockProvider.overrideWithValue(
          () => today ?? DateTime(2026, 11, 22),
        ),
      ];
    }

    for (final brightness in Brightness.values) {
      final suffix = brightness == Brightness.dark ? 'dark' : 'light';
      for (final choice in const [
        WallpaperChoice(id: 'sable'),
        WallpaperChoice(id: 'kete', intensity: 100),
        WallpaperChoice(id: 'ge'),
      ]) {
        await _shot(
          tester,
          'wallpaper_conv_${choice.id}_$suffix',
          _conversation,
          brightness: brightness,
          overrides: await withChoice(
            null,
            chats: {scopeForContact(10): choice},
          ),
        );
      }
      await _shot(
        tester,
        'wallpaper_picker_$suffix',
        () => const ChatWallpaperScreen(),
        brightness: brightness,
        overrides: await withChoice(
          const WallpaperChoice(id: 'kete', intensity: 70),
        ),
      );
      await _shot(
        tester,
        'wallpaper_picker_chat_$suffix',
        () =>
            ChatWallpaperScreen(scope: scopeForContact(10), chatName: 'Kanle'),
        brightness: brightness,
        overrides: await withChoice(
          null,
          chats: {scopeForContact(10): const WallpaperChoice(id: 'ge')},
        ),
      );
    }
    // Les fêtes pendant leur période (fin d'année).
    await _shot(
      tester,
      'wallpaper_picker_fetes_light',
      () => const ChatWallpaperScreen(),
      overrides: await withChoice(
        const WallpaperChoice(id: 'finannee'),
        today: DateTime(2026, 12, 20),
      ),
    );
  });
}
