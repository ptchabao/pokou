import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/country/country_config.dart';
import 'package:pokou/features/auth/data/user_model.dart';
import 'package:pokou/features/auth/presentation/auth_controller.dart';
import 'package:pokou/features/honam/data/honam_models.dart';
import 'package:pokou/features/honam/data/honam_repository.dart';
import 'package:pokou/features/honam/presentation/courier_join_screen.dart';
import 'package:pokou/features/honam/presentation/honam_controller.dart';
import 'package:pokou/features/modules/shared/module_payment.dart';

import '../../helpers/localized_harness.dart';

class _SignedIn extends StateNotifier<AuthState> implements AuthController {
  _SignedIn()
    : super(
        AuthState.authenticated(
          const PokouUser(
            id: 7,
            fullName: 'Afi Mensah',
            plan: 'FREE',
            phone: '+22890112233',
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Repository implements HonamRepository {
  int restarts = 0;

  @override
  Future<void> restartCourierApplication() async => restarts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Urgences', () {
    test('lit les services, les alternatives et la fiabilité', () {
      final info = EmergencyInfo.fromConfig({
        'emergency': {
          'country': 'CI',
          'reliability': 'low',
          'services': [
            {
              'key': 'police',
              'number': '170',
              'alternatives': ['110', '111'],
              'note': null,
            },
          ],
          'others': [
            {
              'label': 'Défense nationale',
              'number': '199',
              'alternatives': <String>[],
            },
          ],
        },
      });
      expect(info.services.single.alternatives, ['110', '111']);
      expect(info.others.single.label, 'Défense nationale');
      expect(info.lowReliability, isTrue);
      expect(info.isEmpty, isFalse);
    });

    test('se contente de l’ancienne forme d’un serveur plus ancien', () {
      final info = EmergencyInfo.fromConfig({
        'emergency_numbers': {'police': '117', 'samu': '8200'},
      });
      expect(info.services.map((s) => s.key), ['police', 'samu']);
      expect(info.lowReliability, isFalse);
    });
  });

  group('Pays de test', () {
    test('un paiement simulé se reconnaît, un vrai non', () {
      expect(isTestPayment({'test_mode': true, 'status': 'confirmed'}), isTrue);
      expect(isTestPayment({'test_mode': false, 'status': 'pending'}), isFalse);
      expect(isTestPayment('https://exemple.test/payer'), isFalse);
    });

    test('la vidéo « Découvrir Pokou » n’est retenue qu’en https', () {
      CountryConfig parse(Object? url) => CountryConfig.fromJson({
        'country': 'FR',
        'modules': ['honam'],
        'test_only': true,
        'discover_video_url': url,
      });
      expect(
        parse('https://youtu.be/x').discoverVideoUrl,
        'https://youtu.be/x',
      );
      expect(parse('').discoverVideoUrl, isNull);
      expect(parse(null).discoverVideoUrl, isNull);
      expect(parse('http://x').discoverVideoUrl, isNull);
      expect(parse(null).testOnly, isTrue);
    });
  });

  testWidgets('« Recommencer » efface la candidature après confirmation', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _SignedIn()),
          honamRepositoryProvider.overrideWithValue(repository),
          courierStatusProvider.overrideWith((ref) async => null),
        ],
        child: localizedHarness(
          const CourierJoinScreen(
            offer: CourierOffer(
              honamOpen: true,
              servedCities: ['Lomé'],
              trialRides: 5,
              membershipPriceTtc: 1180,
              packs: [],
              giftRides: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Recommencer'));
    await tester.pumpAndSettle();
    expect(find.text('Recommencer la candidature ?'), findsOneWidget);

    // Annuler : rien n'est effacé.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repository.restarts, 0);

    await tester.tap(find.byTooltip('Recommencer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    expect(repository.restarts, 1);
    expect(
      find.text('Candidature effacée : tu repars de l’étape 1.'),
      findsOneWidget,
    );
  });
}
