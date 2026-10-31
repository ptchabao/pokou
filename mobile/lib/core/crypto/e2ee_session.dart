import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'e2ee_primitives.dart';

/// Établissement de session et cliquet — le cœur du protocole.
///
/// Deux personnes qui ne se sont jamais écrites doivent se mettre d'accord
/// sur un secret SANS jamais être en ligne en même temps. C'est tout le
/// problème que résout cette poignée de main : l'expéditeur récupère le
/// trousseau public du destinataire auprès du serveur, dérive un secret, et
/// envoie son premier message avec de quoi le retrouver. Le destinataire
/// peut être endormi depuis trois jours.
///
/// Quatre échanges Diffie-Hellman sont combinés, et chacun répond à une
/// question distincte — c'est pour ça qu'aucun n'est superflu :
///
/// - `IK_a × SPK_b` : qui est l'expéditeur ? Lie le secret à son identité
///   longue durée. Sans lui, n'importe qui pourrait se faire passer pour lui.
/// - `EK_a × IK_b` : qui est le destinataire ? Même chose dans l'autre sens.
/// - `EK_a × SPK_b` : confidentialité persistante. L'éphémère est jeté
///   aussitôt ; voler les identités longue durée plus tard ne rouvre rien.
/// - `EK_a × OPK_b` : unicité. La pré-clé à usage unique est rayée du
///   serveur, donc une session ne peut pas être rejouée à l'identique.
///
/// Le quatrième est facultatif : si la réserve du destinataire est épuisée,
/// la session s'ouvre sans lui. Moins fort, mais pas cassé — et surtout pas
/// bloquant, ce qui compte davantage que la perfection ici.
class E2EESession {
  E2EESession({
    required this.sessionId,
    required this.peerIdentityKey,
    required this.sendingChain,
    required this.receivingChain,
    this.sendCounter = 0,
    this.receiveCounter = 0,
    Map<int, List<int>>? skipped,
  }) : skippedKeys = skipped ?? {};

  /// Identifiant dérivé des éléments de la poignée de main.
  ///
  /// C'est lui qui règle, sans négociation ni arbitrage, le cas où les deux
  /// personnes s'écrivent en même temps sans session préalable : chacune
  /// ouvre la sienne, elles ont des identifiants différents, et chacune
  /// garde les deux. Personne n'a à décider qui « gagne » — un départage par
  /// ordre alphabétique des clés, par exemple, serait fragile et
  /// silencieusement faux si les deux côtés n'appliquaient pas la même règle.
  final String sessionId;

  /// Clé d'identité du correspondant AU MOMENT de la poignée de main. Sert à
  /// détecter une réinstallation : si le trousseau publié ne correspond plus,
  /// c'est soit une réinstallation, soit quelqu'un au milieu — et
  /// l'utilisateur doit le savoir dans les deux cas.
  final List<int> peerIdentityKey;

  List<int> sendingChain;
  List<int> receivingChain;
  int sendCounter;
  int receiveCounter;

  /// Clés des messages qu'on a SAUTÉS — arrivés dans le désordre, ou pas
  /// encore arrivés du tout.
  ///
  /// Sans elles, recevoir le message n°5 avant le n°4 perdrait le n°4 pour
  /// toujours : la chaîne n'est pas réversible, une fois avancée jusqu'à 5 on
  /// ne redescend pas. Le réseau mobile réordonne, donc ce n'est pas un cas
  /// rare.
  final Map<int, List<int>> skippedKeys;

  /// Au-delà, on refuse d'avancer. Un numéro de message absurde (par erreur
  /// ou par malveillance) ferait sinon dériver des millions de clés d'un
  /// coup — un déni de service depuis un seul message.
  static const maxSkip = 200;

  Map<String, dynamic> toJson() => {
        'sid': sessionId,
        'pik': base64.encode(peerIdentityKey),
        'sc': base64.encode(sendingChain),
        'rc': base64.encode(receivingChain),
        'sn': sendCounter,
        'rn': receiveCounter,
        'skip': skippedKeys.map((n, key) => MapEntry('$n', base64.encode(key))),
      };

