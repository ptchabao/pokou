import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/features/settings/data/support_repository.dart';
import 'package:pokou/features/settings/presentation/support_screens.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// « Écrire au support » et « Signaler un problème » parlent à l'équipe
/// Pokou par POST /support/tickets — et non plus à Baba.
class _FakeApi extends ApiClient {
  _FakeApi({this.tickets = const [], this.refuseWith})
    : super(baseUrl: 'https://inutilise');

  final List<Map<String, dynamic>> tickets;
  final int? refuseWith;
  final posted = <Map<String, dynamic>>[];

  @override
  Future<dynamic> get(String path, {bool authenticated = true}) async {
    expect(path, '/support/tickets');
    return {'items': tickets};
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    expect(path, '/support/tickets');
    if (refuseWith != null) throw ApiException(refuseWith!, 'refus');
    posted.add(body!);
    return {
      'id': posted.length,
      'kind': body['kind'],
      'category': body['category'],
      'status': 'OPEN',
      'description': body['description'],
      'created_at': '2026-11-16T10:00:00',
    };
  }
}

Future<void> _pump(WidgetTester tester, _FakeApi api, Widget screen) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supportRepositoryProvider.overrideWithValue(
          SupportRepository(apiClient: api),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('SupportTicket.fromJson lit la réponse de l’équipe', () {
    final t = SupportTicket.fromJson({
      'id': 3,
      'kind': 'PROBLEM',
      'category': 'CALLS',
      'status': 'ANSWERED',
      'description': 'L’appel coupe.',
      'reply': 'Corrigé dans la 1.31.',
      'created_at': '2026-11-15T09:00:00',
      'replied_at': '2026-11-16T09:00:00',
    });
    expect(t.isProblem, isTrue);
    expect(t.reply, 'Corrigé dans la 1.31.');
    expect(t.repliedAt, isNotNull);
  });

  testWidgets('écrire au support envoie une demande et liste mes demandes', (
    tester,
  ) async {
    final api = _FakeApi(
      tickets: [
        {
          'id': 1,
          'kind': 'SUPPORT',
          'category': 'QUESTION',
          'status': 'ANSWERED',
          'description': 'Comment changer de numéro ?',
          'reply': 'Réglages › Compte.',
          'created_at': '2026-11-15T09:00:00',
        },
      ],
    );
    await _pump(tester, api, const SupportContactScreen());

    expect(find.text('Mes demandes'.toUpperCase()), findsOneWidget);
    expect(find.text('Répondu'), findsOneWidget);
    expect(find.text('Réglages › Compte.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Je ne reçois plus les notifications.',
    );
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(api.posted.single['kind'], 'SUPPORT');
    expect(
      api.posted.single['description'],
      'Je ne reçois plus les notifications.',
    );
    expect(api.posted.single['platform'], isNotEmpty);
    expect(find.text('Message envoyé au support.'), findsOneWidget);
  });

  testWidgets('trop de demandes : un message clair, pas une erreur brute', (
    tester,
  ) async {
    final api = _FakeApi(refuseWith: 429);
    await _pump(tester, api, const SupportContactScreen());
    expect(find.text('Aucune demande pour l’instant.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Une question de plus.');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('plusieurs demandes'), findsOneWidget);
  });

  testWidgets('signaler un problème : catégorie, description, confirmation', (
    tester,
  ) async {
    final api = _FakeApi();
    await _pump(tester, api, const ReportProblemScreen());

    // Rien ne part sans catégorie.
    final send = find.widgetWithText(FilledButton, 'Envoyer');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.tap(find.text('Appels'));
    await tester.enterText(
      find.byType(TextField),
      'L’appel se coupe au bout de dix secondes.',
    );
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(api.posted.single['kind'], 'PROBLEM');
    expect(api.posted.single['category'], 'CALLS');
    expect(api.posted.single.containsKey('screenshot_media_id'), isFalse);
    expect(find.text('Merci, c’est transmis'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
  });
}
