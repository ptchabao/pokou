import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import 'e2ee_outcome.dart';
import '../providers.dart';
import 'e2ee_envelope.dart';
import 'e2ee_session.dart';
import 'e2ee_store.dart';


/// Le chiffrement de bout en bout, vu depuis le reste de l'application.
///
/// Trois choses seulement sortent d'ici : publier ses clés, chiffrer pour
/// quelqu'un, déchiffrer ce qui arrive. Tout le protocole est derrière.
///
/// ── Ce que ce chiffrement garantit, et ce qu'il ne garantit pas ──────────
///
/// À lire avant d'écrire « chiffré de bout en bout » sur une page produit :
///
/// - ✅ le serveur ne peut pas lire les messages 1:1 ;
/// - ✅ confidentialité persistante : un téléphone volé ne livre pas
///   l'historique déjà lu ;
/// - ✅ un message modifié ou rejoué en route est rejeté, pas affiché ;
/// - ✅ **aucun repli silencieux en clair** : une clé qu'on ne peut pas
///   récupérer arrête l'envoi, elle ne le dégrade pas (voir [seal] et
///   e2ee_outcome.dart) ;
/// - ✅ un changement de clé d'identité arrête l'envoi et demande une
///   décision à l'utilisateur (voir [checkPeerIdentity]) ;
/// - ❌ **pas de sécurité post-compromission** : qui vole l'état d'une
///   session lit ce qui suit jusqu'à la prochaine session. Le vrai protocole
///   Signal ajoute un second cliquet pour ça ;
/// - ❌ **les groupes, les chaînes et les statuts ne sont PAS chiffrés.** Ne
///   pas laisser croire le contraire ;
/// - ❌ l'assistant Baba ne l'est pas non plus, et ne peut pas l'être : il
///   doit lire pour répondre ;
/// - ❌ **aucun audit externe.** C'est la limite la plus importante, et elle
///   n'est pas technique.
class E2EEService {
  E2EEService({required ApiClient apiClient, E2EEStore? store})
      : _api = apiClient,
        _store = store ?? E2EEStore();

  final ApiClient _api;
  final E2EEStore _store;

  /// Réserve à maintenir sur le serveur. Ces clés sont consommées par les
  /// CORRESPONDANTS, pas par leur propriétaire : sans réapprovisionnement,
  /// la réserve se vide sans que personne ne fasse rien.
  static const _prekeyBatch = 50;

  /// Ce que CETTE version sait chiffrer au-delà du texte, déclaré au
  /// serveur avec le trousseau. Un correspondant ne nous envoie une pièce
  /// jointe ou un appel chiffrés que si nous l'avons déclaré — une version
  /// plus ancienne recevrait sinon un bloc qu'elle ne sait pas ouvrir.
  static const mediaCapability = 'media-v1';
  static const callCapability = 'call-v1';
  static const capabilities = [mediaCapability, callCapability];

  /// Ce que l'on sait du correspondant, gardé deux minutes : une photo
  /// envoyée après une autre n'a pas à reposer la question, mais une
  /// réinstallation chez lui doit se voir vite.
  final Map<int, ({PeerCrypto value, DateTime at})> _peerCrypto = {};
  static const _peerCryptoTtl = Duration(minutes: 2);

  /// Ce que l'appareil de [peerUserId] sait chiffrer, et sa clé d'identité
  /// publiée — sans consommer de pré-clé, contrairement à /bundle.
  ///
  /// Seul un 404 (serveur pas encore à jour) vaut « rien » : c'est la
  /// réponse définitive d'une API qui ne connaît pas la route, donc le
  /// comportement d'avant. Toute autre erreur — coupure, 5xx, 429, réponse
  /// illisible — LÈVE une [NetworkException] : « je ne sais pas » ne doit
  /// jamais devenir « il ne sait pas », sans quoi une panne de quelques
  /// secondes ferait partir des photos en clair vers quelqu'un qui aurait pu
  /// les recevoir chiffrées. Une erreur n'est jamais mise en cache.
  Future<PeerCrypto> peerCrypto(int peerUserId) async {
    final cached = _peerCrypto[peerUserId];
    if (cached != null && DateTime.now().difference(cached.at) < _peerCryptoTtl) {
      return cached.value;
    }
    PeerCrypto value;
    try {
      final response = await _api.get('/e2ee/capabilities/$peerUserId');
      final raw = response['capabilities'];
      if (raw is! List) throw const FormatException('capabilities');
      final identity = response['identity_key'];
      value = PeerCrypto(
        capabilities: {for (final c in raw) if (c is String) c},
        identityKey: identity is String ? identity : null,
      );
    } on ApiException catch (exc) {
      if (exc.statusCode != 404) {
        throw NetworkException('capacités indisponibles (${exc.statusCode})');
      }
      value = const PeerCrypto(capabilities: {}, identityKey: null);
    } on NetworkException {
      rethrow;
    } catch (_) {
      throw NetworkException('capacités illisibles');
    }
    _peerCrypto[peerUserId] = (value: value, at: DateTime.now());
    return value;
  }

