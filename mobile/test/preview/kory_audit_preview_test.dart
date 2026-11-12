// Rendus des écrans Kory de la maquette (cagnotte, cotisation, tontine) en
// PNG, hors simulateur, pour les comparer à la maquette :
//
//   POKOU_PREVIEW=/chemin/de/sortie flutter test test/preview/kory_audit_preview_test.dart
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
import 'package:pokou/features/auth/data/user_model.dart';
import 'package:pokou/features/auth/presentation/auth_controller.dart';
import 'package:pokou/core/country/country_config.dart';
import 'package:pokou/features/groups/data/group_model.dart';
import 'package:pokou/features/kory/data/kory_model.dart';
import 'package:pokou/features/kory/presentation/kory_controller.dart';
import 'package:pokou/features/kory/presentation/kory_cotisation_screens.dart';
import 'package:pokou/features/kory/presentation/kory_create_screen.dart';
import 'package:pokou/features/kory/presentation/kory_draft.dart';
import 'package:pokou/features/kory/presentation/kory_invite_screen.dart';
import 'package:pokou/features/kory/presentation/kory_journal_screen.dart';
import 'package:pokou/features/kory/presentation/kory_pay_screens.dart';
import 'package:pokou/features/kory/presentation/kory_pot_screen.dart';
import 'package:pokou/features/kory/presentation/kory_review_screen.dart';
import 'package:pokou/features/kory/presentation/kory_tontine_screens.dart';
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
          const PokouUser(
            id: 7,
            fullName: 'Afi Mensah',
            phone: '+22890112247',
            plan: 'FREE',
          ),
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

final _now = DateTime.now();
String _at(Duration d) => _now.add(d).toIso8601String();

Map<String, dynamic> _entry(
  int id,
  String name,
  int amount,
  String status, {
  int contributor = 30,
  bool mine = false,
  String? ref,
  bool review = false,
  int hoursAgo = 2,
  int? round,
  String? period,
  String? reason,
}) => {
  'id': id,
  'contributor_id': mine ? 7 : contributor + id,
  'contributor_name': name,
  'amount': amount,
  'status': status,
  'declared_at': _at(Duration(hours: -hoursAgo)),
  'reviewed_at': status == 'DECLARED'
      ? null
      : _at(Duration(hours: -hoursAgo + 1)),
  'is_mine': mine,
  'wallet_reference': ref,
  'can_review': review,
  'round_number': round,
  'period_label': period,
  'review_reason': reason,
  'reviewer_name': 'Edem K.',
};

Map<String, dynamic> _cagnotte({bool collector = false}) => {
  'id': 1,
  'kind': 'CAGNOTTE',
  'title': 'Anniversaire de Papa',
  'status': 'OPEN',
  'group_name': 'Famille Koffi',
  'organizer_name': 'Edem K.',
  'collector_name': 'Edem K.',
  'collector_phone': '+22896000012',
  'collector_id': 40,
  'beneficiary_name': 'Papa Koffi',
  'goal_amount': 100000,
  'confirmed_total': 75000,
  'declared_total': 85000,
  'remaining_to_collect': 25000,
  'my_confirmed_total': 10000,
  'join_code': '4F7QK2MD',
  'is_collector': collector,
  'is_organizer': collector,
  'participants_count': 8,
  'created_at': _at(const Duration(days: -4)),
  'due_at': _at(const Duration(days: 6)),
  'server_now': _now.toIso8601String(),
  'my_pledge': collector
      ? null
      : {
          'base': 15000,
          'daily': 500,
          'days': 6,
          'total': 18000,
          'pledged_at': _at(const Duration(days: -2)),
          'firm_at': _at(const Duration(days: -2, hours: 8)),
          'is_firm': true,
          'confirmed': 10000,
          'remaining': 8000,
        },
  'entries': [
    _entry(
      1,
      'Afi Mensah',
      10000,
      'CONFIRMED',
      mine: true,
      ref: 'TG2610311611C3',
      hoursAgo: 30,
    ),
    _entry(
      2,
      'Kafui K.',
      10000,
      'DECLARED',
      ref: 'TG2610311402A7',
      review: collector,
    ),
    _entry(3, 'Séna K.', 5000, 'REJECTED', reason: 'Rien reçu', hoursAgo: 5),
    _entry(4, 'Maman', 20000, 'CONFIRMED', hoursAgo: 50),
  ],
};

