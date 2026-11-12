import 'dart:convert';
import '../../../core/crypto/undecryptable.dart';
import '../../../core/api/api_client.dart';
import '../../../core/crypto/e2ee_outcome.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/crypto/media_cipher.dart';
import '../../../core/storage/pokou_message_store.dart';
import 'direct_message_model.dart';

/// Le dépôt est la FRONTIÈRE du chiffrement.
///
/// En dessous (le réseau), les messages sont chiffrés ; au-dessus (les
/// écrans, le cache local, la recherche), ils sont en clair. Aucun écran ne
/// sait qu'il existe un chiffrement, et c'est délibéré : la seule façon
/// d'oublier de déchiffrer quelque part, c'est qu'il y ait plusieurs
/// endroits où y penser.
/// Taille d'une page d'historique, en conversation comme en groupe.
const kHistoryPageSize = 100;

class MessagingRepository {
  MessagingRepository({
    required ApiClient apiClient,
    E2EEService? e2ee,
    PokouMessageStore? store,
  }) : _api = apiClient,
       _e2ee = e2ee,
       _store = store;

  final ApiClient _api;

  /// `null` désactive le chiffrement — utilisé par les tests qui ne
  /// s'intéressent pas à lui, et par rien d'autre.
  final E2EEService? _e2ee;

  /// Le cache local, et la raison pour laquelle il n'est pas optionnel en
  /// pratique : **un message chiffré ne se déchiffre qu'UNE SEULE FOIS.**
  ///
  /// Le cliquet consomme la clé du message au moment où il l'ouvre, et cette
  /// clé n'existe plus ensuite — c'est exactement ce qui fait la
  /// confidentialité persistante. Le clair obtenu est donc la SEULE copie
  /// lisible qui subsistera : s'il n'est pas écrit sur le disque tout de
  /// suite, le message est perdu pour de bon.
  final PokouMessageStore? _store;

  /// Les déchiffrements en cours, partagés par TOUTES les instances du
  /// dépôt : le WebSocket et la notification reçoivent le même message au
  /// même instant, et le dépôt est reconstruit quand la langue change. Deux
  /// ouvertures simultanées, c'est une clé consommée deux fois — la seconde
  /// échoue.
  static final Map<String, Future<DirectMessage>> _incomingDecryptions = {};

  /// Les types dont le fichier peut voyager chiffré de bout en bout.
  static const _encryptedMediaTypes = {'IMAGE', 'VIDEO', 'AUDIO', 'DOCUMENT'};

  /// Résout le contenu des messages chiffrés d'une page d'historique.
  ///
  /// ── Les deux pannes que cette méthode corrige ────────────────────────
  ///
  /// L'écran d'une conversation recharge son historique COMPLET depuis le
  /// serveur à chaque ouverture. La première version déchiffrait tout, à
  /// chaque fois. Or :
  ///
  /// - **un message déjà lu ne se rouvre pas.** Sa clé a été consommée et le
  ///   cliquet a avancé ; le redéchiffrer échoue forcément. Rouvrir une
  ///   conversation transformait donc TOUS ses messages en « impossible à
  ///   déchiffrer ».
  /// - **ses propres messages ne s'ouvrent pas du tout.** Ils ont été
  ///   chiffrés avec la chaîne d'ENVOI ; on ne possède que la clé de la
  ///   chaîne de RÉCEPTION. L'expéditeur ne pouvait pas relire ce qu'il
  ///   venait d'écrire.
  ///
  /// Le clair déjà obtenu vit dans le cache local : on le consulte AVANT de
  /// tenter quoi que ce soit, et on ne déchiffre que ce qu'on n'a jamais vu.
  /// Le cas de l'expéditeur se règle du même coup — son propre message y a
  /// été écrit en clair à l'envoi.
  Future<List<DirectMessage>> _resolveEncrypted(
    List<DirectMessage> messages,
    int peerUserId,
  ) async {
    if (_e2ee == null) return messages;
    final encryptedIds = [
      for (final m in messages)
        if (m.isEncrypted) m.id,
    ];
    if (encryptedIds.isEmpty) return messages;

    final alreadyKnown =
        await _store?.decryptedFor(encryptedIds) ??
        const <String, DirectMessage>{};

    final resolved = <DirectMessage>[];
    final freshlyOpened = <DirectMessage>[];
    for (final message in messages) {
      if (!message.isEncrypted) {
        resolved.add(message);
        continue;
      }
      final known = alreadyKnown[message.id];
      if (known != null && known.editedAt == message.editedAt) {
        resolved.add(message.resolvedWith(known));
        continue;
      }
      // Par le même point que le temps réel : une seule ouverture à la fois
      // par message. L'historique et une notification qui arrive au même
      // instant tentaient sinon chacun d'ouvrir l'enveloppe ; le second
      // échouait (clé consommée) et sa copie encore chiffrée écrasait la
      // bonne dans le cache.
      final opened = await decryptIncoming(message, peerUserId);
      resolved.add(opened);
      if (!opened.isEncrypted) freshlyOpened.add(opened);
    }

    // Écrit AVANT de rendre la main. La clé vient d'être consommée : si
    // l'application meurt entre ici et la sauvegarde que fera l'appelant, le
    // message devient illisible pour toujours.
    if (freshlyOpened.isNotEmpty) await _store?.saveDirect(freshlyOpened);

    return resolved;
  }