  /// Raccourci : seulement les capacités.
  Future<Set<String>> capabilitiesOf(int peerUserId) async =>
      (await peerCrypto(peerUserId)).capabilities;

  /// Où en est notre session avec [peerUserId], comparée à l'identité qu'il
  /// publie aujourd'hui ([publishedIdentityKey], voir [peerCrypto]).
  ///
  /// `changed` : la session a été ouverte avec une autre identité —
  /// réinstallation, changement de téléphone, ou quelqu'un au milieu. Ce qui
  /// serait scellé dessus ne s'ouvrirait plus chez lui.
  Future<PeerSessionState> sessionState(
    int peerUserId, {
    required String? publishedIdentityKey,
  }) async {
    final sessions = await _store.sessionsWith(peerUserId);
    if (sessions.isEmpty) return PeerSessionState.none;
    if (publishedIdentityKey == null) return PeerSessionState.changed;
    final session = sessions.values.last;
    final known = base64.encode(session.peerIdentityKey);
    if (known != publishedIdentityKey) return PeerSessionState.changed;
    // Établie seulement si on y a déjà REÇU un message : c'est la preuve que
    // le correspondant la détient aussi. Une session qu'on vient d'ouvrir en
    // écrivant, et dont il n'a pas encore lu le premier message, ne lui
    // permettrait pas d'ouvrir une clé d'appel scellée dessus.
    return session.receiveCounter > 0
        ? PeerSessionState.established
        : PeerSessionState.unconfirmed;
  }

  /// Une seule opération à la fois par correspondant.
  ///
  /// `seal` et `open` relisent la session, la font avancer et la
  /// réécrivent en entier. Deux opérations simultanées sur le même
  /// correspondant — une photo qui part pendant qu'un message arrive, une
  /// clé d'appel scellée pendant un envoi — se marchaient dessus : la
  /// dernière écriture effaçait l'avancée de l'autre, et un numéro de
  /// message, donc une clé, servait deux fois. Le destinataire refusait
  /// alors le second message comme un rejeu.
  ///
  /// Statique : le service est reconstruit quand le client d'API l'est (un
  /// changement de langue suffit), et une opération lancée sur l'ancienne
  /// instance doit rester sérialisée avec celles de la nouvelle.
  static final Map<int, Future<void>> _tails = {};

  Future<T> _exclusive<T>(int peerUserId, Future<T> Function() action) {
    final previous = _tails[peerUserId] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>((_) {}, onError: (_) {});
    _tails[peerUserId] = tail;
    tail.whenComplete(() {
      if (identical(_tails[peerUserId], tail)) _tails.remove(peerUserId);
    });
    return result;
  }

  /// Publie son trousseau public. À appeler à chaque démarrage : c'est aussi
  /// ce qui réapprovisionne les pré-clés épuisées.
  Future<void> publishKeys() async {
    final identity = await _store.loadOrCreateIdentity();
    final deviceId = await _store.deviceId();
    final bundle = await identity.publicBundle(deviceId: deviceId);

    var needed = _prekeyBatch;
    try {
      final count = await _api.get('/e2ee/prekeys/count');
      if (count['published'] == true) {
        needed = (count['low'] as bool? ?? true) ? _prekeyBatch : 0;
      }
    } catch (_) {
      // Compteur indisponible : on publie quand même le trousseau, avec un
      // lot. Mieux vaut quelques pré-clés en trop qu'un trousseau absent,
      // qui empêcherait qui que ce soit de nous écrire chiffré.
    }

    final prekeys = needed > 0 ? await _store.generateOneTimePrekeys(needed) : const [];
    await _api.put('/e2ee/bundle', body: {
      ...bundle,
      'capabilities': capabilities,
      'one_time_prekeys': [
        for (final prekey in prekeys)
          {'key_id': prekey.keyId, 'public_key': base64.encode(prekey.publicKey)},
      ],
    });
  }

