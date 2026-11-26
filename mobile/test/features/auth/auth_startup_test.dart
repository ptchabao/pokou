import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/api/api_exceptions.dart';
import 'package:pokou/core/push/push_service.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:pokou/core/storage/pokou_message_store.dart';
import 'package:pokou/core/ws/ws_client.dart';
import 'package:pokou/features/auth/data/auth_repository.dart';
import 'package:pokou/features/auth/data/user_model.dart';
import 'package:pokou/features/auth/presentation/auth_controller.dart';

/// Ce que l'ouverture de l'application doit garantir.
///
/// Deux défauts s'y sont succédé, et tous deux passaient inaperçus parce
/// que rien ne testait ce chemin : l'application restait « authentifiée
/// sans identité » après un hoquet réseau, puis elle faisait attendre deux
/// allers-retours avant d'afficher quoi que ce soit. Les deux se voient
/// ici.
const _user = PokouUser(
  id: 8,
  phone: '+22890000000',
  fullName: 'Kodjo',
  plan: 'free',
);

class _FakeRepository extends AuthRepository {
  _FakeRepository({
    this.session = true,
    this.cached,
    this.profile,
    this.failure,
    this.instance,
  }) : super(
         apiClient: ApiClient(baseUrl: 'https://inutilise'),
         tokenStorage: SecureTokenStorage(),
       );

  final bool session;
  final PokouUser? cached;
  final PokouUser? profile;
  final Object? failure;

  /// L'identité de la base du serveur ; `null` = serveur injoignable.
  String? instance;

  int profileCalls = 0;
  bool loggedOut = false;

  @override
  Future<bool> hasSession() async => session;

  @override
  Future<PokouUser?> cachedProfile() async => cached;

  @override
  Future<PokouUser> getMyProfile() async {
    profileCalls++;
    if (failure != null) throw failure!;
    return profile ?? _user;
  }

  @override
  Future<void> logout() async => loggedOut = true;

  @override
  Future<String?> serverInstanceId() async => instance;
}

class _FakeWs extends WsClient {
  _FakeWs()
    : super(
        baseWsUrl: 'wss://inutilise',
        tokenStorage: SecureTokenStorage(),
        apiClient: ApiClient(baseUrl: 'https://inutilise'),
      );

  bool connected = false;

  /// Ne rend JAMAIS la main : une socket qui n'arrive pas à s'ouvrir ne
  /// doit pas retenir l'écran d'accueil. Si la restauration l'attend, le
  /// test se fige — ce qui est exactement le défaut qu'on veut interdire.
  @override
  Future<void> connect() {
    connected = true;
    return Future<void>.delayed(const Duration(days: 1));
  }

  @override
  void disconnect() {}
}

class _FakePush extends PushService {
  _FakePush(super.ref);

  int? sessionUserId;

  @override
  void setSession({required bool authenticated, int? userId}) {
    sessionUserId = userId;
  }

  @override
  Future<void> registerCurrentToken() async {}

  @override
  void drainPendingAcceptedCall() {}
}

class _FakeStore extends PokouMessageStore {
  @override
  Future<void> clear() async {}
}

/// Retient le propriétaire comme la vraie base (voir claimFor).
class _OwnedStore extends PokouMessageStore {
  String? owner;
  int clears = 0;

  @override
  Future<void> clear() async => clears++;

