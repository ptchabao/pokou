import 'dart:convert';

import 'package:flutter/services.dart';

/// Les deux modules de versets. Le slug est celui du catalogue serveur
/// (voir api/alembic/versions/20261008_verse_modules.py).
enum VerseKind {
  bible('bible_verses', 'bible', 910000),
  quran('quran_verses', 'quran', 920000);

  const VerseKind(this.slug, this.file, this.notificationIdBase);

  final String slug;

  /// Le préfixe des fichiers embarqués : `assets/verses/<file>_<langue>.json`.
  final String file;

  /// Le début de la plage d'identifiants de ses notifications planifiées —
  /// distincte pour chaque module, pour annuler l'un sans toucher l'autre.
  final int notificationIdBase;

  static VerseKind? fromSlug(String slug) {
    for (final kind in values) {
      if (kind.slug == slug) return kind;
    }
    return null;
  }

  static VerseKind? fromName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// Un verset, dans la langue de l'application.
class Verse {
  const Verse({required this.reference, required this.text, this.arabic});

  /// « Jean 3:16 », « Coran — Ash-Sharh 94:5 »…
  final String reference;
  final String text;

  /// Le texte arabe d'un verset coranique, quand la langue n'est pas
  /// l'arabe : la traduction ne remplace pas l'original, elle l'accompagne.
  final String? arabic;

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
    reference: json['r'] as String,
    text: json['t'] as String,
    arabic: json['ar'] as String?,
  );
}

/// Les langues dont les versets sont embarqués — celles de l'application.
const verseLanguages = {'fr', 'en', 'es', 'it', 'ru', 'ar'};

/// Les versets d'un module, dans la langue demandée (le français à défaut).
///
/// Embarqués avec l'application, pas téléchargés : le verset de 6 h doit
/// arriver même quand le téléphone n'a pas de réseau au réveil.
Future<List<Verse>> loadVerses(
  VerseKind kind,
  String languageCode, {
  AssetBundle? bundle,
}) async {
  final code = verseLanguages.contains(languageCode) ? languageCode : 'fr';
  final raw = await (bundle ?? rootBundle).loadString(
    'assets/verses/${kind.file}_$code.json',
  );
  return [
    for (final item in jsonDecode(raw) as List)
      Verse.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
}

/// Le verset d'un jour et d'un moment (0 = matin, 1 = soir).
///
/// Déterministe — le même jour donne le même verset sur l'écran du module
/// et dans la notification — et sans répétition avant d'avoir fait le tour
/// de la liste : deux versets par jour, l'un après l'autre.
int verseIndexFor(DateTime day, int slot, int count) {
  final days =
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return (days * 2 + slot) % count;
}
