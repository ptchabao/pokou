import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_order_screen.dart';
import 'officine_courier_screens.dart';
import 'officine_ui.dart';

/// La pastille ronde en tête d'une carte d'issue : coche verte, croix grise.
class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.ok,
    required this.title,
    this.lines = const [],
  });

  final bool ok;
  final String title;
  final List<Widget> lines;

  @override
  Widget build(BuildContext context) => ModuleCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: ok
              ? AppColors.feedbackSuccess.withValues(alpha: 0.14)
              : AppColors.surfaceElevated,
          child: Icon(
            ok ? Icons.check : Icons.close,
            size: 18,
            color: ok ? AppColors.feedbackSuccess : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ...lines,
            ],
          ),
        ),
      ],
    ),
  );
}

/// Officine · R2. Ordonnance refusée (et devis expiré).
class OfficineRejectedView extends StatelessWidget {
  const OfficineRejectedView({super.key, required this.order});

  final OfficineOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final expired = order.status == 'EXPIRED';
    final at = order.stepTime(order.status) ?? order.updatedAt;
    return OfficinePage(
      actions: [OfficinePatientChatButton(order: order)],
      title: expired ? l.offiExpiredTitle : l.offiRejectedTitle,
      subtitle: at == null
          ? patient
          : l.offiPatientNotifiedAt(patient, officineTime(context, at)),
      primary: HonamPrimaryButton(
        label: l.offiBackToOrders,
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        _Outcome(
          ok: false,
          title: expired
              ? l.offiExpiredBody
              : l.offiRejectedNothingPaid(patient),
        ),
        if (!expired && order.rejectionReason != null) ...[
          officineGap,
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficineCardTitle(l.offiMessageSentToTitle(patient)),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.terracottaTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(order.rejectionReason!),
                ),
              ],
            ),
          ),
        ],
        officineGap,
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficineCardTitle(l.offiWhatNext),
              OfficineStepRow(number: 1, title: l.offiNext1(patient)),
              OfficineStepRow(number: 2, title: l.offiNext2),
              OfficineStepRow(number: 3, title: l.offiNext3),
            ],
          ),
        ),
      ],
    );
  }
}

/// Officine · A2. Rembourser la patiente.
///
/// Sous 2 h, et UNIQUEMENT sur le numéro qui a payé — même si quelqu'un
/// en donne un autre. L'officine note la référence du transfert ; la
/// patiente confirme la réception de son côté.
class OfficineRefundView extends StatefulWidget {
  const OfficineRefundView({
    super.key,
    required this.order,
    required this.run,
    required this.busy,
  });

  final OfficineOrder order;
  final OfficineRun run;
  final bool busy;

  @override
  State<OfficineRefundView> createState() => _OfficineRefundViewState();
}

class _OfficineRefundViewState extends State<OfficineRefundView> {
  late final _reference = TextEditingController(
    text: widget.order.refundReference ?? '',
  );

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  OfficineOrder get order => widget.order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final phone = order.refundToPhone ?? '';
    final cancelled = order.status == 'CANCELLED';
    final sent = order.refundSentAt != null;
    final deadline = order.refundRequestedAt?.add(const Duration(hours: 2));
    final at = order.refundRequestedAt ?? order.updatedAt;

    return OfficinePage(
      actions: [OfficinePatientChatButton(order: order)],
      title: l.offiRefundTitle(patient),
      subtitle: at == null
          ? null
          : (cancelled ? l.offiCancelledAt : l.offiRequestedAt)(
              officineTime(context, at),
            ),
      primary: HonamPrimaryButton(
        label: sent
            ? l.offiWaitingPatientConfirm(patient)
            : l.offiIRefunded(patient),
        busy: widget.busy,
        onPressed: sent
            ? null
            : () {
                final reference = _reference.text.trim();
                widget.run(
                  'refund-sent',
                  body: {if (reference.isNotEmpty) 'reference': reference},
                );
              },
      ),
      children: [
        _Outcome(
          ok: false,
          title: order.missingChoice == 'KEEP'
              ? l.offiPatientKeepsRest(patient)
              : l.offiPatientCancelsAll(patient),
          lines: [
            if (order.refundReason != null)
              Text(
                order.refundReason!,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
          ],
        ),
        officineGap,
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficineBigAmount(label: l.offiToRefund, amount: order.refundDue),
              const Divider(height: 20),
              Text(
                l.offiOnTheirNumber(phone),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                l.offiTheNumberThatPaid,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              OfficineOutlineButton(
                label: l.offiCopyNumber,
                icon: Icons.copy,
                onPressed: phone.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: phone));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l.linkCopied)));
                      },
              ),
            ],
          ),
        ),
        OfficineNote(l.offiRefundOnlyThisNumber, tone: CalloutTone.amber),
        officineGap,
        OfficineCardTitle(l.offiTransferReference),
        TextField(
          controller: _reference,
          enabled: !sent,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: l.offiTransferReferenceHint,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
        ),
        if (deadline != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.offiRefundBefore(
                      officineTime(context, deadline),
                      patient,
                      fcfa(order.refundDue),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Officine · A3. Commande annulée (remboursement confirmé, ou rien à
/// rembourser).
class OfficineCancelledView extends StatelessWidget {
  const OfficineCancelledView({super.key, required this.order});

  final OfficineOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final refunded = order.refundDue > 0;
    final at = order.stepTime('CANCELLED') ?? order.updatedAt;
    final paid = order.stepTime('PAID') != null;
    final collected = paid ? order.collected : 0;
    return OfficinePage(
      actions: [OfficinePatientChatButton(order: order)],
      title: l.offiCancelledTitle,
      subtitle: at == null
          ? patient
          : l.offiPatientCancelledAt(patient, officineTime(context, at)),
      primary: HonamPrimaryButton(
        label: l.offiBackToOrders,
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        if (refunded)
          _Outcome(
            ok: true,
            title: l.offiRefundConfirmed,
            lines: [
              Text(
                order.refundSentAt == null
                    ? l.offiRefundSentTo(fcfa(order.refundDue), patient)
                    : l.offiRefundSentToAt(
                        fcfa(order.refundDue),
                        patient,
                        officineTime(context, order.refundSentAt!),
                      ),
                style: const TextStyle(fontSize: 13),
              ),
              if (order.refundReference != null)
                Text(
                  l.offiReference(order.refundReference!),
                  style: const TextStyle(fontSize: 13),
                ),
              if (order.refundConfirmedAt != null)
                Text(
                  '✓ ${l.offiPatientConfirmedAt(patient, officineTime(context, order.refundConfirmedAt!))}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.feedbackSuccess,
                  ),
                ),
            ],
          )
        else
          _Outcome(ok: false, title: l.offiCancelledNothingPaid),
        officineGap,
        ModuleCard(
          child: Column(
            children: [
              OfficineAmountRow(l.offiCollectedFrom(patient), fcfa(collected)),
              OfficineAmountRow(
                l.offiRefundedTo(patient),
                '−${fcfa(order.refundDue)}',
              ),
              OfficineAmountRow(l.offiCourseNoCourier, fcfa(0), muted: true),
              const Divider(height: 16),
              OfficineAmountRow(
                l.offiLeftForPharmacy,
                fcfa(collected - order.refundDue),
                strong: true,
              ),
            ],
          ),
        ),
        if (order.missingReason != null || order.refundReason != null) ...[
          officineGap,
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficineCardTitle(l.offiWhatHonamKeeps),
                Text(
                  l.offiKeptInHistory(
                    order.missingReason ?? order.refundReason ?? '',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
