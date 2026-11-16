import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_order_screen.dart';
import 'officine_courier_screens.dart';
import 'officine_ui.dart';

/// Officine · 3. Paiement, et P2 « Paiement en attente » une fois que
/// l'officine a dit ne rien avoir reçu.
///
/// L'argent va directement de la patiente au wallet de l'officine : il ne
/// passe jamais par Pokou. L'officine ne valide qu'après l'avoir vu dans
/// son application Mobile Money ou le SMS de l'opérateur.
class OfficinePaymentView extends StatelessWidget {
  const OfficinePaymentView({
    super.key,
    required this.order,
    required this.me,
    required this.run,
    required this.busy,
  });

  final OfficineOrder order;
  final OfficineMe? me;
  final OfficineRun run;
  final bool busy;

  Future<void> _confirm(BuildContext context) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.offiConfirmPaymentTitle),
        content: Text(l.offiConfirmPaymentBody(fcfa(order.total))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.offiConfirmPaymentYes),
          ),
        ],
      ),
    );
    if (ok == true) await run('confirm-payment');
  }

  Future<void> _cancel(BuildContext context) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.offiCancelOrderTitle),
        content: Text(l.offiCancelUnpaidBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.offiCancelOrderYes),
          ),
        ],
      ),
    );
    if (ok == true) {
      await run('cancel', body: {'reason': l.offiCancelUnpaidReason});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final wallet = officineMasked(me?.pharmacy.walletPhone);
    final pending = order.paymentNotReceivedAt != null;
    final quotedAt = order.stepTime('QUOTED');
    final declared = order.patientPaidDeclaredAt;

    return OfficinePage(
      actions: [OfficinePatientChatButton(order: order)],
      title: pending ? l.offiPaymentPendingTitle : l.offiPaymentTitle(patient),
      subtitle: pending
          ? l.offiPatientRemindedAt(
              patient,
              officineTime(context, order.paymentNotReceivedAt!),
            )
          : quotedAt == null
          ? null
          : l.offiQuoteSentAt(officineTime(context, quotedAt)),
      status: pending ? null : order.status,
      primary: HonamPrimaryButton(
        label: pending ? l.offiPaymentFinallyReceived : l.offiPaymentReceived,
        busy: busy,
        onPressed: () => _confirm(context),
      ),
      secondary: pending
          ? OfficineTextAction(
              label: l.offiCancelOrder,
              danger: true,
              onPressed: busy ? null : () => _cancel(context),
            )
          : OfficineTextAction(
              label: l.offiNotYetReceived,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OfficinePaymentMissingScreen(
                    order: order,
                    walletPhone: me?.pharmacy.walletPhone,
                  ),
                ),
              ),
            ),
      children: [
        ModuleCard(
          child: OfficineBigAmount(
            label: l.offiAmountAwaited,
            amount: order.total,
            caption: wallet.isEmpty ? null : l.offiOnYourWallet(wallet),
            trailing: pending
                ? OfficineTag(l.offiPending, tone: OfficineTone.warning)
                : null,
          ),
        ),
        officineGap,
        if (declared != null && !pending) ...[
          ModuleCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.feedbackSuccess.withValues(
                    alpha: 0.14,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 18,
                    color: AppColors.feedbackSuccess,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.offiPatientDeclaredPaid(
                      patient,
                      officineTime(context, declared),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          officineGap,
        ],
        if (pending)
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficineCardTitle(l.offiFollowUp),
                for (final step in order.timeline)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            officineTime(context, step.at),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            step.note ?? honamStepLabel(l, step.status),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )
        else
          OfficineNote(l.offiCheckBeforeValidating),
        officineGap,
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficineCardTitle(l.offiOrder),
              for (final item in order.quoteItems.where((i) => i.available))
                OfficineAmountRow(
                  item.quantity > 1
                      ? '${item.name} ×${item.quantity}'
                      : item.name,
                  fcfa(item.unitPrice * item.quantity),
                ),
              OfficineAmountRow(
                l.offiCourse,
                fcfa(order.deliveryPrice),
                muted: true,
              ),
            ],
          ),
        ),
        if (pending) OfficineNote(l.offiOtherNumberNote(patient)),
      ],
    );
  }
}