Map<String, dynamic> _cotisation({required bool admin}) => {
  'id': 2,
  'kind': 'COTISATION',
  'title': admin ? 'Cotisation des Amis de Bè' : 'Cotisation de la famille',
  'status': 'OPEN',
  'group_name': admin ? 'Les Amis de Bè' : 'Famille Koffi',
  'organizer_name': admin ? 'Afi Mensah' : 'Edem K.',
  'collector_name': admin ? 'Afi Mensah' : 'Edem K.',
  'collector_phone': admin ? '+22890112247' : '+22896000012',
  'collector_id': admin ? 7 : 40,
  'amount_per_member': admin ? 2000 : 5000,
  'period': 'MONTHLY',
  'confirmed_total': 0,
  'my_confirmed_total': 0,
  'join_code': 'COTI2026',
  'is_collector': admin,
  'is_organizer': admin,
  'is_admin': admin,
  'reminded_at': admin ? _at(const Duration(hours: -3)) : null,
  'entries': [
    _entry(
      5,
      'Kafui K.',
      2000,
      'DECLARED',
      ref: 'TG2702051408A1',
      review: admin,
      period: '2027-02',
    ),
    _entry(
      6,
      'Mensah Yawa',
      2000,
      'DECLARED',
      review: admin,
      period: '2027-02',
    ),
  ],
  'cotisation': {
    'members_count': admin ? 18 : 9,
    'is_member': true,
    'members': [
      {'user_id': 7, 'name': 'Afi Mensah'},
      {'user_id': 41, 'name': 'Ama S.'},
      {'user_id': 42, 'name': 'Edem K.'},
    ],
    'current': {
      'label': '2027-02',
      'due_at': _at(const Duration(days: -1)),
      'amount': 2000,
      'expected_total': 36000,
      'confirmed_total': 26000,
      'up_to_date_count': 13,
      'to_confirm_count': 2,
      'late_count': 3,
      'late': [
        {'user_id': 50, 'name': 'Komi T.'},
        {'user_id': 51, 'name': 'Abla G.'},
        {'user_id': 52, 'name': 'Séna K.'},
      ],
    },
    'history': [
      {
        'label': '2027-01',
        'due_at': _at(const Duration(days: -32)),
        'paid_count': 18,
        'members_count': 18,
        'contested_count': 0,
      },
      {
        'label': '2026-12',
        'due_at': _at(const Duration(days: -63)),
        'paid_count': 17,
        'members_count': 18,
        'contested_count': 1,
      },
    ],
    'my_periods': [
      {
        'label': '2026-10',
        'due_at': _at(const Duration(days: -28)),
        'amount': 5000,
        'status': 'CONFIRMED',
        'wallet_reference': 'TG2610101902K3',
        'declared_at': _at(const Duration(days: -28)),
      },
      {
        'label': '2026-09',
        'due_at': _at(const Duration(days: -58)),
        'amount': 5000,
        'status': 'CONFIRMED',
      },
      {
        'label': '2026-08',
        'due_at': _at(const Duration(days: -89)),
        'amount': 5000,
        'status': 'CONFIRMED',
        'was_contested': true,
      },
    ],
    'my_next': {
      'label': '2026-11',
      'due_at': _at(const Duration(days: 2)),
      'amount': 5000,
      'status': 'DUE',
    },
    'schedule': [
      {
        'label': '2027-02',
        'due_at': _at(const Duration(days: -1)),
        'amount': 2000,
      },
      {
        'label': '2027-03',
        'due_at': _at(const Duration(days: 27)),
        'amount': 2000,
      },
    ],
    'next_period': {
      'label': '2027-03',
      'due_at': _at(const Duration(days: 27)),
    },
  },
};

