import '../../../core/api/api_client.dart';
import '../../../core/crypto/e2ee_outcome.dart';
import '../../../core/crypto/media_cipher.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../../core/sync/queued_mutation.dart';
import 'status_model.dart';
import 'status_text_style.dart';

abstract interface class StatusCrypto {
  Future<SealOutcome> seal({
    required int peerUserId,
    required String plaintext,
  });

  Future<String> open({
    required int peerUserId,
    required Map<String, dynamic> envelope,
    required String ciphertext,
  });

  Future<Set<String>> capabilitiesOf(int peerUserId);
}

class StatusRepository {
  StatusRepository({
    required ApiClient apiClient,
    required StatusCrypto crypto,
    required PokouMessageStore store,
    required MutationQueue mutations,
  }) : _api = apiClient,
       _crypto = crypto,
       _store = store,
       _mutations = mutations;

  final ApiClient _api;
  final StatusCrypto _crypto;
  final PokouMessageStore _store;
  final MutationQueue _mutations;

  static const _feedCache = 'status_feed';
  static const _ownedCache = 'status_owned';
  static const _mediaCapability = 'media-v1';

  /// Ratchet-backed envelopes are opened once. Concurrent feed refreshes share
  /// the same operation; the opened result is persisted in the SQLCipher cache.
  static final Map<String, Future<Map<String, dynamic>>> _opening = {};

  Future<List<dynamic>> getFeedRaw() async {
    final response = await _api.get('/status/feed');
    final items = (response['items'] as List).cast<Map<String, dynamic>>();
    final cached = await _store.cachedConversations(_feedCache);
    final localStatuses = _statusMap(cached ?? const []);
    final owned = await _store.cachedConversations(_ownedCache) ?? const [];
    localStatuses.addAll(_statusMap(owned));

    final resolved = <Map<String, dynamic>>[];
    for (final item in items) {
      final group = Map<String, dynamic>.from(item);
      final statuses = (item['statuses'] as List).cast<Map<String, dynamic>>();
      group['statuses'] = [
        for (final status in statuses)
          await _resolveStatus(
            Map<String, dynamic>.from(status),
            localStatuses[status['id'] as String],
          ),
      ];
      resolved.add(group);
    }

    _mergeOwnedStatuses(resolved, owned);
    await _store.saveConversations(_feedCache, resolved);
    return resolved;
  }

  Future<List<StatusFeedItem>> getFeed() async => (await getFeedRaw())
      .cast<Map<String, dynamic>>()
      .map(parseFeedItem)
      .toList();

  StatusFeedItem parseFeedItem(Map<String, dynamic> json) {
    for (final raw in (json['statuses'] as List).cast<Map<String, dynamic>>()) {
      final mediaJson = raw['status_media_key'];
      final mediaId = (raw['media'] as Map<String, dynamic>?)?['id'];
      if (mediaJson is Map && mediaId is int) {
        final key = MediaKey.tryFromJson(mediaJson);
        if (key != null && key.assetId == mediaId) {
          MediaKeyRing.remember(mediaId, key);
        }
      }
    }
    return StatusFeedItem.fromJson(json);
  }

  Future<PokouStatus> createText(
    String visibleText, {
    StatusTextStyle style = StatusTextStyle.plain,
  }) async {
    if (visibleText.runes.length > 700) {
      throw const FormatException('Le statut est limité à 700 caractères');
    }
    // Le fond et la police partent DANS le chiffré (voir StatusTextStyle).
    final text = StatusTextStyle.encode(style, visibleText);
    final recipients = await _sealForAudience(text);
    final response = await _api.post(
      '/status',
      body: {'content_type': 'TEXT', 'recipients': recipients},
    );
    final raw = Map<String, dynamic>.from(response as Map);
    raw['text_content'] = text;
    raw['status_resolved'] = true;
    final status = PokouStatus.fromJson(raw);
    await _cacheOwned(status, raw);
    return status;
  }

  Future<PokouStatus> createMedia({
    required String contentType,
    required int mediaAssetId,
    required MediaKey mediaKey,
  }) async {
    if (mediaKey.assetId != mediaAssetId) {
      throw const FormatException('Clé média liée à un autre fichier');
    }
    if ((mediaKey.caption?.runes.length ?? 0) > 700) {
      throw const FormatException('La légende est limitée à 700 caractères');
    }
    final recipients = await _sealForAudience(mediaKey.seal(), media: true);
    final response = await _api.post(
      '/status',
      body: {
        'content_type': contentType,
        'media_asset_id': mediaAssetId,
        'recipients': recipients,
      },
    );
    final raw = Map<String, dynamic>.from(response as Map);
    raw['text_content'] = mediaKey.caption;
    raw['media'] = mediaKey.toMeta(mediaAssetId).toJson();
    raw['status_media_key'] = mediaKey.toJson();
    raw['status_resolved'] = true;
    MediaKeyRing.remember(mediaAssetId, mediaKey);
    final status = PokouStatus.fromJson(raw);
    await _cacheOwned(status, raw);
    return status;
  }

