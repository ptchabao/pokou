import '../../../core/api/api_client.dart';
import 'spark_model.dart';

/// L'accès à Spark. Aucune règle ici — elles vivent toutes côté serveur.
///
/// Aucune, et c'est délibéré : les quotas, le rayon, l'expiration des
/// intentions et le dénouement de la séquestre décident d'argent et de
/// rendez-vous physiques. Une règle appliquée des deux côtés finit toujours
/// par diverger, et c'est alors l'écran qui ment.
class SparkRepository {
  SparkRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ── La fiche ───────────────────────────────────────────────────────────

  Future<SparkProfile?> myProfile() async {
    final response = await _api.get('/spark/profile');
    final profile = (response as Map<String, dynamic>)['profile'];
    if (profile == null) return null;
    return SparkProfile.fromJson(profile as Map<String, dynamic>);
  }

  Future<SparkProfile> saveProfile({
    required String displayName,
    required String birthDate,
    required String gender,
    String? bio,
    bool isVisible = true,
  }) async {
    final response = await _api.put(
      '/spark/profile',
      body: {
        'display_name': displayName,
        'birth_date': birthDate,
        'gender': gender,
        'bio': ?bio,
        'is_visible': isVisible,
      },
    );
    return SparkProfile.fromJson(response as Map<String, dynamic>);
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    await _api.post(
      '/spark/profile/location',
      body: {'latitude': latitude, 'longitude': longitude},
    );
  }

