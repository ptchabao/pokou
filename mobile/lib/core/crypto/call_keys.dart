import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
/// tenter de rouvrir l'enveloppe. La session l'oublie en raccrochant ; pour
/// un appel de groupe, où l'on peut revenir, [CallKeyVault] la garde.
abstract final class CallKeys {
  static final Map<String, CallKey> _keys = {};

  static void remember(String room, CallKey key) => _keys[room] = key;

  static CallKey? of(String room) => _keys[room];

  static void forget(String room) => _keys.remove(room);
}

/// Les clés des appels de GROUPE encore joignables, gardées sur le téléphone.
///
/// Dans un appel de groupe, raccrocher veut dire « JE quitte » : les autres
/// continuent, et l'on doit pouvoir revenir. Or l'enveloppe qui porte la clé
/// ne s'ouvre qu'UNE fois (le cliquet avance), et [CallKeys] oublie la clé
/// en quittant : revenir échouait toujours sur « clé d'appel impossible à
/// ouvrir » — pour l'appelant aussi, à qui aucune enveloppe n'est destinée.
///
/// La clé est donc gardée ici, dans le coffre du système (Keychain /
/// Keystore), le temps où l'appel reste joignable : [lifetime], la borne
/// après laquelle le serveur refuse d'y faire entrer quiconque. Passé ce
/// délai elle est effacée — elle n'est jamais gardée « pour plus tard ».
class CallKeyVault {
  CallKeyVault({FlutterSecureStorage? storage, DateTime Function()? now})
    : _storage = storage ?? const FlutterSecureStorage(),
      _now = now ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  static const _storageKey = 'pokou_group_call_keys_v1';

  /// Même borne que le serveur (ONGOING_TTL, call_housekeeping.py).
  static const lifetime = Duration(hours: 4);

  Future<void> keep(String room, CallKey key) async {
    try {
      final entries = await _load();
      entries[room] = {
        'k': base64.encode(key.bytes),
        'exp': _now().add(lifetime).millisecondsSinceEpoch,
      };
      await _save(entries);
    } catch (_) {
      // Coffre indisponible : l'appel en cours n'en dépend pas, seul le
      // retour après avoir quitté est perdu.
    }
  }

  Future<CallKey?> restore(String room) async {
    try {
      final entries = await _load();
      final entry = entries[room];
      if (entry is! Map) return null;
      final bytes = base64.decode(entry['k'] as String);
      return bytes.length == 32 ? CallKey(bytes) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> drop(String room) async {
    try {
      final entries = await _load();
      if (entries.remove(room) != null) await _save(entries);
    } catch (_) {}
  }

  /// Les clés encore valables — les périmées sont effacées au passage.
  Future<Map<String, dynamic>> _load() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored == null) return {};
    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic>) return {};
    final now = _now().millisecondsSinceEpoch;
    final before = decoded.length;
    decoded.removeWhere((_, entry) {
      final exp = entry is Map ? entry['exp'] : null;
      return exp is! int || exp <= now;
    });
    if (decoded.length != before) await _save(decoded);
    return decoded;
  }

  Future<void> _save(Map<String, dynamic> entries) => entries.isEmpty
      ? _storage.delete(key: _storageKey)
      : _storage.write(key: _storageKey, value: jsonEncode(entries));
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