const _names = [
  'Ama S.',
  'Yao A.',
  'Afi Mensah',
  'Kafui K.',
  'Séna K.',
  'Komi T.',
  'Abla G.',
  'Mensah D.',
];

Map<String, dynamic> _tontine({required String status, bool admin = false}) {
  final open = status == 'OPEN';
  return {
    'id': open ? 6 : (admin ? 4 : 5),
    'kind': 'TONTINE',
    'title': open ? 'Tontine des collègues' : 'Tontine des voisins',
    'status': status,
    'group_name': open ? 'Collègues du bureau' : 'Voisins de Bè',
    'organizer_name': admin ? 'Afi Mensah' : 'Akossiwa K.',
    'deputy_name': 'Ama S.',
    'collector_name': 'Yao A.',
    'collector_phone': '+22891000044',
    'collector_id': 61,
    'amount_per_member': 5000,
    'period': 'MONTHLY',
    'due_at': _at(const Duration(days: 20)),
    'confirmed_total': 0,
    'my_confirmed_total': 0,
    'join_code': '',
    'is_admin': admin,
    'is_organizer': admin,
    'draw_mode': 'DRAW',
    'draw_seal': open ? '7F3A-92C1' : null,
    'drawn_at': open ? _at(const Duration(days: -90)) : null,
    'current_round': open ? 4 : null,
    'members': [
      for (var i = 0; i < 8; i++)
        {
          'user_id': i == 2 ? 7 : 60 + i,
          'name': _names[i],
          'accepted': open || i < 5 || (i == 2 && !admin ? false : i < 5),
          'declined': false,
          'is_admin': admin ? i == 2 : i == 0,
          'is_deputy': i == 1,
          'fee_paid':
              open || (i < 5 && !(i == 2 && !admin) && !(i == 2 && admin)),
        },
    ],
    'plus_fee': {
      'amount_ht': 1000,
      'amount_ttc': 1180,
      'currency': 'XOF',
      'paid_count': open ? 8 : 4,
      'member_count': 8,
      'i_paid': open,
    },
    'rounds': open
        ? [
            for (var i = 0; i < 8; i++)
              {
                'number': i + 1,
                'beneficiary_id': i == 5 ? 7 : 60 + i,
                'beneficiary_name': _names[i],
                'due_at': _at(Duration(days: 30 * (i - 3))),
                'status': i < 3 ? 'DONE' : (i == 3 ? 'CURRENT' : 'UPCOMING'),
                'confirmed_total': i < 3 ? 35000 : (i == 3 ? 15000 : 0),
                'expected_total': 35000,
                'expected_count': 7,
                'confirmed_count': i < 3 ? (i == 2 ? 6 : 7) : (i == 3 ? 3 : 0),
                'declared_count': i == 3 ? 2 : 0,
                'rejected_count': i == 2 ? 1 : 0,
                'late_count': i == 3 ? 2 : 0,
                'contributors': i == 3
                    ? [
                        {
                          'user_id': 7,
                          'name': 'Afi Mensah',
                          'status': 'CONFIRMED',
                        },
                        {
                          'user_id': 67,
                          'name': 'Mensah D.',
                          'status': 'DECLARED',
                        },
                        {'user_id': 65, 'name': 'Komi T.', 'status': 'LATE'},
                      ]
                    : [],
              },
          ]
        : [],
    'swaps': open
        ? [
            {
              'id': 1,
              'requester_id': 66,
              'requester_name': 'Abla G.',
              'target_id': 7,
              'target_name': 'Afi Mensah',
              'requester_round': 7,
              'target_round': 6,
              'message': 'Je préfère recevoir en janvier.',
              'status': 'PENDING',
              'created_at': _at(const Duration(hours: -4)),
            },
          ]
        : [],
    'entries': open
        ? [_entry(9, 'Afi Mensah', 5000, 'CONFIRMED', mine: true, round: 4)]
        : [],
  };
}