  /// Une tentative d'ouverture, et une seule.
  ///
  /// En cas d'échec, le chiffré est CONSERVÉ et `encryption` reste posé :
  /// le message ne compte donc pas comme résolu, et une version future
  /// capable de le lire pourra encore essayer. Écraser le chiffré par le
  /// texte d'erreur rendrait l'échec définitif — y compris s'il n'était dû
  /// qu'à un aléa.
  /// Le clair d'un message direct — un texte, ou la clé d'une pièce jointe
  /// — appliqué à [message]. Sert au déchiffrement normal ET à la
  /// re-livraison. Renvoie [message] inchangé si la clé ne correspond pas.
  DirectMessage resolveDirectPlaintext(
    DirectMessage message,
    String plaintext,
  ) {
    // Une pièce jointe chiffrée transporte sa CLÉ, pas un texte : la
    // légende, le nom et le type du fichier voyagent avec elle.
    final mediaKey = message.mediaAssetId != null
        ? MediaKey.tryParse(plaintext)
        : null;
    if (mediaKey != null) {
      // Une clé n'est acceptée que pour le fichier qu'elle annonce, et
      // seulement pour un type qui voyage chiffré : un autocollant public,
      // par exemple, ne l'est jamais.
      if (mediaKey.assetId != message.mediaAssetId ||
          !_encryptedMediaTypes.contains(message.messageType)) {
        return message;
      }
      return message.copyWith(
        content: mediaKey.caption,
        mediaKey: mediaKey,
        media: mediaKey.toMeta(message.mediaAssetId!),
        clearCiphertext: true,
      );
    }
    return message.copyWith(content: plaintext, clearCiphertext: true);
  }

  /// Le clair d'un message que J'AI envoyé, pour le re-livrer.
  static String directPlaintextOf(DirectMessage message) =>
      message.mediaKey != null && message.mediaAssetId != null
      ? jsonEncode(
          message.mediaKey!.withAssetId(message.mediaAssetId!).toJson(),
        )
      : (message.content ?? '');

  Future<DirectMessage> _openOnce(DirectMessage message, int peerUserId) async {
    try {
      final plaintext = await _e2ee!.open(
        peerUserId: peerUserId,
        envelope: message.envelope!,
        ciphertext: message.ciphertext!,
      );
      return resolveDirectPlaintext(message, plaintext);
    } catch (_) {
      // L'isolat des notifications a son propre dépôt : il a pu ouvrir ce
      // message à l'instant (une enveloppe ne s'ouvre qu'une fois) et être
      // en train de ranger le clair. On le lui laisse le temps avant de
      // demander une re-livraison à l'expéditeur.
      final elsewhere = await _openedElsewhere(message);
      if (elsewhere != null) return elsewhere;
      // Reçu de nouvel essai : seulement pour un message REÇU — le mien,
      // c'est moi qui en ai le clair.
      if (message.senderId == peerUserId) {
        reportUndecryptable('direct', message.id);
      }
      // Un message qui ne s'ouvre pas n'est pas masqué : une bulle manquante
      // sans explication est bien plus déroutante qu'une bulle qui dit
      // pourquoi — et c'est le seul signe qu'un utilisateur puisse avoir que
      // quelque chose cloche.
      return message;
    }
  }

