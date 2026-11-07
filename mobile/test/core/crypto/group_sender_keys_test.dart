import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:pokou/core/crypto/group_sender_keys.dart';

void main() {
  group('GroupSenderKeys', () {
    test('distributes a sender key and decrypts sequential messages', () async {
      final alice = GroupSenderKeys(store: InMemorySenderKeyStore());
      final bob = GroupSenderKeys(store: InMemorySenderKeyStore());
      const groupId = 23;
      const epoch = 4;
      const aliceId = 8;

      final distribution = await alice.createDistribution(
        groupId: groupId,
        epoch: epoch,
        senderId: aliceId,
      );
      await bob.acceptDistribution(
        groupId: groupId,
        epoch: epoch,
        senderId: aliceId,
        distribution: distribution,
      );

      for (final message in ['premier message', 'message suivant']) {
        final ciphertext = await alice.encrypt(
          groupId: groupId,
          epoch: epoch,
          senderId: aliceId,
          plaintext: message,
        );
        expect(
          await bob.decrypt(
            groupId: groupId,
            epoch: epoch,
            senderId: aliceId,
            ciphertext: ciphertext,
          ),
          message,
        );
      }
    });

    test('isolates sender keys by group and epoch', () async {
      final alice = GroupSenderKeys(store: InMemorySenderKeyStore());
      final bob = GroupSenderKeys(store: InMemorySenderKeyStore());

      final distribution = await alice.createDistribution(
        groupId: 23,
        epoch: 4,
        senderId: 8,
      );
      await expectLater(
        bob.acceptDistribution(
          groupId: 23,
          epoch: 5,
          senderId: 8,
          distribution: distribution,
        ),
        throwsFormatException,
      );

      final ciphertext = await alice.encrypt(
        groupId: 23,
        epoch: 4,
        senderId: 8,
        plaintext: 'confidentiel',
      );
      await expectLater(
        bob.decrypt(groupId: 23, epoch: 5, senderId: 8, ciphertext: ciphertext),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'rotates to an independent chain for a new membership epoch',
      () async {
        final alice = GroupSenderKeys(store: InMemorySenderKeyStore());
        final bob = GroupSenderKeys(store: InMemorySenderKeyStore());

        final epochOne = await alice.createDistribution(
          groupId: 99,
          epoch: 1,
          senderId: 8,
        );
        await bob.acceptDistribution(
          groupId: 99,
          epoch: 1,
          senderId: 8,
          distribution: epochOne,
        );
        final epochTwo = await alice.createDistribution(
          groupId: 99,
          epoch: 2,
          senderId: 8,
        );
        final nextMessage = await alice.encrypt(
          groupId: 99,
          epoch: 2,
          senderId: 8,
          plaintext: 'nouvel epoch',
        );

        await expectLater(
          bob.decrypt(
            groupId: 99,
            epoch: 2,
            senderId: 8,
            ciphertext: nextMessage,
          ),
          throwsA(isA<Exception>()),
        );
        await bob.acceptDistribution(
          groupId: 99,
          epoch: 2,
          senderId: 8,
          distribution: epochTwo,
        );
        expect(
          await bob.decrypt(
            groupId: 99,
            epoch: 2,
            senderId: 8,
            ciphertext: nextMessage,
          ),
          'nouvel epoch',
        );
      },
    );

    test(
      'un expéditeur sur deux appareils reste lisible (clé neuve installée)',
      () async {
        final phone = GroupSenderKeys(store: InMemorySenderKeyStore());
        final simulator = GroupSenderKeys(store: InMemorySenderKeyStore());
        final bob = GroupSenderKeys(store: InMemorySenderKeyStore());
        Future<void> give(GroupSenderKeys from, String id) async =>
            bob.acceptDistribution(
              groupId: 6,
              epoch: 4,
              senderId: 1,
              envelopeId: id,
              distribution: await from.createDistribution(
                groupId: 6,
                epoch: 4,
                senderId: 1,
              ),
            );
        Future<String> roundTrip(GroupSenderKeys from, String text) async =>
            bob.decrypt(
              groupId: 6,
              epoch: 4,
              senderId: 1,
              ciphertext: await from.encrypt(
                groupId: 6,
                epoch: 4,
                senderId: 1,
                plaintext: text,
              ),
            );

        await give(phone, 'a');
        expect(
          await roundTrip(phone, 'depuis le téléphone'),
          'depuis le téléphone',
        );
        await give(simulator, 'b');
        expect(
          await bob.hasOpened(
            groupId: 6,
            epoch: 4,
            senderId: 1,
            envelopeId: 'b',
          ),
          isTrue,
        );
        expect(
          await roundTrip(simulator, 'depuis le simulateur'),
          'depuis le simulateur',
        );
        // L'ancienne clé reste valable, et la même clé reçue deux fois ne
        // fait pas repartir la chaîne de zéro.
        await give(phone, 'c');
        expect(
          await roundTrip(phone, 'encore le téléphone'),
          'encore le téléphone',
        );
      },
    );
  });
}