  /// Chiffre pour quelqu'un, en ouvrant une session au besoin.
  ///
  /// **Ne retombe JAMAIS en clair sur une erreur.** Voir e2ee_outcome.dart
  /// pour les trois issues possibles et pourquoi une seule laisse passer du
  /// clair. Le seul cas toléré est le 404 : une réponse du serveur, pas une
  /// panne. Tout le reste — 500, délai dépassé, coupure, trousseau
  /// illisible, identité changée, échec cryptographique — arrête l'envoi.
  ///
  /// Ne lève pas : les échecs sont des VALEURS de retour. Une exception se
  /// rattrape par distraction dans un `catch` large — c'est même exactement
  /// ce qui s'était passé ici — alors qu'une issue non traitée fait échouer
  /// l'analyse statique grâce au `switch` exhaustif sur une classe scellée.
  Future<SealOutcome> seal({required int peerUserId, required String plaintext}) =>
      _exclusive(peerUserId, () => _seal(peerUserId: peerUserId, plaintext: plaintext));

  Future<SealOutcome> _seal({required int peerUserId, required String plaintext}) async {
    final E2EEIdentity identity;
    final Map<String, E2EESession> sessions;
    try {
      identity = await _store.loadOrCreateIdentity();
      sessions = await _store.sessionsWith(peerUserId);
    } catch (_) {
      return const SealRefused(SealFailure.cryptoFailure);
    }

    // Session existante : on continue sa chaîne, sans préambule — le
    // destinataire l'a déjà.
    if (sessions.isNotEmpty) {
      final session = sessions.values.last;
      try {
        final sealed = await E2EEEnvelope.seal(session: session, plaintext: plaintext);
        await _store.saveSession(peerUserId, session);
        return SealEncrypted(
          encryption: E2EEEnvelope.version,
          ciphertext: sealed.ciphertext,
          envelope: sealed.envelope,
        );
      } catch (_) {
        return const SealRefused(SealFailure.cryptoFailure);
      }
    }

    final Map<String, dynamic> bundleJson;
    try {
      bundleJson = await _api.get('/e2ee/bundle/$peerUserId') as Map<String, dynamic>;
    } on ApiException catch (exc) {
      // 404 et 404 SEULEMENT : le serveur affirme que cette personne n'a pas
      // publié de trousseau. N'importe quel autre code est une panne, ou une
      // réponse qu'on ne sait pas interpréter — dans les deux cas on ne
      // devine pas.
      return exc.statusCode == 404
          ? const SealPeerHasNoKeys()
          : const SealRefused(SealFailure.keyLookupFailed);
    } catch (_) {
      // Coupure réseau, délai dépassé, réponse illisible.
      return const SealRefused(SealFailure.keyLookupFailed);
    }

    final PeerBundle peer;
    try {
      peer = PeerBundle.fromJson(bundleJson);
    } catch (_) {
      // Un trousseau qu'on ne sait pas lire n'est pas une absence de
      // trousseau : c'est une réponse anormale, et c'est la forme qu'aurait
      // une interposition maladroite.
      return const SealRefused(SealFailure.invalidBundle);
    }

    try {
      final opened = await E2EEHandshake.initiate(
        myIdentity: identity.identityKeyPair,
        peer: peer,
      );
      final sealed = await E2EEEnvelope.seal(
        session: opened.session,
        plaintext: plaintext,
        preamble: opened.preamble,
      );
      await _store.saveSession(peerUserId, opened.session);
      return SealEncrypted(
        encryption: E2EEEnvelope.version,
        ciphertext: sealed.ciphertext,
        envelope: sealed.envelope,
      );
    } catch (_) {
      // Signature de pré-clé invalide, courbe inattendue, dérivation
      // impossible : le trousseau était syntaxiquement lisible mais
      // cryptographiquement faux.
      return const SealRefused(SealFailure.cryptoFailure);
    }
  }