  /// Voir GroupRepository.openedElsewhereWait.
  static Duration openedElsewhereWait = const Duration(milliseconds: 900);

  Future<DirectMessage?> _openedElsewhere(DirectMessage message) async {
    final store = _store;
    if (store == null) return null;
    const steps = 3;
    for (var i = 0; i <= steps; i++) {
      try {
        final cached = (await store.decryptedFor([message.id]))[message.id];
        if (cached != null && cached.editedAt == message.editedAt) {
          return message.resolvedWith(cached);
        }
      } catch (_) {
        return null;
      }
      if (i < steps) await Future<void>.delayed(openedElsewhereWait ~/ steps);
    }
    return null;
  }

  /// Déchiffre un message arrivé par le WebSocket. Exposé parce que le temps
  /// réel ne passe pas par les méthodes ci-dessous — et qu'un message poussé
  /// doit être lisible exactement comme un message chargé.
  Future<DirectMessage> decryptIncoming(DirectMessage message, int peerUserId) {
    final inFlight = _incomingDecryptions[message.id];
    if (inFlight != null) return inFlight;
    final decryption = _decryptIncomingOnce(message, peerUserId);
    _incomingDecryptions[message.id] = decryption;
    return decryption.whenComplete(() {
      if (identical(_incomingDecryptions[message.id], decryption)) {
        _incomingDecryptions.remove(message.id);
      }
    });
  }

  Future<DirectMessage> _decryptIncomingOnce(
    DirectMessage message,
    int peerUserId,
  ) async {
    if (!message.isEncrypted || _e2ee == null) return message;
    // Même précaution que pour l'historique : une reconnexion du socket peut
    // rejouer un message déjà reçu, et le redéchiffrer échouerait.
    final known =
        await _store?.decryptedFor([message.id]) ??
        const <String, DirectMessage>{};
    final cached = known[message.id];
    // Une modification porte un nouveau chiffré : l'ancien clair ne vaut
    // plus pour elle.
    if (cached != null && cached.editedAt == message.editedAt) {
      return message.resolvedWith(cached);
    }

    final opened = await _openOnce(message, peerUserId);
    if (!opened.isEncrypted) await _store?.saveDirect([opened]);
    return opened;
  }

  /// Recherche de messages. `contactUserId` restreint à UNE conversation —
  /// l'icône de recherche dans une discussion ne doit pas remonter les
  /// messages des autres.
  Future<List<DirectMessage>> searchMessages(
    String query, {
    int? contactUserId,
  }) async {
    final params = [
      'q=${Uri.encodeQueryComponent(query)}',
      if (contactUserId != null) 'contact_user_id=$contactUserId',
    ];
    final response = await _api.get('/messages/search?${params.join('&')}');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(DirectMessage.fromJson)
        .toList();
  }

  Future<List<DirectMessage>> getConversation(int contactUserId) async =>
      (await getConversationPage(contactUserId)).items;

  /// Une page d'historique, la plus récente quand `skip` vaut 0. `total` est
  /// le nombre de messages que le serveur connaît : la différence avec ce
  /// qu'on a déjà chargé dit s'il reste des pages plus anciennes.
  Future<({List<DirectMessage> items, int total})> getConversationPage(
    int contactUserId, {
    int skip = 0,
    int limit = kHistoryPageSize,
  }) async {
    final response = await _api.get(
      '/messages/$contactUserId?skip=$skip&limit=$limit',
    );
    final items = (response['items'] as List).cast<Map<String, dynamic>>();
    return (
      items: await _resolveEncrypted(
        items.map(DirectMessage.fromJson).toList(),
        contactUserId,
      ),
      total: response['total'] as int? ?? items.length,
    );
  }

