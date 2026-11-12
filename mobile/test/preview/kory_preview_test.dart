// Rendus de l'onglet Kory en PNG, hors simulateur, pour relire le design :
//
//   POKOU_PREVIEW=/chemin/de/sortie flutter test test/preview/kory_preview_test.dart
//
// Sans la variable, le test ne fait rien : ce n'est pas une vérification,
// c'est un outil (voir preview_test.dart, dont les aides sont reprises ici).
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/theme/app_colors.dart';
import 'package:pokou/core/theme/app_theme.dart';
import 'package:pokou/core/widgets/pokou_bottom_nav.dart';
import 'package:pokou/features/auth/data/user_model.dart';
import 'package:pokou/features/auth/presentation/auth_controller.dart';
import 'package:pokou/features/kory/data/kory_model.dart';
import 'package:pokou/features/kory/presentation/kory_controller.dart';
import 'package:pokou/features/kory/presentation/kory_screen.dart';
import 'package:pokou/features/notifications/data/service_notification.dart';
import 'package:pokou/features/notifications/presentation/notifications_center_screen.dart';
import 'package:pokou/l10n/app_localizations.dart';

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

/// Une session ouverte, sans dépôt ni réseau : l'en-tête montre la photo.
class _SignedIn extends StateNotifier<AuthState> implements AuthController {
  _SignedIn()
    : super(
        AuthState.authenticated(
          const PokouUser(id: 7, fullName: 'Afi Mensah', plan: 'FREE'),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget Function() build, {
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
  Future<void> Function()? after,
  // Hauteur en points : au-delà d'un écran, pour voir la page entière.
  double height = 844,
  Locale locale = const Locale('fr'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(1170, height * 3);
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
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
  final error = tester.takeException();
  if (error != null) {
    print('PREVIEWERR $name: ${error.toString().split('\n').first}');
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

Map<String, dynamic> _pot(
  int id,
  String kind,
  String title, {
  String status = 'OPEN',
  int? goal,
  int confirmed = 0,
  int? dueInHours,
  String? organizer,
  int? pending,
  int? perMember,
  String? period,
  List<Map<String, dynamic>> rounds = const [],
  int? currentRound,
}) => {
  'id': id,
  'kind': kind,
  'title': title,
  'status': status,
  'goal_amount': goal,
  'confirmed_total': confirmed,
  'my_confirmed_total': 5000,
  'organizer_name': organizer,
  'pending_count': pending,
  'amount_per_member': perMember,
  'period': period,
  'join_code': 'ABC$id',
  'rounds': rounds,
  'current_round': currentRound,
  if (dueInHours != null)
    'due_at': DateTime.now().add(Duration(hours: dueInHours)).toIso8601String(),
};

List<KoryPot> _pots() => [
  KoryPot.fromJson(
    _pot(
      1,
      'CAGNOTTE',
      'Mariage de Kossi et Afi',
      goal: 150000,
      confirmed: 69000,
      dueInHours: 5 * 24 + 3,
      organizer: 'Kossi Agbeko',
    ),
  ),
  KoryPot.fromJson(
    _pot(
      2,
      'COTISATION',
      'Cotisation des anciens du lycée de Tokoin',
      goal: 240000,
      confirmed: 180000,
      dueInHours: 19 * 24 + 5,
      organizer: 'Ama Lawson',
      pending: 2,
      perMember: 5000,
      period: 'MONTHLY',
    ),
  ),
  KoryPot.fromJson(
    _pot(
      3,
      'TONTINE',
      'Tontine des commerçantes',
      confirmed: 120000,
      organizer: 'Akouvi Dossou',
      currentRound: 2,
      rounds: [
        for (var i = 1; i <= 6; i++)
          {
            'number': i,
            'beneficiary_id': 20 + i,
            'beneficiary_name': [
              'Akouvi',
              'Essi',
              'Yawa',
              'Abla',
              'Adjo',
            ][i % 5],
            'status': i < 2
                ? 'DONE'
                : i == 2
                ? 'CURRENT'
                : 'UPCOMING',
            'confirmed_total': i < 2 ? 60000 : (i == 2 ? 40000 : 0),
            'expected_total': 60000,
          },
      ],
    ),
  ),
  KoryPot.fromJson(
    _pot(
      4,
      'CAGNOTTE',
      'Baptême de la petite Enyonam',
      confirmed: 32500,
      organizer: 'Dzifa Amegan',
    ),
  ),
  KoryPot.fromJson(
    _pot(
      5,
      'CAGNOTTE',
      'Soutien à la famille Ayivi',
      status: 'CLOSED',
      goal: 80000,
      confirmed: 80000,
      organizer: 'Koffi Ayivi',
    ),
  ),
];

List<Override> _common() => [
  authControllerProvider.overrideWith((ref) => _SignedIn()),
  serviceNotificationsProvider.overrideWith(
    (ref) async => const ServiceNotificationsPage(items: [], unread: 2),
  ),
];

List<Override> _data() => [
  ..._common(),
  koryPotsProvider.overrideWith((ref) async => _pots()),
  korySummaryProvider.overrideWith(
    (ref) async =>
        const KorySummary(monthConfirmedTotal: 15000, toReviewCount: 2),
  ),
];

List<Override> _loading() => [
  ..._common(),
  koryPotsProvider.overrideWith((ref) => Completer<List<KoryPot>>().future),
  korySummaryProvider.overrideWith((ref) => Completer<KorySummary>().future),
];

List<Override> _empty() => [
  ..._common(),
  koryPotsProvider.overrideWith((ref) async => const <KoryPot>[]),
  korySummaryProvider.overrideWith(
    (ref) async => const KorySummary(monthConfirmedTotal: 0, toReviewCount: 0),
  ),
];

List<Override> _failing() => [
  ..._common(),
  koryPotsProvider.overrideWith(
    (ref) async => throw const SocketException('hors ligne'),
  ),
  korySummaryProvider.overrideWith(
    (ref) async => throw const SocketException('hors ligne'),
  ),
];

/// L'onglet tel que la coque le montre : fond de l'app, barre du bas.
Widget _kory() => Scaffold(
  backgroundColor: AppColors.background,
  extendBody: true,
  body: const SafeArea(bottom: false, child: KoryScreen()),
  bottomNavigationBar: PokouBottomNav(
    currentIndex: 2,
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

void main() {
  testWidgets('rendus de revue — Kory', (tester) async {
    if (_out == null) return;
    Directory(_out!).createSync(recursive: true);
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
      'kory_light',
      () => _shot(tester, 'kory_light', _kory, overrides: _data()),
    );
    await safe(
      'kory_dark',
      () => _shot(
        tester,
        'kory_dark',
        _kory,
        overrides: _data(),
        brightness: Brightness.dark,
      ),
    );
    // La page entière, d'un seul tenant.
    await safe(
      'kory_light_full',
      () => _shot(
        tester,
        'kory_light_full',
        _kory,
        overrides: _data(),
        height: 2000,
      ),
    );
    await safe(
      'kory_dark_full',
      () => _shot(
        tester,
        'kory_dark_full',
        _kory,
        overrides: _data(),
        brightness: Brightness.dark,
        height: 2000,
      ),
    );
    await safe(
      'kory_loading',
      () => _shot(tester, 'kory_loading', _kory, overrides: _loading()),
    );
    await safe(
      'kory_loading_dark',
      () => _shot(
        tester,
        'kory_loading_dark',
        _kory,
        overrides: _loading(),
        brightness: Brightness.dark,
      ),
    );
    await safe(
      'kory_empty',
      () => _shot(tester, 'kory_empty', _kory, overrides: _empty()),
    );
    await safe(
      'kory_empty_dark',
      () => _shot(
        tester,
        'kory_empty_dark',
        _kory,
        overrides: _empty(),
        brightness: Brightness.dark,
      ),
    );
    await safe(
      'kory_error',
      () => _shot(tester, 'kory_error', _kory, overrides: _failing()),
    );
    await safe(
      'kory_error_dark',
      () => _shot(
        tester,
        'kory_error_dark',
        _kory,
        overrides: _failing(),
        brightness: Brightness.dark,
      ),
    );
    // Un filtre actif, puis une recherche sans résultat.
    await safe(
      'kory_filter',
      () => _shot(
        tester,
        'kory_filter',
        _kory,
        overrides: _data(),
        after: () async {
          await tester.ensureVisible(find.text('Tontines'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Tontines'));
        },
      ),
    );
    await safe(
      'kory_search_none',
      () => _shot(
        tester,
        'kory_search_none',
        _kory,
        overrides: _data(),
        after: () async {
          await tester.enterText(find.byType(TextField), 'anniversaire');
        },
      ),
    );
    // Les cas qui débordent : droite-à-gauche, texte agrandi.
    await safe(
      'kory_ar',
      () => _shot(
        tester,
        'kory_ar',
        _kory,
        overrides: _data(),
        locale: const Locale('ar'),
        height: 2000,
      ),
    );
    await safe(
      'kory_ru_large',
      () => _shot(
        tester,
        'kory_ru_large',
        _kory,
        overrides: _data(),
        locale: const Locale('ru'),
        textScale: 1.3,
        height: 2400,
      ),
    );
    AppColors.applyBrightness(Brightness.light);
  });
}
