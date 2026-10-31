import 'dart:async';

import '../api/api_exceptions.dart';
import '../storage/pokou_message_store.dart';

/// Emits the cached list immediately, then refreshes it from the server.
///
/// Le principe est celui déjà appliqué à l'écran d'accueil : on garde la
/// dernière réponse du serveur TELLE QUELLE — le JSON brut, pas les objets
/// reconstruits — et on la ressert quand la requête échoue faute de réseau.
/// Le JSON brut parce que c'est le serveur qui compose et trie ces listes :
/// les reconstruire côté client donnerait un ordre différent de celui qu'on
/// avait sous les yeux la veille.
///
/// The last known value stays visible while the network refresh runs.
///
/// Trois règles, et elles comptent :
///
/// - seule une `NetworkException` déclenche le repli. Un 403 ou un 500 est
///   une réponse du serveur, pas une absence de réseau ; resservir du cache
///   dessus masquerait une vraie panne.
/// - sans cache, l'erreur remonte inchangée. « Je ne sais pas » et « vous
///   n'avez rien » demandent deux écrans différents, et c'est à l'écran de
///   trancher, pas à cette fonction.
/// - l'écriture du cache n'est pas attendue : elle ne doit pas retarder
///   l'affichage d'une liste déjà reçue.
Stream<List<T>> offlineList<T>({
  required PokouMessageStore store,
  required String scope,
  required Future<List<dynamic>> Function() fetch,
  required T Function(Map<String, dynamic>) parse,
}) async* {
  final cached = await store.cachedConversations(scope);
  if (cached != null) {
    yield cached.cast<Map<String, dynamic>>().map(parse).toList();
  }

  try {
    final items = await fetch();
    unawaited(store.saveConversations(scope, items));
    yield items.cast<Map<String, dynamic>>().map(parse).toList();
  } on NetworkException {
    if (cached == null) rethrow;
  } on ApiException catch (error) {
    if (cached == null || error.statusCode < 500) rethrow;
  }
}
