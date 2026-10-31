import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/auth/data/user_model.dart';

void main() {
  group('PokouUser.fromJson', () {
    test('parses a phone-only account (no email)', () {
      final user = PokouUser.fromJson({
        'id': 42,
        'email': null,
        'phone': '+22890123456',
        'full_name': null,
        'plan': 'free',
      });

      expect(user.id, 42);
      expect(user.email, isNull);
      expect(user.phone, '+22890123456');
      expect(user.displayName, '+22890123456');
    });

    test('falls back to email for displayName when phone and name are absent', () {
      final user = PokouUser.fromJson({
        'id': 1,
        'email': 'ceo@mahizu.com',
        'plan': 'enterprise',
      });

      expect(user.displayName, 'ceo@mahizu.com');
    });

    test('defaults plan to free when missing', () {
      final user = PokouUser.fromJson({'id': 1});
      expect(user.plan, 'free');
    });
  });
}
