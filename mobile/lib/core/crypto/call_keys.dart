import 'dart:convert';
import 'dart:typed_data';

import 'e2ee_primitives.dart';

/// La clé d'un appel chiffré de bout en bout.
///
/// ── Le principe ──────────────────────────────────────────────────────
///
/// L'appelant tire une clé au hasard pour CET appel, et la scelle pour
/// chaque invité avec la session de bout en bout qu'il a déjà avec lui —
/// exactement comme un message. Le serveur range ces enveloppes et les rend
/// à chacun quand il rejoint (voir api/app/routes/calls.py), sans pouvoir
/// les ouvrir. LiveKit chiffre ensuite chaque image et chaque échantillon
/// audio avec cette clé : le serveur de média relaie des trames qu'il ne
/// peut ni voir ni entendre.
///
/// Une clé neuve par appel, jamais dérivée d'une clé à long terme : la
/// compromission d'un téléphone plus tard ne rouvre pas les appels passés.
class CallKey {
  CallKey(this.bytes) : assert(bytes.length == 32);

  factory CallKey.generate() => CallKey(E2EEPrimitives.randomBytes(32));

  final Uint8List bytes;

  static const format = 'pokou-call-v1';

  /// Le texte scellé dans l'enveloppe de bout en bout, pour l'invité [to],
  /// de la part de [from].
  ///
  /// Les deux identifiants voyagent CHIFFRÉS avec la clé : c'est ce qui
  /// empêche de la resservir ailleurs. Sans eux, une clé qu'un contact a
  /// légitimement scellée pour un autre appel pourrait être présentée comme
  /// celle de cet appel-ci — et ce contact entendrait la conversation.
  String seal({required int from, required int to}) => jsonEncode({
    'pokou': format,
    'k': base64.encode(bytes),
    'f': from,
    't': to,
  });

  /// Le texte scellé UNE fois pour tout le groupe [groupId], avec la clé
  /// d'expéditeur de [from] (voir CallRepository.startGroupCall). Le groupe
  /// voyage chiffré avec la clé, pour la même raison que `to` ci-dessus :
  /// elle ne vaut que pour un appel de CE groupe.
  String sealForGroup({required int from, required int groupId}) => jsonEncode({
    'pokou': format,
    'k': base64.encode(bytes),
    'f': from,
    'g': groupId,
  });

  /// La clé d'un appel de groupe, scellée par [from] pour le groupe
  /// [groupId] — `null` sinon.
  static CallKey? tryParseGroup(
    String plaintext, {
    required int from,
    required int groupId,
  }) {
    try {
      final json = jsonDecode(plaintext);
      if (json is! Map || json['pokou'] != format) return null;
      if (json['f'] != from || json['g'] != groupId) return null;
      final bytes = base64.decode(json['k'] as String);
      return bytes.length == 32 ? CallKey(bytes) : null;
    } catch (_) {
      return null;
    }
  }

  /// La clé, si [plaintext] en est une de ce format, scellée par [from] pour
  /// [to] — `null` sinon.
  static CallKey? tryParse(
    String plaintext, {
    required int from,
    required int to,
  }) {
    try {
      final json = jsonDecode(plaintext);
      if (json is! Map || json['pokou'] != format) return null;
      if (json['f'] != from || json['t'] != to) return null;
      final bytes = base64.decode(json['k'] as String);
      return bytes.length == 32 ? CallKey(bytes) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Les clés des appels de cette session, par nom de salon.
///
/// L'appel se monte en plusieurs temps et par plusieurs chemins (écran
/// d'appel entrant, notification, couche native Android) qui ne se
/// transmettent que le nom du salon. La clé, obtenue une fois — tirée par
/// l'appelant, ouverte par l'invité — est rangée ici, et CallSession la
/// retrouve au moment de se connecter.
///
/// Une enveloppe ne s'ouvre qu'UNE fois (le cliquet avance) : rejoindre à
/// nouveau le même salon doit donc retrouver la clé ici plutôt que de
/// tenter de rouvrir l'enveloppe.
abstract final class CallKeys {
  static final Map<String, CallKey> _keys = {};

  static void remember(String room, CallKey key) => _keys[room] = key;

  static CallKey? of(String room) => _keys[room];

  static void forget(String room) => _keys.remove(room);
}

/// Un appel chiffré qu'on ne peut pas rejoindre ou lancer chiffré : clé
/// absente, illisible, ou correspondant qui ne peut pas la recevoir.
/// Jamais rattrapé par un appel en clair : l'autre côté chiffre, il ne
/// verrait que du bruit — et l'utilisateur croirait parler en privé.
class CallEncryptionException implements Exception {
  const CallEncryptionException(this.message);
  final String message;
  @override
  String toString() => 'CallEncryptionException: $message';
}
