import '../../../core/api/api_client.dart';
import '../../../core/sync/queued_mutation.dart';
import 'channel_model.dart';

class ChannelRepository {
  ChannelRepository({required ApiClient apiClient, MutationQueue? mutations})
    : _api = apiClient,
      _mutations = mutations ?? MutationQueue(api: apiClient);

  final ApiClient _api;

  /// Les réglages qui supportent d'attendre le réseau — voir
  /// core/sync/queued_mutation.dart.
  final MutationQueue _mutations;

  /// Voir contacts_repository.dart::listRaw.
  Future<List<dynamic>> listMineRaw() async {
    final response = await _api.get('/channels');
    return response['items'] as List;
  }

  Future<List<PokouChannel>> listMine() async => (await listMineRaw())
      .cast<Map<String, dynamic>>()
      .map(PokouChannel.fromJson)
      .toList();

  Future<PokouChannel> create({
    required String name,
    String? description,
    bool isPrivate = false,
  }) async {
    final response = await _api.post(
      '/channels',
      body: {
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description,
        'is_private': isPrivate,
      },
    );
    return PokouChannel.fromJson(response as Map<String, dynamic>);
  }

  Future<String> regenerateInviteLink(int channelId) async {
    final response = await _api.post(
      '/channels/$channelId/invite-link',
      body: const {},
    );
    return channelInviteLinkFor(response['invite_code'] as String);
  }

  /// Rejoint (s'abonne) via un lien d'invitation — voir DeepLinkService, qui
  /// appelle cette méthode directement au clic sur un lien `.../channel/{code}`
  /// ou `.../invite/channel/{code}`, sans étape manuelle intermédiaire.
  Future<PokouChannel> joinByInvite(String code) async {
    final response = await _api.post(
      '/channels/invite/$code/join',
      body: const {},
    );
    return PokouChannel.fromJson(response as Map<String, dynamic>);
  }

  // ─── Découverte et abonnement ─────────────────────────────────────────────

  /// Une chaîne est PUBLIQUE : on la trouve et on la lit sans y être abonné.
  Future<List<PokouChannel>> search(String query) async {
    final response = await _api.get(
      '/channels/search?q=${Uri.encodeQueryComponent(query)}',
    );
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(PokouChannel.fromJson)
        .toList();
  }

  /// Quelques chaînes à proposer à qui n'en suit aucune.
  ///
  /// Le serveur écarte celles qu'on suit déjà et les nôtres, et met les
  /// certifiées en tête — voir routes/channels.py::suggested_channels.
  Future<List<PokouChannel>> suggested({int limit = 6}) async {
    final response = await _api.get('/channels/suggested?limit=$limit');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(PokouChannel.fromJson)
        .toList();
  }

