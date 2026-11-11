import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/crypto/call_keys.dart';

void main() {
  test(
    'la clé d\'un appel de groupe ne s\'ouvre que pour CE groupe et CET appelant',
    () {
      final key = CallKey.generate();
      final sealed = key.sealForGroup(from: 4, groupId: 12);

      final opened = CallKey.tryParseGroup(sealed, from: 4, groupId: 12);
      expect(opened, isNotNull);
      expect(opened!.bytes, key.bytes);

      // Resservie pour un autre groupe, ou présentée par quelqu'un d'autre.
      expect(CallKey.tryParseGroup(sealed, from: 4, groupId: 13), isNull);
      expect(CallKey.tryParseGroup(sealed, from: 5, groupId: 12), isNull);
      // Une clé à deux n'est pas une clé de groupe, et inversement.
      expect(
        CallKey.tryParseGroup(key.seal(from: 4, to: 12), from: 4, groupId: 12),
        isNull,
      );
      expect(CallKey.tryParse(sealed, from: 4, to: 12), isNull);
    },
  );
}
