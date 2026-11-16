import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/features/groups/data/group_poll.dart';

/// Sondages de groupe chiffrés : la définition voyage dans le corps chiffré
/// du message, les votes sont chiffrés avec la clé du sondage et comptés sur
/// le téléphone.
void main() {
  GroupPollDefinition poll({bool multiple = false}) =>
      GroupPollDefinition.create(
        question: 'Qui vient samedi ?',
        options: const ['Moi', 'Pas moi', 'Peut-être'],
        allowsMultiple: multiple,
      );

  test('la définition se relit depuis le payload déchiffré', () {
    final original = poll(multiple: true);
    final read = GroupPollDefinition.fromPayload(original.toPayload())!;
    expect(read.question, 'Qui vient samedi ?');
    expect(read.allowsMultiple, isTrue);
    expect(read.options.map((o) => o.text), ['Moi', 'Pas moi', 'Peut-être']);
    expect(read.key, original.key);
    expect(read.key, hasLength(32));
    // Une clé par sondage.
    expect(poll().key, isNot(equals(original.key)));
  });

  test("un payload qui n'est pas un sondage chiffré n'en devient pas un", () {
    expect(GroupPollDefinition.fromPayload(null), isNull);
    expect(GroupPollDefinition.fromPayload({'latitude': 6.1}), isNull);
    expect(
      GroupPollDefinition.fromPayload({
        'poll': {'format': 'autre', 'question': 'x'},
      }),
      isNull,
    );
  });

  test(
    'un vote scellé se rouvre, et seulement pour son votant et son sondage',
    () async {
      final definition = poll();
      final sealed = await GroupPollVoteCipher.seal(
        key: definition.key,
        groupId: 7,
        messageId: 'm-1',
        voterId: 42,
        optionIds: [1],
      );
      expect(sealed.contains('Pas moi'), isFalse);

      Future<List<int>?> open({int voterId = 42, String messageId = 'm-1'}) =>
          GroupPollVoteCipher.open(
            key: definition.key,
            groupId: 7,
            messageId: messageId,
            voterId: voterId,
            ciphertext: sealed,
          );
      expect(await open(), [1]);
      // Le serveur ne peut ni l'attribuer à un autre, ni le déplacer.
      expect(await open(voterId: 43), isNull);
      expect(await open(messageId: 'm-2'), isNull);
      expect(
        await GroupPollVoteCipher.open(
          key: poll().key,
          groupId: 7,
          messageId: 'm-1',
          voterId: 42,
          ciphertext: sealed,
        ),
        isNull,
      );
    },
  );

  test(
    'le décompte : une voix par membre, un seul choix compté en choix unique',
    () {
      final result = poll().tally(
        messageId: 'm-1',
        votes: {
          1: [0],
          2: [0, 1], // client fautif : un seul choix compte
          3: [1],
          4: [99], // réponse inconnue : ignorée
        },
        myUserId: 3,
      );
      expect(result.id, 'm-1');
      expect(result.totalVoters, 3);
      expect(result.options.map((o) => o.voteCount), [2, 1, 0]);
      expect(result.options[0].voterIds, [1, 2]);
      expect(result.options[1].mine, isTrue);
      expect(result.options[0].mine, isFalse);
    },
  );

  test('en choix multiple, un votant compte une fois au total', () {
    final result = poll(multiple: true).tally(
      messageId: 'm-1',
      votes: {
        1: [0, 1, 2],
        2: [2],
      },
      myUserId: 1,
    );
    expect(result.totalVoters, 2);
    expect(result.options.map((o) => o.voteCount), [1, 1, 2]);
    expect(result.options.every((o) => o.mine), isTrue);
  });
}
