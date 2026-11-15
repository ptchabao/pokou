import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/officine/data/officine_models.dart';
import 'package:pokou/features/officine/presentation/officine_ui.dart';

/// L'espace officine lit la commande telle que le serveur la renvoie à
/// l'officine (`_order_json(..., "pharmacy")`). Deux choses comptent : la
/// file « À traiter » (ce qui attend un geste de l'officine) et les cinq
/// temps de la frise.
void main() {
  Map<String, dynamic> order(String status, {Map<String, dynamic>? extra}) => {
    'id': 7,
    'status': status,
    'delivery_address': 'Bè-Kpota',
    'created_at': '2026-11-10T09:42:00',
    'patient_name': 'Afi K.',
    'quote_items': [
      {
        'name': 'Amoxicilline 500 mg',
        'quantity': 1,
        'unit_price': 1800,
        'available': true,
      },
      {'name': 'Sirop', 'quantity': 2, 'unit_price': 1100, 'available': false},
    ],
    'medicines_total': 1800,
    'delivery_price': 1000,
    'timeline': [
      {'status': 'SUBMITTED', 'at': '2026-11-10T09:42:00'},
      {'status': 'QUOTED', 'at': '2026-11-10T09:46:00'},
    ],
    ...?extra,
  };

  test('la file « À traiter » : nouvelle, paiement signalé, à préparer', () {
    expect(OfficineOrder.fromJson(order('SUBMITTED')).needsAction, isTrue);
    expect(OfficineOrder.fromJson(order('QUOTED')).needsAction, isFalse);
    expect(OfficineOrder.fromJson(order('ACCEPTED')).needsAction, isFalse);
    expect(
      OfficineOrder.fromJson(
        order(
          'ACCEPTED',
          extra: {'patient_paid_declared_at': '2026-11-10T09:58:00'},
        ),
      ).needsAction,
      isTrue,
    );
    expect(OfficineOrder.fromJson(order('PAID')).needsAction, isTrue);
    expect(OfficineOrder.fromJson(order('READY')).needsAction, isFalse);
  });

  test('montants, choix après un manque et fil de suivi', () {
    final o = OfficineOrder.fromJson(
      order(
        'PAID',
        extra: {'missing_amount': 600, 'missing_reason': 'Manquant : sirop'},
      ),
    );
    expect(o.collected, 2800);
    expect(o.awaitsMissingChoice, isTrue);
    expect(o.patientLabel, 'Afi K.');
    expect(o.stepTime('QUOTED'), isNotNull);
    expect(o.quoteItems.where((i) => i.available), hasLength(1));
  });

  test('les cinq temps de la frise', () {
    expect(officineStep('SUBMITTED'), 0);
    expect(officineStep('ACCEPTED'), 1);
    expect(officineStep('PAID'), 2);
    expect(officineStep('IN_DELIVERY'), 3);
    expect(officineStep('DELIVERED'), 4);
  });

  test("l'accueil : abonnement, crédit et TTC", () {
    final me = OfficineMe.fromJson({
      'pharmacy': {
        'id': 1,
        'name': 'Pharmacie Démo',
        'address': 'Tokoin',
        'phone': '+22890000000',
        'status': 'ACTIVE',
      },
      'visible': true,
      'subscription': {
        'plan': 'WETRI',
        'until': '2099-01-01T00:00:00',
        'prices_ht': {'WETRI': 5000, 'EPE': 50000},
        'vat_rate': 0.18,
      },
      'credit': {'balance_ht': 4200, 'orders_left': 42},
      'stats_month': {'received': 3, 'paid': 2, 'delivered': 1, 'rejected': 0},
    });
    expect(me.subscribed, isTrue);
    expect(me.ttc(5000), 5900);
    expect(me.ordersLeft, 42);
  });

  test('numéro masqué et initiales', () {
    expect(officineMasked('+22896001212'), '+22896 •• •• 12');
    expect(officineInitials('Kodjo Amouzou'), 'KA');
    expect(officineInitials(null), '?');
  });
}
