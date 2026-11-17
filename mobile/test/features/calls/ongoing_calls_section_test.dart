import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/calls/data/call_repository.dart';
import 'package:pokou/features/calls/presentation/call_controller.dart';
import 'package:pokou/features/calls/presentation/ongoing_calls_section.dart';
import 'package:pokou/l10n/app_localizations.dart';

Widget _app(List<OngoingGroupCall> calls) => ProviderScope(
  overrides: [ongoingGroupCallsProvider.overrideWith((ref) async => calls)],
  child: MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: const Scaffold(
      body: SingleChildScrollView(child: OngoingCallsSection()),
    ),
  ),
);

OngoingGroupCall _call({bool iAmIn = false, int people = 3}) =>
    OngoingGroupCall.fromJson({
      'room': 'pokou-call-1',
      'group_id': 4,
      'group_name': 'Famille Mensah',
      'is_video': false,
      'i_am_in': iAmIn,
      'in_call': [
        for (var i = 0; i < people; i++)
          {
            'user_id': 10 + i,
            'name': ['Ama', 'Kofi', 'Afi', 'Yao', 'Séna', 'Komi', 'Abla'][i],
            'avatar': null,
          },
      ],
    });

void main() {
  testWidgets('rien quand aucun appel de groupe n’est en cours', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    expect(find.text('EN COURS'), findsNothing);
  });

  testWidgets('un appel en cours : le groupe, qui est dedans, Rejoindre', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_call()]));
    await tester.pump();
    expect(find.text('EN COURS'), findsOneWidget);
    expect(find.text('Famille Mensah'), findsOneWidget);
    expect(find.textContaining('3 personnes dans l’appel'), findsOneWidget);
    expect(find.textContaining('Ama, Kofi, Afi'), findsOneWidget);
    expect(find.text('Rejoindre'), findsOneWidget);
  });

  testWidgets('au-delà de cinq visages : « +N »', (tester) async {
    await tester.pumpWidget(_app([_call(people: 7)]));
    await tester.pump();
    expect(find.text('+2'), findsOneWidget);
  });
}