Group _group() => Group(
  id: 3,
  name: 'Les Amis de Bè',
  createdBy: 7,
  memberCount: 6,
  members: [
    for (final (i, n) in [
      'Afi Mensah',
      'Ama S.',
      'Edem K.',
      'Mensah Yawa',
      'Komi T.',
      'Abla G.',
    ].indexed)
      GroupMember(
        userId: i == 0 ? 7 : 40 + i,
        role: i == 0 ? 'OWNER' : 'MEMBER',
        displayName: n,
      ),
  ],
);

KoryDraft _draft(String kind) => KoryDraft(kind: kind)
  ..title = kind == 'TONTINE'
      ? 'Tontine des voisins'
      : 'Cotisation des Amis de Bè'
  ..amount = kind == 'TONTINE' ? 5000 : 2000
  ..dueAt = _now.add(const Duration(days: 23))
  ..group = _group()
  ..memberIds = [7, 41, 42, 43, 44, 45]
  ..deputyId = 41;

KoryPot _p(Map<String, dynamic> json) => KoryPot.fromJson(json);

List<Override> _over() => [
  authControllerProvider.overrideWith((ref) => _SignedIn()),
  serviceNotificationsProvider.overrideWith(
    (ref) async => const ServiceNotificationsPage(items: [], unread: 0),
  ),
  currentCountryConfigProvider.overrideWithValue(
    const CountryConfig(
      country: 'TG',
      modules: {'discussions', 'kory', 'kory_plus', 'honam'},
    ),
  ),
  koryPotProvider(1).overrideWith((ref) async => _p(_cagnotte())),
  koryPotProvider(
    11,
  ).overrideWith((ref) async => _p({..._cagnotte(collector: true), 'id': 11})),
  koryPotProvider(2).overrideWith((ref) async => _p(_cotisation(admin: true))),
  koryPotProvider(
    3,
  ).overrideWith((ref) async => _p({..._cotisation(admin: false), 'id': 3})),
  koryPotProvider(
    4,
  ).overrideWith((ref) async => _p(_tontine(status: 'PENDING', admin: true))),
  koryPotProvider(
    5,
  ).overrideWith((ref) async => _p(_tontine(status: 'PENDING'))),
  koryPotProvider(6).overrideWith((ref) async => _p(_tontine(status: 'OPEN'))),
  koryPotProvider(9).overrideWith((ref) => Completer<KoryPot>().future),
  koryPreviewProvider('4F7QK2MD').overrideWith(
    (ref) async => KoryPreview.fromJson({
      'id': 1,
      'kind': 'CAGNOTTE',
      'title': 'Mariage d’Akossiwa',
      'join_code': '4F7QK2MD',
      'beneficiary_name': 'Akossiwa K.',
      'goal_amount': 300000,
      'due_at': '2026-12-15T12:00:00',
      'group_name': 'Les Amis de Bè',
      'organizer_name': 'Ama S.',
      'collector_name': 'Ama S.',
      'collector_phone_masked': '+228 96 •• •• 21',
      'participants_count': 12,
    }),
  ),
];

