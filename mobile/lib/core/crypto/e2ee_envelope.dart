import 'dart:convert';

import 'e2ee_primitives.dart';
import 'e2ee_session.dart';

/// Chiffrement et déchiffrement d'UN message, une fois la session ouverte.
///
/// L'enveloppe voyage en clair — le serveur la voit, et doit la voir : elle
/// contient le numéro du message dans la chaîne, sans lequel le destinataire
/// ne saurait pas quelle clé dériver. Elle ne révèle rien du contenu.
///
/// Mais elle est AUTHENTIFIÉE : elle sert de données additionnelles à
/// AES-GCM. Un serveur qui modifierait un numéro pour rejouer un message ou
/// en faire sauter un ferait échouer le déchiffrement, au lieu de réussir
/// discrètement. C'est cette ligne — passer l'enveloppe en `aad` — qui fait
/// la différence entre « chiffré » et « chiffré et non manipulable ».
class E2EEEnvelope {
  E2EEEnvelope._();

  static const version = 'v1';

  /// Chiffre, et FAIT AVANCER la session. L'appelant doit persister la
  /// session ensuite : ne pas le faire réutiliserait la même clé au message
  /// suivant, ce qui est la faute la plus grave possible avec AES-GCM.
  static Future<({Map<String, dynamic> envelope, String ciphertext})> seal({
    required E2EESession session,
    required String plaintext,
    Map<String, dynamic>? preamble,
  }) async {
    final step = await E2EEPrimitives.ratchet(session.sendingChain);
    final counter = session.sendCounter;

    final nonce = E2EEPrimitives.randomBytes(E2EEPrimitives.nonceLength);
    final envelope = <String, dynamic>{
      'v': 1,
      'sid': session.sessionId,
      'n': counter,
      'iv': base64.encode(nonce),
      if (preamble != null) ...preamble,
    };

    final sealed = await E2EEPrimitives.encrypt(
      utf8.encode(plaintext),
      key: step.messageKey,
      nonce: nonce,
      aad: _canonical(envelope),
    );

    session.sendingChain = step.nextChainKey;
    session.sendCounter = counter + 1;

    // Le code d'authentification est collé au chiffré plutôt que rangé dans
    // l'enveloppe : il n'est d'aucune utilité sans le chiffré, et les
    // séparer inviterait à transporter l'un sans l'autre.
    return (
      envelope: envelope,
      ciphertext: base64.encode([...sealed.ciphertext, ...sealed.mac]),
    );
  }

  /// Déchiffre, en rattrapant les messages sautés.
  ///
  /// Lève plutôt que de renvoyer `null` : un message qui ne s'ouvre pas n'est
  /// pas un message vide, c'est un message qu'il ne faut PAS afficher, et la
  /// distinction doit remonter jusqu'à l'appelant.
  static Future<String> open({
    required E2EESession session,
    required Map<String, dynamic> envelope,
    required String ciphertext,
  }) async {
    final counter = envelope['n'] as int;
    final nonce = base64.decode(envelope['iv'] as String);
    final raw = base64.decode(ciphertext);

    // AES-GCM produit toujours 16 octets d'authentification.
    if (raw.length < 16) {
      throw const FormatException('chiffré trop court pour porter son authentification');
    }
    final body = raw.sublist(0, raw.length - 16);
    final mac = raw.sublist(raw.length - 16);

    final key = await _messageKeyFor(session, counter);

    final plaintext = await E2EEPrimitives.decrypt(
      body,
      mac: mac,
      key: key,
      nonce: nonce,
      aad: _canonical(envelope),
    );
    return utf8.decode(plaintext);
  }

  /// Retrouve la clé du message `counter`, en avançant la chaîne et en
  /// mettant de côté celles qu'on saute.
  static Future<List<int>> _messageKeyFor(E2EESession session, int counter) async {
    // Message déjà sauté, arrivé en retard : sa clé nous attendait. On la
    // retire aussitôt — la garder permettrait de rejouer le message.
    final stored = session.skippedKeys.remove(counter);
    if (stored != null) return stored;

    if (counter < session.receiveCounter) {
      // Rang déjà consommé et pas en réserve : c'est un doublon ou un rejeu.
      // La chaîne n'étant pas réversible, il n'y a rien à faire — et
      // c'est la bonne réponse.
      throw const FormatException('message déjà reçu, ou rejoué');
    }

    final skipping = counter - session.receiveCounter;
    if (skipping > E2EESession.maxSkip) {
      // Un numéro absurde ferait dériver des millions de clés : un déni de
      // service tenant dans un seul message.
      throw const FormatException('trop de messages manquants dans la chaîne');
    }

    var chain = session.receivingChain;
    for (var n = session.receiveCounter; n < counter; n++) {
      final step = await E2EEPrimitives.ratchet(chain);
      session.skippedKeys[n] = step.messageKey;
      chain = step.nextChainKey;
    }

    final step = await E2EEPrimitives.ratchet(chain);
    session.receivingChain = step.nextChainKey;
    session.receiveCounter = counter + 1;
    return step.messageKey;
  }

  /// Sérialisation CANONIQUE de l'enveloppe — clés triées.
  ///
  /// Indispensable : l'enveloppe sert de données authentifiées, donc les deux
  /// côtés doivent produire exactement les mêmes octets. Un simple
  /// `jsonEncode` ne garantit pas l'ordre des clés d'une plateforme à
  /// l'autre, et la panne serait « les messages ne se déchiffrent que parfois
  /// », la pire à diagnostiquer.
  static List<int> _canonical(Map<String, dynamic> envelope) {
    final sorted = Map.fromEntries(
      envelope.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return utf8.encode(jsonEncode(sorted));
  }
}