  factory E2EESession.fromJson(Map<String, dynamic> json) => E2EESession(
        sessionId: json['sid'] as String,
        peerIdentityKey: base64.decode(json['pik'] as String),
        sendingChain: base64.decode(json['sc'] as String),
        receivingChain: base64.decode(json['rc'] as String),
        sendCounter: json['sn'] as int? ?? 0,
        receiveCounter: json['rn'] as int? ?? 0,
        skipped: ((json['skip'] as Map?) ?? {}).map(
          (n, key) => MapEntry(int.parse(n as String), base64.decode(key as String) as List<int>),
        ),
      );
}

/// Le trousseau public de quelqu'un, tel que le serveur le rend.
class PeerBundle {
  const PeerBundle({
    required this.identityKey,
    required this.signingKey,
    required this.signedPrekey,
    required this.signedPrekeySignature,
    this.oneTimePrekeyId,
    this.oneTimePrekey,
  });

  final List<int> identityKey;
  final List<int> signingKey;
  final List<int> signedPrekey;
  final List<int> signedPrekeySignature;
  final int? oneTimePrekeyId;
  final List<int>? oneTimePrekey;

  factory PeerBundle.fromJson(Map<String, dynamic> json) {
    final oneTime = json['one_time_prekey'] as Map<String, dynamic>?;
    return PeerBundle(
      identityKey: base64.decode(json['identity_key'] as String),
      signingKey: base64.decode(json['signing_key'] as String),
      signedPrekey: base64.decode(json['signed_prekey'] as String),
      signedPrekeySignature: base64.decode(json['signed_prekey_signature'] as String),
      oneTimePrekeyId: oneTime?['key_id'] as int?,
      oneTimePrekey:
          oneTime == null ? null : base64.decode(oneTime['public_key'] as String),
    );
  }
}

/// Levée quand le trousseau reçu du serveur ne tient pas debout.
///
/// Ne JAMAIS rattraper cette exception en continuant en clair : c'est
/// exactement la situation où quelqu'un s'est mis au milieu, et « réessayer
/// sans chiffrement » lui donnerait ce qu'il cherche.
class UntrustedBundleException implements Exception {
  const UntrustedBundleException(this.reason);
  final String reason;
  @override
  String toString() => 'Trousseau refusé : $reason';
}

class E2EEHandshake {
  E2EEHandshake._();

  static const _infoRoot = 'pokou-x3dh-v1';
  static const _infoInitiator = 'pokou-chain-initiator-v1';
  static const _infoResponder = 'pokou-chain-responder-v1';

  /// Ouvre une session vers quelqu'un, à partir de son trousseau public.
  ///
  /// Renvoie la session ET les éléments à joindre au premier message, sans
  /// lesquels le destinataire ne pourrait rien reconstituer.
  static Future<({E2EESession session, Map<String, dynamic> preamble})> initiate({
    required SimpleKeyPair myIdentity,
    required PeerBundle peer,
  }) async {
    // La signature est vérifiée AVANT tout calcul. C'est la seule barrière
    // contre un annuaire qui substituerait sa propre pré-clé : sans la clé
    // de signature du destinataire, il ne peut pas produire cette signature.
    final signatureValid = await E2EEPrimitives.verify(
      peer.signedPrekey,
      peer.signedPrekeySignature,
      peer.signingKey,
    );
    if (!signatureValid) {
      throw const UntrustedBundleException('la pré-clé signée ne vérifie pas');
    }

    final ephemeral = await E2EEPrimitives.generateExchangeKeyPair();
    final ephemeralPublic = (await ephemeral.extractPublicKey()).bytes;
    final myIdentityPublic = (await myIdentity.extractPublicKey()).bytes;

    final material = <int>[
      ...await E2EEPrimitives.sharedSecret(myIdentity, peer.signedPrekey),
      ...await E2EEPrimitives.sharedSecret(ephemeral, peer.identityKey),
      ...await E2EEPrimitives.sharedSecret(ephemeral, peer.signedPrekey),
      if (peer.oneTimePrekey != null)
        ...await E2EEPrimitives.sharedSecret(ephemeral, peer.oneTimePrekey!),
    ];

    final session = await _deriveSession(
      material: material,
      peerIdentityKey: peer.identityKey,
      initiatorIdentityKey: myIdentityPublic,
      ephemeralPublic: ephemeralPublic,
      oneTimePrekeyId: peer.oneTimePrekeyId,
      amInitiator: true,
    );

    return (
      session: session,
      preamble: {
        'ik': base64.encode(myIdentityPublic),
        'ek': base64.encode(ephemeralPublic),
        if (peer.oneTimePrekeyId != null) 'pk': peer.oneTimePrekeyId,
      },
    );
  }

