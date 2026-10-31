import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/crypto/media_cipher.dart';
import '../../../core/mahizu/mahizu_session.dart';
import '../../../core/providers.dart';
import '../../../core/push/push_service.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../core/storage/pokou_message_store.dart';
import '../../../core/ws/ws_client.dart';
import '../data/auth_repository.dart';
import '../data/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
  );
});

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final PokouUser? user;

  static const unknown = AuthState(status: AuthStatus.unknown);
  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.authenticated(PokouUser user) =>
      AuthState(status: AuthStatus.authenticated, user: user);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._repository,
    this._ws,
    this._push,
    this._messageStore, {
    SecureTokenStorage? linkedMahizuTokens,
  }) : _linkedMahizuTokens = linkedMahizuTokens,
       super(AuthState.unknown) {
    _restoreSession();
  }

  final AuthRepository _repository;
  final WsClient _ws;
  final PushService _push;
  final PokouMessageStore _messageStore;

  /// Les jetons du compte Mahizu rattaché (voir core/mahizu/) : ils partent
  /// avec la session Pokou, pour qu'un téléphone partagé ne garde pas
  /// l'accès à l'assistant du compte précédent.
  final SecureTokenStorage? _linkedMahizuTokens;

  /// Pose l'état, mais seulement si ce contrôleur est encore vivant.
  ///
  /// `_restoreSession` et `_loadProfile` sont asynchrones et survivent au
  /// contrôleur : au démarrage, une reconstruction du ProviderScope les
  /// laissait écrire dans un notifier déjà jeté — « Tried to use
  /// AuthController after `dispose` was called », exception non rattrapée
  /// qui interrompait la restauration de session en plein milieu.
  void _setState(AuthState next) {
    if (!mounted) return;
    state = next;
    _push.setSession(
      authenticated: next.status == AuthStatus.authenticated,
      userId: next.user?.id,
    );
  }

  /// Rouvrir l'application sans faire attendre.
  ///
  /// L'ancienne version enchaînait DEUX allers-retours réseau avant
  /// d'afficher quoi que ce soit : ouvrir le WebSocket, puis demander le
  /// profil. L'utilisateur regardait donc une roue tourner le temps de la
  /// latence — et hors réseau, jusqu'à l'expiration de la requête, soit une
  /// vingtaine de secondes devant un écran vide, alors même que toutes ses
  /// conversations sont sur l'appareil.
  ///
  /// Deux corrections, et la même idée derrière les deux : rien de ce qui
  /// n'est pas nécessaire pour AFFICHER ne doit être attendu.
  ///
  /// 1. Le profil connu ouvre l'écran tout de suite. L'identité de
  ///    quelqu'un ne change pas d'un lancement à l'autre ; la redemander
  ///    avant d'afficher fait payer un aller-retour à chaque ouverture. Le
  ///    rafraîchissement se fait derrière, et corrige l'écran s'il le faut.
  /// 2. Le WebSocket n'est plus attendu. Savoir qui est connecté ne dépend
  ///    pas de l'ouverture d'une socket ; il se connecte en parallèle.
  Future<void> _restoreSession() async {
    if (!await _repository.hasSession()) {
      _setState(AuthState.unauthenticated);
      return;
    }

    unawaited(_ws.connect());

    final cached = await _repository.cachedProfile();
    if (cached != null) {
      _setState(AuthState.authenticated(cached));
      _push.drainPendingAcceptedCall();
      unawaited(_push.registerCurrentToken());
      // Le rafraîchissement suit, sans bloquer : il met à jour le nom,
      // l'avatar et le forfait, et rattrape un jeton révoqué depuis la
      // dernière ouverture (voir _loadProfile, qui déconnecte sur 401).
      unawaited(_loadProfile());
      return;
    }

    // Première ouverture après installation : il n'y a rien en cache, on
    // attend le profil. C'est le seul cas où l'écran d'attente est mérité.
    await _loadProfile();
  }

  /// Charge le profil, et décide de l'état d'après la RAISON de l'échec.
  ///
  /// L'ancienne version traitait tous les échecs de la même façon : elle
  /// posait `AuthState(status: authenticated)` SANS utilisateur, en pariant
  /// qu'un 401 ferait rebondir l'écran suivant vers /phone. Pour un jeton
  /// périmé, c'était vrai. Pour un simple hoquet réseau, non : la session
  /// restait valable, les listes se chargeaient — et l'application passait
  /// « authentifiée sans identité ».
  ///
  /// Ce n'est pas un détail d'état : `myUserId` en découle, et tout l'écran
  /// d'accueil s'en sert. Toucher une conversation ne faisait alors
  /// strictement rien, sans message ni requête. C'est le symptôme qu'on
  /// cherchait.
  Future<bool> _loadProfile() async {
    try {
      final user = await _repository.getMyProfile();
      _setState(AuthState.authenticated(user));
      _push.drainPendingAcceptedCall();
      await _push.registerCurrentToken();
      return true;
    } on ApiException catch (exc) {
      if (exc.statusCode == 401) {
        // Jeton périmé ou révoqué : la session n'existe plus. On le dit,
        // plutôt que de laisser un écran suivant le découvrir.
        await _repository.logout();
        _ws.disconnect();
        _setState(AuthState.unauthenticated);
        return false;
      }
      _markAuthenticatedWithoutProfile();
      return false;
    } catch (_) {
      // Réseau coupé, serveur qui ne répond pas : la session est intacte.
      _markAuthenticatedWithoutProfile();
      return false;
    }
  }

  /// Session valable, profil manquant — un état de repli, pas un état stable.
  ///
  /// L'application reste utilisable (les listes ont leur cache hors ligne),
  /// et `ensureProfile()` permet de retenter au moment où l'identité devient
  /// nécessaire.
  void _markAuthenticatedWithoutProfile() {
    // Un profil DÉJÀ connu ne se perd pas parce qu'un rafraîchissement a
    // échoué. Depuis que l'application ouvre sur le profil en cache et
    // rafraîchit derrière, écraser l'état ici reviendrait à vider
    // l'identité d'un utilisateur dont l'écran est déjà affiché — et
    // `myUserId` en découle, donc toucher une conversation ne ferait plus
    // rien. C'est exactement le défaut qu'on vient de corriger.
    final known = state.user;
    if (known != null) {
      unawaited(_push.registerCurrentToken());
      return;
    }
    _setState(const AuthState(status: AuthStatus.authenticated));
    // Le jeton push s'enregistre quand même : il ne dépend pas du profil, et
    // l'oublier ici privait l'appareil de notifications jusqu'au redémarrage.
    unawaited(_push.registerCurrentToken());
  }

  /// Le profil, en le rechargeant s'il manque.
  ///
  /// À appeler avant toute action qui exige de savoir QUI est connecté. Sans
  /// ce rattrapage, ces actions échouaient en silence.
  Future<PokouUser?> ensureProfile() async {
    final known = state.user;
    if (known != null) return known;
    await _loadProfile();
    return state.user;
  }

  void setCertificationStatus({
    bool? isVerified,
    bool? isCertificationPending,
    bool? isCertifiedSeller,
    DateTime? certifiedSellerUntil,
  }) {
    if (state.user != null) {
      final updated = state.user!.copyWith(
        isVerified: isVerified ?? state.user!.isVerified,
        isCertificationPending:
            isCertificationPending ?? state.user!.isCertificationPending,
        isCertifiedSeller: isCertifiedSeller ?? state.user!.isCertifiedSeller,
        certifiedSellerUntil: certifiedSellerUntil,
      );
      _setState(AuthState.authenticated(updated));
    }
  }

  Future<int> requestOtp(String phone, {String channel = 'both'}) =>
      _repository.requestOtp(phone, channel: channel);

  /// Lève [TwoStepRequired] quand le compte exige aussi son code : l'écran
  /// demande alors le code, puis appelle [verifyTwoStep].
  Future<void> verifyOtp({required String phone, required String code}) async {
    final user = await _repository.verifyOtp(phone: phone, code: code);
    await _onSignedIn(user);
  }

  Future<void> verifyTwoStep({
    required String verificationToken,
    required String pin,
  }) async {
    final user = await _repository.verifyTwoStep(
      verificationToken: verificationToken,
      pin: pin,
    );
    await _onSignedIn(user);
  }

  Future<void> _onSignedIn(PokouUser user) async {
    await _ws.connect();
    _setState(AuthState.authenticated(user));
    _push.drainPendingAcceptedCall();
    await _push.registerCurrentToken();
  }

  Future<void> logout() async {
    await _repository.logout();
    // Le cache local contient des conversations en clair : il ne doit pas
    // rester lisible pour le compte suivant sur un appareil partagé.
    await _messageStore.clear();
    await _linkedMahizuTokens?.clear();
    MediaKeyRing.clear();
    _ws.disconnect();
    _setState(AuthState.unauthenticated);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      ref.watch(authRepositoryProvider),
      ref.watch(wsClientProvider),
      ref.watch(pushServiceProvider),
      ref.watch(pokouMessageStoreProvider),
      linkedMahizuTokens: ref.watch(mahizuTokenStorageProvider),
    );
  },
);
