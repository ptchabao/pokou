// Retours de l'équipe de test sur Kory : la loupe et les archives, le titre
// qui suit le filtre, le rappel « wallet à wallet » sous l'en-tête, les
// textes de création, le choix dans les contacts et l'activité du groupe.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/country/country_config.dart';
import 'package:pokou/features/auth/data/user_model.dart';
import 'package:pokou/features/auth/presentation/auth_controller.dart';
import 'package:pokou/features/contacts/data/contact_model.dart';
import 'package:pokou/features/contacts/presentation/contacts_controller.dart';
import 'package:pokou/features/kory/data/kory_model.dart';
import 'package:pokou/features/kory/data/kory_repository.dart';
import 'package:pokou/features/kory/presentation/kory_activity_row.dart';
import 'package:pokou/features/kory/presentation/kory_controller.dart';
import 'package:pokou/features/kory/presentation/kory_create_screen.dart';
import 'package:pokou/features/kory/presentation/kory_people_picker.dart';
import 'package:pokou/features/kory/presentation/kory_screen.dart';
import 'package:pokou/features/kory/presentation/kory_search_screen.dart';
import 'package:pokou/features/notifications/data/service_notification.dart';
import 'package:pokou/features/notifications/presentation/notifications_center_screen.dart';
import 'package:pokou/l10n/app_localizations.dart';

