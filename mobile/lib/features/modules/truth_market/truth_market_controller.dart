import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'truth_market_model.dart';
import 'truth_market_repository.dart';

final truthMarketRepositoryProvider = Provider<TruthMarketRepository>((ref) {
  return TruthMarketRepository(apiClient: ref.watch(apiClientProvider));
});

final truthReceivedProvider = FutureProvider.autoDispose<List<TruthQuestion>>((
  ref,
) {
  return ref.watch(truthMarketRepositoryProvider).received();
});

final truthSentProvider = FutureProvider.autoDispose<List<TruthQuestion>>((
  ref,
) {
  return ref.watch(truthMarketRepositoryProvider).sent();
});
