import '../../../core/api/api_client.dart';
import '../../../core/time/server_time.dart';

/// Un appareil = un jeton FCM enregistré côté serveur (voir
/// api/app/routes/devices.py). Il n'y a pas de sessions persistées dans
/// Pokou — les JWT sont autoportants — donc c'est la seule trace qu'un
/// appareil laisse, et `lastSeenAt` est la date de son dernier
/// (ré)enregistrement de jeton, pas sa dernière activité.
class PokouDevice {
  const PokouDevice({
    required this.id,
    required this.platform,
    required this.registeredAt,
    required this.lastSeenAt,
    required this.tokenHint,
    required this.isCurrent,
  });

  final int id;
  final String platform;
  final DateTime registeredAt;
  final DateTime lastSeenAt;
  final String tokenHint;
  final bool isCurrent;

  factory PokouDevice.fromJson(Map<String, dynamic> json) => PokouDevice(
    id: json['id'] as int,
    platform: json['platform'] as String,
    registeredAt: parseServerTime(json['registered_at'] as String),
    lastSeenAt: parseServerTime(json['last_seen_at'] as String),
    tokenHint: json['token_hint'] as String,
    isCurrent: json['is_current'] as bool? ?? false,
  );
}

class DevicesRepository {
  DevicesRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// `currentToken` : le jeton FCM de cet appareil, pour que le serveur nous
  /// dise laquelle des lignes est « cet appareil ». Comparaison côté serveur
  /// — on ne récupère jamais les jetons des autres appareils.
  Future<List<PokouDevice>> list({String? currentToken}) async {
    final query = currentToken == null
        ? ''
        : '?current_token=${Uri.encodeQueryComponent(currentToken)}';
    final response = await _api.get('/devices$query');
    final items = (response['items'] as List).cast<Map<String, dynamic>>();
    return items.map(PokouDevice.fromJson).toList();
  }

  Future<void> revoke(int deviceId) => _api.delete('/devices/$deviceId');
}