  /// Chiffre, ou refuse — et le refus est une EXCEPTION, pas un retour.
  ///
  /// Tout le dispositif tient à cette fonction. L'ancienne version laissait
  /// chaque appelant décider quoi faire de champs nuls, et tous ont fait le
  /// même choix : envoyer en clair. Ici il n'y a rien à décider. Une seule
  /// issue laisse passer du clair, et elle est nommée.
  ///
  /// `_e2ee` nul signifie que le service n'est pas monté (tests, ancienne
  /// configuration) : on retombe alors sur le comportement d'avant le
  /// chiffrement, ce qui est différent d'un chiffrement qui échoue.
  Future<SealOutcome> _sealOrRefuse(int recipientId, String plaintext) async {
    final service = _e2ee;
    if (service == null) return const SealPeerHasNoKeys();

    final outcome = await service.seal(
      peerUserId: recipientId,
      plaintext: plaintext,
    );
    return switch (outcome) {
      SealRefused(:final reason) => throw EncryptionUnavailableException(
        reason,
      ),
      // Le clair ne part que sur un 404 — une réponse du serveur, pas une
      // panne. L'écran affiche la conversation comme non chiffrée.
      SealPeerHasNoKeys() || SealEncrypted() => outcome,
    };
  }

  /// `recipientPhone` accompagne le PREMIER message vers quelqu'un qui n'est
  /// pas dans le carnet : c'est la preuve qu'on le désigne au lieu de deviner
  /// son identifiant (voir `_require_reachable` côté API). Inutile ensuite.
  Future<DirectMessage> send({
    required int recipientId,
    required String content,
    String? recipientPhone,
    String? replyToId,
  }) async {
    // Si Pokou ne peut pas garantir le chiffrement, Pokou n'envoie pas le
    // message — voir _sealOrRefuse, qui lève plutôt que de dégrader.
    final sealed = await _sealOrRefuse(recipientId, content);
    final encrypted = sealed is SealEncrypted;

    final response = await _api.post(
      '/messages',
      body: {
        'recipient_id': recipientId,
        // Jamais les deux : envoyer aussi le clair « au cas où » annulerait
        // tout, et le serveur le jetterait de toute façon.
        'content': encrypted ? null : content,
        'encryption': ?(sealed is SealEncrypted ? sealed.encryption : null),
        'ciphertext': ?(sealed is SealEncrypted ? sealed.ciphertext : null),
        'envelope': ?(sealed is SealEncrypted ? sealed.envelope : null),
        'recipient_phone': ?recipientPhone,
        'reply_to_id': ?replyToId,
      },
    );

    final saved = DirectMessage.fromJson(response as Map<String, dynamic>);
    // La réponse du serveur ne peut pas contenir le clair — il ne l'a
    // jamais eu. On le remet côté client pour que l'expéditeur voie son
    // propre message, sans aller-retour de déchiffrement inutile.
    return encrypted
        ? saved.copyWith(content: content, clearCiphertext: true)
        : saved;
  }

