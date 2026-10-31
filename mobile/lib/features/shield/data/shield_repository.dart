import '../../../core/api/api_client.dart';

/// Pokou — Mode Bouclier. Voir app/routes/shield.py côté API. Aucune
/// réponse n'est mise en cache ici — chaque appel reflète l'état courant.
class ShieldRepository {
  ShieldRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<int> evaluateContext(List<String> recentRedactedMessages) async {
    final response = await _api.post(
      '/shield/context',
      body: {'recent_messages': recentRedactedMessages},
    );
    return response['focus_score'] as int;
  }

  Future<String> evaluateEvent({
    required int contextScore,
    required String eventType, // call | message
    String? senderTag,
    String? hashedText,
    required bool senderKnown,
    int? groupSize,
    int? senderMessageCountLastMinute,
  }) async {
    final response = await _api.post(
      '/shield/evaluate',
      body: {
        'context_score': contextScore,
        'event_type': eventType,
        if (senderTag != null) 'sender_tag': senderTag,
        if (hashedText != null) 'hashed_text': hashedText,
        'sender_known': senderKnown,
        if (groupSize != null) 'group_size': groupSize,
        if (senderMessageCountLastMinute != null)
          'sender_message_count_last_minute': senderMessageCountLastMinute,
      },
    );
    return response['decision'] as String;
  }
}
