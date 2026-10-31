import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:pokou/core/ws/ws_client.dart';

class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({required String key, required String? value, required Map<String, String> options}) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async => _values[key];

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async => _values.remove(key);

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      _values.containsKey(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async => _values.clear();

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => Map.of(_values);
}

/// JWT dont le payload contient un `exp` — la signature n'a pas besoin
/// d'être valide, seule la lecture locale du payload compte ici (voir
/// _isExpiredOrNearExpiry dans ws_client.dart, qui ne vérifie pas la
/// signature — ce n'est pas son rôle, l'API la vérifie côté serveur).
String _fakeJwt({required int expiresInSeconds}) {
  String segment(Map<String, dynamic> data) => base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  final exp = DateTime.now().toUtc().add(Duration(seconds: expiresInSeconds)).millisecondsSinceEpoch ~/ 1000;
  return '${segment({
        'alg': 'HS256',
      })}.${segment({'exp': exp})}.fake-signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _InMemorySecureStorage();

  group('WsClient', () {
    test('refreshes an expired access token before attempting to connect', () async {
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: _fakeJwt(expiresInSeconds: -120),
        refreshToken: 'valid-refresh-token',
      );

      var refreshCalled = false;
      final mockClient = MockClient((request) async {
        // Deux appels partent maintenant : le rafraîchissement, puis la
        // demande de laissez-passer d'ouverture (voir WsClient._fetchTicket).
        // Le faux client doit donc les distinguer — sans quoi il compterait
        // le ticket comme un rafraîchissement.
        if (request.url.path.endsWith('/ws/ticket')) {
          return http.Response(jsonEncode({'ticket': 'abc', 'expires_in': 30}), 200);
        }
        refreshCalled = true;
        expect(request.url.path, endsWith('/auth/refresh'));
        return http.Response(
          jsonEncode({
            'access_token': _fakeJwt(expiresInSeconds: 1800),
            'refresh_token': 'new-refresh-token',
            'expires_in': 1800,
          }),
          200,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient, tokenStorage: tokenStorage, baseUrl: 'https://api.test/v1');
      final client = WsClient(
        baseWsUrl: 'wss://api.test/v1/ws',
        tokenStorage: tokenStorage,
        apiClient: apiClient,
      );

      // La connexion socket elle-même échouera (aucun serveur réel à cette
      // adresse) — ce qui nous intéresse est SEULEMENT que le rafraîchissement
      // ait eu lieu avant la tentative, pas l'issue du handshake.
      await client.connect();
      client.dispose();

      expect(refreshCalled, isTrue);
      expect(await tokenStorage.readAccessToken(), isNot(contains('-120')));
    });

    test('connects directly without refreshing when the token is still valid', () async {
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: _fakeJwt(expiresInSeconds: 1800),
        refreshToken: 'valid-refresh-token',
      );

      var refreshCalled = false;
      var ticketRequested = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/ws/ticket')) {
          ticketRequested = true;
          return http.Response(jsonEncode({'ticket': 'abc', 'expires_in': 30}), 200);
        }
        refreshCalled = true;
        return http.Response(jsonEncode({}), 200);
      });

      final apiClient = ApiClient(httpClient: mockClient, tokenStorage: tokenStorage, baseUrl: 'https://api.test/v1');
      final client = WsClient(
        baseWsUrl: 'wss://api.test/v1/ws',
        tokenStorage: tokenStorage,
        apiClient: apiClient,
      );

      await client.connect();
      client.dispose();

      expect(refreshCalled, isFalse);
      // Le jeton d'accès ne doit PLUS voyager dans l'URL de la socket : on
      // demande un laissez-passer court à usage unique (voir
      // api/app/services/ws_ticket_service.py).
      expect(ticketRequested, isTrue);
    });

    test('sans ticket, on se connecte quand même — ancien serveur', () async {
      // Pendant le déploiement, une application à jour peut joindre une API
      // qui ne l'est pas. Refuser de se connecter couperait le temps réel
      // pour rien : le but est de supprimer une fuite, pas d'ajouter une
      // panne.
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: _fakeJwt(expiresInSeconds: 1800),
        refreshToken: 'valid-refresh-token',
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/ws/ticket')) {
          return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: 'https://api.test/v1',
      );
      final client = WsClient(
        baseWsUrl: 'wss://api.test/v1/ws',
        tokenStorage: tokenStorage,
        apiClient: apiClient,
      );

      // Aucune exception : le repli sur l'ancien chemin est silencieux.
      await client.connect();
      client.dispose();
    });
  });

  group('reconnectDelay', () {
    test('double à chaque échec, puis plafonne à 30 s', () {
      // Random qui tire toujours le maximum : on lit la borne haute.
      final high = _FixedRandom(1 << 31);
      expect(reconnectDelay(0, high), const Duration(milliseconds: 1000));
      expect(reconnectDelay(1, high), const Duration(milliseconds: 2000));
      expect(reconnectDelay(4, high), const Duration(milliseconds: 16000));
      expect(reconnectDelay(5, high), const Duration(milliseconds: 30000));
      expect(reconnectDelay(500, high), const Duration(milliseconds: 30000));
    });

    test('ne descend jamais sous la moitié de la fenêtre', () {
      final low = _FixedRandom(0);
      expect(reconnectDelay(0, low), const Duration(milliseconds: 500));
      expect(reconnectDelay(5, low), const Duration(milliseconds: 15000));
    });

    test('étale les clients : deux tirages diffèrent', () {
      final random = Random(42);
      final delays = {for (var i = 0; i < 20; i++) reconnectDelay(3, random)};
      expect(delays.length, greaterThan(1));
    });
  });
}

/// Un générateur qui renvoie toujours la même valeur, bornée à `max - 1`.
class _FixedRandom implements Random {
  _FixedRandom(this._value);

  final int _value;

  @override
  int nextInt(int max) => min(_value, max - 1);

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}
