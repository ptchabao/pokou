import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../core/widgets/pokou_background.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';
import 'forgot_pin_screen.dart';
import 'onboarding_screen.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Seconde étape de la connexion : le code du compte, après le SMS.
///
/// L'OTP ne délivre aucune session à un compte protégé — seulement un
/// laissez-passer de 5 minutes. Ce code-ci la débloque. Les refus du
/// serveur (code faux, trop d'essais, laissez-passer expiré) sont rédigés
/// pour être lus : ils s'affichent tels quels.
class TwoStepPinScreen extends ConsumerStatefulWidget {
  const TwoStepPinScreen({super.key, required this.verificationToken});

  final String verificationToken;

  @override
  ConsumerState<TwoStepPinScreen> createState() => _TwoStepPinScreenState();
}

const _pinLength = 6;

class _TwoStepPinScreenState extends ConsumerState<TwoStepPinScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Exactement 6 chiffres (voir _validate_pin, account_privacy.py) : un
  // bouton actif avant ça laisserait envoyer un code tronqué pour rien.
  bool get _canSubmit =>
      !_submitting && _pinController.text.trim().length == _pinLength;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l = L.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyTwoStep(
            verificationToken: widget.verificationToken,
            pin: _pinController.text.trim(),
          );
      final next = await routeAfterSignIn(ref);
      if (mounted) context.go(next);
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(l.errorNetwork);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = false;
      _error = message;
      _pinController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PokouBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: PokouBackButton(),
                ),
                const SizedBox(height: 16),
                // Maquette Connexion · 1 : un bouclier, pas un cadenas — ce
                // code protège le COMPTE, pas un simple verrou d'écran.
                Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: AppColors.accentPrimaryDark,
                ),
                const SizedBox(height: 24),
                Text(
                  l.pinTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.twoStepBody,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l.twoStepPinLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _PinBoxes(
                  controller: _pinController,
                  focusNode: _focusNode,
                  onSubmitted: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.semanticError,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ForgotPinScreen(
                                verificationToken: widget.verificationToken,
                              ),
                            ),
                          ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l.pinForgot),
                  ),
                ),
                const SizedBox(height: 16),
                // REG-6 : le délai de 7 jours (PIN_RESET_DELAY côté serveur)
                // avant qu'une reconnexion au seul SMS soit acceptée.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.twoStepRecoveryNote,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.actionContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 6 cases encadrées pour le code PIN (maquette Connexion · 1), sur le même
/// principe que les cases du code SMS : un champ invisible capte la saisie,
/// les cases n'en affichent qu'un rendu — ici un point plutôt que le
/// chiffre, le code restant masqué.
class _PinBoxes extends StatelessWidget {
  const _PinBoxes({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final filled = controller.text.length;
        return GestureDetector(
          onTap: () => focusNode.requestFocus(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _pinLength; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      _PinBox(filled: i < filled, active: i == filled),
                    ],
                  ],
                ),
              ),
              Opacity(
                opacity: 0,
                child: SizedBox(
                  width: _pinLength * 48,
                  child: TextField(
                    contextMenuBuilder: pokouContextMenuBuilder,
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: _pinLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => onSubmitted(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PinBox extends StatelessWidget {
  const _PinBox({required this.filled, required this.active});

  final bool filled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: active ? AppColors.focusRing : AppColors.border,
          width: active ? 2 : 1,
        ),
      ),
      child: filled
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
