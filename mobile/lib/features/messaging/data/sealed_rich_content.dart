import 'dart:convert';

/// Position et fiche contact, CHIFFRÉES de bout en bout.
///
/// ── Pourquoi pas les routes `/polls/location` et `/polls/contact-card` ──
///
/// Elles écrivent la charge utile (coordonnées, nom et numéro du tiers) en
/// clair sur le serveur. Une position dit où l'on est ; une fiche contact
/// donne le numéro de quelqu'un qui n'a rien demandé : ni l'une ni l'autre
/// n'a à être lisible ailleurs que sur les deux téléphones.
///
/// Ici, la charge utile voyage DANS le chiffré d'un message ordinaire
/// (`POST /messages`, type LOCATION ou CONTACT) : le serveur ne voit que le
/// type. En groupe, la même charge part dans le corps chiffré par clé
/// d'expéditeur (`{content, payload}`, voir group_repository.dart).
///
/// Les anciennes routes ne servent plus qu'au correspondant qui n'a pas de
/// trousseau — le cas où un texte, lui aussi, part en clair.
class SealedRichContent {
  const SealedRichContent._();

  static const format = 'pokou-rich-v1';

  /// Les types dont tout le contenu est dans le chiffré.
  static const types = {'LOCATION', 'CONTACT'};

  /// Au plus cinq fiches par message, comme le serveur (`_MAX_CONTACT_CARDS`).
  static const maxContacts = 5;

  static String seal({
    String? content,
    required Map<String, dynamic> payload,
  }) => jsonEncode({'format': format, 'content': content, 'payload': payload});

  /// Le contenu d'un clair scellé par [seal], ou `null` s'il n'en est pas un.
  static ({String? content, Map<String, dynamic> payload})? open(
    String plaintext,
  ) {
    try {
      final decoded = jsonDecode(plaintext);
      if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
        return null;
      }
      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic>) return null;
      final content = decoded['content'];
      return (content: content is String ? content : null, payload: payload);
    } on FormatException {
      return null;
    }
  }

  /// Même forme que `polls.py::_location_payload` : LocationBubble lit les
  /// deux indifféremment.
  static Map<String, dynamic> location({
    required double latitude,
    required double longitude,
    String? label,
  }) => {
    'latitude': latitude,
    'longitude': longitude,
    'label': (label == null || label.trim().isEmpty) ? null : label.trim(),
    'live_until': null,
  };

  /// Même forme que la carte de visite du serveur (`{contacts: [...]}`) :
  /// ContactCardBubble la lit sans distinction.
  static Map<String, dynamic> contacts(
    List<({String displayName, String phone})> cards,
  ) => {
    'contacts': [
      for (final card in cards.take(maxContacts))
        {'display_name': card.displayName.trim(), 'phone': card.phone.trim()},
    ],
  };

  /// Le texte qui accompagne la charge utile : ce que montrent une citation
  /// et une recherche. Le nom du lieu, ou les noms des fiches.
  static String? captionOf(String messageType, Map<String, dynamic> payload) {
    if (messageType == 'LOCATION') return payload['label'] as String?;
    final cards = payload['contacts'];
    if (cards is! List) return null;
    final names = [
      for (final card in cards)
        if (card is Map && card['display_name'] is String)
          card['display_name'] as String,
    ];
    return names.isEmpty ? null : names.join(', ');
  }
}
