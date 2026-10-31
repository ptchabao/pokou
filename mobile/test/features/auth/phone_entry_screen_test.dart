import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:pokou/core/theme/app_theme.dart';
import 'package:pokou/features/auth/data/auth_repository.dart';
import 'package:pokou/features/auth/presentation/auth_controller.dart';
import 'package:pokou/features/auth/presentation/phone_entry_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.otpError})
      : super(apiClient: ApiClient(baseUrl: 'https://unused'), tokenStorage: SecureTokenStorage());

  final ApiException? otpError;
  String? requestedPhone;

  /// Canal demandé au dernier appel — l'écran de saisie doit laisser le
  /// défaut (les deux canaux) ; seul le RENVOI depuis l'écran de code en
  /// choisit un.
  String? requestedChannel;

  @override
  Future<int> requestOtp(String phone, {String channel = 'both'}) async {
    requestedPhone = phone;
    requestedChannel = channel;
    if (otpError != null) throw otpError!;
    return 300;
  }
}

Widget _buildApp(_FakeAuthRepository fakeRepo, {required VoidCallback onOtpScreenShown}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (context, state) => const PhoneEntryScreen()),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        onOtpScreenShown();
        return const Scaffold(body: Text('OTP_SCREEN'));
      },
    ),
  ]);

  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      locale: const Locale('fr'),
    ),
  );
}

void main() {
  testWidgets('submitting a phone number requests an OTP and navigates to /otp', (tester) async {
    final fakeRepo = _FakeAuthRepository();
    var otpScreenShown = false;

    await tester.pumpWidget(_buildApp(fakeRepo, onOtpScreenShown: () => otpScreenShown = true));

    await tester.enterText(find.byType(TextField), '+22890123456');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    // Pas de pumpAndSettle : AssistantOrb anime en continu (voir plus bas) ;
    // quelques pump() bornés suffisent à laisser la navigation vers /otp se
    // produire.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeRepo.requestedPhone, '+22890123456');
    expect(otpScreenShown, isTrue);
    expect(find.text('OTP_SCREEN'), findsOneWidget);
  });

  testWidgets('shows the backend error message and stays on the phone screen', (tester) async {
    final fakeRepo = _FakeAuthRepository(otpError: ApiException(400, 'Numéro de téléphone invalide'));

    await tester.pumpWidget(_buildApp(fakeRepo, onOtpScreenShown: () => fail('should not navigate on error')));

    // Un numéro PLAUSIBLE : depuis l'ajout du sélecteur d'indicatif, le
    // bouton n'est actif que si le numéro est valide pour son pays (voir
    // canSubmit dans phone_entry_screen.dart). Ce que ce test vérifie n'est
    // pas la validation locale mais l'affichage du refus VENANT DU SERVEUR —
    // il lui faut donc un numéro qui arrive jusqu'à lui.
    await tester.enterText(find.byType(TextField), '+22890123456');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    // Pas de pumpAndSettle ici : AssistantOrb tourne une animation "respiration"
    // infinie tant que cet écran reste visible (elle ne se met en pause que
    // hors-écran, via TickerMode), donc pumpAndSettle n'atteindrait jamais un
    // état stable — quelques pump() bornés suffisent pour laisser le Future
    // rejeté et le setState du catch se résoudre.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Numéro de téléphone invalide'), findsOneWidget);
    expect(find.byType(PhoneEntryScreen), findsOneWidget);
  });

  testWidgets("un numéro impossible pour son pays n'est pas envoyable", (tester) async {
    // Le fond du problème que le sélecteur corrige : l'écran était prérempli
    // « +228 » et n'exigeait que 8 chiffres. Un Ivoirien qui tapait son
    // numéro local partait donc au serveur habillé en numéro togolais — un
    // compte au mauvais numéro, sur lequel aucun SMS n'arrive jamais.
    final fakeRepo = _FakeAuthRepository();

    await tester.pumpWidget(_buildApp(fakeRepo, onOtpScreenShown: () => fail('should not navigate')));

    // 07 01 02 03 04 est ivoirien : impossible sous l'indicatif togolais
    // proposé par défaut en test.
    await tester.enterText(find.byType(TextField), '0701020304');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Rien n'est parti : le bouton n'était pas actif.
    expect(fakeRepo.requestedPhone, isNull);
  });

  testWidgets('un numéro collé au format international repositionne le pays', (tester) async {
    final fakeRepo = _FakeAuthRepository();
    var otpScreenShown = false;

    await tester.pumpWidget(_buildApp(fakeRepo, onOtpScreenShown: () => otpScreenShown = true));

    // Collé en entier, indicatif ivoirien compris : le sélecteur doit suivre
    // au lieu de recoller le numéro derrière l'indicatif déjà choisi (ce qui
    // aurait donné « +228 225 07... »).
    await tester.enterText(find.byType(TextField), '+2250701020304');
    await tester.pump();
    expect(find.text('+225'), findsOneWidget);

    await tester.tap(find.text('Continuer'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeRepo.requestedPhone, '+2250701020304');
    expect(otpScreenShown, isTrue);
  });
}
