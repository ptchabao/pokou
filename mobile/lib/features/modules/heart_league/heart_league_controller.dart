import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'heart_league_model.dart';
import 'heart_league_repository.dart';

final heartLeagueRepositoryProvider = Provider<HeartLeagueRepository>((ref) {
  return HeartLeagueRepository(apiClient: ref.watch(apiClientProvider));
});

final leagueStandingProvider = FutureProvider.autoDispose<LeagueStanding>((
  ref,
) {
  return ref.watch(heartLeagueRepositoryProvider).standing();
});

final leagueRankingProvider = FutureProvider.autoDispose<LeagueRanking>((ref) {
  return ref.watch(heartLeagueRepositoryProvider).ranking();
});
