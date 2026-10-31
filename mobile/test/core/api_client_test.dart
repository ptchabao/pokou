import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _InMemorySecureStorage();

  group('ApiClient', () {
    test(
      'deux clients sur le même stockage ne rafraîchissent qu’UNE fois',
      () async {
        // apiClientProvider est recréé quand la langue change — y compris à
        // l'ouverture de l'app. L'ancienne instance survit dans les dépôts :
        // deux verrous, deux /auth/refresh avec le même jeton, et la
        // rotation déconnectait l'utilisateur (prod, 2026-10-02).
        final tokenStorage = SecureTokenStorage();
        await tokenStorage.saveTokens(
          accessToken: 'stale-token',
          refreshToken: 'valid-refresh-token',
        );
        var refreshCalls = 0;
        final refreshGate = Completer<void>();
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshCalls++;
            await refreshGate.future;
            return http.Response(
              jsonEncode({
                'access_token': 'fresh-token',
                'refresh_token': 'new-refresh-token',
                'expires_in': 1800,
              }),
              200,
            );
          }
          if (request.headers['Authorization'] == 'Bearer stale-token') {
            return http.Response(jsonEncode({'detail': 'expired'}), 401);
          }
          return http.Response(jsonEncode({'ok': true}), 200);
        });
        final ancien = ApiClient(
          httpClient: mockClient,
          tokenStorage: tokenStorage,
          baseUrl: 'https://api.test/v1',
        );
        final nouveau = ApiClient(
          httpClient: mockClient,
          tokenStorage: tokenStorage,
          baseUrl: 'https://api.test/v1',
        );

        final a = ancien.get('/a');
        final b = nouveau.get('/b');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        refreshGate.complete();

        expect(await a, {'ok': true});
        expect(await b, {'ok': true});
        expect(refreshCalls, 1);
      },
    );

    test(
      'attaches the bearer token from secure storage on authenticated requests',
      () async {
        final tokenStorage = SecureTokenStorage();
        await tokenStorage.saveTokens(
          accessToken: 'abc123',
          refreshToken: 'refresh',
        );

        http.Request? capturedRequest;
        final mockClient = MockClient((request) async {
          capturedRequest = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final client = ApiClient(
          httpClient: mockClient,
          tokenStorage: tokenStorage,
          baseUrl: 'https://api.test/v1',
        );
        final result = await client.get('/ping');

        expect(capturedRequest?.headers['Authorization'], 'Bearer abc123');
        expect(result, {'ok': true});
      },
    );

    test('does not attach a token for unauthenticated requests', () async {
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'abc123',
        refreshToken: 'refresh',
      );

      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'expires_in': 300}), 200);
      });

      final client = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: 'https://api.test/v1',
      );
      await client.post(
        '/auth/phone/request-otp',
        body: {'phone': '+22890000000'},
        authenticated: false,
      );

      expect(capturedRequest?.headers.containsKey('Authorization'), isFalse);
    });

    test(
      'throws ApiException with the backend detail message on error',
      () async {
        final tokenStorage = SecureTokenStorage();
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Code invalide ou expiré.'}),
            400,
          );
        });

        final client = ApiClient(
          httpClient: mockClient,
          tokenStorage: tokenStorage,
          baseUrl: 'https://api.test/v1',
        );

        expect(
          () => client.post(
            '/auth/phone/verify-otp',
            body: {'phone': 'x', 'code': '000000'},
            authenticated: false,
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having(
                  (e) => e.message,
                  'message',
                  'Code invalide ou expiré.',
                ),
          ),
        );
      },
    );

    test(
      'transparently refreshes and retries once on a 401 (expired access token)',
      () async {
        final tokenStorage = SecureTokenStorage();
        await tokenStorage.saveTokens(
          accessToken: 'stale-token',
          refreshToken: 'valid-refresh-token',
        );

        var pingCallCount = 0;
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            expect(
              request.headers['Authorization'],
              'Bearer valid-refresh-token',
            );
            return http.Response(
              jsonEncode({
                'access_token': 'fresh-token',
                'refresh_token': 'new-refresh-token',
                'expires_in': 1800,
              }),
              200,
            );
          }
          pingCallCount++;
          if (request.headers['Authorization'] == 'Bearer stale-token') {
            return http.Response(
              jsonEncode({'detail': 'Not authenticated'}),
              401,
            );
          }
          expect(request.headers['Authorization'], 'Bearer fresh-token');
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final client = ApiClient(
          httpClient: mockClient,
          tokenStorage: tokenStorage,
          baseUrl: 'https://api.test/v1',
        );
        final result = await client.get('/ping');

        expect(result, {'ok': true});
        expect(
          pingCallCount,
          2,
        ); // premier essai (401) + réessai après rafraîchissement
        expect(await tokenStorage.readAccessToken(), 'fresh-token');
        expect(await tokenStorage.readRefreshToken(), 'new-refresh-token');
      },
    );

    test('propagates the 401 when the refresh token is also invalid', () async {
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'stale-token',
        refreshToken: 'dead-refresh-token',
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({'detail': 'Invalid refresh token'}),
            403,
          );
        }
        return http.Response(jsonEncode({'detail': 'Not authenticated'}), 401);
      });

      final client = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: 'https://api.test/v1',
      );

      expect(
        () => client.get('/ping'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('does not attempt a refresh for non-401 errors', () async {
      final tokenStorage = SecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'token',
        refreshToken: 'refresh',
      );

      var refreshCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCalled = true;
          return http.Response(jsonEncode({}), 200);
        }
        return http.Response(jsonEncode({'detail': 'introuvable'}), 404);
      });

      final client = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: 'https://api.test/v1',
      );

      await expectLater(
        () => client.get('/ping'),
        throwsA(isA<ApiException>()),
      );
      expect(refreshCalled, isFalse);
    });
  });

  // ── La session survit à une coupure réseau ──────────────────────────
  //
  // LE défaut : un rafraîchissement qui échoue pour une raison RÉSEAU était
  // traité comme « le serveur a refusé le jeton », et faisait effacer une
  // session encore valable six jours. C'est ce qui faisait perdre la session
  // d'une nuit sur l'autre — au réveil, l'access token de 30 minutes est
  // périmé et la radio n'est pas encore rétablie.
  //
  // Chaque test ci-dessous vérifie DEUX choses : le comportement immédiat,
  // et que les jetons sont toujours en stockage après coup. La seconde est
  // la vraie : c'est leur effacement qui coûtait la session.
  group('ApiClient — le rafraîchissement distingue refus et coupure', () {
    Future<SecureTokenStorage> storageAvecSession() async {
      final storage = SecureTokenStorage();
      await storage.saveTokens(
        accessToken: 'access-perime',
        refreshToken: 'refresh-valable',
      );
      return storage;
    }

    test('un délai dépassé pendant le refresh CONSERVE la session', () async {
      final storage = await storageAvecSession();
      final client = ApiClient(
        baseUrl: 'https://exemple.test',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            throw TimeoutException('pas de réponse');
          }
          return http.Response('', 401);
        }),
      );

      // Une coupure, pas un refus : l'appelant doit recevoir une panne
      // réseau, que `_loadProfile` traite déjà en gardant la session.
      await expectLater(
        client.get('/users/me/profile'),
        throwsA(isA<NetworkException>()),
      );
      expect(await storage.readRefreshToken(), 'refresh-valable');
    });

    test('une coupure de socket pendant le refresh CONSERVE la session', () async {
      final storage = await storageAvecSession();
      final client = ApiClient(
        baseUrl: 'https://exemple.test',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            throw const SocketException('réseau injoignable');
          }
          return http.Response('', 401);
        }),
      );

      await expectLater(
        client.get('/users/me/profile'),
        throwsA(isA<NetworkException>()),
      );
      expect(await storage.readRefreshToken(), 'refresh-valable');
    });

    test('une API momentanément indisponible CONSERVE la session', () async {
      // 502/503 ne parlent PAS du jeton. Les traiter comme un refus
      // déconnectait tout le monde à chaque déploiement.
      final storage = await storageAvecSession();
      final client = ApiClient(
        baseUrl: 'https://exemple.test',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response('<html>Bad Gateway</html>', 502);
          }
          return http.Response('', 401);
        }),
      );

      await expectLater(
        client.get('/users/me/profile'),
        throwsA(isA<NetworkException>()),
      );
      expect(await storage.readRefreshToken(), 'refresh-valable');
    });

    test('un refus explicite du serveur laisse remonter le 401', () async {
      // L'autre moitié de la règle : une session vraiment morte DOIT être
      // reconnue comme telle, sinon on ne se déconnecte plus jamais.
      final storage = await storageAvecSession();
      final client = ApiClient(
        baseUrl: 'https://exemple.test',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response(
              jsonEncode({'detail': 'Invalid refresh token'}),
              403,
            );
          }
          return http.Response('', 401);
        }),
      );

      await expectLater(
        client.get('/users/me/profile'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('un access périmé + un refresh valable se rattrapent tout seuls', () async {
      // Le cas nominal du réveil : personne ne doit rien voir.
      final storage = await storageAvecSession();
      var appelsProfil = 0;
      final client = ApiClient(
        baseUrl: 'https://exemple.test',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response(
              jsonEncode({
                'access_token': 'access-neuf',
                'refresh_token': 'refresh-neuf',
              }),
              200,
            );
          }
          appelsProfil++;
          // Le premier appel porte le jeton périmé, le second le neuf.
          return appelsProfil == 1
              ? http.Response('', 401)
              : http.Response(jsonEncode({'id': 7}), 200);
        }),
      );

      final profil = await client.get('/users/me/profile');

      expect((profil as Map)['id'], 7);
      expect(await storage.readRefreshToken(), 'refresh-neuf');
      expect(await storage.readAccessToken(), 'access-neuf');
    });

    test('sans jeton de rafraîchissement, c\'est un refus et non une coupure', () async {
      // Un kill entre les deux écritures pouvait laisser cet état. Il n'y a
      // rien à attendre du réseau : la session est bel et bien finie.
      final storage = SecureTokenStorage();
      await storage.clear();
      final client = ApiClient(
        baseUrl: 'https://exemple.test',
        tokenStorage: storage,
        httpClient: MockClient((request) async => http.Response('', 401)),
      );

      await expectLater(
        client.get('/users/me/profile'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('deux requêtes 401 simultanées ne rafraîchissent qu\'UNE fois', () async {
      // Sans la déduplication, chacune tournerait le jeton de son côté et la
      // seconde rotation invaliderait la première.
      final storage = await storageAvecSession();
      var refreshs = 0;
      final client = ApiClient(
        baseUrl: 'https://exemple.test',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshs++;
            return http.Response(
              jsonEncode({
                'access_token': 'access-neuf',
                'refresh_token': 'refresh-neuf',
              }),
              200,
            );
          }
          final porteur = request.headers['Authorization'];
          return porteur == 'Bearer access-neuf'
              ? http.Response(jsonEncode({'ok': true}), 200)
              : http.Response('', 401);
        }),
      );

      await Future.wait([
        client.get('/a'),
        client.get('/b'),
      ]);

      expect(refreshs, 1);
    });

    test('une requête 401 décalée dont le jeton a déjà été renouvelé rejoue directement sans deuxième refresh', () async {
      final storage = await storageAvecSession();
      var refreshs = 0;
      final completerA = Completer<http.Response>();
      final client = ApiClient(
        baseUrl: 'https://exemple.test',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshs++;
            return http.Response(
              jsonEncode({
                'access_token': 'access-neuf',
                'refresh_token': 'refresh-neuf',
              }),
              200,
            );
          }
          final porteur = request.headers['Authorization'];
          if (request.url.path == '/a') {
            if (porteur == 'Bearer access-neuf') {
              return http.Response(jsonEncode({'a': 'ok'}), 200);
            }
            return completerA.future;
          }
          if (request.url.path == '/b') {
            return porteur == 'Bearer access-neuf'
                ? http.Response(jsonEncode({'b': 'ok'}), 200)
                : http.Response('', 401);
          }
          return http.Response('', 404);
        }),
      );

      // /a est lancée avec le vieux token (access-perime) mais attend
      final futureA = client.get('/a');
      await Future<void>.delayed(Duration.zero);

      // /b est lancée, prend 401, déclenche le refresh et termine
      final futureB = client.get('/b');
      await futureB;

      // Le refresh est terminé, stockage contient 'access-neuf'.
      // Maintenant on livre enfin le 401 à /a
      completerA.complete(http.Response('', 401));
      final resA = await futureA;

      expect(resA, {'a': 'ok'});
      expect(refreshs, 1);
    });
  });

  // ── Le stockage lui-même ────────────────────────────────────────────
  group('SecureTokenStorage', () {
    test('le jeton de rafraîchissement est écrit EN PREMIER', () async {
      // `FlutterSecureStorage` n'a pas d'écriture atomique. Tué entre les
      // deux, il faut que l'état survivant soit le RATTRAPABLE :
      // refresh sans access se répare tout seul au premier 401 ; access
      // sans refresh perd la session au bout de 30 minutes.
      final ordre = <String>[];
      final storage = SecureTokenStorage(
        storage: _OrdonnanceurDEcritures(ordre),
      );

      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');

      expect(ordre.first, contains('refresh'));
    });
  });
}

/// Un stockage qui note seulement l'ORDRE des écritures.
class _OrdonnanceurDEcritures implements FlutterSecureStorage {
  _OrdonnanceurDEcritures(this.ordre);

  final List<String> ordre;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    ordre.add(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
