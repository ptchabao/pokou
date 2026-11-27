// Rendus du clavier et des bulles Pokoumoji avec le pack de développement
// (vignettes provisoires), servi par un faux client HTTP depuis le dépôt :
//
//   POKOU_PREVIEW=/chemin flutter test test/preview/pokoumoji_preview_test.dart
// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/theme/app_theme.dart';
import 'package:pokou/features/pokoumoji/data/pokoumoji_runtime.dart';
import 'package:pokou/features/pokoumoji/domain/pokoumoji.dart';
import 'package:pokou/features/pokoumoji/presentation/pokoumoji_panel.dart';
import 'package:pokou/features/pokoumoji/presentation/pokoumoji_text_controller.dart';
import 'package:pokou/features/pokoumoji/presentation/pokoumoji_widgets.dart';
import 'package:pokou/l10n/app_localizations.dart';

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

/// Les débordements (« RenderFlex overflowed ») relevés pendant un rendu.
final _problems = <String>[];

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget Function() build, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('fr'),
  List<Override> overrides = const [],
  Future<void> Function()? after,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
  tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
  // La palette se pose AVANT de construire l'écran : ses couleurs sont
  // lues à la construction.
  AppColors.applyBrightness(brightness);
  final screen = build();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
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
    // Deux images : la première lance les animations, la seconde les finit.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
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
  // Un débordement ne fait pas échouer l'outil : il est relevé, et listé
  // à la fin.
  final problem = tester.takeException();
  if (problem != null) {
    _problems.add('$name: ${problem.toString().split('\n').first}');
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  if (_out == null) return;

  testWidgets('pokoumoji', (tester) async {
    await tester.runAsync(_loadFonts);
    final cat = PokoumojiRuntime.parseCatalogue(
      catalogueJson: File('assets/pokoumoji/catalogue.json').readAsStringSync(),
      aliasesJson: File('assets/pokoumoji/aliases.json').readAsStringSync(),
      collectionsJson: File(
        'assets/pokoumoji/collections.json',
      ).readAsStringSync(),
      includeUnapproved: true,
    );
    const pack = '../backend/app/data/pokoumoji_packs/dev';
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/pokoumoji/packs/dev/', '');
      final f = File('$pack/$path');
      if (!f.existsSync()) return http.Response('', 404);
      return http.Response.bytes(f.readAsBytesSync(), 200);
    });
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('pokoumoji');
      await PokoumojiRuntime.instance.debugLoad(
        catalogue: cat,
        directory: dir,
        client: client,
      );
      // Préchauffe : les fichiers vérifiés sont sur le disque avant le rendu.
      for (final e in cat.entries.where(
        (e) =>
            e.category == 'kimia' ||
            e.category == 'expressions' ||
            e.id.startsWith('gestes_salut'),
      )) {
        await PokoumojiRuntime.instance.fileFor(e, 128);
        await PokoumojiRuntime.instance.fileFor(e, 256);
        await PokoumojiRuntime.instance.fileFor(e, 64);
      }
    });

    Widget panel() => Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: PokoumojiPanel(
          height: 380,
          onInsert: (_) {},
          onSendSticker: (_) {},
        ),
      ),
    );
    await _shot(tester, 'pokoumoji_panel', panel);

    final controller = PokoumojiTextController();
    final joie = cat.resolve('kimia_joie')!;
    final mdr = cat.resolve('kimia_mdr')!;
    controller.text =
        'On se voit ce soir ${PokoumojiComposer.charFor(cat, joie)} trop hâte ${PokoumojiComposer.charFor(cat, mdr)}';
    final rich = PokoumojiComposer.encode(controller.text, cat)!;
    Widget bubbles() => Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bubble(
                PokoumojiMessageView(
                  message: rich.message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              _bubble(
                PokoumojiMessageView(
                  message: pokoumojiRichText([
                    {'type': 'emoji', 'id': 'kimia_mdr', 'fallback': '😂'},
                  ]),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              PokoumojiMessageView(
                message: pokoumojiSticker(
                  cat.resolve('expressions_on_est_ensemble_kimia')!,
                ),
                style: const TextStyle(fontSize: 16),
              ),
              _bubble(
                PokoumojiMessageView(
                  message: pokoumojiRichText([
                    {'type': 'text', 'text': 'Inconnu : '},
                    {'type': 'emoji', 'id': 'inconnu_xyz', 'fallback': '🙂'},
                  ]),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              TextField(controller: controller, maxLines: 2),
              const SizedBox(height: 12),
              Text('Repli : ${rich.plainText}'),
            ],
          ),
        ),
      ),
    );
    await _shot(tester, 'pokoumoji_bulles', bubbles);
    if (_problems.isNotEmpty) print(_problems.join('\n'));
  });
}

Widget _bubble(Widget child) => Container(
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
  ),
  child: child,
);