void main() {
  testWidgets('rendus de revue — écrans Kory de la maquette', (tester) async {
    if (_out == null) return;
    Directory(_out!).createSync(recursive: true);
    await tester.runAsync(_loadFonts);

    Future<void> shot(
      String name,
      Widget Function() build, {
      double height = 844,
      Brightness brightness = Brightness.light,
      Locale locale = const Locale('fr'),
    }) async {
      try {
        await _shot(
          tester,
          name,
          build,
          overrides: _over(),
          height: height,
          brightness: brightness,
          locale: locale,
        );
      } catch (error) {
        print('PREVIEWFAIL $name: ${error.toString().split('\n').first}');
        tester.takeException();
      }
    }

    final cagnotte = _p(_cagnotte());
    final cotAdmin = _p(_cotisation(admin: true));
    final open = _p(_tontine(status: 'OPEN'));
    await shot(
      'k01_cagnotte',
      () => const KoryPotScreen(potId: 1),
      height: 1300,
    );
    await shot(
      'k01_cagnotte_dark',
      () => const KoryPotScreen(potId: 1),
      height: 1300,
      brightness: Brightness.dark,
    );
    await shot('k01_cagnotte_loading', () => const KoryPotScreen(potId: 9));
    await shot(
      'k01_cagnotte_collector',
      () => const KoryPotScreen(potId: 11),
      height: 1300,
    );
    await shot(
      'k02_contribuer',
      () => KoryContributeScreen(pot: cagnotte, amount: 8000),
      height: 1000,
    );
    await shot(
      'k03_declarer',
      () => KoryDeclareScreen(pot: cagnotte, amount: 10000),
      height: 1000,
    );
    await shot('k04_confirmer', () => const KoryReviewScreen(potId: 11));
    await shot(
      'k09_journal',
      () => const KoryJournalScreen(potId: 1),
      height: 1100,
    );
    await shot(
      'k10_rejoindre',
      () => const KoryInviteScreen(code: '4F7QK2MD'),
      height: 1000,
    );
    await shot('k06_creer', () => const KoryCreateScreen(), height: 1200);
    await shot(
      'k18_membres',
      () => KoryCotisationMembersScreen(draft: _draft('COTISATION')),
      height: 1100,
    );
    await shot(
      'k19_recap',
      () => KoryCotisationRecapScreen(draft: _draft('COTISATION')),
      height: 1000,
    );
    await shot('k20_suivi', () => const KoryPotScreen(potId: 2), height: 1500);
    await shot(
      'k21_ma_cotisation',
      () => const KoryPotScreen(potId: 3),
      height: 1300,
    );
    await shot(
      'k22_modifier',
      () => KoryCotisationEditScreen(pot: cotAdmin),
      height: 1000,
    );
    await shot(
      'k24_membres_ordre',
      () => KoryTontineMembersScreen(draft: _draft('TONTINE')),
      height: 1200,
    );
    await shot(
      'k08_ouvrir',
      () => KoryTontineOpenScreen(
        draft: _draft('TONTINE')..memberIds = [7, 41, 42, 43, 44, 45],
      ),
      height: 900,
    );
    await shot(
      'k08_attente_admin',
      () => const KoryPotScreen(potId: 4),
      height: 1200,
    );
    await shot(
      'k25_invitation',
      () => const KoryPotScreen(potId: 5),
      height: 1300,
    );
    await shot(
      'k07_tontine',
      () => const KoryPotScreen(potId: 6),
      height: 1600,
    );
    await shot(
      'k07_tontine_dark',
      () => const KoryPotScreen(potId: 6),
      height: 1600,
      brightness: Brightness.dark,
    );
    await shot(
      'k26_tirage',
      () => const KoryTontineDrawScreen(potId: 6),
      height: 1100,
    );
    await shot('k27_levee', () => const KoryReviewScreen(potId: 6));
    await shot(
      'k28_echange',
      () => KoryTontineSwapScreen(pot: open),
      height: 1100,
    );
    await shot(
      'k29_rapport',
      () => const KoryTontineReportScreen(potId: 6),
      height: 1200,
    );
    await shot(
      'k30_dissoudre',
      () => KoryTontineDissolveScreen(pot: open),
      height: 1000,
    );
    await shot(
      'k20_suivi_ar',
      () => const KoryPotScreen(potId: 2),
      height: 1500,
      locale: const Locale('ar'),
    );
    await shot(
      'k07_tontine_ru',
      () => const KoryPotScreen(potId: 6),
      height: 1600,
      locale: const Locale('ru'),
    );
    AppColors.applyBrightness(Brightness.light);
  });
}
