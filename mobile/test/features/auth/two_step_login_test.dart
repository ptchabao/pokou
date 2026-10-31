import 'package:flutter_test/flutter_test.dart';
import 'package:pokou/core/api/api_client.dart';
import 'package:pokou/core/storage/secure_token_storage.dart';
import 'package:pokou/features/auth/data/auth_repository.dart';

/// La connexion d'un compte protégé par un code.
///
/// `verifyOtp` lisait un `access_token` absent de la réponse : le serveur
/// ne délivre aucune session tant que le code du compte n'a pas été donné.
/// Le compte ne pouvait plus se connecter du tout.
class _FakeApi extends ApiClient {
  _FakeApi(this.responses) : super(baseUrl: 'https://inutilise');

  final Map<String, Map<String, dynamic>> responses;
  final calls = <String, Map<String, dynamic>?>{};

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    calls[path] = body;
    return responses[path];
  }
}

class _FakeTokens extends SecureTokenStorage {
  String? access;
  String? refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> saveProfile(String json) async {}
}

const _session = {
  'access_token': 'acces',
  'refresh_token': 'rafraichissement',
  'user': {'id': 8, 'phone': '+22890000000', 'plan': 'free'},
};

void main() {
  test('un compte protégé ne reçoit pas de session au seul SMS', () async {
    final tokens = _FakeTokens();
    final repository = AuthRepository(
      apiClient: _FakeApi({
        '/auth/phone/verify-otp': {
          'two_step_required': true,
          'verification_token': 'laissez-passer',
          'expires_in': 300,
        },
      }),
      tokenStorage: tokens,
    );

    await expectLater(
      repository.verifyOtp(phone: '+22890000000', code: '123456'),
      throwsA(
        isA<TwoStepRequired>().having(
          (e) => e.verificationToken,
          'verificationToken',
          'laissez-passer',
        ),
      ),
    );
    expect(tokens.access, isNull);
  });

  test('le code du compte ouvre la session', () async {
    final tokens = _FakeTokens();
    final api = _FakeApi({'/auth/phone/two-step': _session});
    final repository = AuthRepository(apiClient: api, tokenStorage: tokens);

    final user = await repository.verifyTwoStep(
      verificationToken: 'laissez-passer',
      pin: '2468',
    );

    expect(user.id, 8);
    expect(tokens.access, 'acces');
    expect(api.calls['/auth/phone/two-step'], {
      'verification_token': 'laissez-passer',
      'pin': '2468',
    });
  });

  test('sans code exigé, le SMS ouvre la session comme avant', () async {
    final tokens = _FakeTokens();
    final repository = AuthRepository(
      apiClient: _FakeApi({'/auth/phone/verify-otp': _session}),
      tokenStorage: tokens,
    );

    final user = await repository.verifyOtp(
      phone: '+22890000000',
      code: '123456',
    );
    expect(user.id, 8);
    expect(tokens.refresh, 'rafraichissement');
  });
}
