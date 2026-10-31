import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_exceptions.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Verrouillage de l'application par code (Profil > Confidentialité &
/// Sécurité). Un code à 4-8 chiffres gardé dans le Keystore/Keychain, pas de
/// biométrie : `local_auth` exigerait de faire hériter MainActivity de
/// FlutterFragmentActivity et d'ajouter la permission USE_BIOMETRIC — à faire
/// dans un second temps, sans bloquer le verrouillage lui-même.
///
/// Ce verrou protège l'écran, pas les données : il n'empêche pas de lire la
/// base locale avec un accès physique à l'appareil. C'est la même garantie
/// que le verrou de conversation de WhatsApp, et rien de plus.
class AppLockState {
  const AppLockState({this.enabled = false, this.locked = false, this.loaded = false});

  final bool enabled;

  /// Écran de saisie du code affiché par-dessus l'app.
  final bool locked;

  /// Le coffre a été lu au moins une fois — évite d'afficher brièvement une
  /// app déverrouillée au démarrage alors qu'un code existe.
  final bool loaded;

  AppLockState copyWith({bool? enabled, bool? locked, bool? loaded}) => AppLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
        loaded: loaded ?? this.loaded,
      );
}

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        super(const AppLockState()) {
    _load();
  }

  final FlutterSecureStorage _storage;

  static const _pinKey = 'pokou_app_lock_pin';

  Future<void> _load() async {
    String? pin;
    try {
      pin = await _storage.read(key: _pinKey);
    } catch (_) {
      // Coffre illisible : on démarre déverrouillé plutôt que d'enfermer
      // l'utilisateur hors de son app.
    }
    final enabled = pin != null && pin.isNotEmpty;
    state = AppLockState(enabled: enabled, locked: enabled, loaded: true);
  }

  Future<bool> setPin(String pin) async {
    if (pin.length < 4) return false;
    try {
      await _storage.write(key: _pinKey, value: pin);
    } catch (_) {
      return false;
    }
    state = state.copyWith(enabled: true, locked: false);
    return true;
  }

  /// Désactivation : exige le code actuel, sinon n'importe qui pourrait
  /// lever le verrou depuis l'écran de réglages une fois l'app ouverte.
  Future<bool> disable(String pin) async {
    if (!await verify(pin)) return false;
    await _forget();
    return true;
  }

  Future<bool> verify(String pin) async {
    try {
      final stored = await _storage.read(key: _pinKey);
      return stored != null && stored == pin;
    } catch (_) {
      return false;
    }
  }

  Future<void> unlock(String pin) async {
    if (await verify(pin)) state = state.copyWith(locked: false);
  }

  /// Appelé à la déconnexion : sans ça, un code oublié laisserait l'app
  /// verrouillée sur l'écran de connexion, sans aucun moyen d'en sortir
  /// autrement qu'en réinstallant.
  Future<void> forgetOnLogout() => _forget();

  /// Code oublié, après vérification du numéro par code à usage unique
  /// (voir _ForgottenPinSheet). Le verrou est levé ET retiré : la personne
  /// reprend la main sur son app et pourra en choisir un nouveau depuis les
  /// réglages, plutôt que de rester dehors.
  Future<void> resetAfterPhoneVerification() => _forget();

  Future<void> _forget() async {
    try {
      await _storage.delete(key: _pinKey);
    } catch (_) {}
    state = const AppLockState(enabled: false, locked: false, loaded: true);
  }

  /// Mise en arrière-plan — reverrouille pour que la prochaine ouverture
  /// demande le code (comportement attendu d'un verrou d'app).
  void lockIfEnabled() {
    if (state.enabled && !state.locked) state = state.copyWith(locked: true);
  }
}

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController();
});

