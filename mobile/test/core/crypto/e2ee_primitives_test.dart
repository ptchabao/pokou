import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/crypto/e2ee_primitives.dart';

/// Les propriétés dont dépend tout le reste. Elles ont la particularité
/// désagréable de se casser SANS SYMPTÔME : un chiffrement affaibli chiffre
/// toujours, un cliquet cassé fait toujours avancer la conversation. Rien à
/// l'écran ne changerait.
void main() {
  test("deux parties dérivent le même secret, dans n'importe quel sens", () async {
    final alice = await E2EEPrimitives.generateExchangeKeyPair();
    final bob = await E2EEPrimitives.generateExchangeKeyPair();

    final fromAlice = await E2EEPrimitives.sharedSecret(
      alice,
      (await bob.extractPublicKey()).bytes,
    );
    final fromBob = await E2EEPrimitives.sharedSecret(
      bob,
      (await alice.extractPublicKey()).bytes,
    );

    expect(fromAlice, equals(fromBob));
    expect(fromAlice.length, 32);
  });

  test('un tiers ne dérive pas le secret des deux autres', () async {
    final alice = await E2EEPrimitives.generateExchangeKeyPair();
    final bob = await E2EEPrimitives.generateExchangeKeyPair();
    final eve = await E2EEPrimitives.generateExchangeKeyPair();

    final legitimate = await E2EEPrimitives.sharedSecret(
      alice,
      (await bob.extractPublicKey()).bytes,
    );
    final intruder = await E2EEPrimitives.sharedSecret(
      eve,
      (await bob.extractPublicKey()).bytes,
    );

    expect(intruder, isNot(equals(legitimate)));
  });

  test('une signature valide passe, une pré-clé substituée échoue', () async {
    final signing = await E2EEPrimitives.generateSigningKeyPair();
    final prekey = await E2EEPrimitives.generateExchangeKeyPair();
    final prekeyBytes = (await prekey.extractPublicKey()).bytes;

    final signature = await E2EEPrimitives.sign(prekeyBytes, signing);
    final signingPublic = (await signing.extractPublicKey()).bytes;

    expect(await E2EEPrimitives.verify(prekeyBytes, signature, signingPublic), isTrue);

    // C'est CE test qui protège de l'annuaire malveillant : un serveur qui
    // substitue sa propre pré-clé sans posséder la clé de signature produit
    // une signature qui ne vérifie pas.
    final substituted = await E2EEPrimitives.generateExchangeKeyPair();
    expect(
      await E2EEPrimitives.verify(
        (await substituted.extractPublicKey()).bytes,
        signature,
        signingPublic,
      ),
      isFalse,
    );
  });

  group('Cliquet symétrique', () {
    test('chaque cran donne une clé de message différente', () async {
      List<int> chain = utf8.encode('chaine-initiale-de-trente-deux-o');
      final keys = <String>[];
      for (var i = 0; i < 5; i++) {
        final step = await E2EEPrimitives.ratchet(chain);
        keys.add(base64.encode(step.messageKey));
        chain = step.nextChainKey;
      }
      expect(keys.toSet().length, 5, reason: 'une clé de message est réutilisée');
    });

    test('la clé de message ne permet pas de retrouver la chaîne', () async {
      final chain = utf8.encode('chaine-initiale-de-trente-deux-o');
      final step = await E2EEPrimitives.ratchet(chain);

      // Les deux sortent du même secret mais par des constantes différentes.
      // Sans cette séparation, connaître une clé de message donnerait la
      // chaîne — donc TOUS les messages suivants.
      expect(step.messageKey, isNot(equals(step.nextChainKey)));
      expect(step.messageKey, isNot(equals(chain)));
    });

    test('le cliquet est déterministe : deux appareils avancent pareil', () async {
      final chain = utf8.encode('chaine-initiale-de-trente-deux-o');
      final first = await E2EEPrimitives.ratchet(chain);
      final second = await E2EEPrimitives.ratchet(chain);

      // L'expéditeur et le destinataire n'échangent jamais les clés de
      // message : chacun les recalcule. Sans ce déterminisme, rien ne se
      // déchiffrerait.
      expect(first.messageKey, equals(second.messageKey));
      expect(first.nextChainKey, equals(second.nextChainKey));
    });
  });

  group('Chiffrement authentifié', () {
    Future<List<int>> key() async => E2EEPrimitives.derive(
          utf8.encode('secret-partage-de-test'),
          info: 'test',
        );

    test('aller-retour : ce qui entre ressort', () async {
      final k = await key();
      final nonce = E2EEPrimitives.randomBytes(E2EEPrimitives.nonceLength);
      final aad = utf8.encode('{"n":0}');
      final plaintext = utf8.encode('Le prix est de 500000 FCFA');

      final sealed = await E2EEPrimitives.encrypt(plaintext, key: k, nonce: nonce, aad: aad);
      final opened = await E2EEPrimitives.decrypt(
        sealed.ciphertext, mac: sealed.mac, key: k, nonce: nonce, aad: aad,
      );

      expect(utf8.decode(opened), 'Le prix est de 500000 FCFA');
      // Le chiffré ne laisse pas filtrer le clair.
      expect(utf8.decode(sealed.ciphertext, allowMalformed: true), isNot(contains('500000')));
    });

    test("un chiffré modifié d'un octet ne s'ouvre pas", () async {
      final k = await key();
      final nonce = E2EEPrimitives.randomBytes(E2EEPrimitives.nonceLength);
      final aad = utf8.encode('{"n":0}');
      final sealed = await E2EEPrimitives.encrypt(
        utf8.encode('virement de 100000'), key: k, nonce: nonce, aad: aad,
      );

      final tampered = [...sealed.ciphertext];
      tampered[0] ^= 0x01;

      expect(
        () => E2EEPrimitives.decrypt(
          tampered, mac: sealed.mac, key: k, nonce: nonce, aad: aad,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test("un en-tête modifié ne s'ouvre pas non plus", () async {
      final k = await key();
      final nonce = E2EEPrimitives.randomBytes(E2EEPrimitives.nonceLength);
      final sealed = await E2EEPrimitives.encrypt(
        utf8.encode('bonjour'), key: k, nonce: nonce, aad: utf8.encode('{"n":0}'),
      );

      // L'en-tête voyage en CLAIR : c'est son authentification, et elle
      // seule, qui empêche un serveur de rejouer un message en changeant
      // son numéro dans la chaîne.
      expect(
        () => E2EEPrimitives.decrypt(
          sealed.ciphertext, mac: sealed.mac, key: k, nonce: nonce,
          aad: utf8.encode('{"n":9}'),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('la mauvaise clé ne donne pas du charabia, elle échoue', () async {
      final nonce = E2EEPrimitives.randomBytes(E2EEPrimitives.nonceLength);
      final aad = utf8.encode('{"n":0}');
      final sealed = await E2EEPrimitives.encrypt(
        utf8.encode('bonjour'), key: await key(), nonce: nonce, aad: aad,
      );
      final wrong = await E2EEPrimitives.derive(
        utf8.encode('un-autre-secret'), info: 'test',
      );

      expect(
        () => E2EEPrimitives.decrypt(
          sealed.ciphertext, mac: sealed.mac, key: wrong, nonce: nonce, aad: aad,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  test('deux étiquettes de domaine donnent deux clés indépendantes', () async {
    final secret = utf8.encode('meme-secret-partage');
    final sending = await E2EEPrimitives.derive(secret, info: 'pokou-chain-initiator');
    final receiving = await E2EEPrimitives.derive(secret, info: 'pokou-chain-responder');

    // C'est ce qui permet deux chaînes indépendantes (aller et retour) à
    // partir d'un seul secret. Si elles se confondaient, les deux parties
    // réutiliseraient la même clé de message — la faute la plus grave
    // possible avec un chiffrement par flot authentifié.
    expect(sending, isNot(equals(receiving)));
    expect(sending.length, 32);
  });

  test('deux vecteurs d\'initialisation tirés de suite diffèrent', () async {
    final seen = <String>{};
    for (var i = 0; i < 200; i++) {
      seen.add(base64.encode(E2EEPrimitives.randomBytes(E2EEPrimitives.nonceLength)));
    }
    // Réutiliser un vecteur avec la même clé casse GCM entièrement. Ici les
    // clés changent à chaque message, mais la propriété vaut d'être tenue.
    expect(seen.length, 200);
  });
}
