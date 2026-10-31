import '../../../core/api/api_client.dart';
import 'vip_room_model.dart';

class VipRoomRepository {
  VipRoomRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<VipRoom?> myRoom() async {
    final response = await _api.get('/vip/room/me');
    final room = (response as Map<String, dynamic>)['room'];
    if (room == null) return null;
    return VipRoom.fromJson(room as Map<String, dynamic>);
  }

  Future<List<VipRoom>> openRooms() => _rooms('/vip/rooms');

  Future<List<VipRoom>> mySubscriptions() => _rooms('/vip/subscriptions');

  Future<List<VipRoom>> _rooms(String path) async {
    final response = await _api.get(path);
    final items =
        (response as Map<String, dynamic>)['items'] as List? ?? const [];
    return items.cast<Map<String, dynamic>>().map(VipRoom.fromJson).toList();
  }

  Future<VipRoom> saveRoom({
    required String title,
    required String pitch,
    required int monthlyPrice,
    bool isOpen = true,
  }) async {
    final response = await _api.put(
      '/vip/room',
      body: {
        'title': title,
        'pitch': pitch,
        'monthly_price': monthlyPrice,
        'is_open': isOpen,
      },
    );
    return VipRoom.fromJson(response as Map<String, dynamic>);
  }

  Future<VipRoomFeed> feed(int roomId) async {
    final response = await _api.get('/vip/rooms/$roomId/posts');
    return VipRoomFeed.fromJson(response as Map<String, dynamic>);
  }

  Future<String?> subscribe(int roomId) async {
    final response = await _api.post(
      '/vip/rooms/$roomId/subscribe',
      body: const {},
    );
    return (response as Map<String, dynamic>)['payment_url'] as String?;
  }

  Future<void> publish({String? text, int? mediaAssetId}) async {
    await _api.post(
      '/vip/posts',
      body: {
        if (text != null && text.isNotEmpty) 'text_content': text,
        'media_asset_id': ?mediaAssetId,
      },
    );
  }

  Future<VipEarnings> earnings() async {
    final response = await _api.get('/vip/earnings');
    return VipEarnings.fromJson(response as Map<String, dynamic>);
  }
}
