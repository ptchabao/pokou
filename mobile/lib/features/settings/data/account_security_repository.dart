import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

/// Le code PIN du COMPTE (vérification en deux étapes) et l'export des
/// données — Réglages › Compte et sécurité.
///
/// À ne pas confondre avec le verrou d'application (app_lock_screen.dart) :
/// celui-ci ne quitte jamais le téléphone et ne protège que son écran. Le
/// code du compte, lui, est demandé par le SERVEUR quand le numéro se
/// connecte sur un nouveau téléphone (voir account_privacy.py).
class AccountSecurityRepository {
  AccountSecurityRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Seul l'état : le serveur ne rend jamais le code, ni son haché.
  Future<bool> pinEnabled() async {
    final json = await _api.get('/account-privacy/two-step');
    return (json as Map<String, dynamic>)['enabled'] == true;
  }

  Future<void> enablePin(String pin) =>
      _api.post('/account-privacy/two-step', body: {'pin': pin});

  /// Le code actuel est exigé même connecté : un téléphone déverrouillé
  /// qu'on laisse traîner suffirait sinon à s'emparer du compte.
  Future<void> changePin({required String current, required String next}) =>
      _api.put(
        '/account-privacy/two-step',
        body: {'current_pin': current, 'new_pin': next},
      );

  Future<void> disablePin(String current) => _api.delete(
    '/account-privacy/two-step',
    body: {'current_pin': current},
  );

  /// Le rappel « de temps en temps » : vérifie le code sans rien changer.
  Future<void> verifyPin(String pin) =>
      _api.post('/account-privacy/two-step/verify', body: {'pin': pin});

  /// Profil, contacts et réglages, tels que le serveur les connaît.
  Future<Map<String, dynamic>> exportData() async =>
      await _api.get('/account-privacy/export') as Map<String, dynamic>;
}

final accountSecurityRepositoryProvider = Provider<AccountSecurityRepository>(
  (ref) => AccountSecurityRepository(apiClient: ref.watch(apiClientProvider)),
);

final accountPinEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(accountSecurityRepositoryProvider).pinEnabled(),
);
