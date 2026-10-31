import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/settings/data/devices_repository.dart';

void main() {
  group('PokouDevice.fromJson', () {
    test('lit la charge utile de GET /devices', () {
      final device = PokouDevice.fromJson({
        'id': 4,
        'platform': 'android',
        'registered_at': '2026-09-01T08:30:00',
        'last_seen_at': '2026-09-04T11:05:00',
        'token_hint': 'ABC123',
        'is_current': true,
      });

      expect(device.id, 4);
      expect(device.platform, 'android');
      expect(device.tokenHint, 'ABC123');
      expect(device.isCurrent, isTrue);
      expect(device.registeredAt.day, 1);
      expect(device.lastSeenAt.day, 4);
    });

    test('is_current absent vaut false', () {
      // Le serveur omet le champ quand le client n'a pas envoyé son jeton :
      // aucune ligne ne doit alors se prétendre « cet appareil ».
      final device = PokouDevice.fromJson({
        'id': 5,
        'platform': 'ios',
        'registered_at': '2026-09-01T08:30:00',
        'last_seen_at': '2026-09-01T08:30:00',
        'token_hint': 'XYZ789',
      });
      expect(device.isCurrent, isFalse);
    });
  });
}
