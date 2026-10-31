import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/crypto/e2ee_envelope.dart';
import 'package:pokou/core/crypto/e2ee_primitives.dart';
import 'package:pokou/core/crypto/e2ee_session.dart';

/// Le test qui compte : deux appareils, qui n'ont en commun qu'un annuaire
/// de clés publiques, s'écrivent réellement.
///
/// Tout le reste du chiffrement peut être correct et la conversation rester
/// muette si la poignée de main n'aboutit pas au MÊME secret des deux côtés.
/// Et l'inverse est pire : elle peut aboutir tout en étant dérivée de trop
/// peu, ce qui ne se verrait nulle part.

/// Un appareil : ses clés privées, et le trousseau public qu'il publie.
class _Device {
  _Device._(this.identity, this.signingKey, this.signedPrekey, this.oneTimePrekey, this.bundle);

  final SimpleKeyPair identity;
  final SimpleKeyPair signingKey;
  final SimpleKeyPair signedPrekey;
  final SimpleKeyPair oneTimePrekey;
  final PeerBundle bundle;

  static Future<_Device> create({bool withOneTimePrekey = true}) async {
    final identity = await E2EEPrimitives.generateExchangeKeyPair();
    final signing = await E2EEPrimitives.generateSigningKeyPair();
    final signedPrekey = await E2EEPrimitives.generateExchangeKeyPair();
    final oneTime = await E2EEPrimitives.generateExchangeKeyPair();

    final signedPrekeyPublic = (await signedPrekey.extractPublicKey()).bytes;
    final signature = await E2EEPrimitives.sign(signedPrekeyPublic, signing);

    return _Device._(
      identity,
      signing,
      signedPrekey,
      oneTime,
      PeerBundle(
        identityKey: (await identity.extractPublicKey()).bytes,
        signingKey: (await signing.extractPublicKey()).bytes,
        signedPrekey: signedPrekeyPublic,
        signedPrekeySignature: signature,
        oneTimePrekeyId: withOneTimePrekey ? 7 : null,
        oneTimePrekey: withOneTimePrekey ? (await oneTime.extractPublicKey()).bytes : null,
      ),
    );
  }
}

