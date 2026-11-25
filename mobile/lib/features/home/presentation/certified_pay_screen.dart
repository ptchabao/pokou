import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../honam/presentation/honam_controller.dart' show openPayment;
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_ui.dart' show KoryLine;
import '../../kory/presentation/kory_wallet.dart';
import '../../modules/shared/module_ui.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// « 2. Vérifier et payer » (maquette 25) : le nom à vérifier, le wallet qui
/// paie, le récapitulatif HT/TVA/TTC, puis le paiement CashPay existant
/// (openPayment). Même écran pour « 2b. Noms différents » quand on y revient
/// après un refus — [nameMismatch] bascule le texte et le bouton.
class CertifiedPayScreen extends ConsumerStatefulWidget {
  const CertifiedPayScreen({
    super.key,
    required this.plan,
    this.nameMismatch = false,
    this.onResolved,
  });

  /// Le plan choisi sur l'écran « 1. Offre » (code, label, prix HT/TTC).
  final Map<String, dynamic> plan;

  /// Vrai quand on revient ici après « Les noms ne correspondent pas » :
  /// alerte en tête, et « Vérifier à nouveau » plutôt que « Vérifier et
  /// payer ».
  final bool nameMismatch;

  /// Appelé une fois le nom corrigé avec succès (cas [nameMismatch]).
  final VoidCallback? onResolved;

  @override
  ConsumerState<CertifiedPayScreen> createState() => _CertifiedPayScreenState();
}

class _CertifiedPayScreenState extends ConsumerState<CertifiedPayScreen> {
  late final _name = TextEditingController(
    text: ref.read(authControllerProvider).user?.fullName ?? '',
  );
  String? _error;
  bool _busy = false;
  bool _otherWallet = false;
  final _walletPhone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _walletPhone.dispose();
    super.dispose();
  }

  Future<void> _verifyAndPay() async {
    final l = L.of(context);
    final api = ref.read(apiClientProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'plan': widget.plan['code'],
        if (_name.text.trim().isNotEmpty) 'full_name': _name.text.trim(),
        if (_otherWallet && _walletPhone.text.trim().isNotEmpty)
          'wallet_phone': _walletPhone.text.trim(),
      };
      if (!mounted) return;
      // La réponse entière : dans un pays de test, le paiement est simulé
      // et le badge déjà actif (`test_mode`), sans page à ouvrir.
      final simulated = await openPayment(
        context,
        api.post('/certified/subscribe', body: body),
      );
      if (simulated) {
        ref.read(authControllerProvider.notifier).reloadProfile();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l.honamFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveName() async {
    final l = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/certified/resolve-name',
            body: {'full_name': _name.text.trim()},
          );
      widget.onResolved?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l.certStillMismatch);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final plan = widget.plan;
    final priceHt = plan['price_ht'] as int? ?? 0;
    final priceTtc = plan['price_ttc'] as int? ?? priceHt;
    final vatRate = (plan['vat_rate'] as num?)?.toDouble() ?? 0;
    final planLabel =
        plan['label'] as String? ?? widget.plan['code'] as String? ?? '';
    final wallet = KoryWallet.of(ref.read(authControllerProvider).user?.phone);

    return ModuleScaffold(
      title: l.certPayTitle,
      subtitle: planLabel,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (widget.nameMismatch) ...[
            ModuleCallout(
              tone: CalloutTone.red,
              title: l.certMismatchTitle,
              text: l.certMismatchAlertBody,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            l.certNameFieldLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(errorText: _error),
          ),
          if (!widget.nameMismatch) ...[
            const SizedBox(height: 6),
            Text(
              l.certNameFieldHelp,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          ModuleSectionTitle(l.certPayWith),
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  groupValue: _otherWallet,
                  onChanged: (v) => setState(() => _otherWallet = v ?? false),
                  title: Text(wallet?.label ?? l.certOwnWallet),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  groupValue: _otherWallet,
                  onChanged: (v) => setState(() => _otherWallet = v ?? true),
                  title: Text(l.certOtherWallet),
                ),
                if (_otherWallet)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: TextField(
                      contextMenuBuilder: pokouContextMenuBuilder,
                      controller: _walletPhone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: l.certOtherWalletHint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.nameMismatch) ...[
            const SizedBox(height: 18),
            ModuleCard(
              child: Column(
                children: [
                  KoryLine(planLabel, '${formatFcfa(priceHt)} HT'),
                  KoryLine(
                    l.certVatLabel('${(vatRate * 100).toStringAsFixed(0)}'),
                    formatFcfa(priceTtc - priceHt),
                  ),
                  const Divider(height: 18),
                  KoryLine(
                    l.certTotalLabel,
                    '${formatFcfa(priceTtc)} TTC',
                    strong: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.certPaymentNote,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ModuleCallout(tone: CalloutTone.beige, text: l.certNameNeverShown),
          ],
          const SizedBox(height: 20),
          ModuleActionButton(
            label: widget.nameMismatch
                ? l.certRetryName
                : l.certVerifyAndPay(formatFcfa(priceTtc)),
            busy: _busy,
            onPressed: _busy
                ? null
                : (widget.nameMismatch ? _resolveName : _verifyAndPay),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(l.actionCancel),
            ),
          ),
        ],
      ),
    );
  }
}