  Future<List<Map<String, dynamic>>> _sealForAudience(
    String plaintext, {
    bool media = false,
  }) async {
    final response = await _api.get('/status/audience');
    final rawIds = response['recipient_ids'];
    if (rawIds is! List || rawIds.any((id) => id is! int)) {
      throw const FormatException('Audience de statut illisible');
    }
    final recipientIds = rawIds.cast<int>().toSet().toList()..sort();
    final sealed = <Map<String, dynamic>>[];
    for (final userId in recipientIds) {
      if (media &&
          !(await _crypto.capabilitiesOf(userId)).contains(_mediaCapability)) {
        throw const EncryptionUnavailableException(SealFailure.keyLookupFailed);
      }
      final outcome = await _crypto.seal(
        peerUserId: userId,
        plaintext: plaintext,
      );
      switch (outcome) {
        case SealEncrypted():
          sealed.add({
            'user_id': userId,
            'encryption': outcome.encryption,
            'ciphertext': outcome.ciphertext,
            'envelope': outcome.envelope,
          });
        case SealPeerHasNoKeys():
          throw const EncryptionUnavailableException(
            SealFailure.keyLookupFailed,
          );
        case SealRefused(:final reason):
          throw EncryptionUnavailableException(reason);
      }
    }
    return sealed;
  }

  Future<Map<String, dynamic>> _resolveStatus(
    Map<String, dynamic> incoming,
    Map<String, dynamic>? cached,
  ) async {
    if (cached?['status_resolved'] == true) {
      final resolved = cached!;
      return {
        ...incoming,
        'text_content': resolved['text_content'],
        'media': resolved['media'],
        'status_media_key': resolved['status_media_key'],
        'status_resolved': true,
        'status_unavailable': false,
      };
    }

    final encrypted = incoming['encrypted_content'];
    if (encrypted is! Map ||
        encrypted['ciphertext'] is! String ||
        encrypted['envelope'] is! Map ||
        incoming['user_id'] is! int) {
      return {...incoming, 'status_unavailable': true};
    }
    final id = incoming['id'] as String;
    final existing = _opening[id];
    if (existing != null) return existing;

    final future = _openStatus(incoming, encrypted);
    _opening[id] = future;
    try {
      final resolved = await future;
      if (resolved['status_resolved'] == true) {
        await _persistOpenedStatus(resolved);
      }
      return resolved;
    } finally {
      if (identical(_opening[id], future)) _opening.remove(id);
    }
  }

  Future<Map<String, dynamic>> _openStatus(
    Map<String, dynamic> incoming,
    Map encrypted,
  ) async {
    try {
      final plaintext = await _crypto.open(
        peerUserId: incoming['user_id'] as int,
        envelope: Map<String, dynamic>.from(encrypted['envelope'] as Map),
        ciphertext: encrypted['ciphertext'] as String,
      );
      final media = incoming['media'] as Map<String, dynamic>?;
      if (media == null) {
        if (incoming['content_type'] != 'TEXT' || plaintext.trim().isEmpty) {
          throw const FormatException('Contenu de statut invalide');
        }
        return {
          ...incoming,
          'text_content': plaintext,
          'status_resolved': true,
          'status_unavailable': false,
          'encrypted_content': null,
        };
      }

      final key = MediaKey.tryParse(plaintext);
      if (key == null || key.assetId != media['id']) {
        throw const FormatException('Clé de média absente ou incorrecte');
      }
      MediaKeyRing.remember(media['id'] as int, key);
      return {
        ...incoming,
        'text_content': key.caption,
        'media': key.toMeta(media['id'] as int).toJson(),
        'status_media_key': key.toJson(),
        'status_resolved': true,
        'status_unavailable': false,
        'encrypted_content': null,
      };
    } catch (_) {
      return {
        ...incoming,
        'text_content': null,
        'media': null,
        'status_unavailable': true,
      };
    }
  }

  Map<String, Map<String, dynamic>> _statusMap(List<dynamic> groups) {
    final found = <String, Map<String, dynamic>>{};
    for (final rawGroup in groups) {
      if (rawGroup is! Map) continue;
      final rawStatuses = rawGroup['statuses'];
      if (rawStatuses is! List) continue;
      for (final raw in rawStatuses) {
        if (raw is Map && raw['id'] is String) {
          found[raw['id'] as String] = Map<String, dynamic>.from(raw);
        }
      }
    }
    for (final raw in groups) {
      if (raw is Map && raw['id'] is String) {
        found[raw['id'] as String] = Map<String, dynamic>.from(raw);
      }
    }
    return found;
  }

