import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../providers.dart';

class PushRepository {
  PushRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<void> registerToken(String token) {
    return _api.post(
      '/devices/register',
      body: {
        'token': token,
        // La VRAIE plateforme : tout partait en « android », iPhone compris,
        // et le serveur lui envoyait des notifications au format Android.
        'platform': kIsWeb
            ? 'web'
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        // Cet appareil met lui-même en forme ses notifications de message
        // (une par conversation, avec le contenu) : le serveur lui envoie
        // des données au lieu d'une notification toute faite. Android
        // seulement — iOS limite les pushs de données en arrière-plan, et
        // une notification qui n'arrive pas vaut moins qu'une notification
        // sans contenu.
        if (defaultTargetPlatform == TargetPlatform.android)
          'capabilities': ['rich_message_push'],
      },
    );
  }
}

final pushRepositoryProvider = Provider<PushRepository>((ref) {
  return PushRepository(apiClient: ref.watch(apiClientProvider));
});