  /// [mediaKey] : le fichier a été chiffré avant le téléversement (voir
  /// MediaSender). Sa clé — avec la légende, le nom et le type — part alors
  /// scellée de bout en bout, et rien d'autre ne voyage en clair.
  ///
  /// Si le scellement n'est pas possible, on lève : envoyer la clé en clair
  /// à côté du bloc reviendrait à ne rien chiffrer du tout.
  Future<DirectMessage> sendMedia({
    required int recipientId,
    String? recipientPhone,
    required String messageType,
    required int mediaAssetId,
    String? caption,
    bool viewOnce = false,
    MediaKey? mediaKey,
  }) async {
    if (mediaKey != null) {
      final sealed = await _sealOrRefuse(recipientId, mediaKey.seal());
      if (sealed is! SealEncrypted) {
        // Le correspondant avait déclaré savoir ouvrir une pièce jointe, et
        // n'a plus de trousseau : on ne sait pas lui faire parvenir la clé.
        throw const EncryptionUnavailableException(SealFailure.keyLookupFailed);
      }
      final response = await _api.post(
        '/messages',
        body: {
          'recipient_id': recipientId,
          'recipient_phone': ?recipientPhone,
          'message_type': messageType,
          'media_asset_id': mediaAssetId,
          'encryption': sealed.encryption,
          'ciphertext': sealed.ciphertext,
          'envelope': sealed.envelope,
          if (viewOnce) 'view_once': true,
        },
      );
      final saved = DirectMessage.fromJson(response as Map<String, dynamic>);
      // Comme pour un texte : le serveur ne renvoie que le chiffré, on remet
      // la clé côté expéditeur pour qu'il revoie sa propre photo.
      return saved.copyWith(
        content: mediaKey.caption,
        mediaKey: mediaKey,
        media: mediaKey.toMeta(mediaAssetId),
        clearCiphertext: true,
      );
    }

    final response = await _api.post(
      '/messages',
      body: {
        'recipient_id': recipientId,
        'recipient_phone': ?recipientPhone,
        'message_type': messageType,
        'media_asset_id': mediaAssetId,
        if (caption != null && caption.trim().isNotEmpty) 'content': caption,
        // Le serveur refuse ce drapeau sur les types qui ne s'y prêtent pas
        // (voir VIEW_ONCE_TYPES dans routes/messages.py) : c'est lui qui
        // fait foi, l'écran ne fait que proposer.
        if (viewOnce) 'view_once': true,
      },
    );
    return DirectMessage.fromJson(response as Map<String, dynamic>);
  }

  /// Modifie le texte d'un message déjà envoyé.
  ///
  /// La route existait côté serveur depuis le début ; rien dans
  /// l'application ne l'appelait. Le serveur refuse au-delà de la fenêtre —
  /// voir `app/utils/editing.py` — et c'est lui qui fait foi : l'horloge du
  /// téléphone peut être fausse, et l'écran ne masque le bouton que par
  /// courtoisie.
  ///
  /// Quand la conversation est chiffrée, il faut RE-chiffrer : le serveur ne
  /// peut pas produire le nouveau texte, il ne détient aucune clé.
  Future<DirectMessage> edit({
    required String messageId,
    required int recipientId,
    required String content,
  }) async {
    // Même règle qu'à l'envoi : une correction qu'on ne peut pas chiffrer ne
    // part pas. Elle partirait sinon en clair PAR-DESSUS un message chiffré,
    // ce qui est le pire des deux mondes.
    final sealed = await _sealOrRefuse(recipientId, content);
    final encrypted = sealed is SealEncrypted;

    final response = await _api.patch(
      '/messages/$messageId',
      body: {
        'content': encrypted ? '' : content,
        'ciphertext': ?(sealed is SealEncrypted ? sealed.ciphertext : null),
        'envelope': ?(sealed is SealEncrypted ? sealed.envelope : null),
      },
    );

    final saved = DirectMessage.fromJson(response as Map<String, dynamic>);
    // Le serveur ne renvoie pas le clair — il ne l'a jamais eu. On le repose
    // côté client pour que l'auteur voie sa propre correction.
    return encrypted
        ? saved.copyWith(content: content, clearCiphertext: true)
        : saved;
  }

  /// Fait avancer une commande dans la conversation.
  ///
  /// Route dédiée, et non un message texte portant un préfixe convenu :
  /// le serveur vérifie que l'expéditeur est bien le VENDEUR du produit.
  /// L'ancienne version envoyait « [POKOU_ORDER] … » comme un message
  /// ordinaire — n'importe qui pouvait le taper et falsifier le suivi.
  ///
  /// Jamais chiffré, et c'est voulu : l'état vit dans `payload`, une colonne
  /// de métadonnées. Le destinataire le lit sans rien déchiffrer, là où le
  /// marqueur textuel produisait une bulle vide dès que le déchiffrement
  /// échouait.
  Future<DirectMessage> sendOrderUpdate({
    required int recipientId,
    required int productId,
    required String status,
  }) async {
    final response = await _api.post(
      '/messages/order-update',
      body: {
        'recipient_id': recipientId,
        'product_id': productId,
        'status': status,
      },
    );
    return DirectMessage.fromJson(response as Map<String, dynamic>);
  }

