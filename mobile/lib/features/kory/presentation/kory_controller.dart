import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../data/kory_model.dart';
import '../data/kory_repository.dart';

final koryRepositoryProvider = Provider<KoryRepository>((ref) {
  return KoryRepository(apiClient: ref.watch(apiClientProvider));
});

final koryPotsProvider = FutureProvider.autoDispose<List<KoryPot>>((ref) {
  return ref.watch(koryRepositoryProvider).pots();
});

final korySummaryProvider = FutureProvider.autoDispose<KorySummary>((ref) {
  return ref.watch(koryRepositoryProvider).summary();
});

final koryPotProvider = FutureProvider.autoDispose.family<KoryPot, int>((
  ref,
  potId,
) {
  return ref.watch(koryRepositoryProvider).pot(potId);
});

/// Relit tout ce qui affiche un total après une écriture.
void refreshKory(WidgetRef ref, {int? potId}) {
  ref.invalidate(koryPotsProvider);
  ref.invalidate(korySummaryProvider);
  if (potId != null) ref.invalidate(koryPotProvider(potId));
}

/// « 25 000 FCFA », avec l'espace fine insécable des formats français.
String formatFcfa(int amount) {
  final digits = NumberFormat.decimalPattern('fr').format(amount);
  return '$digits FCFA';
}
