import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around Keychain (iOS) / Keystore (Android) — the JWT bearer
/// token is never persisted in SharedPreferences or plain files.
///
/// [namespace] préfixe les clés : la session Pokou (`pokou`) et le compte
/// Mahizu rattaché (`mahizu`, voir core/mahizu/) vivent côte à côte sans
/// jamais se marcher dessus.
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage, String namespace = 'pokou'})
      : _storage = storage ?? const FlutterSecureStorage(),
        _accessTokenKey = '${namespace}_access_token',
        _refreshTokenKey = '${namespace}_refresh_token',
        _profileKey = '${namespace}_profile';

  final FlutterSecureStorage _storage;

  final String _accessTokenKey;
  final String _refreshTokenKey;

  /// Le dernier profil connu, en JSON.
  ///
  /// Il vit ici, avec les jetons, parce qu'il a exactement la même durée de
  /// vie qu'eux : c'est la session. Le laisser ailleurs ferait survivre le
  /// nom de quelqu'un à sa déconnexion sur un téléphone partagé.
  final String _profileKey;

  /// L'état du rafraîchissement, PARTAGÉ par tous les `ApiClient` qui
  /// utilisent ce stockage — voir [SharedRefreshState].
  final SharedRefreshState refreshState = SharedRefreshState();

  String? _cachedAccessToken;
  bool _hasReadAccessToken = false;

  String? _cachedRefreshToken;
  bool _hasReadRefreshToken = false;

  String? _cachedProfile;
  bool _hasReadProfile = false;

  /// Le RAFRAÎCHISSEMENT d'abord, l'accès ensuite. L'ordre n'est pas
  /// indifférent.
  ///
  /// `FlutterSecureStorage` n'offre pas d'écriture atomique : ce sont deux
  /// opérations, et l'application peut être tuée entre les deux. Il faut
  /// donc choisir lequel des deux états de panne on préfère.
  ///
  /// - refresh écrit, access manquant → la prochaine requête part sans
  ///   jeton, reçoit 401, rafraîchit, et tout repart. **Invisible.**
  /// - access écrit, refresh manquant → le jour où l'access expire, plus
  ///   rien ne peut le renouveler. **Session perdue.**
  ///
  /// On écrit donc toujours celui qui permet de se rattraper en premier.
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _cachedAccessToken = accessToken;
    _hasReadAccessToken = true;
    _cachedRefreshToken = refreshToken;
    _hasReadRefreshToken = true;
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<String?> readAccessToken() async {
    if (_hasReadAccessToken) return _cachedAccessToken;
    _cachedAccessToken = await _storage.read(key: _accessTokenKey);
    _hasReadAccessToken = true;
    return _cachedAccessToken;
  }

  Future<String?> readRefreshToken() async {
    if (_hasReadRefreshToken) return _cachedRefreshToken;
    _cachedRefreshToken = await _storage.read(key: _refreshTokenKey);
    _hasReadRefreshToken = true;
    return _cachedRefreshToken;
  }

  Future<void> saveProfile(String json) async {
    _cachedProfile = json;
    _hasReadProfile = true;
    await _storage.write(key: _profileKey, value: json);
  }

  Future<String?> readProfile() async {
    if (_hasReadProfile) return _cachedProfile;
    _cachedProfile = await _storage.read(key: _profileKey);
    _hasReadProfile = true;
    return _cachedProfile;
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    _hasReadAccessToken = true;
    _cachedRefreshToken = null;
    _hasReadRefreshToken = true;
    _cachedProfile = null;
    _hasReadProfile = true;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _profileKey);
  }
}

/// Le rafraîchissement en cours et le recul après échec, tenus À CÔTÉ des
/// jetons plutôt que dans chaque `ApiClient`.
///
/// Le verrou vivait dans `ApiClient`. Or `apiClientProvider` est recréé
/// quand la langue de l'application change — ce qui arrive aussi à son
/// ouverture, au chargement des réglages — et l'ancienne instance survit
/// dans les dépôts qui l'ont capturée. Deux clients, deux verrous : deux
/// `/auth/refresh` partaient avec le même jeton à quelques millisecondes
/// d'écart, et la rotation finissait par déconnecter l'utilisateur
/// (journal de prod du 2026-10-02). Les jetons n'existent qu'une fois ;
/// leur rafraîchissement ne doit exister qu'une fois aussi.
class SharedRefreshState {
  Future<Object>? inFlight;
  DateTime? nextAllowedAt;
  int consecutiveFailures = 0;
}