/// Enveloppe l'app entière : superpose l'écran de code quand le verrou est
/// actif. En Stack et non en remplacement, pour que l'état des écrans en
/// dessous (conversation ouverte, appel en cours) survive au verrouillage.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // `paused` et non `inactive` : `inactive` se déclenche aussi pour un
    // simple panneau de notifications tiré vers le bas ou une demande de
    // permission, ce qui verrouillerait l'app en pleine utilisation.
    if (lifecycleState == AppLifecycleState.paused) {
      ref.read(appLockProvider.notifier).lockIfEnabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    return Stack(
      children: [
        widget.child,
        if (lock.locked) const Positioned.fill(child: _LockScreen()),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  final _controller = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Code oublié — le code n'existe que sur cet appareil, donc la seule
  /// preuve d'identité possible est celle qui a servi à ouvrir le compte :
  /// un code à usage unique envoyé au numéro (SMS + WhatsApp, voir
  /// api/app/services/otp_service.py). La déconnexion reste proposée en
  /// dernier recours dans cette feuille, pour un numéro devenu injoignable.
  Future<void> _recoverForgottenPin() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (_) => const _ForgottenPinSheet(),
    );
  }

  Future<void> _submit() async {
    final pin = _controller.text;
    final notifier = ref.read(appLockProvider.notifier);
    if (await notifier.verify(pin)) {
      await notifier.unlock(pin);
      return;
    }
    if (mounted) {
      setState(() => _wrong = true);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 40, color: AppColors.accentPrimaryDark),
                const SizedBox(height: 16),
                Text(
                  L.of(context).lockScreenTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _wrong ? L.of(context).lockWrongCode : L.of(context).lockEnterToContinue,
                  style: TextStyle(
                    fontSize: 13,
                    color: _wrong ? AppColors.semanticError : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                  decoration: const InputDecoration(counterText: '', hintText: '••••'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(L.of(context).lockUnlock),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _recoverForgottenPin,
                  child: Text(
                    L.of(context).lockForgotQuestion,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Récupération d'un code oublié. Le code de verrouillage ne quitte jamais
/// l'appareil et n'est donc pas récupérable ; ce qu'on vérifie ici, c'est la
/// propriété du NUMÉRO — la même preuve qui a servi à créer le compte. Une
/// fois vérifiée, le verrou est retiré (pas contourné) et un nouveau code
/// peut être choisi depuis les réglages.
class _ForgottenPinSheet extends ConsumerStatefulWidget {
  const _ForgottenPinSheet();

  @override
  ConsumerState<_ForgottenPinSheet> createState() => _ForgottenPinSheetState();
}

class _ForgottenPinSheetState extends ConsumerState<_ForgottenPinSheet> {
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String? get _phone => ref.read(authControllerProvider).user?.phone;

  Future<void> _sendCode() async {
    final phone = _phone;
    if (phone == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (mounted) setState(() => _codeSent = true);
    } on ApiException catch (exc) {
      // Message du serveur tel quel : il porte l'information utile
      // (trop de demandes, délai à attendre).
      if (mounted) setState(() => _error = exc.message);
    } catch (_) {
      if (mounted) setState(() => _error = L.of(context).lockSendFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final phone = _phone;
    if (phone == null || _codeController.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Rend aussi une session fraîche : le compte est le même, et le jeton
      // en cours a pu expirer pendant que l'app était verrouillée.
      await ref.read(authControllerProvider.notifier).verifyOtp(
            phone: phone,
            code: _codeController.text.trim(),
          );
      await ref.read(appLockProvider.notifier).resetAfterPhoneVerification();
      if (!mounted) return;
      // Messager capturé AVANT le pop : après, ce contexte n'est plus monté.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(L.of(context).lockRemovedToast),
        ),
      );
    } on ApiException catch (exc) {
      if (mounted) setState(() => _error = exc.message);
    } catch (_) {
      if (mounted) setState(() => _error = L.of(context).lockVerifyFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logoutInstead() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(context).lockLogoutQuestion),
        content: Text(L.of(context).lockLogoutBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(L.of(context).actionCancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(L.of(context).lockLogout)),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(appLockProvider.notifier).forgetOnLogout();
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) Navigator.of(context).pop();
    ref.read(appRouterProvider).go('/phone');
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(L.of(context).lockForgotTitle,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            phone == null
                ? L.of(context).lockNoPhoneOnDevice
                : _codeSent
                    ? L.of(context).lockEnterSentCode(phone)
                    : L.of(context).lockForgotExplain(phone),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, letterSpacing: 6),
              decoration: const InputDecoration(counterText: '', hintText: '000000'),
              onSubmitted: (_) => _verifyCode(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.semanticError, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy || phone == null ? null : (_codeSent ? _verifyCode : _sendCode),
            style: ElevatedButton.styleFrom(
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_codeSent ? L.of(context).lockLift : L.of(context).lockSendCode),
          ),
          if (_codeSent)
            TextButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(L.of(context).lockResendCode, style: const TextStyle(fontSize: 13)),
            ),
          TextButton(
            onPressed: _busy ? null : _logoutInstead,
            child: Text(
              L.of(context).lockNoAccessToNumber,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
