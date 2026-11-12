import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_client.dart';
import '../storage/secure_token_storage.dart';

/// Le jeton d'accès expire au bout de 30 min côté API (voir
/// access_token_expire_minutes dans ApiClient). Sans vérification ici, une
/// connexion WS qui tombe (veille, coupure réseau) APRÈS ce délai boucle
/// indéfiniment sur `connect()` avec le MÊME jeton expiré — chaque tentative
/// est rejetée (handshake WS refusé en 403 avant même l'accept), jusqu'à ce
/// qu'un appel REST sans rapport déclenche par coïncidence le rafraîchissement
/// d'ApiClient. Résultat observé en prod : plus aucun message/appel en temps
/// réel tant que l'utilisateur ne fait rien d'autre dans l'app.
bool _isExpiredOrNearExpiry(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return true;
    final normalized = base64Url.normalize(parts[1]);
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(normalized)))
            as Map<String, dynamic>;
    final exp = payload['exp'] as int?;
    if (exp == null) return true;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    // Marge de 60s pour ne pas se faire rejeter par un jeton qui expire
    // pendant le temps du handshake lui-même.
    return DateTime.now().toUtc().isAfter(
      expiresAt.subtract(const Duration(seconds: 60)),
    );
  } catch (_) {
    return true;
  }
}

/// Le délai avant la tentative de reconnexion n° [attempt] (0 pour la
/// première) : exponentiel, plafonné à 30 s, et tiré au hasard dans la
/// seconde moitié de la fenêtre.
///
/// Un délai fixe faisait revenir tous les clients ensemble : après une
/// coupure chez un opérateur, des milliers de téléphones frappaient l'API
/// à la même seconde, puis toutes les 3 s, et vidaient leur batterie à
/// essayer contre un serveur saturé. L'aléa étale la vague ; la moitié
/// garantie évite qu'un tirage malchanceux retente aussitôt.
Duration reconnectDelay(int attempt, Random random) {
  const base = 1000, cap = 30000;
  final window = min(cap, base * pow(2, min(attempt, 15)).toInt());
  final half = window ~/ 2;
  return Duration(milliseconds: half + random.nextInt(half + 1));
}

/// Persistent WebSocket connection to the API's realtime channel
/// (`api/app/routes/ws.py`). Reconnects with an exponential, jittered
/// backoff (see [reconnectDelay]). When the app is backgrounded or killed,
/// push notifications take over (core/push/push_service.dart).
class WsClient {
  WsClient({
    required String baseWsUrl,
    required SecureTokenStorage tokenStorage,
    required ApiClient apiClient,
    this.pingInterval = const Duration(seconds: 25),
  }) : _baseWsUrl = baseWsUrl,
       _tokenStorage = tokenStorage,
       _apiClient = apiClient;

  /// Le signal de vie du socket.
  ///
  /// Sans lui, une connexion morte ne se voyait pas : après une mise en
  /// veille, un passage du wifi à la 4G ou un proxy qui coupe les
  /// connexions muettes, le socket restait « ouvert » des deux côtés sans
  /// plus rien transporter. Aucune fermeture n'était signalée, donc aucune
  /// reconnexion, aucun rattrapage — et plus un seul écran ne se mettait à
  /// jour tant qu'on ne relançait pas l'application. Le serveur, qui
  /// croyait livrer par le socket, n'envoyait pas non plus de notification.
  ///
  /// Un ping part à cet intervalle ; sans réponse avant le suivant, le
  /// socket est fermé, et [_scheduleReconnect] prend le relais.
  final Duration pingInterval;

  final String _baseWsUrl;
  final SecureTokenStorage _tokenStorage;
  final ApiClient _apiClient;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;

  /// Tentatives ratées depuis la dernière connexion réussie.
  int _attempt = 0;

  /// La connexion en cours d'ouverture. Ouvrir un socket prend plusieurs
  /// allers-retours (jeton, ticket, poignée de main) ; une seconde demande
  /// arrivée entre-temps (retour au premier plan, reconnexion programmée)
  /// ouvrait un SECOND socket, et chaque événement arrivait alors en double.
  /// Seule la demande la plus récente garde son socket.
  int _generation = 0;
  final _random = Random();

  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  /// Passages en ligne / hors ligne. La file d'attente des messages composés
  /// sans réseau s'en sert pour savoir quand réessayer (voir
  /// core/sync/outbox_service.dart) : le socket qui s'ouvre est le signal le
  /// plus fiable que l'API est joignable, et ce client retente déjà tout
  /// seul (voir [reconnectDelay]).
  Stream<bool> get connectionChanges => _connectionController.stream;

  bool get isConnected => _channel != null;

  void _emitConnection(bool connected) {
    if (_disposed || _connectionController.isClosed) return;
    _connectionController.add(connected);
  }