  /// Reconstitue la session à la réception du premier message.
  ///
  /// Les quatre échanges sont les MÊMES, calculés en miroir : chaque paire
  /// (ma clé privée, sa clé publique) d'un côté devient (sa clé publique, ma
  /// clé privée) de l'autre. C'est la propriété de Diffie-Hellman, et c'est
  /// ce qui permet aux deux de trouver le même secret sans se l'envoyer.
  static Future<E2EESession> accept({
    required Map<String, dynamic> preamble,
    required SimpleKeyPair myIdentity,
    required SimpleKeyPair mySignedPrekey,
    SimpleKeyPair? myOneTimePrekey,
  }) async {
    final peerIdentity = base64.decode(preamble['ik'] as String);
    final peerEphemeral = base64.decode(preamble['ek'] as String);
    final oneTimePrekeyId = preamble['pk'] as int?;

    if (oneTimePrekeyId != null && myOneTimePrekey == null) {
      throw const UntrustedBundleException(
        "le message cite une pré-clé à usage unique qu'on ne retrouve pas",
      );
    }

    final material = <int>[
      ...await E2EEPrimitives.sharedSecret(mySignedPrekey, peerIdentity),
      ...await E2EEPrimitives.sharedSecret(myIdentity, peerEphemeral),
      ...await E2EEPrimitives.sharedSecret(mySignedPrekey, peerEphemeral),
      if (myOneTimePrekey != null)
        ...await E2EEPrimitives.sharedSecret(myOneTimePrekey, peerEphemeral),
    ];

    return _deriveSession(
      material: material,
      peerIdentityKey: peerIdentity,
      // Côté receveur, l'initiateur EST le correspondant : c'est lui qui a
      // envoyé la poignée de main.
      initiatorIdentityKey: peerIdentity,
      ephemeralPublic: peerEphemeral,
      oneTimePrekeyId: oneTimePrekeyId,
      amInitiator: false,
    );
  }

  static Future<E2EESession> _deriveSession({
    required List<int> material,
    required List<int> peerIdentityKey,
    required List<int> initiatorIdentityKey,
    required List<int> ephemeralPublic,
    required int? oneTimePrekeyId,
    required bool amInitiator,
  }) async {
    final root = await E2EEPrimitives.derive(material, info: _infoRoot);

    // Deux chaînes distinctes, une par sens. Si les deux parties partageaient
    // une seule chaîne, elles produiraient la même clé de message au même
    // rang — réutiliser une clé AES-GCM révèle le clair des deux messages.
    // C'est la faute la plus grave possible ici, et c'est cette seule ligne
    // qui l'évite.
    final initiatorChain = await E2EEPrimitives.derive(root, info: _infoInitiator);
    final responderChain = await E2EEPrimitives.derive(root, info: _infoResponder);

    // L'empreinte ne doit dépendre que d'éléments que les DEUX côtés
    // connaissent à l'identique — d'où l'identité de l'INITIATEUR et non
    // « celle de l'autre », qui désigne deux personnes différentes selon le
    // côté d'où l'on regarde. C'est le genre d'asymétrie qui ne casse rien
    // visiblement : les messages se déchiffrent, mais chacun range la
    // session sous un nom différent et ne la retrouve plus au redémarrage.
    final fingerprint = await Sha256().hash([
      ...ephemeralPublic,
      ...initiatorIdentityKey,
      (oneTimePrekeyId ?? -1) & 0xFF,
    ]);

    return E2EESession(
      sessionId: base64.encode(fingerprint.bytes.sublist(0, 16)),
      peerIdentityKey: peerIdentityKey,
      sendingChain: amInitiator ? initiatorChain : responderChain,
      receivingChain: amInitiator ? responderChain : initiatorChain,
    );
  }
}
