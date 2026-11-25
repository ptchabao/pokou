import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Interdire la capture d'écran le temps d'un affichage sensible — une vue
/// unique — et seulement ce temps-là.
///
/// Android : `FLAG_SECURE` sur la fenêtre (voir MainActivity.kt, canal
/// `com.pokou.pokou/secure`) — capture, enregistrement et aperçu des récentes
/// deviennent noirs. iOS n'offre aucun équivalent : la vue unique y reste
/// une promesse de convenance.
///
/// Compté, et non booléen : deux visionneuses empilées ne doivent pas
/// libérer l'écran quand la première se ferme.
abstract final class SecureScreen {
  static const _channel = MethodChannel('com.pokou.pokou/secure');
  static int _holders = 0;

  @visibleForTesting
  static int get holders => _holders;

  @visibleForTesting
  static void debugReset() => _holders = 0;

  static Future<void> acquire() async {
    _holders++;
    if (_holders == 1) await _set(true);
  }

  static Future<void> release() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await _set(false);
  }

  static Future<void> _set(bool secure) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // Tests, ou version native antérieure : rien à poser.
    } on PlatformException {
      // Une fenêtre détruite entre-temps : rien à défaire.
    }
  }
}
