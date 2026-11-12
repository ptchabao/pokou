// Rendus de l'onglet Honam et du détail d'une commande en PNG, hors
// simulateur, pour relire le design :
//
//   POKOU_PREVIEW=/chemin/de/sortie flutter test test/preview/honam_preview_test.dart
//
// Sans la variable, le test ne fait rien : ce n'est pas une vérification,
// c'est un outil (voir preview_test.dart, dont les aides sont reprises ici).
// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:async';
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
import 'package:pokou/features/honam/data/honam_models.dart';
import 'package:pokou/features/honam/data/honam_repository.dart';
import 'package:pokou/features/honam/presentation/honam_controller.dart';
import 'package:pokou/features/honam/presentation/honam_order_screen.dart';
import 'package:pokou/features/honam/presentation/honam_screen.dart';
import 'package:pokou/features/notifications/data/service_notification.dart';
import 'package:pokou/features/notifications/presentation/notifications_center_screen.dart';
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
    final image = await boundary.toImage(pixelRatio: 1);
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

// ── Données factices ─────────────────────────────────────────────────────

final _now = DateTime.now().toUtc();

String _ago({int days = 0, int hours = 0, int minutes = 0}) => _now
    .subtract(Duration(days: days, hours: hours, minutes: minutes))
    .toIso8601String();

const _pharmacyCentre = {
  'id': 1,
  'name': 'Pharmacie du Centre',
  'address': '12 avenue de la Libération, Lomé',
  'phone': '+22890112233',
  'is_on_duty': true,
  'opening_hours': '7 h – 22 h',
  'distance_km': 0.8,
};

const _pharmacyBe = {
  'id': 2,
  'name': 'Pharmacie Bè-Kpota Sainte Rita de la Miséricorde',
  'address': 'Carrefour Bè-Kpota, face au marché',
  'phone': '+22890445566',
  'is_on_duty': false,
  'opening_hours': '8 h – 20 h',
  'distance_km': 2.4,
};

const _quote = [
  {
    'name': 'Paracétamol 500 mg, boîte de 16 comprimés',
    'quantity': 2,
    'unit_price': 650,
    'available': true,
  },
  {
    'name': 'Amoxicilline 1 g, boîte de 14 comprimés dispersibles',
    'quantity': 1,
    'unit_price': 3200,
    'available': true,
  },
  {
    'name': 'Sérum physiologique, 30 unidoses',
    'quantity': 1,
    'unit_price': 1800,
    'available': false,
  },
];

Map<String, dynamic> _order(
  int id,
  String status, {
  Map<String, dynamic> pharmacy = _pharmacyCentre,
  bool quoted = true,
  List<Map<String, dynamic>> timeline = const [],
  Map<String, dynamic> extra = const {},
  int createdDaysAgo = 0,
  int createdHoursAgo = 2,
}) => {
  'id': id,
  'status': status,
  'pharmacy': pharmacy,
  'delivery_address': 'Tokoin Hôpital, rue des Hibiscus, portail bleu',
  'created_at': _ago(days: createdDaysAgo, hours: createdHoursAgo),
  if (quoted) ...{
    'quote_items': _quote,
    'medicines_total': 4500,
    'delivery_price': 1000,
    'total': 5500,
  },
  'timeline': timeline,
  ...extra,
};

List<Map<String, dynamic>> _steps(List<(String, String?, int)> steps) => [
  for (final (status, note, minutes) in steps)
    {'status': status, 'note': note, 'at': _ago(minutes: minutes)},
];

final _inDelivery = _order(
  128,
  'IN_DELIVERY',
  extra: {'courier_name': 'Kossi A.', 'delivery_code': '4827'},
  timeline: _steps([
    ('SUBMITTED', null, 118),
    ('QUOTED', null, 96),
    ('ACCEPTED', null, 90),
    ('ACCEPTED', 'Paiement déclaré par le patient', 84),
    ('PAID', null, 71),
    ('READY', "Coursier en route vers l'officine", 40),
    ('IN_DELIVERY', null, 12),
  ]),
);

