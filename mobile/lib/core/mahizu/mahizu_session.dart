import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../api/api_client.dart';
import '../l10n/l10n_provider.dart';
import '../storage/secure_token_storage.dart';

/// L'API Mahizu, qui sert l'assistant (chat, Minou, contacts intelligents,
/// bilan du soir). Pokou n'a AUCUN backend en commun avec elle : c'est un
/// service tiers, avec ses propres comptes. Surchargeable au build par
/// `--dart-define=MAHIZU_API_BASE_URL=...`.
const _mahizuBaseUrl = String.fromEnvironment(
  'MAHIZU_API_BASE_URL',
  defaultValue: 'https://api.mahizu.com/api/v1',
);

/// Les jetons du compte Mahizu rattaché, rangés à part de ceux de Pokou :
/// se déconnecter de l'un ne touche pas l'autre, et un refus de Mahizu ne
/// peut jamais faire perdre la session Pokou.
final mahizuTokenStorageProvider = Provider<SecureTokenStorage>(
  (ref) => SecureTokenStorage(namespace: 'mahizu'),
);

final mahizuApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: _mahizuBaseUrl,
    tokenStorage: ref.watch(mahizuTokenStorageProvider),
    l: ref.watch(appL10nProvider),
  );
});

/// Où en est le rattachement du compte Mahizu.
enum MahizuLinkStatus { unknown, disconnected, codeSent, twoStepRequired, connected }

class MahizuLinkState {
  const MahizuLinkState(this.status, {this.phone, this.verificationToken});

  final MahizuLinkStatus status;

  /// Le numéro auquel le code a été envoyé — celui du compte Pokou.
  final String? phone;

  /// Laissez-passer de seconde étape, quand le compte Mahizu exige son code.
  final String? verificationToken;

  bool get isConnected => status == MahizuLinkStatus.connected;
}

/// Rattache un compte Mahizu par le même parcours que la connexion Pokou :
/// un code envoyé au numéro, puis, si le compte l'exige, son code personnel.
///
/// Il n'y a rien à partager entre les deux services pour que ça marche :
/// Mahizu reconnaît la personne à son numéro, comme Pokou.
class MahizuSessionController extends StateNotifier<MahizuLinkState> {
  /// [initial] fixe l'état sans relire le stockage — pour les tests.
  MahizuSessionController(this._api, this._tokens, {MahizuLinkState? initial})
    : super(initial ?? const MahizuLinkState(MahizuLinkStatus.unknown)) {
    if (initial == null) _restore();
  }

  final ApiClient _api;
  final SecureTokenStorage _tokens;

  Future<void> _restore() async {
    final refresh = await _tokens.readRefreshToken();
    if (!mounted) return;
    state = MahizuLinkState(
      refresh == null ? MahizuLinkStatus.disconnected : MahizuLinkStatus.connected,
    );
  }

  Future<void> requestCode(String phone) async {
    await _api.post(
      '/auth/phone/request-otp',
      body: {'phone': phone},
      authenticated: false,
    );
    state = MahizuLinkState(MahizuLinkStatus.codeSent, phone: phone);
  }

  Future<void> verifyCode(String code) async {
    final phone = state.phone;
    if (phone == null) return;
    final response = await _api.post(
      '/auth/phone/verify-otp',
      body: {'phone': phone, 'code': code},
      authenticated: false,
    ) as Map<String, dynamic>;
    if (response['two_step_required'] == true) {
      state = MahizuLinkState(
        MahizuLinkStatus.twoStepRequired,
        phone: phone,
        verificationToken: response['verification_token'] as String,
      );
      return;
    }
    await _open(response);
  }

  Future<void> verifyPin(String pin) async {
    final token = state.verificationToken;
    if (token == null) return;
    final response = await _api.post(
      '/auth/phone/two-step',
      body: {'verification_token': token, 'pin': pin},
      authenticated: false,
    ) as Map<String, dynamic>;
    await _open(response);
  }

  Future<void> _open(Map<String, dynamic> response) async {
    await _tokens.saveTokens(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
    );
    state = const MahizuLinkState(MahizuLinkStatus.connected);
  }

  /// Revenir à la saisie du numéro, sans rien envoyer.
  void restart() => state = const MahizuLinkState(MahizuLinkStatus.disconnected);

  Future<void> disconnect() async {
    await _tokens.clear();
    if (!mounted) return;
    state = const MahizuLinkState(MahizuLinkStatus.disconnected);
  }
}

final mahizuSessionProvider =
    StateNotifierProvider<MahizuSessionController, MahizuLinkState>((ref) {
      // Reconstruit à chaque changement de session Pokou : la déconnexion
      // efface les jetons Mahizu (voir AuthController.logout), et l'état
      // relu ensuite doit le refléter.
      ref.watch(authControllerProvider.select((s) => s.status));
      return MahizuSessionController(
        ref.watch(mahizuApiClientProvider),
        ref.watch(mahizuTokenStorageProvider),
      );
    });
