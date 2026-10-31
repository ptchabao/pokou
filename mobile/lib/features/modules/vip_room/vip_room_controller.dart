import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'vip_room_model.dart';
import 'vip_room_repository.dart';

final vipRoomRepositoryProvider = Provider<VipRoomRepository>((ref) {
  return VipRoomRepository(apiClient: ref.watch(apiClientProvider));
});

final myVipRoomProvider = FutureProvider.autoDispose<VipRoom?>((ref) {
  return ref.watch(vipRoomRepositoryProvider).myRoom();
});

final openVipRoomsProvider = FutureProvider.autoDispose<List<VipRoom>>((ref) {
  return ref.watch(vipRoomRepositoryProvider).openRooms();
});

final myVipSubscriptionsProvider = FutureProvider.autoDispose<List<VipRoom>>((
  ref,
) {
  return ref.watch(vipRoomRepositoryProvider).mySubscriptions();
});

final vipRoomFeedProvider = FutureProvider.autoDispose.family<VipRoomFeed, int>(
  (ref, roomId) {
    return ref.watch(vipRoomRepositoryProvider).feed(roomId);
  },
);

final vipEarningsProvider = FutureProvider.autoDispose<VipEarnings>((ref) {
  return ref.watch(vipRoomRepositoryProvider).earnings();
});
