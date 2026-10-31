import '../../../core/api/api_client.dart';

class UnreadMessagesDigest {
  const UnreadMessagesDigest({required this.contactName, required this.count});

  final String contactName;
  final int count;

  factory UnreadMessagesDigest.fromJson(Map<String, dynamic> json) =>
      UnreadMessagesDigest(
        contactName: json['contact_name'] as String,
        count: json['count'] as int,
      );
}

class MissedCallDigest {
  const MissedCallDigest({required this.contactName, required this.isVideo});

  final String contactName;
  final bool isVideo;

  factory MissedCallDigest.fromJson(Map<String, dynamic> json) =>
      MissedCallDigest(
        contactName: json['contact_name'] as String,
        isVideo: json['is_video'] as bool,
      );
}

/// Récap serveur de la journée — messages non lus, appels manqués, signaux
/// moniteurs. Ce que Mode Bouclier a mis en attente n'y figure pas : c'est
/// un état purement client (voir ShieldController.todayDeferredCount),
/// fusionné au texte du récap côté app plutôt que par le serveur.
class DailyDigest {
  const DailyDigest({
    required this.unreadMessages,
    required this.missedCalls,
    required this.monitorSignalsCount,
  });

  final List<UnreadMessagesDigest> unreadMessages;
  final List<MissedCallDigest> missedCalls;
  final int monitorSignalsCount;

  bool get isEmpty =>
      unreadMessages.isEmpty && missedCalls.isEmpty && monitorSignalsCount == 0;

  factory DailyDigest.fromJson(Map<String, dynamic> json) => DailyDigest(
    unreadMessages: (json['unread_messages'] as List)
        .cast<Map<String, dynamic>>()
        .map(UnreadMessagesDigest.fromJson)
        .toList(),
    missedCalls: (json['missed_calls'] as List)
        .cast<Map<String, dynamic>>()
        .map(MissedCallDigest.fromJson)
        .toList(),
    monitorSignalsCount: json['monitor_signals_count'] as int,
  );
}

class DailyDigestRepository {
  DailyDigestRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<DailyDigest> fetch() async {
    final response = await _api.get('/mahizu/daily-digest');
    return DailyDigest.fromJson(response as Map<String, dynamic>);
  }
}
