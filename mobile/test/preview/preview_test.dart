// Rendus d'écrans en PNG, hors simulateur, pour relire le design :
//
//   POKOU_PREVIEW=/chemin/de/sortie flutter test test/preview
//
// Sans la variable, le test ne fait rien : ce n'est pas une vérification,
// c'est un outil. Les polices de l'app sont chargées ; les emojis en
// couleur, eux, ne s'affichent pas dans ce moteur de test.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/country/country_config.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/theme/app_theme.dart';
import 'package:pokou/core/widgets/pokou_bottom_nav.dart';
import 'package:pokou/features/contacts/data/conversation_summary.dart';
import 'package:pokou/features/contacts/presentation/discussions_controller.dart';
import 'package:pokou/features/home/presentation/home_screen.dart';
import 'package:pokou/features/honam/data/honam_models.dart';
import 'package:pokou/features/honam/presentation/honam_controller.dart';
import 'package:pokou/features/kory/data/kory_model.dart';
import 'package:pokou/features/kory/presentation/kory_controller.dart';
import 'package:pokou/features/marketplace/presentation/product_editor.dart';
import 'package:pokou/features/messaging/presentation/composer/composer_panel.dart';
import 'package:pokou/features/notifications/data/service_notification.dart';
import 'package:pokou/features/notifications/presentation/notifications_center_screen.dart';
import 'package:pokou/features/status/presentation/post_status_screen.dart';
import 'package:pokou/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _out = Platform.environment['POKOU_PREVIEW'];
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
    // Deux images : la première lance les animations, la seconde les finit.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
  }
  final boundary =
      _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$_out/$name.png').writeAsBytesSync(bytes!);
  print('PREVIEW $name');
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

List<Override> _homeData() => [
  currentCountryConfigProvider.overrideWithValue(
    const CountryConfig(country: 'TG', modules: {'kory', 'honam', 'assime'}),
  ),
  serviceNotificationsProvider.overrideWith(
    (ref) async => const ServiceNotificationsPage(items: [], unread: 2),
  ),
  honamOrdersProvider.overrideWith((ref) async => const <HonamOrder>[]),
  koryPotsProvider.overrideWith(
    (ref) async => [
      KoryPot.fromJson({
        'id': 1,
        'kind': 'CAGNOTTE',
        'title': 'Mariage de Kossi',
        'status': 'OPEN',
        'goal_amount': 150000,
        'confirmed_total': 69000,
        'due_at': DateTime.now()
            .add(const Duration(days: 6, hours: 3))
            .toIso8601String(),
        'join_code': 'ABC123',
        'is_organizer': true,
      }),
    ],
  ),
  discussionsProvider.overrideWith(
    (ref) => Stream.value([
      for (final (i, name) in ['Kanle', 'Famille Mensah', 'Afi Dossou'].indexed)
        ConversationSummary.fromJson({
          'kind': i == 1 ? 'group' : 'contact',
          'id': i + 1,
          'name': name,
          'contact_user_id': i == 1 ? null : i + 10,
          'unread_count': i == 0 ? 2 : 0,
          'last_message': {
            'id': 'm$i',
            'content': [
              'Tu me reçois ?',
              'On se retrouve dimanche',
              'Merci beaucoup',
            ][i],
            'created_at': DateTime.now()
                .subtract(Duration(minutes: 12 * (i + 1)))
                .toIso8601String(),
            'sender_id': i + 10,
            'message_type': 'TEXT',
          },
        }),
    ]),
  ),
];

Widget _home() => Scaffold(
  backgroundColor: AppColors.background,
  extendBody: true,
  body: HomeScreen(onOpenTab: (_) {}),
  bottomNavigationBar: PokouBottomNav(
    currentIndex: 0,
    onTap: (_) {},
    tabs: const [
      PokouTab.home,
      PokouTab.discussions,
      PokouTab.kory,
      PokouTab.honam,
      PokouTab.more,
    ],
  ),
);

Widget _panel() => Scaffold(
  backgroundColor: AppColors.chatBackground,
  body: Column(
    children: [
      const Spacer(),
      ComposerPanel(
        controller: TextEditingController(),
        height: 336,
        onBackspace: () {},
        onStickerSelected: (_) {},
        tab: ComposerPanelTab.emoji,
        onTabChanged: (_) {},
        onGifRequested: () {},
      ),
    ],
  ),
);

void main() {
  testWidgets('rendus de revue', (tester) async {
    if (_out == null) return;
    Directory(_out!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(_loadFonts);

    Future<void> safe(String name, Future<void> Function() run) async {
      try {
        await run();
      } catch (error) {
        print('PREVIEWFAIL $name: ${error.toString().split('\n').first}');
        tester.takeException();
      }
    }

    await safe(
      'status',
      () => _shot(tester, 'status_empty', () => const PostStatusScreen()),
    );
    await safe(
      'status_text',
      () => _shot(
        tester,
        'status_text',
        () => const PostStatusScreen(),
        after: () async {
          await tester.enterText(
            find.byType(TextField),
            'Bonne fête de Tabaski à toute la famille',
          );
          await tester.tap(find.byIcon(Icons.palette_outlined));
          await tester.tap(find.byIcon(Icons.palette_outlined));
          await tester.tap(find.byIcon(Icons.palette_outlined));
        },
      ),
    );
    await safe(
      'status_cream',
      () => _shot(
        tester,
        'status_cream',
        () => const PostStatusScreen(),
        after: () async {
          await tester.enterText(find.byType(TextField), 'Merci à tous');
          for (var i = 0; i < 7; i++) {
            await tester.tap(find.byIcon(Icons.palette_outlined));
          }
        },
      ),
    );
    await safe(
      'editor',
      () => _shot(tester, 'editor', () => const ProductEditor()),
    );
    await safe('panel', () => _shot(tester, 'panel', _panel));
    await safe(
      'panel_dark',
      () => _shot(tester, 'panel_dark', _panel, brightness: Brightness.dark),
    );
    await safe(
      'home',
      () => _shot(tester, 'home', _home, overrides: _homeData()),
    );
    await safe(
      'home_dark',
      () => _shot(
        tester,
        'home_dark',
        _home,
        overrides: _homeData(),
        brightness: Brightness.dark,
      ),
    );
    await safe(
      'home2',
      () => _shot(
        tester,
        'home2',
        _home,
        overrides: _homeData(),
        after: () async {
          await tester.drag(find.byType(ListView).first, const Offset(0, -420));
        },
      ),
    );
    AppColors.applyBrightness(Brightness.light);
  });
}
