import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import 'app_locales.dart';

/// Les traductions HORS arbre de widgets.
///
/// `L.of(context)` suppose un `BuildContext`, et tout le code qui parle à
/// l'utilisateur n'en a pas : les contrôleurs Riverpod posent leurs messages
/// d'erreur dans un état, le client HTTP en lève, le service de notifications
/// en construit alors que l'application est fermée. Ce provider applique la
/// MÊME règle que `MaterialApp` — langue choisie dans le profil, sinon celle
/// du téléphone, sinon le français — pour que les deux chemins ne puissent
/// pas diverger.
final appL10nProvider = Provider<L>((ref) {
  final code = ref.watch(appSettingsProvider).localeCode;
  return lookupL(resolveAppLocale(code, L.supportedLocales));
});
