import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/account_security_repository.dart';
import 'settings_widgets.dart';

/// Longueur du code du compte — la même que celle qu'exige le serveur
/// (`TWO_STEP_PIN_LENGTH`).
const kAccountPinLength = 6;

/// REG-5 · Activer (ou modifier) le code PIN du compte.
///
/// Le code est demandé par le serveur quand le numéro se connecte sur un
/// nouveau téléphone : intercepter le SMS ne suffit plus à prendre le
/// compte. Il se saisit deux fois — une faute de frappe ici fermerait la
/// porte à son propriétaire.
///
/// En modification, le code ACTUEL vient d'abord : le serveur l'exige, un
/// téléphone déverrouillé qu'on laisse traîner ne doit pas suffire.
class AccountPinScreen extends ConsumerStatefulWidget {
  const AccountPinScreen({super.key, this.change = false});

  /// `true` : modifier un code déjà actif.
  final bool change;

  @override
  ConsumerState<AccountPinScreen> createState() => _AccountPinScreenState();
}

enum _Step { current, choose, confirm }

class _AccountPinScreenState extends ConsumerState<AccountPinScreen> {
  late _Step _step = widget.change ? _Step.current : _Step.choose;
  final _input = TextEditingController();
  final _focus = FocusNode();
  String _current = '';
  String _chosen = '';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _label(L l) => switch (_step) {
    _Step.current => l.accountPinCurrent,
    _Step.choose => l.accountPinChoose,
    _Step.confirm => l.accountPinConfirm,
  };

  void _onChanged(String value) {
    setState(() => _error = null);
    if (value.length < kAccountPinLength) return;
    switch (_step) {
      case _Step.current:
        _current = value;
        _next(_Step.choose);
      case _Step.choose:
        _chosen = value;
        _next(_Step.confirm);
      case _Step.confirm:
        if (value != _chosen) {
          // On repart du choix : deux codes différents, on ne sait pas
          // lequel des deux était voulu.
          _chosen = '';
          _next(_Step.choose);
          setState(() => _error = L.of(context).accountPinMismatch);
        }
    }
  }

  void _next(_Step step) {
    _input.clear();
    setState(() => _step = step);
    _focus.requestFocus();
  }

  bool get _ready =>
      _step == _Step.confirm &&
      _input.text.length == kAccountPinLength &&
      _input.text == _chosen;

  Future<void> _submit() async {
    if (!_ready || _busy) return;
    final l = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(accountSecurityRepositoryProvider);
      if (widget.change) {
        await repository.changePin(current: _current, next: _chosen);
      } else {
        await repository.enablePin(_chosen);
      }
      // Le rappel repart d'aujourd'hui : on vient de le taper deux fois.
      await ref
          .read(appSettingsProvider.notifier)
          .markPinReminded(DateTime.now());
      ref.invalidate(accountPinEnabledProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.change ? l.accountPinChanged : l.accountPinEnabled),
        ),
      );
      Navigator.of(context).maybePop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Code actuel refusé : on le redemande, le reste n'a pas de sens.
      if (widget.change && e.statusCode == 403) {
        _current = '';
        _chosen = '';
        _next(_Step.current);
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = l.errorNetwork);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.accountPinTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.key_outlined,
                        color: AppColors.accentPrimaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.accountPinIntro,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _label(l),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  PinBoxes(
                    controller: _input,
                    focusNode: _focus,
                    enabled: !_busy,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.semanticError,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SettingsCard(
                    children: [
                      SettingsRow(
                        label: l.accountPinReminder,
                        subtitle: l.accountPinReminderSub,
                        trailing: SettingsSwitch(
                          value: settings.pinReminder,
                          semanticLabel: l.accountPinReminder,
                          onChanged: ref
                              .read(appSettingsProvider.notifier)
                              .setPinReminder,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsNote(text: l.accountPinNote),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _ready && !_busy ? _submit : null,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.change ? l.accountPinSave : l.accountPinEnable),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six cases, un point par chiffre saisi. Le vrai champ est invisible
/// derrière : le clavier numérique, le collage et l'accessibilité restent
/// ceux d'un champ ordinaire.
class PinBoxes extends StatelessWidget {
  const PinBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: focusNode.requestFocus,
      child: Stack(
        children: [
          // Le champ réel, transparent, sous les cases.
          Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              enabled: enabled,
              keyboardType: TextInputType.number,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(kAccountPinLength),
              ],
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          Positioned.fill(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < kAccountPinLength; i++)
                    Container(
                      width: 42,
                      height: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          // La case à remplir se voit.
                          color: i == value.text.length
                              ? AppColors.accentPrimary
                              : AppColors.border,
                          width: i == value.text.length ? 1.6 : 1,
                        ),
                      ),
                      child: i < value.text.length
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