  /// Demande la certification de sa chaîne, contre un abonnement.
  ///
  /// Renvoie l'adresse de paiement Mobile Money. Payer n'accorde PAS le
  /// badge : l'équipe examine ensuite le dossier (voir
  /// routes/channels.py::request_certification).
  Future<String?> requestCertification(
    int channelId, {
    required String plan,
  }) async {
    final response = await _api.post(
      '/channels/$channelId/certification',
      body: {'plan': plan},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  Future<PokouChannel> follow(int channelId) async {
    final response = await _api.post(
      '/channels/$channelId/follow',
      body: const {},
    );
    return PokouChannel.fromJson(response as Map<String, dynamic>);
  }

  Future<PokouChannel> unfollow(int channelId) async {
    final response = await _api.delete('/channels/$channelId/follow');
    return PokouChannel.fromJson(response as Map<String, dynamic>);
  }

  /// Suivre ou ne plus suivre, depuis la chaîne elle-même — même hors
  /// ligne. Renvoie `null` quand le geste attend le réseau : l'écran montre
  /// alors l'état voulu, et la file le dira au serveur à la reconnexion.
  Future<PokouChannel?> setFollowing(int channelId, bool following) async {
    final result = await _mutations.send(
      QueuedMutation(
        key: 'channel:follow:$channelId',
        method: following ? 'POST' : 'DELETE',
        path: '/channels/$channelId/follow',
      ),
    );
    if (result.queued) return null;
    return PokouChannel.fromJson(result.response as Map<String, dynamic>);
  }

  // ─── Publications ─────────────────────────────────────────────────────────

  /// Le fil d'une chaîne, DANS L'ORDRE DU TEMPS : la plus ancienne d'abord,
  /// la plus récente en dernier.
  ///
  /// Le serveur, lui, renvoie les plus récentes d'abord — c'est ce qu'il
  /// faut pour prendre les cinquante dernières, et ça n'a rien à voir avec
  /// l'ordre de lecture. L'inversion est donc faite ICI, à la frontière avec
  /// l'API : l'écran affiche une liste, il n'a pas à connaître la clause
  /// `ORDER BY` qui l'a produite.
  ///
  /// Une chaîne se lit comme une conversation — on ouvre pour voir ce qui
  /// vient d'arriver, puis on remonte pour le contexte. À l'envers, chaque
  /// nouvelle publication tombait AU-DESSUS de celle qu'on venait de lire et
  /// les séparateurs de journée se suivaient à rebours.
  Future<List<ChannelPost>> posts(int channelId) async {
    final response = await _api.get('/channels/$channelId/posts');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(ChannelPost.fromJson)
        .toList()
        .reversed
        .toList();
  }

  /// Une publication porte un texte, une image, un sondage — ou plusieurs à
  /// la fois. Le serveur refuse les trois vides d'un coup.
  Future<ChannelPost> publish({
    required int channelId,
    String? textContent,
    int? mediaAssetId,
    String? pollQuestion,
    List<String> pollOptions = const [],
    bool pollAllowsMultiple = false,
  }) async {
    final response = await _api.post(
      '/channels/$channelId/posts',
      body: {
        if (textContent != null && textContent.trim().isNotEmpty)
          'text_content': textContent.trim(),
        if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
        if (pollQuestion != null && pollQuestion.trim().isNotEmpty)
          'poll': {
            'question': pollQuestion.trim(),
            // Options envoyées TELLES QUELLES, y compris les vides : c'est le
            // serveur qui les nettoie et compte les vraies réponses (voir
            // polls.py::_clean_options), pour que la borne « au moins deux »
            // n'existe qu'à un seul endroit.
            'options': pollOptions,
            'allows_multiple': pollAllowsMultiple,
          },
      },
    );
    return ChannelPost.fromJson(response as Map<String, dynamic>);
  }

  Future<ChannelPost> editPost({
    required int channelId,
    required String postId,
    required String textContent,
  }) async {
    final response = await _api.patch(
      '/channels/$channelId/posts/$postId',
      body: {'text_content': textContent},
    );
    return ChannelPost.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deletePost({required int channelId, required String postId}) =>
      _api.delete('/channels/$channelId/posts/$postId');

  /// Compteur de vues — idempotent par personne côté API, donc appelable
  /// sans précaution à l'affichage d'une publication.
  Future<void> markViewed({required int channelId, required String postId}) =>
      _mutations.send(
        QueuedMutation(
          key: 'channel:view:$postId',
          method: 'POST',
          path: '/channels/$channelId/posts/$postId/view',
        ),
      );

  /// Poser ou retirer sa réaction partagent la même clé : réagir puis se
  /// raviser hors ligne ne laisse partir que le dernier choix.
  ///
  /// Renvoie `true` quand le geste attend le réseau.
  Future<bool> react({
    required int channelId,
    required String postId,
    required String emoji,
  }) async => (await _mutations.send(
    QueuedMutation(
      key: 'channel:reaction:$postId',
      method: 'PUT',
      path: '/channels/$channelId/posts/$postId/reaction',
      body: {'emoji': emoji},
    ),
  )).queued;

  Future<bool> removeReaction({
    required int channelId,
    required String postId,
  }) async => (await _mutations.send(
    QueuedMutation(
      key: 'channel:reaction:$postId',
      method: 'DELETE',
      path: '/channels/$channelId/posts/$postId/reaction',
    ),
  )).queued;

  /// Met à jour la chaîne — nom, description, et son IMAGE. `clearAvatar`
  /// distingue « ne touche pas à l'image » de « retire-la ».
  Future<PokouChannel> updateChannel({
    required int channelId,
    String? name,
    String? description,
    int? avatarMediaId,
    bool clearAvatar = false,
  }) async {
    final response = await _api.patch(
      '/channels/$channelId',
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (avatarMediaId != null) 'avatar_media_id': avatarMediaId,
        if (clearAvatar) 'clear_avatar': true,
      },
    );
    return PokouChannel.fromJson(response as Map<String, dynamic>);
  }
}
