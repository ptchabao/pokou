/// Anonymisation locale approximative avant envoi à l'API (Mode Bouclier —
/// voir le cahier des charges). Ce n'est PAS une vraie extraction d'entités
/// nommées (NER) : un modèle on-device réel (ex. Google ML Kit Entity
/// Extraction) ferait mieux mais n'est pas intégré dans cette phase. Ces
/// heuristiques ne couvrent que les montants et les noms propres probables
/// (mots capitalisés) — objets et lieux ("[OBJET]", "[LIEU]" dans l'exemple
/// du cahier des charges) nécessiteraient une vraie compréhension du texte
/// et ne sont délibérément pas approximés ici pour ne pas donner une
/// fausse impression d'anonymisation complète.
library;

final _amountPattern = RegExp(
  r'\b\d[\d\s.,]*\s*(?:FCFA|CFA|XOF|F|€|\$|USD|EUR|M|K|Mds)?\b',
  caseSensitive: false,
);

final _properNounPattern = RegExp(r'\b[A-ZÀ-Ý][a-zà-ÿ]{2,}\b');

String redactForShield(String text) {
  var result = text.replaceAll(_amountPattern, '[MONTANT]');
  result = result.replaceAllMapped(_properNounPattern, (match) => '[NOM]');
  return result;
}