  Future<void> _persistOpenedStatus(Map<String, dynamic> status) async {
    final cached = await _store.cachedConversations(_feedCache);
    final groups = (cached ?? const [])
        .whereType<Map>()
        .map((group) => Map<String, dynamic>.from(group))
        .toList();
    final authorId = status['user_id'] as int;
    final index = groups.indexWhere((group) => group['user_id'] == authorId);
    if (index < 0) {
      groups.add({
        'user_id': authorId,
        'display_name': '',
        'statuses': [status],
      });
    } else {
      final group = groups[index];
      final statuses = (group['statuses'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final statusIndex = statuses.indexWhere(
        (item) => item['id'] == status['id'],
      );
      if (statusIndex < 0) {
        statuses.add(status);
      } else {
        statuses[statusIndex] = status;
      }
      group['statuses'] = statuses;
    }
    await _store.saveConversations(_feedCache, groups);
  }

  void _mergeOwnedStatuses(
    List<Map<String, dynamic>> groups,
    List<dynamic> owned,
  ) {
    final validOwned = [
      for (final raw in owned)
        if (raw is Map &&
            DateTime.tryParse(
                  raw['expires_at'] as String? ?? '',
                )?.isAfter(DateTime.now()) ==
                true)
          Map<String, dynamic>.from(raw),
    ];
    if (validOwned.isEmpty) return;
    for (final status in validOwned) {
      final userId = status['user_id'] as int;
      final group = groups.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['user_id'] == userId,
        orElse: () => null,
      );
      if (group == null) {
        groups.add({
          'user_id': userId,
          'display_name': '',
          'statuses': [status],
        });
        continue;
      }
      final statuses = (group['statuses'] as List).cast<Map<String, dynamic>>();
      final index = statuses.indexWhere((item) => item['id'] == status['id']);
      if (index < 0) {
        statuses.add(status);
      } else {
        statuses[index] = {
          ...statuses[index],
          'text_content': status['text_content'],
          'media': status['media'],
          'status_media_key': status['status_media_key'],
          'status_resolved': true,
          'status_unavailable': false,
        };
      }
    }
  }

  Future<void> _cacheOwned(
    PokouStatus status,
    Map<String, dynamic> resolved,
  ) async {
    final cached = await _store.cachedConversations(_ownedCache) ?? [];
    final updated = [
      for (final row in cached)
        if (row is! Map || row['id'] != status.id) row,
      resolved,
    ];
    await _store.saveConversations(_ownedCache, updated);
    await _store.updateCachedConversations(_feedCache, (groups) {
      final copy = groups
          .whereType<Map>()
          .map((group) => Map<String, dynamic>.from(group))
          .toList();
      _mergeOwnedStatuses(copy, [resolved]);
      return copy;
    });
  }

  /// Idempotent côté API : une vue hors ligne est comptée à la reconnexion.
  Future<void> markViewed(String statusId) => _mutations.send(
    QueuedMutation(
      key: 'status:view:$statusId',
      method: 'POST',
      path: '/status/$statusId/view',
    ),
  );

  Future<void> delete(String statusId) async {
    await _api.delete('/status/$statusId');
    for (final scope in [_ownedCache, _feedCache]) {
      await _store.updateCachedConversations(scope, (items) {
        if (scope == _ownedCache) {
          return items
              .where((raw) => raw is! Map || raw['id'] != statusId)
              .toList();
        }
        return [
          for (final group in items.whereType<Map>())
            {
              ...Map<String, dynamic>.from(group),
              'statuses': (group['statuses'] as List? ?? const [])
                  .where((raw) => raw is! Map || raw['id'] != statusId)
                  .toList(),
            },
        ];
      });
    }
  }

  Future<Map<String, dynamic>> boost(String statusId) async {
    final response = await _api.post(
      '/marketplace/boost/status/$statusId',
      body: const {},
    );
    return (response as Map).cast<String, dynamic>();
  }

  Future<List<StatusViewer>> viewers(String statusId) async {
    final response = await _api.get('/status/$statusId/views');
    return (response['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(StatusViewer.fromJson)
        .toList();
  }

  Future<StatusPrivacy> getPrivacy() async {
    final response = await _api.get('/status/privacy');
    return StatusPrivacy.fromJson(response as Map<String, dynamic>);
  }

  Future<StatusPrivacy> setPrivacy({
    required StatusAudience audience,
    List<int> userIds = const [],
  }) async {
    final response = await _api.put(
      '/status/privacy',
      body: {
        'mode': audience.wire,
        'user_ids': audience.needsList ? userIds : const <int>[],
      },
    );
    return StatusPrivacy.fromJson(response as Map<String, dynamic>);
  }
}