final _quoted = _order(
  131,
  'QUOTED',
  pharmacy: _pharmacyBe,
  createdHoursAgo: 1,
  extra: {'original_required': true},
  timeline: _steps([('SUBMITTED', null, 55), ('QUOTED', null, 20)]),
);

final _submitted = _order(
  132,
  'SUBMITTED',
  quoted: false,
  createdHoursAgo: 0,
  timeline: _steps([('SUBMITTED', null, 6)]),
);

final _accepted = _order(
  133,
  'ACCEPTED',
  extra: {
    'pay_to_phone': '+228 90 11 22 33',
    'payment_not_received_at': _ago(minutes: 4),
  },
  timeline: _steps([
    ('SUBMITTED', null, 70),
    ('QUOTED', null, 50),
    ('ACCEPTED', null, 30),
  ]),
);

final _delivered = _order(
  117,
  'DELIVERED',
  createdDaysAgo: 3,
  extra: {'courier_name': 'Afi D.'},
  timeline: _steps([
    ('SUBMITTED', null, 3 * 1440 + 130),
    ('QUOTED', null, 3 * 1440 + 112),
    ('ACCEPTED', null, 3 * 1440 + 100),
    ('PAID', null, 3 * 1440 + 86),
    ('READY', null, 3 * 1440 + 60),
    ('IN_DELIVERY', null, 3 * 1440 + 41),
    ('DELIVERED', null, 3 * 1440 + 17),
  ]),
);

final _deliveredOld = _order(
  104,
  'DELIVERED',
  pharmacy: _pharmacyBe,
  createdDaysAgo: 12,
  timeline: _steps([
    ('SUBMITTED', null, 12 * 1440 + 90),
    ('DELIVERED', null, 12 * 1440 + 10),
  ]),
);

final _cancelled = _order(
  121,
  'CANCELLED',
  createdDaysAgo: 5,
  timeline: _steps([
    ('SUBMITTED', null, 5 * 1440 + 50),
    ('QUOTED', null, 5 * 1440 + 30),
    ('CANCELLED', null, 5 * 1440 + 12),
  ]),
);

final _rejected = _order(
  109,
  'REJECTED',
  pharmacy: _pharmacyBe,
  quoted: false,
  createdDaysAgo: 9,
  extra: {'rejection_reason': 'Ordonnance illisible'},
  timeline: _steps([
    ('SUBMITTED', null, 9 * 1440 + 50),
    ('REJECTED', 'Ordonnance illisible', 9 * 1440 + 20),
  ]),
);

List<HonamOrder> _orders() => [
  for (final json in [
    _inDelivery,
    _quoted,
    _submitted,
    _delivered,
    _deliveredOld,
    _cancelled,
    _rejected,
  ])
    HonamOrder.fromJson(json),
];

List<Pharmacy> _pharmacies() => [
  Pharmacy.fromJson(_pharmacyCentre),
  Pharmacy.fromJson(_pharmacyBe),
  Pharmacy.fromJson(const {
    'id': 3,
    'name': 'Pharmacie Adidogomé',
    'address': 'Route de Kpalimé',
    'phone': '+22890778899',
    'is_on_duty': false,
    'distance_km': 4.1,
  }),
];

