import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/auth/presentation/forgot_pin_screen.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// Code PIN oublié : une seule voie, le délai de 7 jours. Jamais de
/// réinitialisation par e-mail — ni proposée, ni annoncée.
void main() {
  testWidgets('seul le délai de 7 jours est proposé, pas l’e-mail', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const ForgotPinScreen(verificationToken: 'laissez-passer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attendre 7 jours'), findsOneWidget);
    expect(find.textContaining('e-mail'), findsNothing);
    expect(find.byType(RadioListTile<String>), findsNothing);
    expect(find.text('Deux façons de retrouver ton compte :'), findsNothing);
  });
}
