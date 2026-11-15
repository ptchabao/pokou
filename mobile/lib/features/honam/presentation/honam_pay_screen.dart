import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_ui.dart';
import '../../kory/presentation/kory_wallet.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';
import 'honam_ui.dart';

/// Payer la pharmacie (maquette Honam patient 4), de wallet à wallet,
/// comme dans Kory : Pokou ne touche pas l'argent. L'écran donne le
/// montant, le numéro de la pharmacie et le code USSD de son opérateur ;
/// la référence du SMS aide la pharmacie à retrouver l'envoi.
class HonamPayScreen extends ConsumerStatefulWidget {
  const HonamPayScreen({super.key, required this.order});

  final HonamOrder order;

  @override
  ConsumerState<HonamPayScreen> createState() => _HonamPayScreenState();
}

class _HonamPayScreenState extends ConsumerState<HonamPayScreen> {
  final _reference = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _declare() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .action(
            widget.order.id,
            'declare-paid',
            body: {
              if (_reference.text.trim().isNotEmpty)
                'reference': _reference.text.trim(),
            },
          );
      HapticFeedback.lightImpact();
      ref.invalidate(honamOrderProvider(widget.order.id));
      ref.invalidate(honamOrdersProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      koryToast(context, L.of(context).honamFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = widget.order;
    final pharmacy = order.pharmacy?.name ?? l.honamUiPharmacy;
    final wallet = KoryWallet.of(order.payToPhone);
    return KoryPage(
      title: l.honamPPayTitle,
      subtitle: l.honamPOrderOf(pharmacy),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.honamDeclarePaid,
            busy: _busy,
            onPressed: _declare,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryCard(
            child: KoryFigure(
              label: l.honamPAmountToSend,
              amount: order.total ?? 0,
              caption: [
                l.honamPToPharmacy(pharmacy),
                if (wallet != null) wallet.label,
              ].join(' · '),
            ),
          ),
          const SizedBox(height: 12),
          KoryCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (wallet?.ussd != null) ...[
                  HonamLinkRow(
                    icon: Icons.dialpad,
                    title: l.honamPDialUssd,
                    subtitle: wallet!.operator,
                    onTap: () async {
                      // Le montant et le numéro se copient d'abord : le menu
                      // de l'opérateur les demande l'un après l'autre.
                      await Clipboard.setData(ClipboardData(text: wallet.phone));
                      final ok = await wallet.dialUssd();
                      if (!ok && context.mounted) koryFailed(context);
                    },
                  ),
                  Divider(height: 1, color: AppColors.border),
                ],
                HonamLinkRow(
                  icon: Icons.copy,
                  title: l.koryCopyPhone,
                  subtitle: wallet?.masked,
                  onTap: wallet == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: wallet.phone),
                          );
                          if (context.mounted) koryToast(context, l.koryCopied);
                        },
                ),
                Divider(height: 1, color: AppColors.border),
                HonamLinkRow(
                  icon: Icons.payments_outlined,
                  title: l.honamPCopyAmount,
                  subtitle: formatFcfa(order.total ?? 0),
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: '${order.total ?? 0}'),
                    );
                    if (context.mounted) koryToast(context, l.koryCopied);
                  },
                ),
              ],
            ),
          ),
          if (order.paymentNotReceived) ...[
            const SizedBox(height: 12),
            KoryNotice(tone: KoryTone.danger, text: l.honamPaymentNotReceived),
          ],
          KorySection(l.koryXTransactionRef),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _reference,
            maxLength: 64,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'XXXX-0000',
              helperText: l.honamPReferenceHelp(wallet?.operator ?? ''),
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          KoryNotice(
            tone: KoryTone.warning,
            icon: Icons.warning_amber_rounded,
            text: l.honamPCheckRecipient(pharmacy),
          ),
        ],
      ),
    );
  }
}
