import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/router/app_router.dart';
import '../../../core/settings/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/account_security_repository.dart';
import 'account_pin_screen.dart';

/// Tous les combien le code PIN du compte est redemandé.
const kPinReminderEvery = Duration(days: 7);

/// « Me le redemander de temps en temps » (Code PIN) : au plus une fois par
/// semaine, un peu après l'ouverture, Pokou demande le code — pour qu'on ne
/// le découvre pas oublié le jour où l'on change de téléphone.
///
/// Branché dans main.dart. Le code est vérifié par le SERVEUR (il ne quitte
/// jamais la base) ; « Plus tard » repousse d'une semaine, comme une
/// réponse juste : le rappel n'est pas une sanction.
final accountPinReminderProvider = Provider<void>((ref) {
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.listen<AuthStatus>(
    authControllerProvider.select((state) => state.status),
    (_, status) {
      timer?.cancel();
      if (status != AuthStatus.authenticated) return;
      // Pas au démarrage même : l'écran d'accueil se pose d'abord.
      timer = Timer(const Duration(seconds: 20), () => _maybeRemind(ref));
    },
    fireImmediately: true,
  );
});

Future<void> _maybeRemind(Ref ref) async {
  final settings = ref.read(appSettingsProvider);
  if (!settings.pinReminder) return;
  final notifier = ref.read(appSettingsProvider.notifier);
  final last = DateTime.tryParse(settings.pinReminderLastAt ?? '');
  if (last == null) {
    // Premier passage : le compteur part d'aujourd'hui, sans demander.
    await notifier.markPinReminded(DateTime.now());
    return;
  }
  if (DateTime.now().toUtc().difference(last) < kPinReminderEvery) return;
  final repository = ref.read(accountSecurityRepositoryProvider);
  try {
    if (!await repository.pinEnabled()) return;
  } catch (_) {
    return;
  }
  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _PinReminderDialog(repository: repository),
  );
  await notifier.markPinReminded(DateTime.now());
}

class _PinReminderDialog extends StatefulWidget {
  const _PinReminderDialog({required this.repository});

  final AccountSecurityRepository repository;

  @override
  State<_PinReminderDialog> createState() => _PinReminderDialogState();
}

class _PinReminderDialogState extends State<_PinReminderDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final l = L.of(context);
    if (_controller.text.length != kAccountPinLength || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.verifyPin(_controller.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l.accountPinReminderOk)));
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
    return AlertDialog(
      title: Text(l.accountPinReminderTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.accountPinReminderBody),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(kAccountPinLength),
            ],
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.accountPinReminderLater),
        ),
        TextButton(
          onPressed: _busy ? null : _check,
          child: Text(l.actionContinue),
        ),
      ],
    );
  }
}