  Future<List<SparkPhoto>> addPhoto(int mediaAssetId) async {
    final response = await _api.post(
      '/spark/photos',
      body: {'media_asset_id': mediaAssetId},
    );
    return ((response as Map<String, dynamic>)['photos'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkPhoto.fromJson)
        .toList();
  }

  Future<void> removePhoto(int photoId) async {
    await _api.delete('/spark/photos/$photoId');
  }

  // ── La Carte du Moment ─────────────────────────────────────────────────

  Future<List<SparkIntentOption>> intentOptions() async {
    final response = await _api.get('/spark/intents');
    return ((response as Map<String, dynamic>)['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkIntentOption.fromJson)
        .toList();
  }

  Future<SparkIntent?> currentIntent() async {
    final response = await _api.get('/spark/intent');
    final intent = (response as Map<String, dynamic>)['intent'];
    if (intent == null) return null;
    return SparkIntent.fromJson(intent as Map<String, dynamic>);
  }

  Future<SparkIntent> setIntent(String kind) async {
    final response = await _api.post('/spark/intent', body: {'kind': kind});
    return SparkIntent.fromJson(response as Map<String, dynamic>);
  }

  // ── Le flux ────────────────────────────────────────────────────────────

  Future<SparkFeed> feed() async {
    final response = await _api.get('/spark/feed');
    return SparkFeed.fromJson(response as Map<String, dynamic>);
  }

  /// Rend `matched` et, le cas échéant, l'identifiant du match ouvert.
  Future<({bool matched, int? matchId, int likesLeft})> like(int userId) async {
    final response = await _api.post(
      '/spark/like/$userId',
      body: {'kind': 'LIKE'},
    );
    final body = response as Map<String, dynamic>;
    return (
      matched: body['matched'] as bool? ?? false,
      matchId: body['match_id'] as int?,
      likesLeft: body['likes_left'] as int? ?? 0,
    );
  }

  /// Le Super Spark n'est PAS accordé ici : il ouvre un paiement, et le
  /// serveur ne le pose qu'à la confirmation.
  Future<String?> superSpark(int userId, int voiceMediaId) async {
    final response = await _api.post(
      '/spark/like/$userId',
      body: {'kind': 'SUPER', 'voice_media_id': voiceMediaId},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  Future<void> pass(int userId) async {
    await _api.post('/spark/pass/$userId', body: const {});
  }

  Future<({int count, bool locked, List<SparkCard> items})> likers() async {
    final response = await _api.get('/spark/likers');
    final body = response as Map<String, dynamic>;
    return (
      count: body['count'] as int? ?? 0,
      locked: body['locked'] as bool? ?? true,
      items: ((body['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(SparkCard.fromJson)
          .toList(),
    );
  }

  // ── La Salle d'Entrée ──────────────────────────────────────────────────

  Future<List<SparkMatch>> matches() async {
    final response = await _api.get('/spark/matches');
    return ((response as Map<String, dynamic>)['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkMatch.fromJson)
        .toList();
  }

  Future<SparkMatch> match(int matchId) async {
    final response = await _api.get('/spark/matches/$matchId');
    return SparkMatch.fromJson(response as Map<String, dynamic>);
  }

  Future<void> sendVoice(int matchId, int mediaAssetId) async {
    await _api.post(
      '/spark/matches/$matchId/messages',
      body: {'kind': 'VOICE', 'media_asset_id': mediaAssetId},
    );
  }

  Future<void> sendSticker(int matchId, String sticker) async {
    await _api.post(
      '/spark/matches/$matchId/messages',
      body: {'kind': 'STICKER', 'sticker': sticker},
    );
  }

  Future<SparkMatch> continueMatch(int matchId) async {
    final response = await _api.post(
      '/spark/matches/$matchId/continue',
      body: const {},
    );
    return SparkMatch.fromJson(response as Map<String, dynamic>);
  }

  Future<String?> extendRoom(int matchId) async {
    final response = await _api.post(
      '/spark/matches/$matchId/extend',
      body: const {},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  // ── Le Wingman ─────────────────────────────────────────────────────────

  Future<void> askWingmen(int candidateId, List<int> friendIds) async {
    await _api.post(
      '/spark/wingman/$candidateId',
      body: {'friend_ids': friendIds},
    );
  }

  Future<List<WingmanRequest>> wingmanRequests() async {
    final response = await _api.get('/spark/wingman/requests');
    return ((response as Map<String, dynamic>)['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(WingmanRequest.fromJson)
        .toList();
  }

  Future<void> castWingmanVote(int voteId, String vote) async {
    await _api.post('/spark/wingman/requests/$voteId', body: {'vote': vote});
  }

  Future<WingmanVerdict> wingmanVerdict(int candidateId) async {
    final response = await _api.get('/spark/wingman/$candidateId');
    return WingmanVerdict.fromJson(response as Map<String, dynamic>);
  }

  // ── L'économie ─────────────────────────────────────────────────────────

  Future<SparkShop> shop() async {
    final response = await _api.get('/spark/shop');
    return SparkShop.fromJson(response as Map<String, dynamic>);
  }

  Future<String?> buyLikes(int size) async {
    final response = await _api.post(
      '/spark/likes/purchase',
      body: {'size': size},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  Future<String?> subscribePlus() => _payment('/spark/plus');

  Future<String?> unlockLikers() => _payment('/spark/see-likers');

  Future<String?> buyBoost() => _payment('/spark/boost');

  Future<String?> _payment(String path) async {
    final response = await _api.post(path, body: const {});
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  // ── Les rendez-vous ────────────────────────────────────────────────────

  Future<List<SparkPack>> packs({double? latitude, double? longitude}) async {
    final query = latitude != null && longitude != null
        ? '?latitude=$latitude&longitude=$longitude'
        : '';
    final response = await _api.get('/spark/packs$query');
    return ((response as Map<String, dynamic>)['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkPack.fromJson)
        .toList();
  }

  Future<({int dateId, String? paymentUrl})> bookDate({
    required int matchId,
    required int packId,
    required DateTime scheduledAt,
  }) async {
    final response = await _api.post(
      '/spark/dates',
      body: {
        'match_id': matchId,
        'pack_id': packId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      },
    );
    final body = response as Map<String, dynamic>;
    return (
      dateId: body['date_id'] as int? ?? 0,
      paymentUrl: body['payment_url'] as String?,
    );
  }

  Future<List<SparkDate>> dates() async {
    final response = await _api.get('/spark/dates');
    return ((response as Map<String, dynamic>)['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkDate.fromJson)
        .toList();
  }

  Future<SparkDate> date(int dateId) async {
    final response = await _api.get('/spark/dates/$dateId');
    return SparkDate.fromJson(response as Map<String, dynamic>);
  }

  Future<SparkDate> validateDate(int dateId) async {
    final response = await _api.post(
      '/spark/dates/$dateId/validate',
      body: const {},
    );
    return SparkDate.fromJson(response as Map<String, dynamic>);
  }

  Future<SparkDate> cancelDate(int dateId) async {
    final response = await _api.post(
      '/spark/dates/$dateId/cancel',
      body: const {},
    );
    return SparkDate.fromJson(response as Map<String, dynamic>);
  }

  Future<SparkDate> reportNoShow(int dateId, int absentUserId) async {
    final response = await _api.post(
      '/spark/dates/$dateId/no-show',
      body: {'absent_user_id': absentUserId},
    );
    return SparkDate.fromJson(response as Map<String, dynamic>);
  }

  // ── La sécurité ────────────────────────────────────────────────────────

  Future<List<SparkSafetyContact>> safetyContacts() async {
    final response = await _api.get('/spark/safety/contacts');
    return ((response as Map<String, dynamic>)['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkSafetyContact.fromJson)
        .toList();
  }

  Future<void> addSafetyContact(int userId) async {
    await _api.post(
      '/spark/safety/contacts',
      body: {'contact_user_id': userId},
    );
  }

  Future<void> removeSafetyContact(int contactId) async {
    await _api.delete('/spark/safety/contacts/$contactId');
  }

  /// Le Safe Word. **Ne lève jamais** : une erreur affichée au moment où
  /// quelqu'un déclenche discrètement une alerte le mettrait en danger.
  Future<int> triggerSafeWord({
    int? dateId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _api.post(
        '/spark/safety/alert',
        body: {
          'date_id': ?dateId,
          'latitude': ?latitude,
          'longitude': ?longitude,
        },
      );
      return (response as Map<String, dynamic>)['notified'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<SparkCheckin>> pendingCheckins() async {
    final response = await _api.get('/spark/safety/checkins');
    return ((response as Map<String, dynamic>)['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SparkCheckin.fromJson)
        .toList();
  }

  Future<void> answerCheckin(int checkinId) async {
    await _api.post('/spark/safety/checkins/$checkinId', body: const {});
  }
}
