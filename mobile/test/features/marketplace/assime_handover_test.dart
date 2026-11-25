import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/features/marketplace/data/marketplace_repository.dart';
import 'package:pokou/features/marketplace/data/product_model.dart';
import 'package:pokou/features/marketplace/presentation/assime_sale_screens.dart';
import 'package:pokou/features/marketplace/presentation/marketplace_controller.dart';

import '../../helpers/localized_harness.dart';

/// Le dépôt sans réseau : une remise en main propre, close par le code.
class _Repository extends MarketplaceRepository {
  _Repository() : super(apiClient: ApiClient(baseUrl: 'https://inutilise'));

  int started = 0;
  final codes = <String>[];
  int? soldOutside;

  Map<String, dynamic> _handover({String? code}) => {
    'product_id': 1,
    'product_name': 'Pagne wax',
    'status': 'PENDING',
    'role': code == null ? 'seller' : 'buyer',
    'seller_name': 'Boutique Mensah',
    'buyer_name': 'Ama',
    'expires_at': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 15))
        .toIso8601String(),
    'ttl_minutes': 15,
    'code': ?code,
  };

  @override
  Future<List<Map<String, dynamic>>> buyerCandidates(int productId) async => [
    {
      'user_id': 2,
      'name': 'Ama',
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    },
  ];

  @override
  Future<Map<String, dynamic>> handover(int productId) async => started == 0
      ? throw ApiException(404, 'Aucune')
      : _handover(code: '482913');

  @override
  Future<Map<String, dynamic>> startHandover(
    int productId, {
    required int buyerId,
    int? finalPrice,
  }) async {
    started++;
    return _handover();
  }

  @override
  Future<Map<String, dynamic>> confirmHandover(
    int productId,
    String code,
  ) async {
    codes.add(code);
    if (code != '482913') {
      throw ApiException(
        422,
        'Ce code ne correspond pas.',
        code: 'handover_wrong_code',
        attemptsLeft: 4,
      );
    }
    return {..._handover(), 'status': 'DONE'};
  }

  @override
  Future<void> markSold(int productId, {int? buyerId, int? finalPrice}) async =>
      soldOutside = productId;
}

MarketplaceProduct _product() => MarketplaceProduct.fromJson({
  'id': 1,
  'seller_id': 9,
  'name': 'Pagne wax',
  'price': '12000',
});

Future<_Repository> _pump(WidgetTester tester, Widget screen) async {
  final repository = _Repository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [marketplaceRepositoryProvider.overrideWithValue(repository)],
      child: localizedHarness(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => screen),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('le vendeur valide la remise, saisit le code et clôt la vente', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      AssimeMarkSoldScreen(product: _product()),
    );
    // Le message de la maquette : les deux se rencontrent.
    expect(find.text('Vente en main propre'), findsOneWidget);

    await tester.tap(find.text('Commande validée et livrée'));
    await tester.pumpAndSettle();
    expect(repository.started, 1);
    expect(find.textContaining('Demande à Ama le code'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('assime-handover-code')),
      '111111',
    );
    await tester.pump();
    await tester.tap(find.text('Clôturer la vente'));
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect : encore 4 essais.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('assime-handover-code')),
      '482913',
    );
    await tester.pump();
    await tester.tap(find.text('Clôturer la vente'));
    await tester.pumpAndSettle();
    expect(repository.codes, ['111111', '482913']);
    expect(
      find.text('Vente clôturée. Ama est invité à te noter.'),
      findsOneWidget,
    );
  });

  testWidgets('acheteur hors de Pokou : vendue sans code', (tester) async {
    final repository = await _pump(
      tester,
      AssimeMarkSoldScreen(product: _product()),
    );
    await tester.tap(find.text('Quelqu’un hors de Pokou'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sans code'), findsOneWidget);
    await tester.tap(find.text('Confirmer la vente'));
    await tester.pumpAndSettle();
    expect(repository.soldOutside, 1);
    expect(repository.started, 0);
  });

  testWidgets('l’acheteur voit son code à donner au vendeur', (tester) async {
    final repository = _Repository()..started = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: localizedHarness(const AssimeHandoverCodeScreen(productId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('482913'), findsOneWidget);
    expect(
      find.textContaining('Donne ce code à Boutique Mensah'),
      findsOneWidget,
    );
  });
}
