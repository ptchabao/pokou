import 'dart:convert';
import 'dart:typed_data';

import '../../../core/crypto/e2ee_primitives.dart';
import '../../messaging/data/direct_message_model.dart'
    show PollData, PollOptionData;

/// Un sondage de groupe, chiffré de bout en bout.
///
/// ── Pourquoi pas la route des sondages à deux ──────────────────────────
///
/// En discussion à deux, le serveur tient la question, les réponses et les
/// votes en clair (api polls.py). Un groupe est chiffré de bout en bout : le
/// serveur refuse ces sondages-là (409), il devrait sinon lire ce que le
/// reste du groupe lui cache.
///
/// Ici, la question, les réponses et une CLÉ propre au sondage voyagent dans
/// le message lui-même — un message de groupe de type POLL, chiffré avec la
/// clé d'expéditeur comme n'importe quel texte. Chaque vote est chiffré avec
/// la clé du sondage et déposé sur le serveur, qui en garde un par membre
/// (api groups.py::set_group_poll_vote) sans pouvoir l'ouvrir. Le décompte
/// se fait ici.
///
/// Une clé de sondage, et pas la clé d'expéditeur du votant : un message
/// chiffré par clé d'expéditeur ne s'ouvre qu'UNE fois (la chaîne avance),
/// alors qu'un vote se relit à chaque ouverture du sondage, se remplace, et
/// doit pouvoir être relu par son propre auteur.
class GroupPollDefinition {
  const GroupPollDefinition({
    required this.question,
    required this.allowsMultiple,
    required this.options,
    required this.key,
  });

  /// Tire la clé du sondage au hasard — une par sondage, jamais réutilisée.
  factory GroupPollDefinition.create({
    required String question,
    required List<String> options,
    required bool allowsMultiple,
  }) => GroupPollDefinition(
    question: question,
    allowsMultiple: allowsMultiple,
    options: [
      for (var index = 0; index < options.length; index++)
        (id: index, text: options[index]),
    ],
    key: E2EEPrimitives.randomBytes(32),
  );

  static const format = 'pokou-group-poll-v1';

  final String question;
  final bool allowsMultiple;
  final List<({int id, String text})> options;
  final Uint8List key;

  /// Ce qui part dans le corps chiffré du message (`payload`).
  Map<String, dynamic> toPayload() => {
    'poll': {
      'format': format,
      'question': question,
      'allows_multiple': allowsMultiple,
      'options': [
        for (final option in options) {'id': option.id, 'text': option.text},
      ],
      'key': base64.encode(key),
    },
  };

  /// Le sondage décrit par le `payload` déchiffré d'un message, ou `null`
  /// s'il n'en porte pas (ou pas sous une forme lisible).
  static GroupPollDefinition? fromPayload(Map<String, dynamic>? payload) {
    try {
      final poll = payload?['poll'];
      if (poll is! Map || poll['format'] != format) return null;
      final key = base64.decode(poll['key'] as String);
      if (key.length != 32) return null;
      final options = [
        for (final raw in poll['options'] as List)
          (id: (raw as Map)['id'] as int, text: raw['text'] as String),
      ];
      if (options.length < 2) return null;
      return GroupPollDefinition(
        question: poll['question'] as String,
        allowsMultiple: poll['allows_multiple'] as bool? ?? false,
        options: options,
        key: key,
      );
    } catch (_) {
      return null;
    }
  }

  /// Le sondage tel que la bulle l’affiche, à partir des votes ouverts —
  /// `votes[membre] = ses choix`. Même forme que ce que renvoie le serveur
  /// pour un sondage à deux, pour que la même bulle serve aux deux.
  PollData tally({
    required String messageId,
    required Map<int, List<int>> votes,
    required int? myUserId,
  }) {
    final voters = <int>{};
    final byOption = {for (final option in options) option.id: <int>[]};
    for (final entry in votes.entries) {
      final chosen = entry.value.where(byOption.containsKey).toSet();
      if (chosen.isEmpty) continue;
      // Un sondage à choix unique ne compte qu'un choix, quoi qu'envoie un
      // client.
      for (final optionId in allowsMultiple ? chosen : {chosen.first}) {
        byOption[optionId]!.add(entry.key);
      }
      voters.add(entry.key);
    }
    return PollData(
      id: messageId,
      question: question,
      allowsMultiple: allowsMultiple,
      totalVoters: voters.length,
      options: [
        for (final (index, option) in options.indexed)
          PollOptionData(
            id: option.id,
            text: option.text,
            position: index,
            voteCount: byOption[option.id]!.length,
            voterIds: byOption[option.id]!,
            mine: myUserId != null && byOption[option.id]!.contains(myUserId),
          ),
      ],
    );
  }
}

/// Chiffrement des votes avec la clé du sondage (AES-256-GCM).
///
/// Le groupe, le message et le votant sont liés au chiffré (données
/// authentifiées) : le serveur ne peut pas présenter le vote de l'un comme
/// celui d'un autre, ni le déplacer sur un autre sondage — il échouerait à
/// l'ouverture.
class GroupPollVoteCipher {
  GroupPollVoteCipher._();

  /// Valeur du champ `encryption` attendue par le serveur.
  static const encryption = 'poll-key-v1';

  static List<int> _aad(int groupId, String messageId, int voterId) =>
      utf8.encode('pokou-group-poll-vote-v1:$groupId:$messageId:$voterId');

  static Future<String> seal({
    required Uint8List key,
    required int groupId,
    required String messageId,
    required int voterId,
    required List<int> optionIds,
  }) async {
    final nonce = E2EEPrimitives.randomBytes(E2EEPrimitives.nonceLength);
    final box = await E2EEPrimitives.encrypt(
      utf8.encode(jsonEncode({'options': optionIds})),
      key: key,
      nonce: nonce,
      aad: _aad(groupId, messageId, voterId),
    );
    return base64.encode([...nonce, ...box.ciphertext, ...box.mac]);
  }

  /// Les choix d'un vote, ou `null` s'il ne s'ouvre pas : un vote illisible
  /// ou altéré ne compte pas, il ne fait pas échouer tout le sondage.
  static Future<List<int>?> open({
    required Uint8List key,
    required int groupId,
    required String messageId,
    required int voterId,
    required String ciphertext,
  }) async {
    try {
      final bytes = base64.decode(ciphertext);
      const nonceLength = E2EEPrimitives.nonceLength;
      const macLength = 16;
      if (bytes.length < nonceLength + macLength) return null;
      final clear = await E2EEPrimitives.decrypt(
        bytes.sublist(nonceLength, bytes.length - macLength),
        mac: bytes.sublist(bytes.length - macLength),
        key: key,
        nonce: bytes.sublist(0, nonceLength),
        aad: _aad(groupId, messageId, voterId),
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map || decoded['options'] is! List) return null;
      return [
        for (final id in decoded['options'] as List)
          if (id is int) id,
      ];
    } catch (_) {
      return null;
    }
  }
}
