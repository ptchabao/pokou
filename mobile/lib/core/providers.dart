import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'l10n/l10n_provider.dart';
import 'media/media_repository.dart';
import 'storage/secure_token_storage.dart';
import 'storage/pokou_message_store.dart';
import 'sync/queued_mutation.dart';
import 'ws/ws_client.dart';

/// App-wide singletons. Feature-specific repository providers (auth, inbox,
/// chat) depend on these rather than constructing their own instances.
final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) => SecureTokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(secureTokenStorageProvider),
    // Ses messages d'erreur remontent tels quels à l'écran : ils doivent
    // suivre la langue choisie, pas rester en français.
    l: ref.watch(appL10nProvider),
  );
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(apiClient: ref.watch(apiClientProvider));
});

/// Cache local des conversations — lu par les écrans de messagerie et vidé
/// par la file d'attente. Gardé en vie pour toute la durée de l'app : c'est
/// une connexion SQLite, pas un état d'écran.
final pokouMessageStoreProvider = Provider<PokouMessageStore>((ref) {
  final store = PokouMessageStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Les réglages qui partent à la reconnexion quand on est hors ligne — voir
/// core/sync/queued_mutation.dart. Vidée par `OutboxService`.
final mutationQueueProvider = Provider<MutationQueue>((ref) {
  return MutationQueue(
    api: ref.watch(apiClientProvider),
    store: ref.watch(pokouMessageStoreProvider),
  );
});

/// `wsClientProvider` is only meaningfully connected once a session exists —
/// `AuthController` calls `.connect()`/`dispose()` on login/logout. Kept
/// alive for the app's lifetime (not `.autoDispose`) so it survives screen
/// navigation.
final wsClientProvider = Provider<WsClient>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final wsUrl = apiClient.baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
  final client = WsClient(
    baseWsUrl: '$wsUrl/ws',
    tokenStorage: ref.watch(secureTokenStorageProvider),
    apiClient: apiClient,
  );
  ref.onDispose(client.dispose);
  return client;
});
