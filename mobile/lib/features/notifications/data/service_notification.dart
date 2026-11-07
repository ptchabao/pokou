import '../../../core/api/api_client.dart';
import '../../../core/time/server_time.dart';

/// Une notification de SERVICE (Kory, Honam, Assimé, Pokou certifié…) —
/// jamais un message : les discussions restent dans Discussions.
class ServiceNotification {
  const ServiceNotification({
    required this.id,
    required this.service,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.route,
  });

  final int id;
  final String service; // kory | honam | assime | certified | groups
  final String title;
  final String body;
  final String? route;
  final DateTime createdAt;
  final bool read;

  factory ServiceNotification.fromJson(Map<String, dynamic> json) =>
      ServiceNotification(
        id: json['id'] as int,
        service: json['service'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        route: json['route'] as String?,
        createdAt:
            tryParseServerTime(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        read: json['read'] as bool? ?? false,
      );
}

class ServiceNotificationsPage {
  const ServiceNotificationsPage({required this.items, required this.unread});

  final List<ServiceNotification> items;
  final int unread;
}

class ServiceNotificationsRepository {
  ServiceNotificationsRepository(this._api);

  final ApiClient _api;

  Future<ServiceNotificationsPage> list() async {
    final response = await _api.get('/notifications') as Map<String, dynamic>;
    return ServiceNotificationsPage(
      items: [
        for (final raw in (response['items'] as List? ?? const []))
          ServiceNotification.fromJson(raw as Map<String, dynamic>),
      ],
      unread: response['unread'] as int? ?? 0,
    );
  }

  Future<void> readAll() =>
      _api.post('/notifications/read-all', body: const {});

  Future<void> read(int id) =>
      _api.post('/notifications/$id/read', body: const {});
}
