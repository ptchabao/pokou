import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../api/api_exceptions.dart';
import 'mahizu_session.dart';
import '../../core/widgets/pokou_context_menu.dart';

/// Ce que montrent les écrans de l'assistant tant qu'aucun compte Mahizu
/// n'est rattaché : une explication, puis le parcours code → (code du
/// compte) → connecté. Le numéro est celui du compte Pokou, jamais ressaisi.
class MahizuConnectPanel extends ConsumerStatefulWidget {
  const MahizuConnectPanel({super.key});

  @override
  ConsumerState<MahizuConnectPanel> createState() => _MahizuConnectPanelState();
}

class _MahizuConnectPanelState extends ConsumerState<MahizuConnectPanel> {
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _codeController.clear();
    } on ApiException catch (exc) {
      _error = exc.message;
    } on NetworkException catch (exc) {
      _error = exc.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final link = ref.watch(mahizuSessionProvider);
    final session = ref.read(mahizuSessionProvider.notifier);
    final phone = ref.watch(authControllerProvider).user?.phone;

    final askingCode = link.status == MahizuLinkStatus.codeSent;
    final askingPin = link.status == MahizuLinkStatus.twoStepRequired;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.link_rounded, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l.mahizuConnectTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l.mahizuConnectBody(phone ?? ''),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (askingCode || askingPin) ...[
                TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: _codeController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  obscureText: askingPin,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: askingPin ? l.mahizuPinLabel : l.mahizuCodeLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() {
                          final value = _codeController.text.trim();
                          return askingPin ? session.verifyPin(value) : session.verifyCode(value);
                        }),
                  child: Text(l.mahizuConfirm),
                ),
                TextButton(
                  onPressed: _busy ? null : session.restart,
                  child: Text(l.mahizuRestart),
                ),
              ] else
                FilledButton(
                  onPressed: _busy || phone == null ? null : () => _run(() => session.requestCode(phone)),
                  child: Text(l.mahizuSendCode),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