class _SignedIn extends StateNotifier<AuthState> implements AuthController {
  _SignedIn()
    : super(
        AuthState.authenticated(
          const PokouUser(
            id: 7,
            fullName: 'Afi Mensah',
            phone: '+22890112233',
            plan: 'FREE',
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Le dépôt, sans réseau : il note les archivages demandés.
class _FakeRepo implements KoryRepository {
  final archived = <(int, bool)>[];

  @override
  Future<KoryPot> setArchived(int potId, {required bool archived}) async {
    this.archived.add((potId, archived));
    return _pot(potId, 'CAGNOTTE', 'x', status: 'CLOSED');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

KoryPot _pot(
  int id,
  String kind,
  String title, {
  String status = 'OPEN',
  bool archived = false,
}) => KoryPot.fromJson({
  'id': id,
  'kind': kind,
  'title': title,
  'status': status,
  'confirmed_total': 1000,
  'my_confirmed_total': 0,
  'join_code': 'C$id',
  'archivable': status == 'CLOSED',
  'archived': archived,
});

final _pots = [
  _pot(1, 'CAGNOTTE', 'Mariage de Kossi'),
  _pot(2, 'COTISATION', 'Cotisation du lycée'),
  _pot(3, 'TONTINE', 'Tontine des commerçantes'),
  _pot(4, 'CAGNOTTE', 'Baptême d’Enyonam', status: 'CLOSED'),
];

List<Override> _overrides(_FakeRepo repo, {List<KoryPot>? archived}) => [
  authControllerProvider.overrideWith((ref) => _SignedIn()),
  serviceNotificationsProvider.overrideWith(
    (ref) async => const ServiceNotificationsPage(items: [], unread: 0),
  ),
  koryRepositoryProvider.overrideWithValue(repo),
  koryPotsProvider.overrideWith((ref) async => _pots),
  koryArchivedPotsProvider.overrideWith(
    (ref) async =>
        archived ??
        [
          _pot(
            9,
            'CAGNOTTE',
            'Anniversaire de Yawa',
            status: 'CLOSED',
            archived: true,
          ),
        ],
  ),
  korySummaryProvider.overrideWith(
    (ref) async =>
        const KorySummary(monthConfirmedTotal: 5000, toReviewCount: 0),
  ),
  currentCountryConfigProvider.overrideWithValue(
    CountryConfig.guessFromPhone('+22890112233'),
  ),
];

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: home,
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets(
    'la loupe remplace la barre de recherche, le rappel est en tête',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const KoryScreen(), _overrides(_FakeRepo())),
      );
      await _settle(tester);

      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Rechercher'), findsOneWidget);
      // « Wallet à wallet » juste sous l'en-tête : avant le premier montant.
      final trust = tester.getTopLeft(find.byType(KoryTrustCard)).dy;
      final firstFilter = tester.getTopLeft(find.text('Toutes')).dy;
      expect(trust, lessThan(firstFilter));
      expect(trust, lessThan(tester.getTopLeft(find.text('Mes collectes')).dy));
    },
  );

  testWidgets('le titre de la liste suit le filtre choisi', (tester) async {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const KoryScreen(), _overrides(_FakeRepo())));
    await _settle(tester);
    expect(find.text('Mes collectes'), findsOneWidget);

    for (final (filter, title) in const [
      ('Tontines', 'Mes tontines'),
      ('Cagnottes', 'Mes cagnottes'),
      ('Cotisations', 'Mes cotisations'),
      ('Toutes', 'Mes collectes'),
    ]) {
      await tester.ensureVisible(find.text(filter));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(filter));
      await _settle(tester);
      expect(find.text(title), findsOneWidget, reason: filter);
    }
  });

  testWidgets('archiver une collecte close depuis sa carte', (tester) async {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(const KoryScreen(), _overrides(repo)));
    await _settle(tester);
    // Une seule carte est close : un seul bouton « Archiver ».
    expect(find.byTooltip('Archiver'), findsOneWidget);
    await tester.tap(find.byTooltip('Archiver'));
    await _settle(tester);
    expect(repo.archived, [(4, true)]);
    expect(find.text('Collecte rangée dans tes archives'), findsOneWidget);
  });

  testWidgets('la recherche plein écran cherche aussi dans les archives', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const KorySearchScreen(), _overrides(_FakeRepo())),
    );
    await _settle(tester);
    expect(find.text('Archives'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'anniv');
    await _settle(tester);
    expect(find.text('Anniversaire de Yawa'), findsOneWidget);
    expect(find.text('Dans les archives'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bapteme');
    await _settle(tester);
    expect(find.text('Baptême d’Enyonam'), findsOneWidget);
    expect(find.text('Dans les archives'), findsNothing);
  });

  testWidgets('les archives : désarchiver, et l’état vide', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(const KoryArchivesScreen(), _overrides(repo)));
    await _settle(tester);
    expect(find.text('Anniversaire de Yawa'), findsOneWidget);
    await tester.tap(find.byTooltip('Désarchiver'));
    await _settle(tester);
    expect(repo.archived, [(9, false)]);

    // Une nouvelle portée : l'ancienne garde ses valeurs en cache.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(
        const KoryArchivesScreen(),
        _overrides(_FakeRepo(), archived: const []),
      ),
    );
    await _settle(tester);
    expect(find.text('Aucune archive'), findsOneWidget);
  });

  testWidgets('la création décrit chaque type, mot pour mot', (tester) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(const KoryCreateScreen(), _overrides(_FakeRepo())),
    );
    await _settle(tester);
    expect(
      find.text(
        "Crée une cagnotte rapide pour organiser des évènements entre proches. "
        "C'est sans frais. Pokou ne touche pas à l'argent. Chacun verse "
        "librement et directement sa participation sur le wallet du collecteur.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cotisation'));
    await _settle(tester);
    expect(
      find.text(
        "Crée une collecte de fonds, avec un montant fixe, une échéance et une "
        "périodicité. C'est sans frais. Pokou ne touche pas à l'argent. À "
        "chaque échéance chacun verse directement sa participation sur le "
        "wallet du collecteur.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Tontine Plus'));
    await _settle(tester);
    expect(
      find.text(
        "Crée une vraie tontine avec des montants fixes, des tours de collecte, "
        "et une périodicité. Des frais Kory Plus s'appliquent pour chaque "
        "participant.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('choisir des contacts Pokou et des numéros du carnet', (
    tester,
  ) async {
    const contacts = [
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
    ];
    List<KoryPickable>? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const KoryContactsPicker(alreadyUserIds: {13}),
                  ),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
        [
          ..._overrides(_FakeRepo()),
          contactsProvider.overrideWith((ref) => Stream.value(contacts)),
        ],
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await _settle(tester);

    expect(find.text('Kossi Agbeko'), findsOneWidget);
    expect(find.text('Yawa Dossou'), findsOneWidget);
    expect(find.text('Déjà dans la collecte'), findsOneWidget);
    expect(find.text('Pas encore sur Pokou · invitation par SMS'), findsOne);

    // La recherche, par nom puis par numéro.
    await tester.enterText(find.byType(TextField), 'kossi');
    await _settle(tester);
    expect(find.text('Yawa Dossou'), findsNothing);
    await tester.tap(find.text('Kossi Agbeko'));
    await tester.enterText(find.byType(TextField), '0002');
    await _settle(tester);
    expect(find.text('Kossi Agbeko'), findsNothing);
    await tester.tap(find.text('Yawa Dossou'));
    await _settle(tester);
    await tester.tap(find.text('Ajouter · 2'));
    await _settle(tester);

    expect(result!.map((p) => p.userId ?? p.phone), [11, '+22890000002']);
  });

  testWidgets('l’activité Kory dans le fil du groupe', (tester) async {
    Future<String> text(Map<String, dynamic> payload) async {
      await tester.pumpWidget(
        _app(
          Scaffold(body: KoryActivityRow(payload: payload)),
          _overrides(_FakeRepo()),
        ),
      );
      await tester.pump();
      final l = L.of(tester.element(find.byType(KoryActivityRow)));
      return koryActivityText(l, payload);
    }

    final base = {'kind': 'kory_activity', 'pot_id': 1, 'title': 'Mariage'};
    expect(
      await text({
        ...base,
        'event': 'contribution',
        'contributor_name': 'Ama',
        'amount': 5000,
        'total': 12000,
      }),
      'Contribution de Ama confirmée : ${formatFcfa(5000)}',
    );
    expect(find.textContaining('Total confirmé'), findsOneWidget);
    expect(
      await text({...base, 'event': 'contribution', 'contributor_name': 'Ama'}),
      'Contribution de Ama confirmée',
    );
    expect(
      await text({
        ...base,
        'event': 'round',
        'round': 2,
        'rounds': 6,
        'beneficiary_name': 'Essi',
      }),
      'Tour 2 sur 6 : Essi reçoit.',
    );
    expect(
      await text({
        ...base,
        'event': 'created',
        'pot_kind': 'TONTINE',
        'actor_name': 'Afi',
      }),
      'Afi a ouvert la tontine « Mariage »',
    );
    expect(isKoryActivity(base), isTrue);
    expect(isKoryActivity({'kind': 'proof_mode'}), isFalse);
  });
}