/// Le libellé d'une étape du fil de suivi.
String honamStepLabel(L l, String status) => switch (status) {
  'SUBMITTED' => l.offiStepReceived,
  'QUOTED' => l.offiTimelineQuoted,
  'ACCEPTED' => l.offiTimelineAccepted,
  'PAID' => l.offiStepPaid,
  'READY' => l.offiStepReady,
  'IN_DELIVERY' => l.offiTagInDelivery,
  'DELIVERED' => l.offiStepDelivered,
  _ => l.offiTagCancelled,
};

/// Ce que l'officine constate (maquette P1).
enum _Observed { nothing, different }

/// Officine · P1. Paiement non reçu.
///
/// L'officine dit ce qu'elle constate ; la patiente est prévenue par un
/// message dans la commande, et la commande passe en « Paiement en
/// attente » (P2).
class OfficinePaymentMissingScreen extends ConsumerStatefulWidget {
  const OfficinePaymentMissingScreen({
    super.key,
    required this.order,
    this.walletPhone,
  });

  final OfficineOrder order;
  final String? walletPhone;

  @override
  ConsumerState<OfficinePaymentMissingScreen> createState() =>
      _OfficinePaymentMissingScreenState();
}

class _OfficinePaymentMissingScreenState
    extends ConsumerState<OfficinePaymentMissingScreen> {
  _Observed _observed = _Observed.nothing;
  final _amount = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _notify() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final order = widget.order;
    final patient = officinePatient(context, order);
    final wallet = officineMasked(widget.walletPhone);
    final received = int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), ''));
    if (_observed == _Observed.different && received == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    final message = _observed == _Observed.nothing
        ? l.offiNotReceivedMessage(patient, fcfa(order.total), wallet)
        : l.offiDifferentAmountMessage(
            patient,
            fcfa(received),
            fcfa(order.total),
            fcfa((order.total ?? 0) - received!),
          );
    setState(() => _busy = true);
    final repository = ref.read(officineRepositoryProvider);
    try {
      await repository.act(order.id, 'payment-not-received');
      await repository.sendMessage(order.id, message);
      HapticFeedback.lightImpact();
      refreshOfficine(ref, order.id);
      messenger.showSnackBar(
        SnackBar(content: Text(l.offiMessageSentTo(patient))),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = widget.order;
    final patient = officinePatient(context, order);
    final declared = order.patientPaidDeclaredAt;
    return OfficinePage(
      actions: [OfficinePatientChatButton(order: order)],
      title: l.offiPaymentMissingTitle,
      subtitle: l.offiPatientAwaits(patient, fcfa(order.total)),
      primary: HonamPrimaryButton(
        label: l.offiNotifyPatient(patient),
        busy: _busy,
        onPressed: _notify,
      ),
      secondary: OfficineTextAction(
        label: l.offiWaitMore,
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        if (declared != null) ...[
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficineCardTitle(l.offiWhatPatientSaid(patient)),
                OfficineAmountRow(
                  l.offiTime,
                  officineTime(context, declared),
                  muted: true,
                ),
                OfficineAmountRow(l.offiAmount, fcfa(order.total), muted: true),
              ],
            ),
          ),
          officineGap,
        ],
        OfficineCardTitle(l.offiWhatYouSee),
        OfficineChoice<_Observed>(
          value: _Observed.nothing,
          group: _observed,
          onChanged: (v) => setState(() => _observed = v),
          title: l.offiNothingReceived,
          subtitle: l.offiNothingReceivedHint(patient),
        ),
        OfficineChoice<_Observed>(
          value: _Observed.different,
          group: _observed,
          onChanged: (v) => setState(() => _observed = v),
          title: l.offiDifferentAmount,
          subtitle: l.offiDifferentAmountHint(patient),
        ),
        if (_observed == _Observed.different)
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.offiAmountReceived,
              suffixText: 'FCFA',
            ),
          ),
        OfficineNote(l.offiDontPrepareYet, tone: CalloutTone.amber),
      ],
    );
  }
}
