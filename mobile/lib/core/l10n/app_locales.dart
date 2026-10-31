import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

/// La langue de référence de Pokou.
///
/// Celle dans laquelle l'application est écrite, et vers laquelle une clé
/// non traduite retombe déjà. En faire aussi le repli des langues non gérées
/// garde une seule réponse à « et si on ne parle pas cette langue ? ».
const fallbackLocale = Locale('fr');

/// Quelle langue afficher pour un téléphone donné.
///
/// Dans un fichier à part, et nommée, pour une raison précise : c'est une
/// RÈGLE, et une règle enfouie dans le constructeur de `MaterialApp` ne se
/// teste pas. Celle-ci s'était déjà trompée — sans repli explicite, Flutter
/// prend la PREMIÈRE locale déclarée, et le générateur les range par ordre
/// alphabétique. Un téléphone en japonais ouvrait donc Pokou en arabe,
/// aligné à droite.
///
/// La comparaison porte sur le seul `languageCode` : `fr_CA` doit trouver le
/// français, et `ar_MA` l'arabe. Exiger le pays entier ne servirait qu'à
/// faire échouer la résolution sur des variantes qu'on sait lire.
Locale appLocaleResolution(Locale? deviceLocale, Iterable<Locale> supported) {
  if (deviceLocale == null) return fallbackLocale;
  for (final locale in supported) {
    if (locale.languageCode == deviceLocale.languageCode) return locale;
  }
  return fallbackLocale;
}

/// La langue à appliquer, à partir du code enregistré dans le profil.
///
/// `null` veut dire « suivre le téléphone » : c'est le réglage par défaut,
/// et la seule différence avec un choix explicite. Cette fonction est la
/// règle unique — `MaterialApp`, les contrôleurs Riverpod et l'isolate de
/// notifications l'appellent tous plutôt que d'en réécrire chacun une
/// version légèrement différente.
Locale resolveAppLocale(String? savedCode, Iterable<Locale> supported) {
  if (savedCode != null) return Locale(savedCode);
  return appLocaleResolution(PlatformDispatcher.instance.locale, supported);
}
