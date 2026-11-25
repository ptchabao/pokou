// Rendus des retours de test Kory (loupe, archives, titre du filtre,
// rappel « wallet à wallet », textes de création, choix des contacts,
// activité dans le groupe), en PNG :
//
//   POKOU_PREVIEW=/chemin/de/sortie flutter test test/preview/kory_feedback_preview_test.dart
//
// Sans la variable, le test ne fait rien. Aides reprises de
// kory_preview_test.dart.
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
import 'package:pokou/features/auth/data/user_model.dart';
import 'package:pokou/features/auth/presentation/auth_controller.dart';
import 'package:pokou/features/contacts/data/contact_model.dart';
import 'package:pokou/features/contacts/presentation/contacts_controller.dart';
import 'package:pokou/features/kory/data/kory_model.dart';
import 'package:pokou/features/kory/presentation/kory_activity_row.dart';
import 'package:pokou/features/kory/presentation/kory_controller.dart';
import 'package:pokou/features/kory/presentation/kory_create_screen.dart';
import 'package:pokou/features/kory/presentation/kory_people_picker.dart';
import 'package:pokou/features/kory/presentation/kory_screen.dart';
import 'package:pokou/features/kory/presentation/kory_search_screen.dart';
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

KoryPot _p(
  int id,
  String kind,
  String title, {
  String status = 'OPEN',
  int? goal,
  int confirmed = 0,
  int? dueInHours,
  String? organizer,
  bool archived = false,
}) => KoryPot.fromJson({
  'id': id,
  'kind': kind,
  'title': title,
  'status': status,
  'goal_amount': goal,
  'confirmed_total': confirmed,
  'my_confirmed_total': 5000,
  'organizer_name': organizer,
  'join_code': 'ABC$id',
  'archivable': status == 'CLOSED',
  'archived': archived,
  if (dueInHours != null)
    'due_at': DateTime.now().add(Duration(hours: dueInHours)).toIso8601String(),
});

List<KoryPot> _pots() => [
  _p(
    1,
    'CAGNOTTE',
    'Mariage de Kossi et Afi',
    goal: 150000,
    confirmed: 69000,
    dueInHours: 5 * 24,
    organizer: 'Kossi Agbeko',
  ),
  _p(
    2,
    'COTISATION',
    'Cotisation des anciens du lycée',
    confirmed: 180000,
    dueInHours: 19 * 24,
    organizer: 'Ama Lawson',
  ),
  _p(
    3,
    'TONTINE',
    'Tontine des commerçantes',
    confirmed: 120000,
    organizer: 'Akouvi Dossou',
  ),
  _p(
    5,
    'CAGNOTTE',
    'Soutien à la famille Ayivi',
    status: 'CLOSED',
    goal: 80000,
    confirmed: 80000,
    organizer: 'Koffi Ayivi',
  ),
];

List<KoryPot> _archived() => [
  _p(
    9,
    'CAGNOTTE',
    'Anniversaire de Yawa',
    status: 'CLOSED',
    goal: 50000,
    confirmed: 42000,
    organizer: 'Yawa Dossou',
    archived: true,
  ),
];

List<Override> _data() => [
  authControllerProvider.overrideWith((ref) => _SignedIn()),
  serviceNotificationsProvider.overrideWith(
    (ref) async => const ServiceNotificationsPage(items: [], unread: 2),
  ),
  koryPotsProvider.overrideWith((ref) async => _pots()),
  koryArchivedPotsProvider.overrideWith((ref) async => _archived()),
  korySummaryProvider.overrideWith(
    (ref) async =>
        const KorySummary(monthConfirmedTotal: 15000, toReviewCount: 2),
  ),
  currentCountryConfigProvider.overrideWithValue(
    CountryConfig.guessFromPhone('+22890112233'),
  ),
  contactsProvider.overrideWith(
    (ref) => Stream.value(const [
      PokouContact(
        id: 1,
        phone: '+22890000001',
        displayName: 'Kossi Agbeko',
        contactUserId: 11,
        isRegistered: true,
      ),
      PokouContact(
        id: 2,
        phone: '+22890000002',
        displayName: 'Yawa Dossou',
        isRegistered: false,
      ),
      PokouContact(
        id: 3,
        phone: '+22890000003',
        displayName: 'Essi Lawson',
        contactUserId: 13,
        isRegistered: true,
      ),
    ]),
  ),
];

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

Widget _activity() {
  const base = {
    'kind': 'kory_activity',
    'pot_id': 1,
    'title': 'Mariage de Kossi',
  };
  return Scaffold(
    backgroundColor: AppColors.chatBackground,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: const [
          KoryActivityRow(
            payload: {
              ...base,
              'event': 'created',
              'pot_kind': 'CAGNOTTE',
              'actor_name': 'Afi Mensah',
            },
          ),
          KoryActivityRow(
            payload: {
              ...base,
              'event': 'contribution',
              'contributor_name': 'Ama Lawson',
              'amount': 5000,
              'total': 74000,
            },
          ),
          KoryActivityRow(
            payload: {
              ...base,
              'event': 'contribution',
              'contributor_name': 'Essi',
              'total': 79000,
              'amounts_visible': false,
            },
          ),
          KoryActivityRow(
            payload: {
              ...base,
              'event': 'round',
              'round': 3,
              'rounds': 6,
              'beneficiary_name': 'Yawa',
            },
          ),
          KoryActivityRow(
            payload: {...base, 'event': 'reminder', 'actor_name': 'Afi Mensah'},
          ),
          KoryActivityRow(
            payload: {...base, 'event': 'closed', 'total': 80000},
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('rendus de revue — retours Kory', (tester) async {
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

    for (final dark in [false, true]) {
      final b = dark ? Brightness.dark : Brightness.light;
      final s = dark ? 'dark' : 'light';
      await safe(
        'kfb_tab_$s',
        () => _shot(
          tester,
          'kfb_tab_$s',
          _kory,
          overrides: _data(),
          brightness: b,
          height: 1900,
        ),
      );
      await safe(
        'kfb_tontines_$s',
        () => _shot(
          tester,
          'kfb_tontines_$s',
          _kory,
          overrides: _data(),
          brightness: b,
          after: () async {
            await tester.ensureVisible(find.text('Tontines'));
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.text('Tontines'));
          },
        ),
      );
      await safe(
        'kfb_search_$s',
        () => _shot(
          tester,
          'kfb_search_$s',
          () => const KorySearchScreen(),
          overrides: _data(),
          brightness: b,
          after: () async {
            await tester.enterText(find.byType(TextField), 'a');
          },
        ),
      );
      await safe(
        'kfb_archives_$s',
        () => _shot(
          tester,
          'kfb_archives_$s',
          () => const KoryArchivesScreen(),
          overrides: _data(),
          brightness: b,
        ),
      );
      await safe(
        'kfb_create_$s',
        () => _shot(
          tester,
          'kfb_create_$s',
          () => const KoryCreateScreen(),
          overrides: _data(),
          brightness: b,
          height: 1300,
        ),
      );
      await safe(
        'kfb_picker_$s',
        () => _shot(
          tester,
          'kfb_picker_$s',
          () => const KoryContactsPicker(alreadyUserIds: {13}),
          overrides: _data(),
          brightness: b,
        ),
      );
      await safe(
        'kfb_activity_$s',
        () => _shot(
          tester,
          'kfb_activity_$s',
          _activity,
          overrides: _data(),
          brightness: b,
        ),
      );
    }
    AppColors.applyBrightness(Brightness.light);
  });
}
