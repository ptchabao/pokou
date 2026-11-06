import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../storage/secure_token_storage.dart';
import '../../l10n/app_localizations.dart';
import '../l10n/app_locales.dart';
import 'api_exceptions.dart';

/// Base URL of the Pokou API. Override at build/run time with
/// `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` to point at a
/// backend started locally instead (10.0.2.2 is the Android emulator's
/// alias for the host machine's localhost) — defaults to the real deployed
/// API so `flutter run` works out of the box against it.
const _defaultBaseUrl = 'https://apipokou.cabinet-p-et-associes.com/api/v1';

/// Ce qu'a donné une tentative de rafraîchissement.
///
/// ── Pourquoi trois états et pas un booléen ──────────────────────────────
///
/// `_performRefresh` rendait `false` pour TOUT échec, et l'appelant en
/// concluait « la session n'existe plus ». Un réseau absent au réveil du
/// téléphone effaçait donc un jeton de rafraîchissement encore valable six
/// jours — c'est exactement ce qui faisait perdre la session d'une nuit sur
/// l'autre.
///
/// Or les deux cas sont parfaitement distinguables : le serveur répond
/// explicitement 401 ou 403 quand il REFUSE, et une coupure lève une
/// exception. Il n'y avait qu'à cesser de les confondre.
enum RefreshOutcome {
  /// Nouveaux jetons obtenus et enregistrés.
  refreshed,

  /// Le serveur a REFUSÉ le jeton : révoqué, expiré, inconnu. C'est le seul
  /// cas où la session doit être considérée comme morte.
  rejected,