  @override
  Future<bool> claimFor(String newOwner) async {
    final changed = owner != newOwner;
    if (changed) clears++;
    owner = newOwner;
    return changed;
  }
}

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  /// Un `Ref` réel, pour construire le faux PushService — il en exige un,
  /// sans jamais s'en servir dans les chemins testés ici.
  Ref refOf() => container.read(Provider<Ref>((ref) => ref));

  Future<AuthController> start(_FakeRepository repository, _FakeWs ws) async {
    final controller = AuthController(
      repository,
      ws,
      _FakePush(refOf()),
      _FakeStore(),
    );
    // Laisse la restauration se dérouler, sans attendre ce qu'elle a
    // volontairement détaché.
    await Future<void>.delayed(Duration.zero);
    return controller;
  }

  test('sans session, on va droit à la connexion', () async {
    final controller = await start(_FakeRepository(session: false), _FakeWs());
    expect(controller.state.status, AuthStatus.unauthenticated);
  });

  test('un profil en cache ouvre l\'écran sans attendre le réseau', () async {
    // Le cœur du sujet : l'identité de quelqu'un ne change pas d'un
    // lancement à l'autre. La redemander avant d'afficher fait payer un
    // aller-retour à chaque ouverture, et une vingtaine de secondes hors
    // réseau — devant un écran vide, alors que tout est sur l'appareil.
    final repository = _FakeRepository(cached: _user);
    final controller = await start(repository, _FakeWs());

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.id, 8);
  });

  test('le WebSocket n\'est jamais attendu', () async {
    // `_FakeWs.connect()` ne rend pas la main. Si la restauration
    // l'attendait, l'état resterait « inconnu » et ce test échouerait.
    final ws = _FakeWs();
    final controller = await start(_FakeRepository(cached: _user), ws);

    expect(ws.connected, isTrue, reason: 'il se connecte quand même');
    expect(controller.state.status, AuthStatus.authenticated);
  });

  test('sans cache, on attend le profil — le seul cas qui le mérite', () async {
    final repository = _FakeRepository(cached: null, profile: _user);
    final controller = await start(repository, _FakeWs());

    expect(repository.profileCalls, 1);
    expect(controller.state.user?.id, 8);
  });

  test(
    'un rafraîchissement raté ne fait pas perdre le profil affiché',
    () async {
      // Le piège du démarrage optimiste. `myUserId` découle de cet état, et
      // tout l'écran d'accueil s'en sert : l'écraser rendrait les
      // conversations impossibles à ouvrir, sans le moindre message.
      final repository = _FakeRepository(
        cached: _user,
        failure: NetworkException('coupure'),
      );
      final controller = await start(repository, _FakeWs());
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user?.id, 8, reason: 'le profil en cache survit');
    },
  );

  test(
    'un jeton révoqué déconnecte, même après ouverture sur le cache',
    () async {
      // La contrepartie du démarrage optimiste : si le serveur dit que la
      // session n'existe plus, il faut le suivre — sinon on garderait
      // indéfiniment l'écran de quelqu'un qui n'est plus connecté.
      final repository = _FakeRepository(
        cached: _user,
        failure: ApiException(401, 'jeton périmé'),
      );
      final controller = await start(repository, _FakeWs());
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(repository.loggedOut, isTrue);
    },
  );

  test(
    'une panne réseau au tout premier lancement laisse l\'app utilisable',
    () async {
      // Pas de cache, pas de réseau : on ne connaît pas l'identité, mais la
      // session est valable. Rester bloqué sur l'écran d'attente serait pire
      // que d'ouvrir avec ce qu'on a.
      final repository = _FakeRepository(
        cached: null,
        failure: NetworkException('coupure'),
      );
      final controller = await start(repository, _FakeWs());

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user, isNull);
    },
  );

  // ── La session d'une nuit sur l'autre ───────────────────────────────
  //
  // Le scénario rapporté : « je ferme Pokou le soir, au réveil je dois me
  // réauthentifier ». L'access token vit 30 minutes, le refresh 7 jours —
  // la session était donc parfaitement valable. Ce qui la détruisait, c'est
  // qu'un rafraîchissement raté pour une raison RÉSEAU remontait un 401, et
  // qu'un 401 déclenche `logout()`.

  test('une coupure réseau au réveil ne déconnecte PAS', () async {
    // Au réveil du téléphone, la radio n'est pas encore rétablie : le
    // premier appel échoue. La session doit survivre à ça — c'est le
    // moment précis où le défaut se produisait.
    final repository = _FakeRepository(
      session: true,
      cached: _user,
      failure: NetworkException('réseau injoignable'),
    );

    final controller = await start(repository, _FakeWs());

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.id, _user.id);
    expect(
      repository.loggedOut,
      isFalse,
      reason: 'une coupure réseau n\'est pas une session invalide',
    );
  });

  test('un refus explicite du serveur déconnecte bien', () async {
    // L'autre moitié : une session vraiment révoquée doit l'être. Sans ce
    // test, la correction reviendrait à ne plus jamais se déconnecter.
    final repository = _FakeRepository(
      session: true,
      cached: _user,
      failure: ApiException(401, 'Session révoquée'),
    );

    final controller = await start(repository, _FakeWs());

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(repository.loggedOut, isTrue);
  });

  test('une panne serveur passagère ne déconnecte pas non plus', () async {
    // 500/502/503 ne disent rien de la session. Les traiter comme un refus
    // déconnectait tout le monde à chaque déploiement de l'API.
    final repository = _FakeRepository(
      session: true,
      cached: _user,
      failure: ApiException(503, 'Service Unavailable'),
    );

    final controller = await start(repository, _FakeWs());

    expect(controller.state.status, AuthStatus.authenticated);
    expect(repository.loggedOut, isFalse);
  });

  test('une déconnexion volontaire efface tout', () async {
    // Le contrat inverse, et il ne doit pas s'affaiblir : ce qu'on vient de
    // rendre plus difficile à déclencher par accident doit rester
    // immédiat quand c'est demandé.
    final repository = _FakeRepository(session: true, cached: _user);
    final controller = await start(repository, _FakeWs());
    expect(controller.state.status, AuthStatus.authenticated);

    await controller.logout();

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(repository.loggedOut, isTrue);
  });

  group('remise à zéro du serveur', () {
    Future<(AuthController, int Function())> startOwned(
      _FakeRepository repository,
      _OwnedStore store,
    ) async {
      var wipes = 0;
      final controller = AuthController(
        repository,
        _FakeWs(),
        _FakePush(refOf()),
        store,
        wipeEncryptionKeys: () async => wipes++,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return (controller, () => wipes);
    }

    test(
      'un autre serveur, même numéro de compte : clés et cache effacés',
      () async {
        final store = _OwnedStore()..owner = 'ancien:8';
        final repository = _FakeRepository(cached: _user, instance: 'nouveau');
        final (_, wipes) = await startOwned(repository, store);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(store.owner, 'nouveau:8');
        expect(
          wipes(),
          1,
          reason: 'les sessions de l\'ancien compte 8 ne valent plus',
        );
      },
    );

    test('le même serveur et le même compte gardent tout', () async {
      final store = _OwnedStore()..owner = 'meme:8';
      final repository = _FakeRepository(cached: _user, instance: 'meme');
      final (_, wipes) = await startOwned(repository, store);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(wipes(), 0);
      expect(store.clears, 0);
    });

    test('serveur injoignable : on n\'efface rien', () async {
      final store = _OwnedStore()..owner = 'ancien:8';
      final repository = _FakeRepository(cached: _user, instance: null);
      final (_, wipes) = await startOwned(repository, store);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(wipes(), 0);
      expect(store.owner, 'ancien:8');
    });

    test('la déconnexion efface aussi les clés', () async {
      final store = _OwnedStore()..owner = 'meme:8';
      final repository = _FakeRepository(cached: _user, instance: 'meme');
      final (controller, wipes) = await startOwned(repository, store);
      await controller.logout();
      expect(wipes(), 1);
    });
  });
}
