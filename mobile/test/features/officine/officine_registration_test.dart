import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/theme/app_theme.dart';
import 'package:pokou/features/officine/data/officine_models.dart';
import 'package:pokou/features/officine/data/officine_repository.dart';
import 'package:pokou/features/officine/presentation/officine_controller.dart';
import 'package:pokou/features/officine/presentation/officine_entry.dart';
import 'package:pokou/features/officine/presentation/officine_registration_screens.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// « Référencer votre officine » (maquettes Officine 14 à 16) : l'entrée de
/// « Plus » pour un compte sans officine, le dossier refusé repris puis
/// renvoyé avec la formule choisie, et l'écran de vérification.

Map<String, dynamic> _json(String status, {String plan = 'EPE'}) => {
  'status': status,
  'has_pharmacy': false,
  'prices_ht': {'WETRI': 5000, 'EPE': 50000},
  'vat_rate': 0.18,
  'review_hours': 48,
  if (status != 'NONE') ...{
    'name': 'Pharmacie Démo',
    'address': 'Tokoin, rue 254, Lomé',
    'license_number': 'ARR-2019-0412',
    'wallet_phone': '+22896000012',
    'has_authorization': true,
    'plan': plan,
    'review_note': status == 'REJECTED' ? 'Arrêté illisible' : null,
    'submitted_at': '2026-11-03T10:05:00',
    'review_due_at': '2026-11-05T10:05:00',
  },
};

class _FakeRepository extends OfficineRepository {
  _FakeRepository(this.state)
    : super(apiClient: ApiClient(baseUrl: 'https://unused'));

  OfficineRegistration? state;
  String? sentPlan;
  OfficineRegistrationDraft? sentDraft;

  @override
  Future<OfficineMe?> me() async => null;

  @override
  Future<OfficineRegistration?> registration() async => state;

  @override
  Future<OfficineRegistration> register(
    OfficineRegistrationDraft draft, {
    required String plan,
    int? authorizationMediaId,
    double? latitude,
    double? longitude,
  }) async {
    sentPlan = plan;
    sentDraft = draft;
    return state = OfficineRegistration.fromJson(_json('PENDING', plan: plan));
  }
}

Widget _app(_FakeRepository repository, Widget home) => ProviderScope(
  overrides: [
    officineRepositoryProvider.overrideWithValue(repository),
    officineRegistrationPositionProvider.overrideWithValue(() async => null),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    locale: const Locale('fr'),
    home: home,
  ),
);

void main() {
  test('le dossier lu tel que le serveur le renvoie', () {
    final none = OfficineRegistration.fromJson(_json('NONE'));
    expect(none.canApply, isTrue);
    expect(none.pending, isFalse);
    expect(none.ttc(50000), 59000);
    final pending = OfficineRegistration.fromJson(_json('PENDING'));
    expect(pending.canApply, isFalse);
    expect(pending.pending, isTrue);
    expect(pending.reviewDueAt, isNotNull);
    final rejected = OfficineRegistration.fromJson(_json('REJECTED'));
    expect(rejected.canApply, isTrue);
    expect(rejected.reviewNote, 'Arrêté illisible');
  });

  testWidgets('sans officine, « Plus » propose de la référencer', (
    tester,
  ) async {
    final repository = _FakeRepository(
      OfficineRegistration.fromJson(_json('NONE')),
    );
    await tester.pumpWidget(
      _app(repository, const Scaffold(body: OfficineEntryCard())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Référencer mon officine'), findsOneWidget);

    await tester.tap(find.text('Référencer mon officine'));
    await tester.pumpAndSettle();
    expect(find.text('Référencer votre officine'), findsOneWidget);
    expect(find.text('Étape 1 sur 3'), findsOneWidget);
    expect(find.text('Autorisation d’ouverture'), findsOneWidget);
  });

  testWidgets('un dossier en attente mène à la vérification en cours', (
    tester,
  ) async {
    final repository = _FakeRepository(
      OfficineRegistration.fromJson(_json('PENDING')),
    );
    await tester.pumpWidget(
      _app(repository, const Scaffold(body: OfficineEntryCard())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dossier en cours de vérification'), findsOneWidget);

    await tester.tap(find.text('Vérification en cours'));
    await tester.pumpAndSettle();
    expect(find.text('Étape 3 sur 3'), findsOneWidget);
    expect(find.text('Dossier envoyé'), findsOneWidget);
    expect(find.text('Vérification par le support'), findsOneWidget);
    expect(find.text('Paiement ÉPÉ HONAM, puis ouverture'), findsOneWidget);
    expect(find.textContaining('TTC par CashPay'), findsOneWidget);
    expect(find.textContaining('l’affiche QR'), findsOneWidget);

    await tester.tap(find.text('Terminé'));
    await tester.pumpAndSettle();
    expect(find.text('Étape 3 sur 3'), findsNothing);
  });

  testWidgets('un dossier refusé se corrige et repart avec la formule', (
    tester,
  ) async {
    // Un téléphone haut : tout le formulaire tient dans la liste.
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rejected = OfficineRegistration.fromJson(_json('REJECTED'));
    final repository = _FakeRepository(rejected);
    await tester.pumpWidget(
      _app(repository, OfficineRegistrationInfoScreen(initial: rejected)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dossier non retenu : Arrêté illisible'), findsOneWidget);
    // Le formulaire est repris ; l'arrêté déjà envoyé sert encore.
    expect(find.text('Pharmacie Démo'), findsOneWidget);
    expect(find.textContaining('Ajoutée'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'ARR-2019-0412'),
      'ARR-2019-0413',
    );
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez votre formule'), findsOneWidget);
    expect(find.text('Étape 2 sur 3'), findsOneWidget);
    expect(find.text('2 mois offerts'), findsOneWidget);
    expect(find.text('Votre officine visible des patients proches'), findsOne);

    await tester.tap(find.text('Wétri HONAM'));
    await tester.pump();
    await tester.tap(find.text('Envoyer pour vérification'));
    await tester.pumpAndSettle();
    expect(repository.sentPlan, 'WETRI');
    expect(repository.sentDraft?.licenseNumber, 'ARR-2019-0413');
    expect(repository.sentDraft?.authorizationPath, isNull);
    // L'écran 3/3 remplace le formulaire.
    expect(find.text('Vérification en cours'), findsOneWidget);
    expect(find.text('Paiement Wétri HONAM, puis ouverture'), findsOneWidget);
  });
}
