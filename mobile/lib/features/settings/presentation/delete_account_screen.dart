import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/security/app_lock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// REG-7 · Supprimer mon compte (AUTH-06, AUTH-12, CERT-15).
///
/// Le serveur exige qu'on retape son numéro (`confirm_phone`) : la
/// comparaison se fait chiffres contre chiffres, côté serveur. On la refait
/// ici seulement pour désactiver le bouton tant que la saisie ne correspond
/// pas — le geste ne doit pas pouvoir être un glissement de doigt.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _phone = TextEditingController();
  bool _deleting = false;
  String? _error;

  static String _digits(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    _phone.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _matches {
    final mine = _digits(ref.read(authControllerProvider).user?.phone);
    return mine.isNotEmpty && _digits(_phone.text) == mine;
  }

  Future<void> _delete() async {
    final l = L.of(context);
    if (!_matches) {
      setState(() => _error = l.deleteAccountMismatch);
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).delete(
        '/account-privacy/account',
        body: {'confirm_phone': _phone.text.trim()},
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e.statusCode == 400 ? l.deleteAccountMismatch : e.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = l.deleteAccountFailed;
      });
      return;
    }
    // Le compte n'existe plus côté serveur : on efface ce qui reste sur ce
    // téléphone (jetons, cache des discussions, clés de médias, verrou).
    await ref.read(appLockProvider.notifier).forgetOnLogout();
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.deleteAccountTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.semanticError.withValues(alpha: 0.10),
                      border: Border.all(
                        color: AppColors.semanticError.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.semanticError,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.deleteAccountWarning,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    title: l.deleteAccountRemovedTitle,
                    lines: [
                      l.deleteAccountRemovedProfile,
                      l.deleteAccountRemovedChats,
                      l.deleteAccountRemovedBadge,
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: l.deleteAccountKeptTitle,
                    lines: [
                      l.deleteAccountKeptMessages,
                      l.deleteAccountKeptProof,
                      l.deleteAccountKeptKory,
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    enabled: !_deleting,
                    decoration: InputDecoration(
                      labelText: l.deleteAccountConfirmLabel,
                      hintText: '+228 90 00 00 00',
                      errorText: _error,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.semanticError,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _deleting || !_matches ? null : _delete,
                    child: _deleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l.deleteAccountTitle),
                  ),
                  TextButton(
                    onPressed: _deleting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text(l.actionCancel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $line',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
