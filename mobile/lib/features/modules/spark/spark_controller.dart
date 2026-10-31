import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'spark_model.dart';
import 'spark_repository.dart';

final sparkRepositoryProvider = Provider<SparkRepository>((ref) {
  return SparkRepository(apiClient: ref.watch(apiClientProvider));
});

final sparkProfileProvider = FutureProvider.autoDispose<SparkProfile?>((ref) {
  return ref.watch(sparkRepositoryProvider).myProfile();
});

final sparkIntentOptionsProvider =
    FutureProvider.autoDispose<List<SparkIntentOption>>((ref) {
      return ref.watch(sparkRepositoryProvider).intentOptions();
    });

final sparkIntentProvider = FutureProvider.autoDispose<SparkIntent?>((ref) {
  return ref.watch(sparkRepositoryProvider).currentIntent();
});

final sparkFeedProvider = FutureProvider.autoDispose<SparkFeed>((ref) {
  return ref.watch(sparkRepositoryProvider).feed();
});

final sparkMatchesProvider = FutureProvider.autoDispose<List<SparkMatch>>((
  ref,
) {
  return ref.watch(sparkRepositoryProvider).matches();
});

final sparkMatchProvider = FutureProvider.autoDispose.family<SparkMatch, int>((
  ref,
  matchId,
) {
  return ref.watch(sparkRepositoryProvider).match(matchId);
});

final sparkLikersProvider =
    FutureProvider.autoDispose<
      ({int count, bool locked, List<SparkCard> items})
    >((ref) {
      return ref.watch(sparkRepositoryProvider).likers();
    });

final sparkShopProvider = FutureProvider.autoDispose<SparkShop>((ref) {
  return ref.watch(sparkRepositoryProvider).shop();
});

final sparkPacksProvider = FutureProvider.autoDispose<List<SparkPack>>((ref) {
  return ref.watch(sparkRepositoryProvider).packs();
});

final sparkDatesProvider = FutureProvider.autoDispose<List<SparkDate>>((ref) {
  return ref.watch(sparkRepositoryProvider).dates();
});

final sparkSafetyContactsProvider =
    FutureProvider.autoDispose<List<SparkSafetyContact>>((ref) {
      return ref.watch(sparkRepositoryProvider).safetyContacts();
    });

/// Les vérifications « tout va bien ? » en attente.
///
/// Consultées à l'ouverture de l'écran, jamais par une tâche de fond : une
/// question dont l'existence dépend d'un ordonnanceur est une question qui ne
/// sera pas posée le jour où il tombe.
final sparkCheckinsProvider = FutureProvider.autoDispose<List<SparkCheckin>>((
  ref,
) {
  return ref.watch(sparkRepositoryProvider).pendingCheckins();
});

/// Les avis qu'on me demande.
///
/// Ne dépend pas de l'activation de Spark : on peut rendre ce service à un
/// ami sans y être soi-même, et c'est exactement par là que le module se
/// diffuse.
final wingmanRequestsProvider =
    FutureProvider.autoDispose<List<WingmanRequest>>((ref) {
      return ref.watch(sparkRepositoryProvider).wingmanRequests();
    });

final wingmanVerdictProvider = FutureProvider.autoDispose
    .family<WingmanVerdict, int>((ref, candidateId) {
      return ref.watch(sparkRepositoryProvider).wingmanVerdict(candidateId);
    });