  /// Demande un laissez-passer d'ouverture au serveur.
  ///
  /// Renvoie `null` si la route n'existe pas encore (API pas à jour) ou si
  /// l'appel échoue : l'appelant retombe alors sur l'ancien chemin. Un
  /// ticket qu'on n'obtient pas ne doit pas empêcher de se connecter — le
  /// but est de supprimer une fuite, pas d'ajouter une panne.
  Future<String?> _fetchTicket() async {
    try {
      final response = await _apiClient.post('/ws/ticket', body: const {});
      final ticket = (response as Map<String, dynamic>)['ticket'];
      return ticket is String && ticket.isNotEmpty ? ticket : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> connect() async {
    if (_disposed) return;
    final generation = ++_generation;
    bool superseded() => _disposed || generation != _generation;
    var token = await _tokenStorage.readAccessToken();
    if (token == null || superseded()) return;

    if (_isExpiredOrNearExpiry(token)) {
      // Passe par ApiClient (dédup partagée, voir refreshTokens()) plutôt
      // qu'un rafraîchissement maison — /auth/refresh tourne le refresh
      // token, donc un rafraîchissement concurrent depuis un appel REST
      // invaliderait celui-ci s'ils n'étaient pas coordonnés.
      final refreshed = await _apiClient.refreshTokens();
      if (superseded()) return;
      if (!refreshed) {
        _scheduleReconnect();
        return;
      }
      token = await _tokenStorage.readAccessToken();
      if (token == null) return;
    }

    try {
      // Un TICKET dans l'URL, pas le jeton d'accès.
      //
      // Une URL de WebSocket se retrouve dans le journal du serveur, chez le
      // reverse proxy, dans les traces de supervision. Y mettre le jeton
      // d'accès revient à publier une session valable trente minutes à
      // chaque connexion. Le ticket, lui, vaut trente SECONDES, ne sert
      // qu'une fois, et n'ouvre qu'une socket.
      //
      // Repli sur l'ancien chemin si le serveur ne connaît pas encore la
      // route : pendant le déploiement, une application à jour peut joindre
      // une API qui ne l'est pas, et refuser de se connecter couperait le
      // temps réel pour rien.
      final ticket = await _fetchTicket();
      if (superseded()) return;
      final freshToken = await _tokenStorage.readAccessToken() ?? token;
      final query = ticket != null ? 'ticket=$ticket' : 'token=$freshToken';
      final channel = IOWebSocketChannel.connect(
        Uri.parse('$_baseWsUrl?$query'),
        pingInterval: pingInterval,
      );
      // `connect()` returns before the handshake completes — awaiting
      // `ready` is what actually surfaces a failed lookup/upgrade (DNS,
      // refused upgrade, etc.) here instead of as an unhandled exception
      // from the channel's internal future.
      await channel.ready;
      if (superseded()) {
        unawaited(channel.sink.close());
        return;
      }
      // Un socket précédent encore ouvert (connexion demandée deux fois de
      // suite) est fermé : un seul écoute.
      unawaited(_subscription?.cancel());
      unawaited(_channel?.sink.close());
      _channel = channel;
      _attempt = 0;
      _emitConnection(true);
      _subscription = channel.stream.listen(
        (raw) {
          try {
            final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
            _eventsController.add(decoded);
          } catch (_) {
            // Ignore malformed frames rather than crash the connection.
          }
        },
        onDone: () {
          if (identical(_channel, channel)) _scheduleReconnect();
        },
        onError: (_) {
          if (identical(_channel, channel)) _scheduleReconnect();
        },
      );
    } catch (_) {
      if (!superseded()) _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _channel = null;
    _emitConnection(false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay(_attempt++, _random), connect);
  }

  /// L'application revient au premier plan après [pausedFor].
  ///
  /// Le système suspend les sockets d'une application en arrière-plan sans
  /// toujours le dire. Après une vraie absence on ne fait donc pas confiance
  /// au socket : on en rouvre un, ce qui déclenche le rattrapage de tout ce
  /// qui s'est passé entre-temps (voir PokouSyncEngine). Après un simple
  /// aller-retour (sélecteur de photo, demande de permission) on le garde ;
  /// et s'il était déjà tombé, on n'attend pas la fin du délai de
  /// reconnexion — l'utilisateur regarde l'écran MAINTENANT.
  Future<void> resume(Duration pausedFor) async {
    if (_disposed) return;
    if (_channel != null && pausedFor < staleAfter) return;
    disconnect();
    _attempt = 0;
    _emitConnection(false);
    await connect();
  }

  /// Au-delà de cette absence, le socket est rouvert au retour.
  static const staleAfter = Duration(seconds: 20);

  /// Closes the current socket without permanently killing this client —
  /// use on logout, so a subsequent login can `connect()` again. Contrast
  /// with `dispose()`, which is final (app teardown only).
  void disconnect() {
    _generation++;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _eventsController.close();
    _connectionController.close();
  }
}
