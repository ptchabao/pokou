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
import 'officine_shell.dart';
import 'officine_ui.dart';

/// Officine · 1. Commandes : trois piles — ce qui attend un geste de
/// l'officine (« À traiter »), ce qui attend quelqu'un d'autre (« En
/// cours » : la patiente, un coursier), et les commandes livrées.
class OfficineOrdersTab extends ConsumerStatefulWidget {
  const OfficineOrdersTab({super.key, required this.me});

  final OfficineMe me;

  @override
  ConsumerState<OfficineOrdersTab> createState() => _OfficineOrdersTabState();
}

class _OfficineOrdersTabState extends ConsumerState<OfficineOrdersTab> {
  int _segment = 0;

  Future<void> _refresh() async {
    ref.invalidate(officineQueueProvider);
    ref.invalidate(officineOrdersByStatusProvider('DELIVERED'));
    ref.invalidate(officineMeProvider);
    await ref.read(officineQueueProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final queue = ref.watch(officineQueueProvider);
    final delivered = ref.watch(officineOrdersByStatusProvider('DELIVERED'));
    final all = queue.valueOrNull ?? const <OfficineOrder>[];
    final toDo = all.where((o) => o.needsAction).toList();
    final ongoing = all.where((o) => !o.needsAction).toList();
    // Les livrées, les plus récentes d'abord.
    final done = [...?delivered.valueOrNull]
      ..sort((a, b) => b.id.compareTo(a.id));

    final lists = [toDo, ongoing, done];
    final shown = lists[_segment];
    final loading = _segment == 2 ? delivered : queue;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          OfficineTabHeader(me: widget.me, title: l.offiOrdersTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: OfficineSegments(
              labels: [
                l.offiSegToDo(toDo.length),
                l.offiSegOngoing(ongoing.length),
                l.offiSegDelivered(done.length),
              ],
              index: _segment,
              onChanged: (i) => setState(() => _segment = i),
            ),
          ),
          if (shown.isEmpty && loading.isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (shown.isEmpty && loading.hasError)
            ModuleEmptyState(
              icon: Icons.cloud_off,
              title: l.honamFailed,
              message: l.modulesCheckNetwork,
              action: HonamPrimaryButton(
                label: l.actionRetry,
                icon: Icons.refresh,
                expanded: false,
                onPressed: _refresh,
              ),
            )
          else if (shown.isEmpty)
            ModuleEmptyState(
              icon: Icons.hourglass_empty,
              title: [
                l.offiEmptyToDo,
                l.offiEmptyOngoing,
                l.offiEmptyDelivered,
              ][_segment],
              message: l.offiEmptyBody,
            )
          else
            for (final order in shown)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: OfficineOrderCard(order: order),
              ),
        ],
      ),
    );
  }
}

/// La carte d'une commande dans la liste : ce qu'elle attend, la patiente,
/// et le geste qui la fait avancer.
class OfficineOrderCard extends ConsumerStatefulWidget {
  const OfficineOrderCard({super.key, required this.order});

  final OfficineOrder order;

  @override
  ConsumerState<OfficineOrderCard> createState() => _OfficineOrderCardState();
}

class _OfficineOrderCardState extends ConsumerState<OfficineOrderCard> {
  bool _busy = false;

  OfficineOrder get order => widget.order;

  void _open() => openOfficineOrder(context, order.id);

  /// « Demander un coursier » depuis la liste : la commande passe à PRÊTE,
  /// puis l'écran de recherche s'ouvre.
  Future<void> _askCourier() async {
    if (_busy) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(officineRepositoryProvider).act(order.id, 'ready');
      HapticFeedback.lightImpact();
      refreshOfficine(ref, order.id);
      if (mounted) _open();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final (
      String tag,
      OfficineTone tone,
      IconData icon,
    ) = switch (order.status) {
      'SUBMITTED' => (
        l.offiTagNew,
        OfficineTone.neutral,
        Icons.description_outlined,
      ),
      'QUOTED' => (
        l.offiTagQuoteSent,
        OfficineTone.neutral,
        Icons.receipt_long_outlined,
      ),
      'ACCEPTED' when order.patientPaidDeclaredAt != null => (
        l.offiTagPaymentToConfirm,
        OfficineTone.warning,
        Icons.account_balance_wallet_outlined,
      ),
      'ACCEPTED' => (
        l.offiTagPaymentAwaited,
        OfficineTone.warning,
        Icons.account_balance_wallet_outlined,
      ),
      'PAID' when order.awaitsMissingChoice => (
        l.offiTagMissingChoice,
        OfficineTone.warning,
        Icons.inventory_2_outlined,
      ),
      'PAID' => (
        l.offiTagReadyToGo,
        OfficineTone.success,
        Icons.inventory_2_outlined,
      ),
      'READY' when order.courierName == null => (
        l.offiTagSearching,
        OfficineTone.neutral,
        Icons.delivery_dining_outlined,
      ),
      'READY' => (
        l.offiTagCourierComing,
        OfficineTone.neutral,
        Icons.delivery_dining_outlined,
      ),
      'IN_DELIVERY' => (
        l.offiTagInDelivery,
        OfficineTone.neutral,
        Icons.delivery_dining_outlined,
      ),
      'DELIVERED' when order.courierPaidAt == null => (
        l.offiTagCourseToPay,
        OfficineTone.warning,
        Icons.check_circle_outline,
      ),
      _ => (
        l.offiTagDelivered,
        OfficineTone.success,
        Icons.check_circle_outline,
      ),
    };

    final String detail = switch (order.status) {
      'SUBMITTED' =>
        order.patientNote == null || order.patientNote!.isEmpty
            ? order.deliveryAddress
            : '« ${order.patientNote} »',
      'ACCEPTED' => l.offiAwaitedOnWallet(fcfa(order.total)),
      'PAID' => l.offiPaidAt(
        fcfa(order.total),
        officineTime(context, order.stepTime('PAID') ?? order.createdAt),
      ),
      'READY' || 'IN_DELIVERY' => order.courierName ?? l.offiNoCourierYet,
      'DELIVERED' => l.offiDeliveredBy(
        officineTime(context, order.deliveredAt ?? order.createdAt),
        order.courierName ?? l.honamCourier,
      ),
      _ => order.deliveryAddress,
    };

    final Widget? action = switch (order.status) {
      'SUBMITTED' => HonamPrimaryButton(
        label: l.offiMakeQuote,
        onPressed: _open,
      ),
      'ACCEPTED' when order.patientPaidDeclaredAt != null =>
        OfficineOutlineButton(label: l.offiCheckPayment, onPressed: _open),
      'PAID'
          when order.missingAmount == null || order.missingChoice == 'KEEP' =>
        OfficineOutlineButton(
          label: l.offiAskCourier,
          onPressed: _busy ? null : _askCourier,
        ),
      _ => null,
    };

    return ModuleCard(
      onTap: _open,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OfficineTag(tag, tone: tone),
              const Spacer(),
              Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                officineAgo(context, order.updatedAt ?? order.createdAt),
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HonamThumb(size: 44, child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (order.status != 'SUBMITTED')
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              order.deliveryAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }
}