  /// Déchiffre un message reçu.
  ///
  /// Lève si le message ne s'ouvre pas. L'appelant DOIT afficher un message
  /// illisible comme tel plutôt que de le masquer : un message manquant sans
  /// explication est bien plus déroutant qu'un message marqué « impossible à
  /// déchiffrer », et c'est aussi le seul signe qu'un utilisateur puisse
  /// avoir qu'il se passe quelque chose d'anormal.
  Future<String> open({
    required int peerUserId,
    required Map<String, dynamic> envelope,
    required String ciphertext,
  }) => _exclusive(
    peerUserId,
    () => _open(peerUserId: peerUserId, envelope: envelope, ciphertext: ciphertext),
  );

  Future<String> _open({
    required int peerUserId,
    required Map<String, dynamic> envelope,
    required String ciphertext,
  }) async {
    final sessionId = envelope['sid'] as String?;
    final sessions = await _store.sessionsWith(peerUserId);

    var session = sessionId == null ? null : sessions[sessionId];

    if (session == null) {
      // Premier message d'une nouvelle session : le préambule contient de
      // quoi la reconstituer.
      if (envelope['ik'] == null || envelope['ek'] == null) {
        throw const FormatException('session inconnue et message sans préambule');
      }
      final identity = await _store.loadOrCreateIdentity();
      final prekeyId = envelope['pk'] as int?;
      session = await E2EEHandshake.accept(
        preamble: envelope,
        myIdentity: identity.identityKeyPair,
        mySignedPrekey: identity.signedPrekeyPair,
        myOneTimePrekey: prekeyId == null ? null : await _store.takeOneTimePrekey(prekeyId),
      );
    }

    final plaintext = await E2EEEnvelope.open(
      session: session,
      envelope: envelope,
      ciphertext: ciphertext,
    );
    // La session a avancé : la persister est ce qui empêche de redériver
    // deux fois la même clé au redémarrage.
    await _store.saveSession(peerUserId, session);
    return plaintext;
  }

  /// La clé d'identité du correspondant a-t-elle changé depuis la session en
  /// cours ? — une réinstallation, ou quelqu'un au milieu.
  ///
  /// L'utilisateur doit le savoir dans les deux cas : c'est le seul moment
  /// où le chiffrement de bout en bout lui demande quelque chose, et le seul
  /// endroit où une attaque devient visible.
  Future<bool> identityChanged({required int peerUserId, required String publishedIdentityKey}) async {
    final sessions = await _store.sessionsWith(peerUserId);
    if (sessions.isEmpty) return false;
    final known = base64.encode(sessions.values.last.peerIdentityKey);
    return known != publishedIdentityKey;
  }

  /// Interroge le serveur et compare l'identité publiée à celle de la
  /// session en cours.
  ///
  /// C'est le branchement qui manquait : `identityChanged` existait depuis
  /// le début et n'était appelé de NULLE PART. Une clé qui change — le seul
  /// évènement qu'un utilisateur puisse constater quand quelqu'un s'insère
  /// entre lui et son correspondant — passait donc totalement inaperçue.
  ///
  /// Appelé à l'ouverture d'une conversation : un aller-retour par ouverture
  /// est le prix de ce contrôle, et c'est le seul moment où l'on est certain
  /// que quelqu'un regarde l'écran et peut décider.
  ///
  /// Ne lève jamais — un contrôle qui échoue ne doit pas empêcher d'ouvrir
  /// une conversation. Il renvoie [PeerIdentity.unknown], et l'envoi, lui,
  /// reste protégé par [seal] qui refuse de son côté.
  Future<PeerIdentity> checkPeerIdentity({required int peerUserId}) async {
    final Map<String, E2EESession> sessions;
    try {
      sessions = await _store.sessionsWith(peerUserId);
    } catch (_) {
      return PeerIdentity.unknown;
    }
    // Aucune session : il n'y a rien à comparer, et le premier échange
    // établira la référence.
    if (sessions.isEmpty) return PeerIdentity.noSessionYet;

    final Map<String, dynamic> bundleJson;
    try {
      bundleJson = await _api.get('/e2ee/bundle/$peerUserId') as Map<String, dynamic>;
    } on ApiException catch (exc) {
      // 404 alors qu'une session existe : la personne a retiré son
      // trousseau. Ce n'est pas un changement d'identité, mais ce n'est pas
      // normal non plus — on ne prétend pas savoir.
      return exc.statusCode == 404 ? PeerIdentity.unknown : PeerIdentity.unknown;
    } catch (_) {
      return PeerIdentity.unknown;
    }

    final published = bundleJson['identity_key'];
    if (published is! String) return PeerIdentity.unknown;

    final known = base64.encode(sessions.values.last.peerIdentityKey);
    return known == published ? PeerIdentity.unchanged : PeerIdentity.changed;
  }

