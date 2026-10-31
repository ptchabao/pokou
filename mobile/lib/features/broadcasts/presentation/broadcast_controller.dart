import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/broadcast_model.dart';
import '../data/broadcast_repository.dart';

final broadcastRepositoryProvider = Provider<BroadcastRepository>((ref) {
  return BroadcastRepository(apiClient: ref.watch(apiClientProvider));
});

final broadcastListsProvider = FutureProvider.autoDispose<List<BroadcastList>>((
  ref,
) {
  return ref.watch(broadcastRepositoryProvider).list();
});

final broadcastMessagesProvider = FutureProvider.autoDispose
    .family<List<BroadcastSentMessage>, int>((ref, listId) {
      return ref.watch(broadcastRepositoryProvider).messages(listId);
    });
