import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../storage/pokou_message_store.dart';

/// Un réglage posé sans réseau, qui partira tout seul à la reconnexion.
///
/// La file des messages (`OutboxService`) savait déjà rejouer un message et
/// quelques gestes de conversation. Tout le reste — suivre une chaîne,
/// épingler une discussion, compter une vue — échouait sur un « action
/// impossible » dès qu'on était hors ligne, alors que le geste était
/// parfaitement clair et qu'il suffisait de le dire au serveur plus tard.
///
/// Ce que cette file accepte, et ce qu'elle refuse :
///
/// - uniquement des requêtes IDEMPOTENTES par nature : un PUT d'état, un
///   DELETE, un POST que le serveur dédoublonne (une vue). Les rejouer deux
///   fois ne change rien, donc une réponse perdue en route n'est pas grave.
/// - jamais une création (publier, mettre en vente) ni un paiement : sans
///   clé d'idempotence côté serveur, un rejeu après une réponse perdue
///   créerait un doublon — ou ferait payer deux fois.
///
/// [key] désigne la CIBLE, pas le geste : `channel:follow:12`, et non
/// `channel:follow:12:true`. Deux intentions sur la même cible se
/// remplacent, et seule la dernière — celle que l'écran montre — part.
class QueuedMutation {
  const QueuedMutation({
    required this.key,
    required this.method,
    required this.path,
    this.body,
  });

  final String key;

  /// `PUT`, `POST`, `PATCH` ou `DELETE`.
  final String method;
  final String path;
  final Map<String, dynamic>? body;

  static const type = 'http';

  Map<String, dynamic> toPayload() => {
    'method': method,
    'path': path,
    if (body != null) 'body': body,
  };

  static QueuedMutation? fromOperation(SyncOutboxOperation operation) {
    if (operation.type != type) return null;
    final method = operation.payload['method'];
    final path = operation.payload['path'];
    if (method is! String || path is! String) return null;
    return QueuedMutation(
      key: operation.idempotencyRef,
      method: method,
      path: path,
      body: (operation.payload['body'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Future<dynamic> send(ApiClient api) => switch (method) {
    'PUT' => api.put(path, body: body ?? const {}),
    'POST' => api.post(path, body: body ?? const {}),
    'PATCH' => api.patch(path, body: body ?? const {}),
    'DELETE' => api.delete(path),
    _ => throw ArgumentError.value(method, 'method'),
  };
}

/// Envoie tout de suite si le réseau répond, met en file sinon.
///
/// Injecté dans les dépôts plutôt qu'appelé depuis les écrans : c'est le
/// dépôt qui connaît le chemin de l'API, et l'écran n'a pas à le répéter.
class MutationQueue {
  MutationQueue({required ApiClient api, PokouMessageStore? store})
    : _api = api,
      _store = store;

  final ApiClient _api;

  /// Absent (tests, dépôts construits à la main) : rien n'est mis en file,
  /// l'absence de réseau remonte comme avant.
  final PokouMessageStore? _store;

  /// `queued` dit si le geste attend dans la file ; sinon `response` porte
  /// la réponse du serveur, pour l'écran qui en a besoin. Seule l'ABSENCE de réseau met en file : un refus du serveur
  /// (4xx) ou une panne (5xx) remonte tel quel, comme avant, pour que
  /// l'écran dise ce qui ne va pas au lieu de promettre un envoi qui ne
  /// passera jamais.
  Future<({bool queued, dynamic response})> send(
    QueuedMutation mutation,
  ) async {
    final store = _store;
    final dynamic response;
    try {
      response = await mutation.send(_api);
    } on NetworkException {
      if (store == null) rethrow;
      await store.enqueueSyncOperation(
        operationId: store.newLocalId(),
        idempotencyRef: mutation.key,
        type: QueuedMutation.type,
        payload: mutation.toPayload(),
        supersede: true,
      );
      return (queued: true, response: null);
    }
    await store?.dropSyncOperation(mutation.key);
    return (queued: false, response: response);
  }
}
