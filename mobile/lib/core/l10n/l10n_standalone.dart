import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/app_localizations.dart';
import 'app_locales.dart';

/// Les traductions HORS application vivante.
///
/// Le handler d'arrière-plan de Firebase tourne dans son propre isolate :
/// pas de `BuildContext`, pas de `ProviderContainer`, rien de ce que
/// l'application a chargé. Il lit donc la langue là où elle est écrite, dans
/// le même coffre que le reste des réglages, et retombe sur la règle commune
/// quand rien n'a été choisi.
Future<L> loadStandaloneL({FlutterSecureStorage? storage}) async {
  String? code;
  try {
    final raw = await (storage ?? const FlutterSecureStorage())
        .read(key: 'pokou_app_settings');
    if (raw != null) {
      code = (jsonDecode(raw) as Map<String, dynamic>)['locale_code'] as String?;
    }
  } catch (_) {
    // Coffre illisible : la langue du téléphone reste une réponse correcte.
  }
  return lookupL(resolveAppLocale(code, L.supportedLocales));
}
