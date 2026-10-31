import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../core/widgets/pokou_background.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';
import 'onboarding_screen.dart';

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

class _TwoStepPinScreenState extends ConsumerState<TwoStepPinScreen> {
  final _pinController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_submitting && _pinController.text.trim().length >= 4;

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
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: AppColors.accentPrimaryDark,
                ),
                const SizedBox(height: 24),
                Text(
                  l.twoStepTitle,
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
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(hintText: l.twoStepHint),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: AppColors.semanticError,
                      fontSize: 13,
                    ),
                  ),
                ],
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
