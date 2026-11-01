/// Les heures du serveur, lues dans le fuseau du téléphone.
///
/// Le serveur écrit ses dates en UTC, sans indicateur de fuseau
/// (« 2026-11-01T12:00:00 »). `DateTime.parse` lit une telle chaîne comme
/// une heure LOCALE : un message envoyé à 12 h à Lomé (UTC) s'affichait
/// donc 12 h aussi à Paris, au lieu de 13 h. Toute date venue du serveur
/// passe par ici : sans indicateur, elle est UTC, et elle est rendue dans
/// le fuseau de la personne qui lit.
library;

final _offset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);

/// [raw] en heure locale. Une chaîne qui porte déjà son fuseau (« Z »,
/// « +01:00 ») est respectée ; une date seule (« 2026-11-01 ») reste un jour
/// du calendrier, sans conversion.
DateTime parseServerTime(String raw) {
  final value = raw.trim();
  if (!value.contains('T') && !value.contains(' ')) return DateTime.parse(value);
  return DateTime.parse(_offset.hasMatch(value) ? value : '${value}Z').toLocal();
}

/// Comme [parseServerTime], `null` pour une valeur absente ou illisible.
DateTime? tryParseServerTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  try {
    return parseServerTime(raw);
  } on FormatException {
    return null;
  }
}

/// Pour l'écriture : en UTC avec son « Z », pour que la relecture ne dépende
/// pas du fuseau de l'appareil au moment où elle a lieu.
String toUtcIso(DateTime value) => value.toUtc().toIso8601String();

/// Pour un paramètre envoyé au serveur : UTC, sans indicateur, le format
/// qu'il écrit lui-même et compare à ses colonnes.
String toServerTime(DateTime value) {
  final iso = value.toUtc().toIso8601String();
  return iso.endsWith('Z') ? iso.substring(0, iso.length - 1) : iso;
}
