import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/kory/data/kory_model.dart';
import 'package:pokou/features/kory/presentation/kory_draft.dart';
import 'package:pokou/features/kory/presentation/kory_wallet.dart';

void main() {
  test('une cotisation, ses échéances et un échange se lisent du serveur', () {
    final pot = KoryPot.fromJson({
      'id': 2,
      'kind': 'COTISATION',
      'title': 'Cotisation des Amis de Bè',
      'status': 'OPEN',
      'confirmed_total': 0,
      'my_confirmed_total': 0,
      'is_organizer': true,
      'is_collector': true,
      'is_admin': true,
      'join_code': 'ABCD2345',
      'amounts_visible': false,
      'entries': [
        {
          'id': 1,
          'contributor_id': 4,
          'amount': null,
          'amount_hidden': true,
          'status': 'DECLARED',
          'declared_at': '2027-02-05T10:00:00',
          'is_mine': false,
        },
      ],
      'swaps': [
        {
          'id': 1,
          'requester_id': 3,
          'target_id': 4,
          'requester_round': 6,
          'target_round': 7,
          'status': 'ACCEPTED',
          'created_at': '2027-02-01T09:00:00',
        },
      ],
      'cotisation': {
        'members_count': 18,
        'is_member': true,
        'current': {
          'label': '2027-02',
          'due_at': '2027-02-05T12:00:00',
          'amount': 2000,
          'expected_total': 36000,
          'confirmed_total': 26000,
          'up_to_date_count': 13,
          'to_confirm_count': 2,
          'late_count': 3,
          'late': [
            {'user_id': 9, 'name': 'Komi T.'},
          ],
        },
        'next_period': {'label': '2027-03', 'due_at': '2027-03-05T12:00:00'},
      },
    });
    expect(pot.isAdmin, isTrue);
    expect(pot.amountsVisible, isFalse);
    expect(pot.entries.single.amountHidden, isTrue);
    expect(pot.entries.single.amount, 0);
    expect(pot.swaps.single.isOpen, isTrue);
    expect(pot.cotisation!.current!.late.single.status, 'LATE');
    expect(pot.cotisation!.nextPeriodDue, isNotNull);
  });

  test(
    'le calendrier suit celui du serveur : un mois sans 31 garde son dernier jour',
    () {
      final start = DateTime(2026, 1, 31, 12);
      expect(koryAddPeriod(start, 'MONTHLY', 1), DateTime(2026, 2, 28, 12));
      expect(koryAddPeriod(start, 'QUARTERLY', 1), DateTime(2026, 4, 30, 12));
      expect(koryAddPeriod(start, 'BIWEEKLY', 1), DateTime(2026, 2, 14, 12));
    },
  );

  test('le wallet du collecteur se reconnaît à son préfixe, numéro masqué', () {
    final flooz = KoryWallet.of('+22896000012')!;
    expect(flooz.operator, 'Flooz');
    expect(flooz.ussd, '*155#');
    expect(flooz.masked.contains('12'), isTrue);
    expect(flooz.masked.contains('0000'), isFalse);
    expect(KoryWallet.of('+22890112247')!.operator, 'Mixx by Yas');
    expect(KoryWallet.of('+33612345678')!.operator, isNull);
    expect(KoryWallet.of(null), isNull);
  });
}
