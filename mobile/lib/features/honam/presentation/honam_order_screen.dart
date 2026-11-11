import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../modules/shared/module_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';
import 'courier_tracking.dart';
import 'honam_send_screen.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Le suivi d'une commande (fil de suivi, NAV-04) : devis, paiement à
/// l'officine, code de remise, et les cas particuliers — refus, paiement non
/// reçu, produit manquant.
class HonamOrderScreen extends ConsumerWidget {
  const HonamOrderScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final async = ref.watch(honamOrderProvider(orderId));

    Future<void> runWith(String action, Map<String, dynamic>? body) async {
      try {
        await ref
            .read(honamRepositoryProvider)
            .action(orderId, action, body: body);
        HapticFeedback.lightImpact();
        ref.invalidate(honamOrderProvider(orderId));
        ref.invalidate(honamOrdersProvider);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.honamFailed)));
      }
    }

    Future<void> run(String action) => runWith(action, null);

    return ModuleScaffold(
      title: l.honamOrderTitle('$orderId'),
      subtitle: async.valueOrNull?.pharmacy?.name,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ModuleEmptyState(
          icon: Icons.cloud_off,
          title: l.honamFailed,
          message: l.modulesCheckNetwork,
        ),
        data: (order) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(honamOrderProvider(orderId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _StatusHeader(order: order),
              if (order.status == 'REJECTED' || order.status == 'EXPIRED') ...[
                if (order.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  Text(l.honamReason(order.rejectionReason!)),
                ],
                const SizedBox(height: 12),
                ModuleActionButton(
                  label: l.honamResend,
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          HonamSendScreen(resendFromOrderId: order.id),
                    ),
                  ),
                ),
              ],
              if (order.quoteItems.isNotEmpty) _Quote(order: order),
              if (order.status == 'QUOTED') ...[
                const SizedBox(height: 12),
                ModuleActionButton(
                  label: l.honamAcceptQuote,
                  onPressed: () => run('accept'),
                ),
              ],
              if (order.status == 'ACCEPTED')
                _PayStep(order: order, onDeclare: () => run('declare-paid')),
              if (order.deliveryCode != null) _Code(order: order),
              if (order.status == 'IN_DELIVERY' ||
                  (order.status == 'READY' && order.courierName != null))
                CourierTrackingCard(orderId: order.id),
              if (order.awaitsMissingChoice) ...[
                const SizedBox(height: 12),
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.honamMissingTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.honamMissingBody(
                          formatFcfa(order.missingAmount!),
                          order.missingReason ?? '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ModuleActionButton(
                        label: l.honamKeepRest,
                        onPressed: () =>
                            runWith('missing-choice', {'choice': 'KEEP'}),
                      ),
                      const SizedBox(height: 8),
                      ModuleQuietButton(
                        label: l.honamCancelAll,
                        onPressed: () =>
                            runWith('missing-choice', {'choice': 'CANCEL'}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.honamRefundDelay,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (order.refundDue > 0 && !order.refundConfirmed) ...[
                const SizedBox(height: 12),
                ModuleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.honamRefundDue(
                          formatFcfa(order.refundDue),
                          order.refundReason ?? '',
                        ),
                      ),
                      Text(
                        l.honamRefundDelay,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ModuleQuietButton(
                        label: l.honamRefundReceived,
                        onPressed: () => run('refund-received'),
                      ),
                    ],
                  ),
                ),
              ],
              if (const {
                'SUBMITTED',
                'QUOTED',
                'ACCEPTED',
              }.contains(order.status)) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => run('cancel'),
                  child: Text(l.honamCancel),
                ),
              ],
              ModuleSectionTitle(l.honamTimeline),
              for (final step in order.timeline) _Step(step: step),
              _OrderMessages(orderId: order.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderMessages extends ConsumerStatefulWidget {
  const _OrderMessages({required this.orderId});

  final int orderId;

  @override
  ConsumerState<_OrderMessages> createState() => _OrderMessagesState();
}

class _OrderMessagesState extends ConsumerState<_OrderMessages> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(honamRepositoryProvider)
          .sendOrderMessage(widget.orderId, body);
      _controller.clear();
      ref.invalidate(honamOrderMessagesProvider(widget.orderId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).honamFailed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(honamOrderMessagesProvider(widget.orderId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleSectionTitle(L.of(context).honamOrderMessages),
        messages.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            L.of(context).honamFailed,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          data: (items) => Column(
            children: [
              for (final message in items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(message.senderName ?? message.senderRole),
                  subtitle: Text(message.body),
                  trailing: Text(
                    DateFormat.Hm().format(message.createdAt.toLocal()),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                controller: _controller,
                maxLength: 1000,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: L.of(context).honamWriteMessage,
                  counterText: '',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              tooltip: L.of(context).actionSend,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ModuleCard(
      child: Row(
        children: [
          const PokouIcon(
            PokouModuleIcon.honam,
            color: AppColors.feedbackSuccess,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  honamStatusLabel(l, order.status),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  order.deliveryAddress,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                if (order.courierName != null)
                  Text(
                    order.courierName!,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    const figures = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModuleSectionTitle(l.honamQuote),
        ModuleCard(
          child: Column(
            children: [
              for (final item in order.quoteItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity} × ${item.name}',
                          style: item.available
                              ? null
                              : TextStyle(
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                        ),
                      ),
                      Text(
                        item.available
                            ? formatFcfa(item.unitPrice * item.quantity)
                            : l.honamUnavailableItem,
                        style: figures,
                      ),
                    ],
                  ),
                ),
              const Divider(),
              _line(l.honamMedicines, formatFcfa(order.medicinesTotal ?? 0)),
              _line(l.honamDelivery, formatFcfa(order.deliveryPrice ?? 0)),
              _line(l.honamTotal, formatFcfa(order.total ?? 0), bold: true),
              if (order.originalRequired) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: AppColors.feedbackInfo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.honamOriginal)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.w600 : null),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _PayStep extends StatelessWidget {
  const _PayStep({required this.order, required this.onDeclare});

  final HonamOrder order;
  final VoidCallback onDeclare;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final phone = order.payToPhone ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ModuleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.honamPayTo(formatFcfa(order.total ?? 0), phone)),
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: phone)),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l.koryCopyPhone),
            ),
            if (order.paymentNotReceived)
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.feedbackDanger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.honamPaymentNotReceived,
                      style: const TextStyle(color: AppColors.feedbackDanger),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            order.patientPaidDeclared
                ? Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top,
                        color: AppColors.feedbackWarning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.honamPaidDeclared)),
                    ],
                  )
                : ModuleActionButton(
                    label: l.honamDeclarePaid,
                    onPressed: onDeclare,
                  ),
          ],
        ),
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ModuleCard(
        child: Column(
          children: [
            Text(l.honamCode, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Semantics(
              label: order.deliveryCode!.split('').join(' '),
              child: Text(
                order.deliveryCode!,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 6,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(l.honamCodeHelp, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.step});

  final TimelineStep step;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.radio_button_checked, size: 16),
      title: Text(step.note ?? honamStatusLabel(l, step.status)),
      subtitle: Text(
        DateFormat.yMMMd(locale).add_Hm().format(step.at.toLocal()),
      ),
    );
  }
}
