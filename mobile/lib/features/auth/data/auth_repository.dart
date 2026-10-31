import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import 'user_model.dart';

/// L'OTP est passé, mais le compte exige aussi son code : aucune session
/// n'a été délivrée. [verificationToken] est le laissez-passer de 5 minutes
/// à présenter avec le code (voir [AuthRepository.verifyTwoStep]).
///
/// Sans ce cas, `verifyOtp` lisait un `access_token` absent de la réponse
/// et plantait : un compte protégé ne pouvait plus se connecter du tout.
class TwoStepRequired implements Exception {
  const TwoStepRequired(this.verificationToken);

  final String verificationToken;
}

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SecureTokenStorage tokenStorage,
  }) : _api = apiClient,
       _tokens = tokenStorage;

  final ApiClient _api;
  final SecureTokenStorage _tokens;

  /// Returns the OTP's TTL in seconds.
  ///
  /// `channel` — « both » (défaut), « sms » ou « whatsapp ». Le renvoi ciblé
  /// sert à quelqu'un dont le code a expiré sans jamais arriver : repartir
  /// par le canal qui vient d'échouer coûte un message pour rien.
  Future<int> requestOtp(String phone, {String channel = 'both'}) async {
    final response = await _api.post(
      '/auth/phone/request-otp',
      body: {'phone': phone, 'channel': channel},
      authenticated: false,
    );
    return response['expires_in'] as int;
  }

  Future<PokouUser> verifyOtp({
    required String phone,
    required String code,
    bool acceptTerms = false,
    bool ageConfirmed = false,
  }) async {
    final response = await _api.post(
      '/auth/phone/verify-otp',
      body: {
        'phone': phone,
        'code': code,
        if (acceptTerms) 'accept_terms': true,
        if (ageConfirmed) 'age_confirmed': true,
      },
      authenticated: false,
    );
    if (response['two_step_required'] == true) {
      throw TwoStepRequired(response['verification_token'] as String);
    }
    return _openSession(response as Map<String, dynamic>);
  }

  /// Seconde étape : le code du compte, avec le laissez-passer de l'OTP.
  Future<PokouUser> verifyTwoStep({
    required String verificationToken,
    required String pin,
  }) async {
    final response = await _api.post(
      '/auth/phone/two-step',
      body: {'verification_token': verificationToken, 'pin': pin},
      authenticated: false,
    );
    return _openSession(response as Map<String, dynamic>);
  }

  Future<PokouUser> _openSession(Map<String, dynamic> response) async {
    await _tokens.saveTokens(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
    );
    final user = PokouUser.fromJson(response['user'] as Map<String, dynamic>);
    await _cache(user);
    return user;
  }

  /// Y a-t-il une session à restaurer ?
  ///
  /// C'est le jeton de RAFRAÎCHISSEMENT qui répond, pas celui d'accès.
  ///
  /// L'accès vit 30 minutes et n'est jamais effacé en expirant : sa présence
  /// ne dit donc rien de la restaurabilité d'une session. Le
  /// rafraîchissement vit 7 jours et c'est lui, et lui seul, qui permet de
  /// repartir après une nuit. Lire l'access revenait à poser la question à
  /// celui des deux qui ne connaît pas la réponse.
  Future<bool> hasSession() async {
    return await _tokens.readRefreshToken() != null;
  }

  Future<PokouUser> getMyProfile() async {
    final response = await _api.get('/users/me/profile');
    final user = PokouUser.fromJson(response as Map<String, dynamic>);
    await _cache(user);
    return user;
  }

  /// Le dernier profil connu, sans réseau.
  ///
  /// C'est ce qui permet d'ouvrir l'application sur sa liste de
  /// conversations plutôt que sur une roue qui tourne : l'identité de
  /// l'utilisateur ne change pas d'un lancement à l'autre, la redemander au
  /// serveur avant d'afficher quoi que ce soit fait payer un aller-retour à
  /// chaque ouverture — et une vingtaine de secondes hors réseau, le temps
  /// que la requête expire.
  ///
  /// L'avatar n'est pas conservé (`toJson` n'écrit que son identifiant) : il
  /// revient au rafraîchissement, une fraction de seconde plus tard. Un nom
  /// et un identifiant suffisent à ouvrir l'écran.
  Future<PokouUser?> cachedProfile() async {
    try {
      final raw = await _tokens.readProfile();
      if (raw == null) return null;
      return PokouUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Format changé entre deux versions : on repart du réseau plutôt que
      // d'empêcher le démarrage.
      return null;
    }
  }

  Future<void> _cache(PokouUser user) async {
    try {
      await _tokens.saveProfile(jsonEncode(user.toJson()));
    } catch (_) {
      // Un cache qu'on ne peut pas écrire ne doit pas faire échouer une
      // connexion qui, elle, a réussi.
    }
  }

  Future<void> logout() => _tokens.clear();
}
