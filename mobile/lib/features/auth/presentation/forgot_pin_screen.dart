import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// REG-6 · Code PIN oublié (AUTH-11).
///
/// Seul le délai de 7 jours est proposé : la réinitialisation par e-mail
/// suppose une adresse vérifiée et un envoi de courriels, qui ne sont pas
/// encore en place. Elle est affichée, désactivée, pour que l'écran dise
/// la vérité sur ce qui existe.
class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key, required this.verificationToken});

  final String verificationToken;

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  bool _busy = false;
  String? _scheduled;
  String? _error;

  Future<void> _continue() async {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).post(
        '/auth/phone/two-step/forgot',
        body: {'verification_token': widget.verificationToken},
        authenticated: false,
      );
      final at = DateTime.parse(
        '${(response as Map<String, dynamic>)['available_at']}Z',
      ).toLocal();
      if (mounted) {
        setState(
          () => _scheduled = l.pinForgotScheduled(
            DateFormat.yMMMMd(locale).add_Hm().format(at),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = l.errorNetwork);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.pinForgot.replaceAll(' ?', ''))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l.pinForgotIntro),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RadioGroup<String>(
                      groupValue: 'wait',
                      onChanged: (_) {},
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'email',
                            enabled: false,
                            title: Text(l.pinForgotEmail),
                            subtitle: Text(l.pinForgotEmailSub),
                          ),
                          RadioListTile<String>(
                            value: 'wait',
                            title: Text(l.pinForgotWait),
                            subtitle: Text(l.pinForgotWaitSub),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.chatAiIconColor.withValues(alpha: 0.10),
                      border: Border.all(
                        color: AppColors.chatAiIconColor.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(l.pinForgotWarning),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.pinForgotMeanwhile,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  if (_scheduled != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _scheduled!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.feedbackSuccess,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.semanticError),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busy
                    ? null
                    : (_scheduled != null
                          ? () => Navigator.of(context).maybePop()
                          : _continue),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.pinForgotContinue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
