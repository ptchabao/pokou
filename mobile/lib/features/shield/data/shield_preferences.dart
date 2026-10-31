import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Master on/off for Shield Mode (Réglages > Confidentialité & Sécurité) —
/// separate from the per-conversation `active` state in shield_controller.dart,
/// which is the automatic focus-based activation. This is the user's own
/// choice to have the feature exist at all.
class ShieldPreferences {
  ShieldPreferences({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _enabledKey = 'pokou_shield_enabled';

  Future<bool> readEnabled() async {
    final value = await _storage.read(key: _enabledKey);
    return value !=
        'false'; // activé par défaut — absence de clé = jamais désactivé
  }

  Future<void> writeEnabled(bool enabled) =>
      _storage.write(key: _enabledKey, value: enabled.toString());
}
