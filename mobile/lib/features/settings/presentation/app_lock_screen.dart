import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/app_lock.dart';
import '../../../core/theme/app_colors.dart';
import 'settings_widgets.dart';

/// Profil > Verrouillage de l'application. Activation, changement et
/// désactivation du code — la vérification et le verrou lui-même vivent dans
/// core/security/app_lock.dart.
class AppLockSettingsScreen extends ConsumerStatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  ConsumerState<AppLockSettingsScreen> createState() =>
      _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends ConsumerState<AppLockSettingsScreen> {
  /// Demande un code, deux fois, et ne le renvoie que si les deux saisies
  /// concordent — un code mal tapé à l'activation enfermerait l'utilisateur
  /// hors de son app.
  Future<String?> _askNewPin() async {
    final firstController = TextEditingController();
    final secondController = TextEditingController();
    String? error;

    final pin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (builderContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(builderContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                L.of(context).lockChooseCode,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                L.of(context).lockCodeRule,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: firstController,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: L.of(context).lockCode,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: secondController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: L.of(context).lockConfirmCode,
                  counterText: '',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(
                    color: AppColors.semanticError,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  final first = firstController.text;
                  if (first.length < 4) {
                    setSheetState(() => error = L.of(context).lockTooShort);
                    return;
                  }
                  if (first != secondController.text) {
                    setSheetState(() => error = L.of(context).lockMismatch);
                    return;
                  }
                  Navigator.pop(sheetContext, first);
                },
                child: Text(L.of(context).actionSave),
              ),
            ],
          ),
        ),
      ),
    );
    firstController.dispose();
    secondController.dispose();
    return pin;
  }

  /// Demande le code ACTUEL — exigé pour désactiver le verrou ou en changer,
  /// sinon quiconque tient l'app déverrouillée pourrait le lever.
  Future<String?> _askCurrentPin(String title) async {
    final controller = TextEditingController();
    final pin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: InputDecoration(
                hintText: L.of(context).lockCurrentCode,
                counterText: '',
              ),
              onSubmitted: (value) => Navigator.pop(sheetContext, value),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, controller.text),
              child: Text(L.of(context).lockValidate),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return pin;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _enable() async {
    // Les libellés sont lus avant l'await : après, le contexte peut avoir été
    // démonté et `L.of(context)` ne serait plus légitime.
    final done = L.of(context).lockEnabledToast;
    final failed = L.of(context).lockSaveFailed;
    final pin = await _askNewPin();
    if (pin == null) return;
    final ok = await ref.read(appLockProvider.notifier).setPin(pin);
    _toast(ok ? done : failed);
  }

  Future<void> _change() async {
    final l = L.of(context);
    final current = await _askCurrentPin(l.lockEnterCurrent);
    if (current == null) return;
    if (!await ref.read(appLockProvider.notifier).verify(current)) {
      _toast(l.lockWrongCode);
      return;
    }
    final pin = await _askNewPin();
    if (pin == null) return;
    final ok = await ref.read(appLockProvider.notifier).setPin(pin);
    _toast(ok ? l.lockCodeChanged : l.lockSaveFailed);
  }

  Future<void> _disable() async {
    final l = L.of(context);
    final current = await _askCurrentPin(l.lockEnterToDisable);
    if (current == null) return;
    final ok = await ref.read(appLockProvider.notifier).disable(current);
    _toast(ok ? l.lockDisabledToast : l.lockWrongCode);
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);

    return SettingsScaffold(
      title: L.of(context).lockTitle,
      children: [
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.lock_outline,
              label: L.of(context).lockByCode,
              subtitle: lock.enabled
                  ? L.of(context).lockOn
                  : L.of(context).lockOff,
              trailing: SettingsSwitch(
                value: lock.enabled,
                semanticLabel: L.of(context).lockTitle,
                onChanged: (value) => value ? _enable() : _disable(),
              ),
            ),
            if (lock.enabled)
              SettingsRow(
                icon: Icons.password_outlined,
                label: L.of(context).lockChangeCode,
                onTap: _change,
              ),
          ],
        ),
        SettingsFootnote(L.of(context).lockFootnoteKeystore),
        SettingsFootnote(L.of(context).lockFootnoteBiometrics),
      ],
    );
  }
}
