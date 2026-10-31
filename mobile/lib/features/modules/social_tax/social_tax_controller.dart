import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'social_tax_model.dart';
import 'social_tax_repository.dart';

final socialTaxRepositoryProvider = Provider<SocialTaxRepository>((ref) {
  return SocialTaxRepository(apiClient: ref.watch(apiClientProvider));
});

final ceremonyFundsProvider = FutureProvider.autoDispose<List<CeremonyFund>>((
  ref,
) {
  return ref.watch(socialTaxRepositoryProvider).funds();
});

final ceremonyFundProvider = FutureProvider.autoDispose
    .family<CeremonyFund, int>((ref, fundId) {
      return ref.watch(socialTaxRepositoryProvider).fund(fundId);
    });