  /// Le serveur n'a pas pu être joint, ou n'a pas répondu, ou a répondu une
  /// erreur qui ne parle pas du jeton (502, 503, portail captif). La session
  /// est intacte ; il faut réessayer, pas déconnecter.
  unreachable,
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    SecureTokenStorage? tokenStorage,
    String? baseUrl,
    L? l,
  }) : _l = l ?? lookupL(fallbackLocale),
       _http = httpClient ?? http.Client(),
       _tokenStorage = tokenStorage ?? SecureTokenStorage(),
       baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: _defaultBaseUrl,
           );

  /// Les traductions des messages d'erreur, qui remontent tels quels à
  /// l'écran. Sans injection, on retombe sur la langue de référence : un
  /// client construit hors de l'application (un test) n'a pas de réglages.
  final L _l;

  final http.Client _http;
  final SecureTokenStorage _tokenStorage;
  final String baseUrl;

  // Les 401 concurrents (plusieurs requêtes en vol au moment où le jeton
  // d'accès expire) partagent ce même rafraîchissement plutôt que d'en
  // déclencher un chacun — /auth/refresh fait une rotation du jeton, donc
  // des rafraîchissements simultanés s'invalideraient mutuellement.
  //
  // Partagé par TOUS les clients de ce stockage, et pas seulement par les
  // requêtes de cette instance : voir SharedRefreshState.
  //
  // Après un échec réseau, réessayer à chaque requête ferait une rafale
  // d'appels sur un réseau qui ne répond déjà pas — et viderait la
  // batterie précisément au moment où l'utilisateur n'a pas de réseau. Le
  // délai double à chaque échec consécutif.
  SharedRefreshState get _shared => _tokenStorage.refreshState;

  /// 2 s, 4 s, 8 s… plafonné à une minute. Assez court pour rattraper un
  /// réseau qui revient, assez long pour ne pas marteler.
  static const _refreshBackoffBase = Duration(seconds: 2);
  static const _refreshBackoffMax = Duration(seconds: 60);

  Future<Map<String, String>> _headers({bool authenticated = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = _l.apiError(response.statusCode);
    String? code;
    try {
      final body = jsonDecode(response.body);
      final detail = body is Map ? body['detail'] : null;
      if (detail is Map) {
        code = detail['code'] as String?;
        // Refus structuré `{code, message}` : le code choisit un texte
        // traduit, le message du serveur sert de repli.
        message = detail['code'] == 'use_honam'
            ? _l.marketUseHonam
            : (detail['message'] as String?) ?? message;
      } else if (detail != null) {
        message = detail.toString();
      }
    } catch (_) {
      // Body wasn't JSON — keep the generic message.
    }
    throw ApiException(response.statusCode, message, code: code);
  }

  /// Le jeton d'accès expire au bout de 30 min côté API (voir
  /// access_token_expire_minutes) ; sans ce mécanisme, toute session de
  /// plus de 30 min se traduisait par des écrans cassés (contacts/messages
  /// "disparus") plutôt qu'un rafraîchissement transparent. `send` est
  /// rappelé tel quel en cas de 401 — il doit relire le jeton à chaque
  /// invocation (voir _headers), pas le capturer une fois pour toutes.
  Future<http.Response> _sendWithRefresh(
    Future<http.Response> Function() send, {
    required bool authenticated,
  }) async {
    final tokenBefore = authenticated ? await _tokenStorage.readAccessToken() : null;
    var response = await send();
    if (response.statusCode != 401 || !authenticated) return response;

    // Si le jeton d'accès en stockage a DÉJÀ changé pendant que notre
    // requête était en vol (un autre appel concurrent a terminé un
    // rafraîchissement entre-temps), inutile de redemander un rafraîchissement :
    // ce 401 était causé par l'ancien jeton périmé. On rejoue immédiatement
    // avec le nouveau jeton sans solliciter /auth/refresh.
    final tokenAfter = await _tokenStorage.readAccessToken();
    if (tokenAfter != null && tokenAfter != tokenBefore) {
      _log('401 reçu avec un ancien jeton déjà rafraîchi — rejeu direct');
      return send();
    }

    switch (await _refresh(failedToken: tokenBefore)) {
      case RefreshOutcome.refreshed:
        return send();
      case RefreshOutcome.rejected:
        // Le serveur a refusé le jeton : on laisse le 401 remonter, et
        // l'appelant en tirera la seule conclusion valable — la session est
        // finie.
        return response;
      case RefreshOutcome.unreachable:
        // On ne SAIT PAS si la session est valable, et c'est toute la
        // différence. Remonter le 401 ici ferait effacer des jetons encore
        // bons ; on remonte une coupure réseau, que l'appelant traite déjà
        // en gardant la session et en réessayant plus tard.
        throw NetworkException(_l.apiNetworkSilent);
    }
  }

  Future<RefreshOutcome> _refresh({String? failedToken}) {
    // Le recul après échec réseau. Pendant ce temps, inutile de redemander
    // au serveur : on rend `unreachable` tout de suite, ce qui préserve la
    // session sans consommer ni requête ni batterie.
    final shared = _shared;
    final notBefore = shared.nextAllowedAt;
    if (notBefore != null && DateTime.now().isBefore(notBefore)) {
      return Future.value(RefreshOutcome.unreachable);
    }
    final enCours = shared.inFlight;
    if (enCours != null) return enCours.then((outcome) => outcome as RefreshOutcome);
    final lance = _performRefresh(triggerToken: failedToken).whenComplete(
      () => shared.inFlight = null,
    );
    shared.inFlight = lance;
    return lance;
  }

  /// Exposé pour WsClient : le WebSocket a besoin d'un jeton d'accès frais
  /// avant chaque (re)connexion (voir ws_client.dart), mais doit passer par
  /// CE rafraîchissement plutôt qu'en refaire un à part — /auth/refresh
  /// tourne le refresh token, donc deux rafraîchissements concurrents
  /// (un REST, un WS) s'invalideraient mutuellement sans le partage de
  /// l’état partagé `SharedRefreshState`.
  Future<bool> refreshTokens() async =>
      await _refresh() == RefreshOutcome.refreshed;

  /// Une tentative de rafraîchissement, et le VERDICT qu'elle rend.
  ///
  /// Rien de ce qui est journalisé ici ne contient de jeton, ni même un
  /// fragment : seulement l'issue et, pour un refus, le code HTTP. C'était
  /// l'autre moitié du problème — un `catch (_)` muet avalait la raison, et
  /// le défaut est resté invisible pendant des mois.
  Future<RefreshOutcome> _performRefresh({String? triggerToken}) async {
    // Si pendant la planification de ce rafraîchissement, un jeton plus
    // récent a déjà été enregistré par un appel concurrent :
    final currentAccess = await _tokenStorage.readAccessToken();
    if (triggerToken != null && currentAccess != null && currentAccess != triggerToken) {
      _log('refresh: déjà rafraîchi par un autre appel concurrent');
      return _settle(RefreshOutcome.refreshed);
    }

    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      // Pas de jeton du tout : il n'y a rien à rafraîchir et rien à
      // attendre du réseau. C'est un refus, pas une coupure.
      _log('refresh: aucun jeton de rafraîchissement en stockage');
      return _settle(RefreshOutcome.rejected);
    }
    try {
      final response = await _http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Authorization': 'Bearer $refreshToken'},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        await _tokenStorage.saveTokens(
          accessToken: body['access_token'] as String,
          refreshToken: body['refresh_token'] as String,
        );
        _log('refresh: réussi');
        return _settle(RefreshOutcome.refreshed);
      }

      // 401/403 : le serveur parle DU JETON — révoqué, expiré, inconnu.
      // Tout le reste (500, 502, 503, portail captif qui rend du HTML) ne
      // dit rien de la session et ne doit pas la condamner.
      if (response.statusCode == 401 || response.statusCode == 403) {
        _log('refresh: refusé par le serveur (${response.statusCode})');
        return _settle(RefreshOutcome.rejected);
      }
      _log('refresh: serveur indisponible (${response.statusCode})');
      return _settle(RefreshOutcome.unreachable);
    } catch (error) {
      // Coupure, délai dépassé, DNS, réponse illisible : on ne sait rien de
      // la session. On ne touche à rien.
      _log('refresh: injoignable (${error.runtimeType})');
      return _settle(RefreshOutcome.unreachable);
    }
  }

  /// Enregistre l'issue et ajuste le recul avant la prochaine tentative.
  RefreshOutcome _settle(RefreshOutcome outcome) {
    final shared = _shared;
    if (outcome == RefreshOutcome.unreachable) {
      shared.consecutiveFailures++;
      final millis =
          _refreshBackoffBase.inMilliseconds *
          (1 << (shared.consecutiveFailures - 1).clamp(0, 10));
      final delay = Duration(
        milliseconds: millis.clamp(0, _refreshBackoffMax.inMilliseconds),
      );
      shared.nextAllowedAt = DateTime.now().add(delay);
    } else {
      shared.consecutiveFailures = 0;
      shared.nextAllowedAt = null;
    }
    return outcome;
  }

  /// Journal technique du chemin d'authentification.
  ///
  /// `debugPrint` et non `print` : il est retiré en release par l'outillage
  /// Flutter, et on ne veut pas de trace d'authentification dans les
  /// journaux d'un téléphone de production. Aucun jeton n'y passe jamais.
  void _log(String message) {
    assert(() {
      debugPrint('[Pokou/auth] $message');
      return true;
    }());
  }

  Future<dynamic> get(String path, {bool authenticated = true}) async {
    try {
      final response = await _sendWithRefresh(
        () async => _http
            .get(
              Uri.parse('$baseUrl$path'),
              headers: await _headers(authenticated: authenticated),
            )
            .timeout(const Duration(seconds: 20)),
        authenticated: authenticated,
      );
      return _decode(response);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      // Un délai dépassé est une COUPURE, pas un refus.
      //
      // Il échappait au filet : `SocketException` couvre « pas de réseau du
      // tout », mais pas le réseau qui accepte la connexion et ne répond
      // jamais — portail captif, wifi de maquis, 3G saturée, c'est-à-dire
      // le cas le plus fréquent ici. L'appelant le recevait alors comme une
      // panne définitive : message marqué en échec au lieu d'être gardé en
      // attente, écran d'erreur au lieu du cache.
      throw NetworkException(_l.apiNetworkSilent);
    }
  }

  /// `timeout` n'est à préciser que pour les routes qui font attendre le
  /// serveur bien plus qu'un aller-retour de base de données — typiquement
  /// celles qui appellent un modèle de langage. Les 20 s par défaut y
  /// expiraient alors que la requête avait ABOUTI côté serveur, ce qui
  /// affichait « non envoyé » sur un message pourtant traité.
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final response = await _sendWithRefresh(
        () async => _http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: await _headers(authenticated: authenticated),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(timeout),
        authenticated: authenticated,
      );
      return _decode(response);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      // Un délai dépassé est une COUPURE, pas un refus.
      //
      // Il échappait au filet : `SocketException` couvre « pas de réseau du
      // tout », mais pas le réseau qui accepte la connexion et ne répond
      // jamais — portail captif, wifi de maquis, 3G saturée, c'est-à-dire
      // le cas le plus fréquent ici. L'appelant le recevait alors comme une
      // panne définitive : message marqué en échec au lieu d'être gardé en
      // attente, écran d'erreur au lieu du cache.
      throw NetworkException(_l.apiNetworkSilent);
    }
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final response = await _sendWithRefresh(
        () async => _http
            .put(
              Uri.parse('$baseUrl$path'),
              headers: await _headers(authenticated: authenticated),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 20)),
        authenticated: authenticated,
      );
      return _decode(response);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      // Un délai dépassé est une COUPURE, pas un refus.
      //
      // Il échappait au filet : `SocketException` couvre « pas de réseau du
      // tout », mais pas le réseau qui accepte la connexion et ne répond
      // jamais — portail captif, wifi de maquis, 3G saturée, c'est-à-dire
      // le cas le plus fréquent ici. L'appelant le recevait alors comme une
      // panne définitive : message marqué en échec au lieu d'être gardé en
      // attente, écran d'erreur au lieu du cache.
      throw NetworkException(_l.apiNetworkSilent);
    }
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final response = await _sendWithRefresh(
        () async => _http
            .patch(
              Uri.parse('$baseUrl$path'),
              headers: await _headers(authenticated: authenticated),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 20)),
        authenticated: authenticated,
      );
      return _decode(response);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      // Un délai dépassé est une COUPURE, pas un refus.
      //
      // Il échappait au filet : `SocketException` couvre « pas de réseau du
      // tout », mais pas le réseau qui accepte la connexion et ne répond
      // jamais — portail captif, wifi de maquis, 3G saturée, c'est-à-dire
      // le cas le plus fréquent ici. L'appelant le recevait alors comme une
      // panne définitive : message marqué en échec au lieu d'être gardé en
      // attente, écran d'erreur au lieu du cache.
      throw NetworkException(_l.apiNetworkSilent);
    }
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final response = await _sendWithRefresh(
        () async => _http
            .delete(
              Uri.parse('$baseUrl$path'),
              headers: await _headers(authenticated: authenticated),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 20)),
        authenticated: authenticated,
      );
      return _decode(response);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      // Un délai dépassé est une COUPURE, pas un refus.
      //
      // Il échappait au filet : `SocketException` couvre « pas de réseau du
      // tout », mais pas le réseau qui accepte la connexion et ne répond
      // jamais — portail captif, wifi de maquis, 3G saturée, c'est-à-dire
      // le cas le plus fréquent ici. L'appelant le recevait alors comme une
      // panne définitive : message marqué en échec au lieu d'être gardé en
      // attente, écran d'erreur au lieu du cache.
      throw NetworkException(_l.apiNetworkSilent);
    }
  }

  /// Upload multipart d'une pièce jointe (Pokou — notes vocales/documents/
  /// images/vidéos). `fields` va dans le corps du formulaire (ex.
  /// `message_type`), pas dans les query params. Un `MultipartRequest` ne
  /// se réutilise pas (son flux est à usage unique) — on en reconstruit un
  /// neuf à chaque tentative, `bytes` étant déjà entièrement en mémoire.
  /// Téléverse un fichier, en rendant compte de l'avancement.
  ///
  /// [onProgress] reçoit une fraction entre 0 et 1. Sans lui, le
  /// comportement est exactement celui d'avant.
  ///
  /// ── Ce que la progression mesure, et ce qu'elle ne mesure pas ───────
  ///
  /// Les octets REMIS À LA PILE RÉSEAU, pas les octets acquittés par le
  /// serveur. Sur une connexion lente, la barre peut donc atteindre 100 %
  /// quelques secondes avant la réponse — c'est le cas de tous les
  /// téléversements par flux, et c'est pourquoi l'écran distingue
  /// « Envoi… » de « Envoyé » : la fraction dit où en est le transfert, la
  /// réponse dit si c'est arrivé.
  ///
  /// Le délai passe à cinq minutes quand on suit la progression : soixante
  /// secondes suffisent à une requête JSON, pas à une vidéo sur un réseau
  /// mobile — et le dépassement effaçait le travail au moment précis où il
  /// allait aboutir.
  Future<dynamic> uploadFile(
    String path, {
    required List<int> bytes,
    required String filename,
    required String mimeType,
    Map<String, String> fields = const {},
    void Function(double fraction)? onProgress,
    // Le nom du champ du fichier : `file` partout, sauf les routes qui en
    // attendent un autre (la transcription vocale lit `audio`).
    String fileField = 'file',
  }) async {
    Future<http.Response> sendOnce() async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      final headers = await _headers(authenticated: true);
      headers.remove('Content-Type'); // laissé au multipart boundary
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );
      if (onProgress == null) {
        final streamed = await _http
            .send(request)
            .timeout(const Duration(seconds: 60));
        return http.Response.fromStream(streamed);
      }

      // `finalize()` AVANT de lire les en-têtes : c'est lui qui pose le
      // `content-type` avec la frontière multipart. Les copier avant
      // donnerait une requête sans frontière, que le serveur refuse.
      final corps = request.finalize();
      final total = request.contentLength;
      final relais = http.StreamedRequest('POST', Uri.parse('$baseUrl$path'));
      relais.headers.addAll(request.headers);
      relais.contentLength = total;

      var envoye = 0;
      corps.listen(
        (morceau) {
          envoye += morceau.length;
          relais.sink.add(morceau);
          if (total > 0) onProgress(envoye / total);
        },
        onDone: relais.sink.close,
        onError: relais.sink.addError,
        cancelOnError: true,
      );

      final streamed = await _http
          .send(relais)
          .timeout(const Duration(minutes: 5));
      return http.Response.fromStream(streamed);
    }

    try {
      final response = await _sendWithRefresh(sendOnce, authenticated: true);
      return _decode(response);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      // Un délai dépassé est une COUPURE, pas un refus.
      //
      // Il échappait au filet : `SocketException` couvre « pas de réseau du
      // tout », mais pas le réseau qui accepte la connexion et ne répond
      // jamais — portail captif, wifi de maquis, 3G saturée, c'est-à-dire
      // le cas le plus fréquent ici. L'appelant le recevait alors comme une
      // panne définitive : message marqué en échec au lieu d'être gardé en
      // attente, écran d'erreur au lieu du cache.
      throw NetworkException(_l.apiNetworkSilent);
    }
  }

  /// Récupère les octets bruts d'un média protégé (nécessite le Bearer
  /// token — impossible de passer par une simple URL statique).
  Future<List<int>> getBytes(String path) async {
    try {
      final response = await _sendWithRefresh(
        () async => _http
            .get(
              Uri.parse('$baseUrl$path'),
              headers: await _headers(authenticated: true),
            )
            .timeout(const Duration(seconds: 60)),
        authenticated: true,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      throw ApiException(response.statusCode, _l.apiError(response.statusCode));
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      // Un délai dépassé est une COUPURE, pas un refus.
      //
      // Il échappait au filet : `SocketException` couvre « pas de réseau du
      // tout », mais pas le réseau qui accepte la connexion et ne répond
      // jamais — portail captif, wifi de maquis, 3G saturée, c'est-à-dire
      // le cas le plus fréquent ici. L'appelant le recevait alors comme une
      // panne définitive : message marqué en échec au lieu d'être gardé en
      // attente, écran d'erreur au lieu du cache.
      throw NetworkException(_l.apiNetworkSilent);
    }
  }
}