  /// Accepte la nouvelle identité d'un correspondant.
  ///
  /// Efface les sessions connues : le prochain message rejouera une poignée
  /// de main complète avec le trousseau publié, et l'avertissement
  /// disparaît. C'est un geste DÉLIBÉRÉ de l'utilisateur, jamais automatique
  /// — l'automatiser reviendrait à supprimer le contrôle qu'on vient
  /// d'ajouter.
  ///
  /// Conséquence à assumer : l'historique déjà reçu reste lisible (il est en
  /// clair dans le cache local), mais la session qui le portait est perdue.
  Future<void> acceptPeerIdentity({required int peerUserId}) =>
      _exclusive(peerUserId, () => _store.forgetSessions(peerUserId));
}

/// L'état de l'identité cryptographique d'un correspondant.
enum PeerIdentity {
  /// Jamais échangé avec lui : rien à comparer.
  noSessionYet,

  /// Même clé qu'à la dernière session.
  unchanged,

  /// La clé a changé. Réinstallation, nouveau téléphone — ou quelqu'un au
  /// milieu. Rien ne permet de trancher, donc on le dit et on laisse
  /// décider.
  changed,

  /// Le contrôle n'a pas pu être fait (réseau, réponse illisible). On ne
  /// prétend ni que tout va bien, ni le contraire.
  unknown,
}

final e2eeServiceProvider = Provider<E2EEService>((ref) {
  return E2EEService(apiClient: ref.watch(apiClientProvider));
});

/// Publie le trousseau public dès qu'une session existe, et le
/// réapprovisionne à chaque démarrage.
///
/// À chaque démarrage, et pas seulement à l'inscription : les pré-clés à
/// usage unique sont consommées par les CORRESPONDANTS. Leur propriétaire ne
/// fait rien, et sa réserve se vide quand même. Une réserve épuisée
/// n'empêche pas de recevoir, mais affaiblit chaque nouvelle session — une
/// dégradation parfaitement silencieuse, donc à traiter automatiquement.
///
/// Best-effort : une panne de publication ne doit jamais empêcher
/// d'utiliser l'application. On retombe alors sur des messages en clair,
/// c'est-à-dire sur le comportement d'avant.
final e2eeKeyPublicationProvider = Provider<void>((ref) {
  final session = ref.watch(authControllerProvider).user;
  if (session == null) return;
  Future(() async {
    try {
      await ref.read(e2eeServiceProvider).publishKeys();
    } catch (_) {
      // Voir docstring.
    }
  });
});

/// Ce que l'on sait de l'appareil d'un correspondant — voir
/// E2EEService.peerCrypto.
class PeerCrypto {
  const PeerCrypto({required this.capabilities, required this.identityKey});

  final Set<String> capabilities;

  /// La clé d'identité qu'il publie aujourd'hui, `null` sans trousseau.
  final String? identityKey;
}

/// Notre session avec un correspondant — voir E2EEService.sessionState.
enum PeerSessionState {
  /// Aucune session : la première enveloppe l'ouvrira, avec son préambule.
  none,

  /// Une session ouverte avec l'identité qu'il publie aujourd'hui, mais où
  /// rien n'a encore été reçu : il ne l'a peut-être pas encore ouverte.
  unconfirmed,

  /// Une session ouverte avec l'identité qu'il publie aujourd'hui, et où il
  /// nous a déjà écrit : il la détient.
  established,

  /// Une session ouverte avec une AUTRE identité que celle publiée.
  changed,
}

