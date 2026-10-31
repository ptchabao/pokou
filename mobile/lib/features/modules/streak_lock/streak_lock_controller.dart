import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'streak_lock_model.dart';
import 'streak_lock_repository.dart';

final streakLockRepositoryProvider = Provider<StreakLockRepository>((ref) {
  return StreakLockRepository(apiClient: ref.watch(apiClientProvider));
});

final streaksProvider = FutureProvider.autoDispose<List<Streak>>((ref) {
  return ref.watch(streakLockRepositoryProvider).streaks();
});
