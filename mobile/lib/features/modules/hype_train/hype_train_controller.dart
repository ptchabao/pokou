import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'hype_train_model.dart';
import 'hype_train_repository.dart';

final hypeTrainRepositoryProvider = Provider<HypeTrainRepository>((ref) {
  return HypeTrainRepository(apiClient: ref.watch(apiClientProvider));
});

final liveHypeTrainsProvider = FutureProvider.autoDispose<List<HypeTrain>>((
  ref,
) {
  return ref.watch(hypeTrainRepositoryProvider).live();
});

final myHypeTrainsProvider = FutureProvider.autoDispose<List<HypeTrain>>((ref) {
  return ref.watch(hypeTrainRepositoryProvider).mine();
});

final hypeTrainDetailProvider = FutureProvider.autoDispose
    .family<HypeTrain, int>((ref, trainId) {
      return ref.watch(hypeTrainRepositoryProvider).detail(trainId);
    });