void main() {
  late _Device alice;
  late _Device bob;

  setUp(() async {
    alice = await _Device.create();
    bob = await _Device.create();
  });

  Future<({E2EESession aliceSide, E2EESession bobSide, Map<String, dynamic> preamble})>
      openSession({bool withOneTimePrekey = true}) async {
    final target = withOneTimePrekey ? bob : await _Device.create(withOneTimePrekey: false);
    final initiated = await E2EEHandshake.initiate(
      myIdentity: alice.identity,
      peer: target.bundle,
    );
    final accepted = await E2EEHandshake.accept(
      preamble: initiated.preamble,
      myIdentity: target.identity,
      mySignedPrekey: target.signedPrekey,
      myOneTimePrekey: withOneTimePrekey ? target.oneTimePrekey : null,
    );
    return (aliceSide: initiated.session, bobSide: accepted, preamble: initiated.preamble);
  }

  group('Poignée de main', () {
    test('les deux appareils aboutissent au même secret', () async {
      final s = await openSession();

      // Croisés : ce qu'Alice envoie, Bob le reçoit. Si les deux chaînes
      // étaient identiques au lieu d'être croisées, les deux parties
      // produiraient la MÊME clé au même rang — la faute la plus grave
      // possible, et parfaitement invisible à l'usage.
      expect(s.aliceSide.sendingChain, equals(s.bobSide.receivingChain));
      expect(s.aliceSide.receivingChain, equals(s.bobSide.sendingChain));
      expect(s.aliceSide.sendingChain, isNot(equals(s.aliceSide.receivingChain)));
      expect(s.aliceSide.sessionId, equals(s.bobSide.sessionId));
    });

    test('elle aboutit aussi sans pré-clé à usage unique', () async {
      // Réserve épuisée : moins fort, mais il ne faut surtout pas bloquer.
      final s = await openSession(withOneTimePrekey: false);
      expect(s.aliceSide.sendingChain, equals(s.bobSide.receivingChain));
    });

    test('une pré-clé signée substituée est refusée', () async {
      final impostor = await E2EEPrimitives.generateExchangeKeyPair();
      final forged = PeerBundle(
        identityKey: bob.bundle.identityKey,
        signingKey: bob.bundle.signingKey,
        // Un annuaire malveillant remplace la pré-clé par la sienne, dont il
        // a la privée — et peut alors tout lire. La signature est la SEULE
        // chose qui l'en empêche.
        signedPrekey: (await impostor.extractPublicKey()).bytes,
        signedPrekeySignature: bob.bundle.signedPrekeySignature,
      );

      expect(
        () => E2EEHandshake.initiate(myIdentity: alice.identity, peer: forged),
        throwsA(isA<UntrustedBundleException>()),
      );
    });

    test('deux sessions ouvertes en même temps ne se confondent pas', () async {
      // Le cas qui n'arrive jamais en test manuel et toujours en production :
      // les deux personnes s'écrivent à la seconde près, sans session
      // préalable. Chacune ouvre la sienne ; les identifiants doivent
      // différer pour que personne n'ait à arbitrer.
      final fromAlice = await E2EEHandshake.initiate(
        myIdentity: alice.identity, peer: bob.bundle,
      );
      final fromBob = await E2EEHandshake.initiate(
        myIdentity: bob.identity, peer: alice.bundle,
      );
      expect(fromAlice.session.sessionId, isNot(equals(fromBob.session.sessionId)));
    });
  });

  group('Conversation', () {
    test('un aller-retour complet passe', () async {
      final s = await openSession();

      final first = await E2EEEnvelope.seal(
        session: s.aliceSide,
        plaintext: 'Le sac de ciment est à 5500 FCFA',
        preamble: s.preamble,
      );
      expect(
        await E2EEEnvelope.open(
          session: s.bobSide, envelope: first.envelope, ciphertext: first.ciphertext,
        ),
        'Le sac de ciment est à 5500 FCFA',
      );

      final reply = await E2EEEnvelope.seal(session: s.bobSide, plaintext: "J'en prends 20");
      expect(
        await E2EEEnvelope.open(
          session: s.aliceSide, envelope: reply.envelope, ciphertext: reply.ciphertext,
        ),
        "J'en prends 20",
      );
    });

    test('dix messages d\'affilée, chacun avec sa propre clé', () async {
      final s = await openSession();
      final ciphertexts = <String>[];

      for (var i = 0; i < 10; i++) {
        final sealed = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'message $i');
        ciphertexts.add(sealed.ciphertext);
        expect(
          await E2EEEnvelope.open(
            session: s.bobSide, envelope: sealed.envelope, ciphertext: sealed.ciphertext,
          ),
          'message $i',
        );
      }
      // Dix chiffrés distincts pour dix textes distincts — et surtout, deux
      // messages identiques donneraient aussi deux chiffrés distincts, la
      // clé changeant à chaque cran.
      expect(ciphertexts.toSet().length, 10);
    });

    test('le même texte envoyé deux fois donne deux chiffrés différents', () async {
      final s = await openSession();
      final first = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'OK');
      final second = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'OK');

      // Sinon un observateur apprendrait, sans rien déchiffrer, que les deux
      // messages sont les mêmes — et une conversation de « oui / non » se
      // lirait entièrement.
      expect(first.ciphertext, isNot(equals(second.ciphertext)));
    });
  });

  group('Réseau imparfait', () {
    test('des messages arrivés dans le désordre se lisent quand même', () async {
      final s = await openSession();
      final sent = <({Map<String, dynamic> envelope, String ciphertext})>[];
      for (var i = 0; i < 4; i++) {
        sent.add(await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'message $i'));
      }

      // Le réseau mobile réordonne : ce n'est pas un cas tordu. La chaîne
      // n'étant pas réversible, sans mise en réserve des clés sautées le
      // message 0 serait perdu POUR TOUJOURS après avoir lu le 3.
      expect(
        await E2EEEnvelope.open(
          session: s.bobSide, envelope: sent[3].envelope, ciphertext: sent[3].ciphertext,
        ),
        'message 3',
      );
      expect(
        await E2EEEnvelope.open(
          session: s.bobSide, envelope: sent[0].envelope, ciphertext: sent[0].ciphertext,
        ),
        'message 0',
      );
      expect(
        await E2EEEnvelope.open(
          session: s.bobSide, envelope: sent[2].envelope, ciphertext: sent[2].ciphertext,
        ),
        'message 2',
      );
    });

    test('un message rejoué une seconde fois est refusé', () async {
      final s = await openSession();
      final sealed = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'virement envoyé');

      await E2EEEnvelope.open(
        session: s.bobSide, envelope: sealed.envelope, ciphertext: sealed.ciphertext,
      );

      // Rejouer « virement envoyé » doit échouer, pas s'afficher deux fois.
      expect(
        () => E2EEEnvelope.open(
          session: s.bobSide, envelope: sealed.envelope, ciphertext: sealed.ciphertext,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('un numéro de message absurde ne fait pas dériver un million de clés', () async {
      final s = await openSession();
      final sealed = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'bonjour');
      final tampered = {...sealed.envelope, 'n': 5000000};

      expect(
        () => E2EEEnvelope.open(
          session: s.bobSide, envelope: tampered, ciphertext: sealed.ciphertext,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Ce qui doit échouer', () {
    test("un chiffré modifié ne s'ouvre pas", () async {
      final s = await openSession();
      final sealed = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'à payer : 100000');

      final bytes = base64.decode(sealed.ciphertext);
      bytes[0] ^= 0xFF;

      expect(
        () => E2EEEnvelope.open(
          session: s.bobSide, envelope: sealed.envelope, ciphertext: base64.encode(bytes),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test("une enveloppe modifiée ne s'ouvre pas", () async {
      final s = await openSession();
      final sealed = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'bonjour');

      // Changer l'identifiant de session sans toucher au chiffré : c'est ce
      // que ferait un serveur qui range un message dans la mauvaise
      // conversation. L'enveloppe étant authentifiée, ça échoue.
      final tampered = {...sealed.envelope, 'sid': 'AAAAAAAAAAAAAAAAAAAAAA=='};
      expect(
        () => E2EEEnvelope.open(
          session: s.bobSide, envelope: tampered, ciphertext: sealed.ciphertext,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test("un intrus avec sa propre session ne lit rien", () async {
      final s = await openSession();
      final eve = await _Device.create();
      final eveSession = await E2EEHandshake.initiate(
        myIdentity: eve.identity, peer: bob.bundle,
      );

      final sealed = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'secret');
      expect(
        () => E2EEEnvelope.open(
          session: eveSession.session, envelope: sealed.envelope, ciphertext: sealed.ciphertext,
        ),
        throwsA(anything),
      );
    });
  });

  group('Aller-retour réseau', _roundTripSuite);

  group('Usage réel', _realUsageSuite);

  group('Confidentialité persistante', () {
    test("l'état volé aujourd'hui ne rouvre pas les messages d'hier", () async {
      final s = await openSession();

      final old = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'message ancien');
      await E2EEEnvelope.open(
        session: s.bobSide, envelope: old.envelope, ciphertext: old.ciphertext,
      );
      // La session de Bob a avancé. On la sérialise telle qu'un voleur la
      // trouverait sur le téléphone à cet instant.
      final stolen = E2EESession.fromJson(jsonDecode(jsonEncode(s.bobSide.toJson())));

      // La propriété : cet état ne permet PAS de rouvrir le message déjà lu.
      // C'est ce qui fait qu'un téléphone volé ne livre pas l'historique
      // chiffré, et ça tient au seul fait que HMAC ne s'inverse pas.
      expect(
        () => E2EEEnvelope.open(
          session: stolen, envelope: old.envelope, ciphertext: old.ciphertext,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('une session survit à un aller-retour par le disque', () async {
      final s = await openSession();
      final sealed = await E2EEEnvelope.seal(session: s.aliceSide, plaintext: 'après redémarrage');

      // Le cas réel : l'application est fermée entre l'envoi et la lecture.
      final revived = E2EESession.fromJson(jsonDecode(jsonEncode(s.bobSide.toJson())));

      expect(
        await E2EEEnvelope.open(
          session: revived, envelope: sealed.envelope, ciphertext: sealed.ciphertext,
        ),
        'après redémarrage',
      );
    });
  });
}

/// L'enveloppe traverse le réseau : Dart → JSON → Python → colonne JSON →
/// Python → JSON → Dart. Or c'est elle qui AUTHENTIFIE le message : si un
/// seul octet de sa sérialisation canonique diffère entre l'expéditeur et le
/// destinataire, plus rien ne se déchiffre.
///
/// La panne serait spectaculaire et le test qui manque ici est exactement
/// celui qu'on n'écrit pas : chaque couche marche, et l'assemblage non.
void _roundTripSuite() {
  test("l'enveloppe survit à un aller-retour JSON par le serveur", () async {
    final alice = await _Device.create();
    final bob = await _Device.create();

    final opened = await E2EEHandshake.initiate(
      myIdentity: alice.identity, peer: bob.bundle,
    );
    final sealed = await E2EEEnvelope.seal(
      session: opened.session,
      plaintext: 'Arrivage de ciment demain à 5500',
      preamble: opened.preamble,
    );

    // Exactement ce que subit l'enveloppe entre les deux appareils. Le
    // décodage recrée une Map dont l'ORDRE des clés n'est pas garanti —
    // d'où la sérialisation canonique côté chiffrement.
    final overTheWire = jsonDecode(jsonEncode(sealed.envelope)) as Map<String, dynamic>;
    expect(overTheWire, isNot(same(sealed.envelope)));

    final bobSession = await E2EEHandshake.accept(
      preamble: overTheWire,
      myIdentity: bob.identity,
      mySignedPrekey: bob.signedPrekey,
      myOneTimePrekey: bob.oneTimePrekey,
    );

    expect(
      await E2EEEnvelope.open(
        session: bobSession, envelope: overTheWire, ciphertext: sealed.ciphertext,
      ),
      'Arrivage de ciment demain à 5500',
    );
  });

  test("l'ordre des clés de l'enveloppe n'a aucune importance", () async {
    final alice = await _Device.create();
    final bob = await _Device.create();
    final opened = await E2EEHandshake.initiate(
      myIdentity: alice.identity, peer: bob.bundle,
    );
    final sealed = await E2EEEnvelope.seal(
      session: opened.session, plaintext: 'bonjour', preamble: opened.preamble,
    );

    // Un sérialiseur JSON peut réordonner. Sans canonicalisation, le
    // déchiffrement marcherait sur une plateforme et pas sur l'autre —
    // le pire des symptômes possibles.
    final shuffled = Map<String, dynamic>.fromEntries(
      sealed.envelope.entries.toList().reversed,
    );

    final bobSession = await E2EEHandshake.accept(
      preamble: shuffled,
      myIdentity: bob.identity,
      mySignedPrekey: bob.signedPrekey,
      myOneTimePrekey: bob.oneTimePrekey,
    );
    expect(
      await E2EEEnvelope.open(
        session: bobSession, envelope: shuffled, ciphertext: sealed.ciphertext,
      ),
      'bonjour',
    );
  });
}

/// Ce que les tests précédents ne couvraient PAS, et qui a cassé en vrai.
///
/// Ils vérifiaient qu'Alice chiffre et que Bob déchiffre — une fois, dans
/// l'ordre, chacun son rôle. La vraie application ne fonctionne pas comme ça :
/// elle recharge tout l'historique à chaque ouverture de conversation, et
/// l'expéditeur relit ses propres messages comme n'importe quels autres.
void _realUsageSuite() {
  test("un message déjà ouvert ne se rouvre PAS une seconde fois", () async {
    final alice = await _Device.create();
    final bob = await _Device.create();
    final opened = await E2EEHandshake.initiate(myIdentity: alice.identity, peer: bob.bundle);
    final bobSession = await E2EEHandshake.accept(
      preamble: opened.preamble,
      myIdentity: bob.identity,
      mySignedPrekey: bob.signedPrekey,
      myOneTimePrekey: bob.oneTimePrekey,
    );

    final sealed = await E2EEEnvelope.seal(
      session: opened.session, plaintext: 'Arrivage demain', preamble: opened.preamble,
    );
    expect(
      await E2EEEnvelope.open(
        session: bobSession, envelope: sealed.envelope, ciphertext: sealed.ciphertext,
      ),
      'Arrivage demain',
    );

    // LA propriété que l'application doit respecter : la clé a été consommée,
    // le cliquet a avancé, ce message ne se rouvrira jamais. C'est voulu —
    // c'est ce qui fait la confidentialité persistante. Mais ça impose au
    // client de CONSERVER le clair : redemander l'historique au serveur et
    // tout redéchiffrer transformait chaque réouverture de conversation en
    // mur de « message impossible à déchiffrer ».
    expect(
      () => E2EEEnvelope.open(
        session: bobSession, envelope: sealed.envelope, ciphertext: sealed.ciphertext,
      ),
      throwsA(isA<FormatException>()),
      reason: 'le clair doit être conservé par le client, pas redérivé',
    );
  });

  test("l'expéditeur ne peut PAS rouvrir ce qu'il vient d'écrire", () async {
    final alice = await _Device.create();
    final bob = await _Device.create();
    final opened = await E2EEHandshake.initiate(myIdentity: alice.identity, peer: bob.bundle);

    final sealed = await E2EEEnvelope.seal(
      session: opened.session, plaintext: 'Le prix est de 5500', preamble: opened.preamble,
    );

    // Son message est chiffré avec sa chaîne d'ENVOI ; il ne détient que la
    // clé de la chaîne de RÉCEPTION. Ce n'est pas un défaut — deux chaînes
    // distinctes sont précisément ce qui évite que les deux parties
    // produisent la même clé au même rang. Mais ça veut dire que le clair de
    // ses propres messages n'existe QUE dans son cache local.
    expect(
      () => E2EEEnvelope.open(
        session: opened.session, envelope: sealed.envelope, ciphertext: sealed.ciphertext,
      ),
      throwsA(anything),
      reason: "l'expéditeur doit garder son propre clair, il ne peut pas le retrouver",
    );
  });
}
