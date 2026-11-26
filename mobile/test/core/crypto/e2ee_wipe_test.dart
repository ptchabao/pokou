import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/crypto/e2ee_store.dart';

// Après une remise à zéro du serveur, les clés du téléphone sont effacées —
// TOUTES celles du chiffrement, et SEULEMENT elles : la session de connexion
// et les réglages restent.

class _Memory extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};
  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => values[key];
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => values.remove(key);
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      values.clear();
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(values);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seules les clés de chiffrement sont effacées', () async {
    final memory = _Memory();
    FlutterSecureStoragePlatform.instance = memory;
    memory.values.addAll({
      'e2ee_identity_v1': '{}',
      'e2ee_device_id_v1': 'abc',
      'e2ee_sessions_3': '{}',
      'e2ee_otp_12': 'k',
      'signal_sender_key_v1_Zw==': 's',
      'pokou_group_call_keys_v1': '{}',
      'pokou_calls_seen_at': '2026',
      'pokou_access_token': 'jwt',
      'pokou_app_settings': '{"theme":"dark"}',
    });

    final removed = await E2EEStore().wipeAllLocalKeys();

    expect(removed, 7);
    expect(
      memory.values.keys,
      unorderedEquals(['pokou_access_token', 'pokou_app_settings']),
    );
  });
}
