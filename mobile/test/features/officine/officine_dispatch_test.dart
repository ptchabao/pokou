import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/honam/data/honam_models.dart';
import 'package:pokou/features/officine/data/officine_models.dart';
import 'package:pokou/features/officine/presentation/officine_controller.dart';
import 'package:pokou/features/officine/presentation/officine_delivery_views.dart';
import 'package:pokou/l10n/app_localizations.dart';

/// Officine 8 et 9 (maquette p.93) : la recherche d'un coursier telle que
/// le serveur la mène (`dispatch`), le retrait à l'officine, l'accusé de
/// lecture, et le compte de l'officine (p.94).
void main() {
  String ago(Duration d) =>
      DateTime.now().toUtc().subtract(d).toIso8601String();

  Map<String, dynamic> ready({Map<String, dynamic>? dispatch, extra}) => {
    'id': 12,
    'status': 'READY',
    'delivery_address': 'Adidogomé',
    'created_at': ago(const Duration(hours: 1)),
    'patient_name': 'Yao M.',
    'delivery_price': 1000,
    'delivery_distance_km': 5.8,
    'dispatch': {
      'started_at': ago(const Duration(minutes: 1, seconds: 10)),
      'radius_km': 5,
      'wide_radius_km': 8,
      'available_count': 4,
      'attached_count': 1,
      'unanswered': <String>[],
      'priority_minutes': 5,
      'no_courier_minutes': 10,
      'area': 'Tokoin',
      ...?dispatch,
    },
    ...?extra,
  };

  test('la recherche, le retrait et la discussion se lisent du serveur', () {
    final o = OfficineOrder.fromJson(
      ready(
        dispatch: {
          'unanswered': ['Kodjo'],
        },
        extra: {
          'courier_user_id': 44,
          'courier_chat_closes_at': ago(const Duration(minutes: 5)),
          'pickup_proposed_at': ago(const Duration(minutes: 2)),
        },
      ),
    );
    expect(o.dispatch!.availableCount, 4);
    expect(o.dispatch!.area, 'Tokoin');
    expect(o.dispatch!.unanswered, ['Kodjo']);
    expect(o.dispatch!.canWiden, isTrue);
    expect(o.dispatch!.cancelled, isFalse);
    expect(o.deliveryDistanceKm, 5.8);
    expect(o.courierUserId, 44);
    expect(o.courierChatClosed, isTrue);
    expect(o.pickupProposedAt, isNotNull);
    expect(o.pickupAtPharmacy, isFalse);

    final message = HonamOrderMessage.fromJson({
      'id': 1,
      'sender_role': 'PHARMACY',
      'body': 'Le colis est prêt',
      'created_at': '2026-11-16T10:03:00',
      'read_at': '2026-11-16T10:04:00',
    });
    expect(message.readAt, isNotNull);
  });

  test('le compte : garde, fermeture, wallet en vérification, téléphones', () {
    final me = OfficineMe.fromJson({
      'pharmacy': {
        'id': 1,
        'name': 'Pharmacie Démo',
        'address': 'Tokoin, rue 254, Lomé',
        'phone': '+22822000000',
        'is_on_duty': false,
        'status': 'ACTIVE',
        'wallet_phone': '+22896000012',
        'wallet_phone_pending': '+22890000034',
        'next_duty_on': '2026-11-09',
        'temporarily_closed': true,
      },
      'staff': {'role': 'TITULAIRE', 'ring_on_order': false},
      'phones_count': 2,
      'visible': false,
    });
    expect(me.isTitulaire, isTrue);
    expect(me.ringOnOrder, isFalse);
    expect(me.phonesCount, 2);
    expect(me.pharmacy.temporarilyClosed, isTrue);
    expect(me.pharmacy.nextDutyOn, DateTime(2026, 11, 9));
    expect(me.pharmacy.walletPhonePending, '+22890000034');

    final phone = CounterPhone.fromJson({
      'id': 3,
      'name': 'Ama',
      'phone_masked': '+22890 •• •• 12',
      'role': 'COLLABORATEUR',
      'me': true,
    });
    expect(phone.me, isTrue);
    expect(phone.phoneMasked, contains('••'));
  });

  Future<void> pump(WidgetTester tester, OfficineOrder order) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          officineCouriersProvider.overrideWith(
            (ref) async =>
                const OfficineCouriers(items: [], priorityMinutes: 5),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: L.supportedLocales,
          localizationsDelegates: L.localizationsDelegates,
          home: OfficineCourierSearchView(
            order: order,
            run: (action, {body}) async => true,
            busy: false,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Officine 8 : disponibles, distance, sans réponse, annuler', (
    tester,
  ) async {
    await pump(
      tester,
      OfficineOrder.fromJson(
        ready(
          dispatch: {
            'started_at': ago(const Duration(minutes: 6)),
            'unanswered': ['Kodjo'],
          },
        ),
      ),
    );
    expect(find.text('Demander un coursier'), findsOneWidget);
    expect(find.textContaining('5,8 km'), findsOneWidget);
    expect(find.text('Kodjo n’a pas répondu en 5 min'), findsOneWidget);
    expect(find.text('4 disponibles autour de Tokoin'), findsOneWidget);
    expect(find.text('Annuler la demande'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Officine 9 : relancer, élargir à 8 km, proposer le retrait', (
    tester,
  ) async {
    await pump(
      tester,
      OfficineOrder.fromJson(
        ready(dispatch: {'started_at': ago(const Duration(minutes: 11))}),
      ),
    );
    expect(find.text('Aucun coursier disponible'), findsOneWidget);
    expect(find.text('Relancer la recherche'), findsOneWidget);
    expect(find.text('Élargir la zone à 8 km'), findsOneWidget);
    expect(find.text('Proposer le retrait'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
