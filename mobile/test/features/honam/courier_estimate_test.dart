import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/honam/data/honam_models.dart';
import 'package:pokou/features/honam/presentation/courier_join_screen.dart';
import 'package:pokou/features/honam/presentation/honam_controller.dart';

import '../../helpers/localized_harness.dart';

// Retour testeur (18 novembre) : « Tu gagnes » restait à 0 et les montants
// s'affichaient en négatif. Avec l'offre du Togo telle que le serveur la
// rend (1 000 F la course, adhésion et packs TTC), tout est positif.

const _togo = CourierOffer(
  honamOpen: true,
  servedCities: ['Lomé'],
  trialRides: 5,
  membershipPriceTtc: 1180,
  giftRides: 2,
  deliveryPrice: 1000,
  packs: [
    (code: 'ABLAVI', label: 'ABLAVI 1er', rides: 5, priceTtc: 590),
    (code: 'POKOU_VI', label: 'Pokou Vi', rides: 10, priceTtc: 1062),
    (code: 'OSEI_TUTU', label: 'Oseï Tutu', rides: 20, priceTtc: 1888),
    (code: 'QUEEN', label: 'Queen Pokou', rides: null, priceTtc: 3540),
  ],
);

void main() {
  testWidgets('Tu gagnes 1 000 F par course, et un net positif', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courierStatusProvider.overrideWith((ref) async => null),
          courierOfferProvider.overrideWith((ref, code) async => _togo),
        ],
        child: localizedHarness(const CourierOfferScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(
      texts.any(
        (t) => t.contains('1') && t.contains('000') && t.contains('par course'),
      ),
      isTrue,
      reason: 'le prix d\'une course est affiché',
    );
    final netLabel = find.text('Net pour toi');
    expect(netLabel, findsOneWidget);
    // Aucune somme négative en dehors de la ligne de coût (« −… »).
    final net = texts[texts.indexOf('Net pour toi') + 1];
    expect(
      net.startsWith('-') || net.startsWith('−'),
      isFalse,
      reason: 'net = $net',
    );
  });
}