/// Le dépôt, sans réseau : seul le suivi du coursier passe par lui.
class _FakeRepository implements HonamRepository {
  @override
  Future<CourierTracking> tracking(
    int orderId, {
    bool asPharmacy = false,
  }) async => CourierTracking(
    active: true,
    courierName: 'Kossi A.',
    latitude: 6.13,
    longitude: 1.22,
    at: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    distanceKm: 1.2,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _never = Completer<Never>().future;

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

List<Override> _base() => [
  authControllerProvider.overrideWith((ref) => _SignedIn()),
  currentCountryConfigProvider.overrideWithValue(
    const CountryConfig(country: 'TG', modules: {'kory', 'honam', 'assime'}),
  ),
  serviceNotificationsProvider.overrideWith(
    (ref) async => const ServiceNotificationsPage(items: [], unread: 2),
  ),
  honamRepositoryProvider.overrideWithValue(_FakeRepository()),
  honamEmergencyProvider.overrideWith(
    (ref) async => {'samu': '8200', 'pompiers': '118', 'police': '117'},
  ),
  honamNearbyProvider.overrideWith((ref) async => _pharmacies()),
  honamOrderMessagesProvider.overrideWith(
    (ref, id) async => [
      HonamOrderMessage.fromJson({
        'id': 1,
        'sender_name': 'Pharmacie du Centre',
        'sender_role': 'PHARMACY',
        'body': 'Bonjour, le sérum est en rupture. Le reste est prêt.',
        'created_at': _ago(minutes: 64),
      }),
      HonamOrderMessage.fromJson({
        'id': 2,
        'sender_name': 'Moi',
        'sender_role': 'PATIENT',
        'body': "D'accord, merci. J'attends le coursier.",
        'created_at': _ago(minutes: 61),
      }),
    ],
  ),
];

List<Override> _tabData({List<HonamOrder>? orders}) => [
  ..._base(),
  honamOrdersProvider.overrideWith((ref) async => orders ?? _orders()),
];

List<Override> _detail(Map<String, dynamic> json) => [
  ..._base(),
  honamOrdersProvider.overrideWith((ref) async => _orders()),
  honamOrderProvider.overrideWith((ref, id) async => HonamOrder.fromJson(json)),
];

Widget _tab() => Scaffold(
  backgroundColor: AppColors.background,
  extendBody: true,
  body: const HonamScreen(),
  bottomNavigationBar: PokouBottomNav(
    currentIndex: 3,
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
  testWidgets('rendus de revue Honam', (tester) async {
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

    Future<void> scroll(double dy) async {
      await tester.drag(find.byType(ListView).first, Offset(0, -dy));
    }

    // ── L'onglet.
    for (final brightness in Brightness.values.reversed) {
      final suffix = brightness == Brightness.dark ? '_dark' : '';
      await safe(
        'tab$suffix',
        () => _shot(
          tester,
          'honam_tab$suffix',
          _tab,
          overrides: _tabData(),
          brightness: brightness,
        ),
      );
      await safe(
        'tab_expanded$suffix',
        () => _shot(
          tester,
          'honam_tab_expanded$suffix',
          _tab,
          overrides: _tabData(),
          brightness: brightness,
          after: () async {
            await scroll(330);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.text('Voir plus').first);
          },
        ),
      );
      await safe(
        'tab_completed$suffix',
        () => _shot(
          tester,
          'honam_tab_completed$suffix',
          _tab,
          overrides: _tabData(),
          brightness: brightness,
          after: () async {
            await tester.tap(find.text('Terminées'));
            await tester.pump(const Duration(milliseconds: 300));
            await scroll(330);
          },
        ),
      );
      await safe(
        'tab_cancelled$suffix',
        () => _shot(
          tester,
          'honam_tab_cancelled$suffix',
          _tab,
          overrides: _tabData(),
          brightness: brightness,
          after: () async {
            await tester.tap(find.text('Annulées'));
            await tester.pump(const Duration(milliseconds: 300));
            await scroll(330);
          },
        ),
      );
      await safe(
        'tab_bottom$suffix',
        () => _shot(
          tester,
          'honam_tab_bottom$suffix',
          _tab,
          overrides: _tabData(orders: [HonamOrder.fromJson(_delivered)]),
          brightness: brightness,
          after: () => scroll(620),
        ),
      );
      await safe(
        'tab_loading$suffix',
        () => _shot(
          tester,
          'honam_tab_loading$suffix',
          _tab,
          overrides: [
            ..._base(),
            honamOrdersProvider.overrideWith((ref) => _never),
            honamNearbyProvider.overrideWith((ref) => _never),
          ],
          brightness: brightness,
        ),
      );
      await safe(
        'tab_loading_bottom$suffix',
        () => _shot(
          tester,
          'honam_tab_loading_bottom$suffix',
          _tab,
          overrides: [
            ..._base(),
            honamOrdersProvider.overrideWith((ref) => _never),
            honamNearbyProvider.overrideWith((ref) => _never),
          ],
          brightness: brightness,
          after: () => scroll(620),
        ),
      );
      await safe(
        'tab_empty$suffix',
        () => _shot(
          tester,
          'honam_tab_empty$suffix',
          _tab,
          overrides: [
            ..._tabData(orders: const []),
            honamNearbyProvider.overrideWith((ref) async => <Pharmacy>[]),
          ],
          brightness: brightness,
        ),
      );
      await safe(
        'tab_empty_bottom$suffix',
        () => _shot(
          tester,
          'honam_tab_empty_bottom$suffix',
          _tab,
          overrides: [
            ..._tabData(orders: const []),
            honamNearbyProvider.overrideWith((ref) async => <Pharmacy>[]),
          ],
          brightness: brightness,
          after: () => scroll(620),
        ),
      );
      await safe(
        'tab_error$suffix',
        () => _shot(
          tester,
          'honam_tab_error$suffix',
          _tab,
          overrides: [
            ..._base(),
            honamOrdersProvider.overrideWith(
              (ref) async => throw Exception('hors ligne'),
            ),
            honamNearbyProvider.overrideWith(
              (ref) async => throw Exception('hors ligne'),
            ),
          ],
          brightness: brightness,
          after: () => scroll(330),
        ),
      );

      // ── Le détail d'une commande.
      for (final (name, json) in [
        ('delivered', _delivered),
        ('in_delivery', _inDelivery),
        ('quoted', _quoted),
        ('accepted', _accepted),
        ('submitted', _submitted),
        ('rejected', _rejected),
      ]) {
        await safe(
          'order_$name$suffix',
          () => _shot(
            tester,
            'honam_order_$name$suffix',
            () => HonamOrderScreen(orderId: json['id'] as int),
            overrides: _detail(json),
            brightness: brightness,
          ),
        );
      }
      await safe(
        'order_delivered_bottom$suffix',
        () => _shot(
          tester,
          'honam_order_delivered_bottom$suffix',
          () => const HonamOrderScreen(orderId: 117),
          overrides: _detail(_delivered),
          brightness: brightness,
          after: () => scroll(700),
        ),
      );
      await safe(
        'order_in_delivery_bottom$suffix',
        () => _shot(
          tester,
          'honam_order_in_delivery_bottom$suffix',
          () => const HonamOrderScreen(orderId: 128),
          overrides: _detail(_inDelivery),
          brightness: brightness,
          after: () => scroll(560),
        ),
      );
      await safe(
        'order_timeline$suffix',
        () => _shot(
          tester,
          'honam_order_timeline$suffix',
          () => const HonamOrderScreen(orderId: 128),
          overrides: _detail(_inDelivery),
          brightness: brightness,
          after: () async {
            await tester.tap(find.byIcon(Icons.timeline));
            await tester.pump(const Duration(milliseconds: 400));
          },
        ),
      );
      await safe(
        'order_loading$suffix',
        () => _shot(
          tester,
          'honam_order_loading$suffix',
          () => const HonamOrderScreen(orderId: 128),
          overrides: [
            ..._base(),
            honamOrderProvider.overrideWith((ref, id) => _never),
          ],
          brightness: brightness,
        ),
      );
      await safe(
        'order_error$suffix',
        () => _shot(
          tester,
          'honam_order_error$suffix',
          () => const HonamOrderScreen(orderId: 128),
          overrides: [
            ..._base(),
            honamOrderProvider.overrideWith(
              (ref, id) async => throw Exception('hors ligne'),
            ),
          ],
          brightness: brightness,
        ),
      );
    }

    // ── Une langue longue et une langue de droite à gauche, pour les
    // débordements.
    for (final code in ['ru', 'ar']) {
      await safe(
        'tab_$code',
        () => _shot(
          tester,
          'honam_tab_$code',
          _tab,
          overrides: _tabData(),
          locale: Locale(code),
          after: () => scroll(330),
        ),
      );
      await safe(
        'order_$code',
        () => _shot(
          tester,
          'honam_order_$code',
          () => const HonamOrderScreen(orderId: 128),
          overrides: _detail(_inDelivery),
          locale: Locale(code),
        ),
      );
    }

    AppColors.applyBrightness(Brightness.light);
    for (final problem in _problems) {
      print('PREVIEWPROBLEM $problem');
    }
    print('PREVIEWPROBLEMS ${_problems.length}');
  });
}
