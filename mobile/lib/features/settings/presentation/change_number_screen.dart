import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/country/country_config.dart';
import '../../../core/widgets/pokou_bottom_nav.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// REG-4 · Changer de numéro (MSG-20).
///
/// Deux temps : le code part vers le NOUVEAU numéro, puis sa saisie bascule
/// le compte. Rien ne change tant que le code n'est pas confirmé.
class ChangeNumberScreen extends ConsumerStatefulWidget {
  const ChangeNumberScreen({super.key});

  @override
  ConsumerState<ChangeNumberScreen> createState() => _ChangeNumberScreenState();
}

class _ChangeNumberScreenState extends ConsumerState<ChangeNumberScreen> {
  /// Le numéro SANS l'indicatif, saisi à côté de sa case : l'indicatif
  /// est celui du compte et ne se retape pas.
  final _phone = TextEditingController();
  String _prefix = '+';
  final _code = TextEditingController();
  String _notify = 'chatted';
  bool _busy = false;
  bool _codeSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = ref.read(authControllerProvider).user?.phone ?? '';
    _prefix = RegExp(r'^\+\d{3}').firstMatch(current)?.group(0) ?? '+';
  }

  /// Le numéro complet envoyé à l'API. Un numéro collé AVEC son indicatif
  /// (« +229… ») garde le sien : changer de pays reste possible.
  String get _newPhone {
    final typed = _phone.text.trim();
    return typed.startsWith('+') ? typed : '$_prefix $typed';
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  static String _masked(String? phone) {
    if (phone == null || phone.length < 6) return phone ?? '';
    return '${phone.substring(0, 4)} •• •• •• ${phone.substring(phone.length - 2)}';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = L.of(context).errorNetwork);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    await ref.read(apiClientProvider).post(
      '/account/phone/change/request',
      body: {'new_phone': _newPhone},
    );
    if (mounted) setState(() => _codeSent = true);
  });

  Future<void> _confirm() => _run(() async {
    final l = L.of(context);
    await ref.read(apiClientProvider).post(
      '/account/phone/change/confirm',
      body: {
        'new_phone': _newPhone,
        'code': _code.text.trim(),
        'notify': _notify,
      },
    );
    await ref.read(authControllerProvider.notifier).reloadProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.changeNumberDone)));
    Navigator.of(context).maybePop();
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final oldPhone = ref.watch(authControllerProvider).user?.phone;
    // Lot 1 (messagerie seule) : ni Kory ni encadré de collecte.
    final lot1 = isLot1(ref.watch(currentCountryConfigProvider).modules);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.changeNumberTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.changeNumberOld,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _masked(oldPhone),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.changeNumberNew,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        // L'indicatif dans sa propre case, le numéro à côté.
                        Row(
                          children: [
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _prefix,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                contextMenuBuilder: pokouContextMenuBuilder,
                                controller: _phone,
                                enabled: !_codeSent && !_busy,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: l.changeNumberHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_codeSent) ...[
                          const SizedBox(height: 12),
                          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                            controller: _code,
                            enabled: !_busy,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: l.changeNumberCodeLabel,
                              counterText: '',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.changeNumberNotify,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _Card(
                    padding: EdgeInsets.zero,
                    child: RadioGroup<String>(
                      groupValue: _notify,
                      onChanged: (v) {
                        if (v != null && !_busy) setState(() => _notify = v);
                      },
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'all',
                            title: Text(l.changeNumberNotifyAll),
                          ),
                          RadioListTile<String>(
                            value: 'chatted',
                            title: Text(l.changeNumberNotifyChatted),
                          ),
                          RadioListTile<String>(
                            value: 'none',
                            title: Text(l.changeNumberNotifyNone),
                            subtitle: Text(l.changeNumberNotifyNoneSub),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Text(
                      lot1 ? l.changeNumberInfoLot1 : l.changeNumberInfo,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  if (!lot1) ...[
                    const SizedBox(height: 12),
                    _AmberBox(text: l.changeNumberKoryWarning),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
                    : (_codeSent ? _confirm : _sendCode),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _codeSent
                            ? l.changeNumberConfirm
                            : l.changeNumberSendCode,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// Encadré ambre du système de design : une attention, pas une alerte.
class _AmberBox extends StatelessWidget {
  const _AmberBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chatAiIconColor.withValues(alpha: 0.10),
        border: Border.all(
          color: AppColors.chatAiIconColor.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.chatAiLinkColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