  Future<void> markRead(String messageId) =>
      _api.post('/messages/$messageId/read', body: const {});

  Future<DirectMessage> forward({
    required String messageId,
    required int recipientId,
  }) async {
    final response = await _api.post(
      '/messages/$messageId/forward',
      body: {'recipient_id': recipientId},
    );
    return DirectMessage.fromJson(response as Map<String, dynamic>);
  }

  /// Vrai si le serveur l'a GARDÉ, barré, parce que la discussion est en
  /// mode preuve.
  Future<bool> delete(String messageId) async {
    final json = await _api.delete('/messages/$messageId');
    return json is Map && json['kept_as_proof'] == true;
  }

  // ── Mode preuve à deux ──────────────────────────────────────────────────

  Future<DirectProofMode> proofMode(int contactUserId) async =>
      DirectProofMode.fromJson(
        await _api.get('/messages/$contactUserId/proof-mode')
            as Map<String, dynamic>,
      );

  Future<DirectProofMode> setProofMode(int contactUserId, bool enabled) async =>
      DirectProofMode.fromJson(
        await _api.put(
              '/messages/$contactUserId/proof-mode',
              body: {'enabled': enabled},
            )
            as Map<String, dynamic>,
      );

  /// Pose OU remplace sa réaction (une seule par personne et par message,
  /// voir api/app/routes/messages.py::set_reaction) — le sélecteur rapide
  /// rappelle cette méthode à chaque tap, sans se soucier de savoir si une
  /// réaction existait déjà.
  Future<DirectMessage> setReaction({
    required String messageId,
    required String emoji,
  }) async {
    final response = await _api.put(
      '/messages/$messageId/reaction',
      body: {'emoji': emoji},
    );
    return DirectMessage.fromJson(response as Map<String, dynamic>);
  }

  Future<DirectMessage> removeReaction(String messageId) async {
    final response = await _api.delete('/messages/$messageId/reaction');
    return DirectMessage.fromJson(response as Map<String, dynamic>);
  }

  /// Consomme un média à vue unique — n'a de sens que côté DESTINATAIRE (voir
  /// api/app/routes/messages.py::mark_view_once_viewed).
  Future<DirectMessage> markViewOnceViewed(String messageId) async {
    final response = await _api.post(
      '/messages/$messageId/viewed',
      body: const {},
    );
    return DirectMessage.fromJson(response as Map<String, dynamic>);
  }

  /// Vote (ou change de vote) sur un sondage — même route qu'il soit attaché
  /// à un message 1:1 ou de groupe (voir api/app/routes/polls.py::vote),
  /// `optionIds` remplace l'ensemble du vote plutôt que de l'incrémenter.
  Future<PollData> votePoll({
    required String pollId,
    required List<int> optionIds,
  }) async {
    final response = await _api.post(
      '/polls/$pollId/vote',
      body: {'option_ids': optionIds},
    );
    return PollData.fromJson(response as Map<String, dynamic>);
  }

  /// Un numéro touché (texte libre ou carte de visite) sans vouloir
  /// forcément l'ajouter au carnet — voir
  /// api/app/routes/contacts.py::lookup_phone, qui ne crée rien.
  Future<PhoneLookupResult> lookupPhone(String phone) async {
    final response = await _api.get(
      '/contacts/lookup?phone=${Uri.encodeQueryComponent(phone)}',
    );
    return PhoneLookupResult.fromJson(response as Map<String, dynamic>);
  }
}

/// Résultat de `GET /contacts/lookup` — ce qu'on sait d'un numéro touché
/// avant de décider quoi faire (ouvrir la conversation, ou proposer
/// d'inviter par WhatsApp).
class PhoneLookupResult {
  const PhoneLookupResult({
    required this.phone,
    required this.registered,
    this.userId,
    this.displayName,
  });

  final String phone;
  final bool registered;
  final int? userId;
  final String? displayName;

  factory PhoneLookupResult.fromJson(Map<String, dynamic> json) =>
      PhoneLookupResult(
        phone: json['phone'] as String,
        registered: json['registered'] as bool? ?? false,
        userId: json['user_id'] as int?,
        displayName: json['display_name'] as String?,
      );
}
