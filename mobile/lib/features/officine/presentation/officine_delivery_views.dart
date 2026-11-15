import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/courier_tracking.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_courier_screens.dart';
import 'officine_order_screen.dart';
import 'officine_ui.dart';

/// Officine · A1. La préparation d'une commande payée.
///
/// On coche ce qu'on met dans le sachet. Un produit manque ? On le signale
/// ICI, pendant la préparation, avant tout appel de coursier : la patiente
/// choisit entre recevoir le reste et tout annuler, et l'officine la
/// rembourse sous 2 h, uniquement sur le numéro qui a payé.
class OfficinePreparationView extends ConsumerStatefulWidget {
  const OfficinePreparationView({
    super.key,
    required this.order,
    required this.run,
    required this.busy,
  });

  final OfficineOrder order;
  final OfficineRun run;
  final bool busy;

  @override
  ConsumerState<OfficinePreparationView> createState() =>
      _OfficinePreparationViewState();
}

class _OfficinePreparationViewState
    extends ConsumerState<OfficinePreparationView> {
  final _packed = <int>{};
  final _missing = <int>{};

  OfficineOrder get order => widget.order;

  List<({int index, String name, int quantity, int price})> get _items => [
    for (final (i, item) in order.quoteItems.indexed)
      if (item.available)
        (
          index: i,
          name: item.name,
          quantity: item.quantity,
          price: item.unitPrice * item.quantity,
        ),
  ];

  int get _missingAmount => _items
      .where((item) => _missing.contains(item.index))
      .fold(0, (sum, item) => sum + item.price);

  Future<void> _reportMissing() async {
    final l = L.of(context);
    final names = _items
        .where((item) => _missing.contains(item.index))
        .map((item) => item.name)
        .join(', ');
    final reason = l.offiMissingReason(names);
    await widget.run(
      'missing-product',
      body: {
        'amount': _missingAmount,
        'reason': reason.length > 255 ? reason.substring(0, 255) : reason,
      },
    );
  }

  Future<void> _cancelAll() async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.offiCancelOrderTitle),
        content: Text(
          l.offiCancelPaidBody(
            officinePatient(context, order),
            fcfa(order.total),
          ),
        ),
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
      await widget.run('cancel', body: {'reason': l.offiCancelPaidReason});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final paidAt = order.stepTime('PAID');
    final reported = order.missingAmount != null;
    final canAskCourier = !reported || order.missingChoice == 'KEEP';
    final kept = order.missingChoice == 'KEEP';

    final Widget primary;
    if (!reported && _missing.isNotEmpty) {
      primary = HonamPrimaryButton(
        label: l.offiNotifyPatient(patient),
        busy: widget.busy,
        onPressed: _reportMissing,
      );
    } else {
      primary = HonamPrimaryButton(
        label: canAskCourier ? l.offiAskCourier : l.offiWaitingChoice(patient),
        busy: widget.busy,
        onPressed: canAskCourier ? () => widget.run('ready') : null,
      );
    }

    return OfficinePage(
      title: l.offiPreparationTitle(patient),
      subtitle: paidAt == null
          ? null
          : l.offiPaidAt(fcfa(order.total), officineTime(context, paidAt)),
      status: order.status,
      onRefresh: () async => refreshOfficine(ref, order.id),
      primary: primary,
      secondary: reported
          ? null
          : OfficineTextAction(
              label: l.offiCancelWholeOrder,
              danger: true,
              onPressed: widget.busy ? null : _cancelAll,
            ),
      children: [
        OfficineCardTitle(l.offiProductsToPrepare),
        ModuleCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, item) in _items.indexed) ...[
                if (i > 0) const HonamHairline(indent: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _packed.contains(item.index),
                        activeColor: AppColors.feedbackSuccess,
                        onChanged: _missing.contains(item.index)
                            ? null
                            : (v) => setState(
                                () => v == true
                                    ? _packed.add(item.index)
                                    : _packed.remove(item.index),
                              ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${l.offiQuantity(item.quantity)} · ${fcfa(item.price)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!reported)
                        FilterChip(
                          label: Text(l.offiMissing),
                          selected: _missing.contains(item.index),
                          showCheckmark: false,
                          selectedColor: AppColors.terracottaTint,
                          side: BorderSide(
                            color: _missing.contains(item.index)
                                ? AppColors.accentPrimary
                                : AppColors.border,
                          ),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _missing.add(item.index);
                              _packed.remove(item.index);
                            } else {
                              _missing.remove(item.index);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        officineGap,
        if (!reported && _missing.isNotEmpty)
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficineCardTitle(l.offiHonamProposes(patient)),
                _ProposalRow(
                  title: l.offiReceiveRest,
                  subtitle: l.offiReceiveRestHint,
                  amount: fcfa(_missingAmount),
                ),
                const SizedBox(height: 8),
                _ProposalRow(
                  title: l.offiCancelAll,
                  subtitle: l.offiCancelAllHint,
                  amount: fcfa(order.total),
                ),
              ],
            ),
          ),
        if (reported)
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficineCardTitle(
                  l.offiMissingProduct,
                  trailing: OfficineTag(
                    order.missingChoice == null
                        ? l.offiWaitingChoiceShort
                        : kept
                        ? l.offiPatientKeeps
                        : l.offiTagCancelled,
                    tone: order.missingChoice == null
                        ? OfficineTone.warning
                        : OfficineTone.neutral,
                  ),
                ),
                OfficineAmountRow(
                  order.missingReason ?? l.offiMissing,
                  fcfa(order.missingAmount),
                ),
              ],
            ),
          ),
        if (kept && order.refundDue > 0) ...[
          officineGap,
          ModuleCard(
            onTap: () => openOfficineOrder(context, order.id, refund: true),
            child: Row(
              children: [
                const Icon(
                  Icons.currency_exchange,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.refundConfirmedAt != null
                        ? l.offiRefundConfirmedShort(fcfa(order.refundDue))
                        : l.offiRefundToDo(fcfa(order.refundDue), patient),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
        OfficineNote(l.offiNoCourierYetNote),
      ],
    );
  }
}

class _ProposalRow extends StatelessWidget {
  const _ProposalRow({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              L.of(context).offiRefunded,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Officine · 8. Demander un coursier, puis 9 « Aucun coursier
/// disponible » passé dix minutes sans preneur.
///
/// La course part d'abord aux livreurs habituels de l'officine, puis aux
/// coursiers de la zone. Dès qu'un coursier accepte, l'écran passe de
/// lui-même à la livraison (4).
class OfficineCourierSearchView extends ConsumerStatefulWidget {
  const OfficineCourierSearchView({
    super.key,
    required this.order,
    required this.busy,
  });

  final OfficineOrder order;
  final bool busy;

  @override
  ConsumerState<OfficineCourierSearchView> createState() =>
      _OfficineCourierSearchViewState();
}

class _OfficineCourierSearchViewState
    extends ConsumerState<OfficineCourierSearchView> {
  Timer? _tick;

  /// Passé ce délai sans preneur : l'écran 9.
  static const _noCourierAfter = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  OfficineOrder get order => widget.order;

  Future<void> _proposePickup() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final patient = officinePatient(context, order);
    try {
      await ref
          .read(officineRepositoryProvider)
          .sendMessage(
            order.id,
            l.offiPickupMessage(patient, fcfa(order.deliveryPrice)),
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l.offiMessageSentTo(patient))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final since = order.stepTime('READY') ?? order.updatedAt ?? order.createdAt;
    final elapsed = DateTime.now().toUtc().difference(since.toUtc());
    final couriers = ref.watch(officineCouriersProvider).valueOrNull;
    final priority = Duration(minutes: couriers?.priorityMinutes ?? 5);
    final hasAttached = (couriers?.items.isNotEmpty ?? false);
    final pastPriority = !hasAttached || elapsed >= priority;
    final nobody = elapsed >= _noCourierAfter;
    final subtitle = l.offiOrderOf(patient, order.deliveryAddress);

    void refresh() => refreshOfficine(ref, order.id);

    if (nobody) {
      return OfficinePage(
        title: l.offiNoCourierTitle,
        subtitle: subtitle,
        onRefresh: () async => refresh(),
        primary: HonamPrimaryButton(
          label: l.offiBackToOrders,
          onPressed: () => Navigator.of(context).pop(),
        ),
        children: [
          HonamThumb(
            size: 52,
            child: const Icon(Icons.delivery_dining_outlined),
          ),
          const SizedBox(height: 12),
          Text(
            l.offiNoCourierBody(elapsed.inMinutes),
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          OfficineOutlineButton(
            label: l.offiRetrySearch,
            icon: Icons.refresh,
            onPressed: refresh,
          ),
          officineGap,
          ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficineCardTitle(l.offiProposePickupTitle),
                Text(
                  l.offiProposePickupBody(patient, fcfa(order.deliveryPrice)),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                OfficineOutlineButton(
                  label: l.offiProposePickup,
                  expanded: false,
                  onPressed: _proposePickup,
                ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OfficineTextAction(
              label: l.offiInviteCouriers,
              icon: Icons.person_add_alt,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OfficineCouriersScreen(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return OfficinePage(
      title: l.offiAskCourierTitle,
      subtitle: subtitle,
      onRefresh: () async => refresh(),
      children: [
        ModuleCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.terracottaTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining_outlined,
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.offiSearching,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      l.offiSince(
                        elapsed.inMinutes,
                        elapsed.inSeconds.remainder(60),
                      ),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        officineGap,
        ModuleCard(
          child: Column(
            children: [
              if (hasAttached)
                OfficineStepRow(
                  title: l.offiProposedAttached,
                  subtitle: l.offiProposedAttachedHint(priority.inMinutes),
                  done: pastPriority,
                  current: !pastPriority,
                ),
              OfficineStepRow(
                title: l.offiProposedZone,
                number: hasAttached ? 2 : 1,
                current: pastPriority,
              ),
              OfficineStepRow(
                title: l.offiCourierAccepts,
                subtitle: l.offiCourierAcceptsHint,
                number: hasAttached ? 3 : 2,
              ),
            ],
          ),
        ),
        officineGap,
        ModuleCard(
          child: Column(
            children: [
              OfficineAmountRow(
                l.offiCoursePaidToCourier,
                fcfa(order.deliveryPrice),
              ),
              OfficineAmountRow(l.offiBy, l.offiByYourWallet, muted: true),
            ],
          ),
        ),
        OfficineNote(l.offiSealedNote(patient)),
      ],
    );
  }
}

/// Officine · 4. Livraison : le coursier qui a accepté, la remise du colis,
/// et ce qu'il faudra lui payer. Pendant la course, le suivi (7).
class OfficineDeliveryView extends ConsumerStatefulWidget {
  const OfficineDeliveryView({
    super.key,
    required this.order,
    required this.run,
    required this.busy,
  });

  final OfficineOrder order;
  final OfficineRun run;
  final bool busy;

  @override
  ConsumerState<OfficineDeliveryView> createState() =>
      _OfficineDeliveryViewState();
}

class _OfficineDeliveryViewState extends ConsumerState<OfficineDeliveryView> {
  final _checks = <int>{};

  OfficineOrder get order => widget.order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final courier = order.courierName ?? l.honamCourier;
    final inDelivery = order.status == 'IN_DELIVERY';
    final paidAt = order.stepTime('PAID');
    final acceptedAt = order.timeline
        .where((s) => s.status == 'READY' && s.note != null)
        .map((s) => s.at)
        .lastOrNull;
    final checks = [
      l.offiCheckSealed(patient),
      l.offiCheckDosage,
      l.offiCheckPhoto,
    ];

    return OfficinePage(
      title: l.offiDeliveryTitle(patient),
      subtitle: paidAt == null
          ? null
          : l.offiPaidAt(fcfa(order.total), officineTime(context, paidAt)),
      status: order.status,
      onRefresh: () async => refreshOfficine(ref, order.id),
      primary: inDelivery
          ? HonamPrimaryButton(
              label: l.offiFollowDelivery,
              icon: Icons.map_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OfficineTrackingScreen(order: order),
                ),
              ),
            )
          : HonamPrimaryButton(
              label: l.offiHandedTo(courier),
              busy: widget.busy,
              onPressed: _checks.length == checks.length
                  ? () => widget.run('handed-over')
                  : null,
            ),
      secondary: OfficineTextAction(
        label: l.offiReportDefault,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OfficineDefectScreen(order: order)),
        ),
      ),
      children: [
        OfficineCourierCard(
          order: order,
          caption: acceptedAt == null
              ? null
              : l.offiAcceptedAt(officineTime(context, acceptedAt)),
        ),
        if (inDelivery)
          CourierTrackingCard(orderId: order.id, asPharmacy: true),
        officineGap,
        if (!inDelivery) ...[
          ModuleCard(
            padding: const EdgeInsets.fromLTRB(4, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: OfficineCardTitle(l.offiHandover),
                ),
                for (final (i, text) in checks.indexed)
                  CheckboxListTile(
                    value: _checks.contains(i),
                    onChanged: (v) => setState(
                      () => v == true ? _checks.add(i) : _checks.remove(i),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    activeColor: AppColors.feedbackSuccess,
                    title: Text(text),
                  ),
              ],
            ),
          ),
          officineGap,
        ],
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficineCardTitle(l.offiAfterDelivery),
              Text(
                l.offiAfterDeliveryBody(patient, courier),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              OfficineAmountRow(
                l.offiCourseToPay(courier),
                fcfa(order.deliveryPrice),
                strong: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// La carte du coursier : initiales, nom, « coursier vérifié », Écrire.
class OfficineCourierCard extends StatelessWidget {
  const OfficineCourierCard({super.key, required this.order, this.caption});

  final OfficineOrder order;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final courier = order.courierName ?? l.honamCourier;
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.terracottaTint,
                child: Text(
                  officineInitials(courier),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onTerracottaTint,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courier,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: AppColors.feedbackSuccess,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.offiVerifiedCourier,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.feedbackSuccess,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(caption!, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 10),
          OfficineOutlineButton(
            label: l.offiWrite,
            icon: Icons.chat_bubble_outline,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OfficineCourierChatScreen(order: order),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Officine · 7. Suivi de la livraison : la position du coursier pendant
/// la course, sans carte par défaut (`CourierTrackingCard`, vue officine).
class OfficineTrackingScreen extends StatelessWidget {
  const OfficineTrackingScreen({super.key, required this.order});

  final OfficineOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final handedAt = order.stepTime('IN_DELIVERY');
    return OfficinePage(
      title: l.offiDeliveryTitle(patient),
      subtitle: handedAt == null
          ? null
          : l.offiHandedAt(
              order.courierName ?? l.honamCourier,
              officineTime(context, handedAt),
            ),
      children: [
        CourierTrackingCard(orderId: order.id, asPharmacy: true),
        officineGap,
        OfficineCourierCard(order: order),
        OfficineNote(l.offiTrackingNote),
      ],
    );
  }
}

/// Officine · 4b (course à payer) et 4c (commande close).
class OfficineDeliveredView extends ConsumerWidget {
  const OfficineDeliveredView({
    super.key,
    required this.order,
    required this.run,
    required this.busy,
  });

  final OfficineOrder order;
  final OfficineRun run;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final courier = order.courierName ?? l.honamCourier;
    final closed = order.courierPaidAt != null;
    final declared = order.courierPaidDeclaredAt != null;
    final deliveredAt = order.deliveredAt ?? order.stepTime('DELIVERED');
    final wallet = order.courierWalletPhone;

    final summary = ModuleCard(
      child: Column(
        children: [
          OfficineAmountRow(
            l.offiCollectedFrom(patient),
            fcfa(order.collected),
          ),
          OfficineAmountRow(
            l.offiPaidToCourier(courier),
            '−${fcfa(order.deliveryPrice)}',
          ),
          const Divider(height: 16),
          OfficineAmountRow(
            l.offiLeftForPharmacy,
            fcfa(order.collected - (order.deliveryPrice ?? 0)),
            strong: true,
          ),
        ],
      ),
    );

    final original = !order.originalRequired
        ? null
        : ModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficineCardTitle(
                  l.offiOriginal,
                  trailing: OfficineTag(
                    order.originalReturnedAt != null
                        ? l.offiOriginalBack
                        : l.offiPending,
                    tone: order.originalReturnedAt != null
                        ? OfficineTone.success
                        : OfficineTone.warning,
                  ),
                ),
                Text(
                  order.originalReturnedAt != null
                      ? l.offiOriginalReturnedAt(
                          honamDateTime(context, order.originalReturnedAt!),
                        )
                      : order.originalCollectedAt != null
                      ? l.offiOriginalCollected(
                          courier,
                          officineTime(context, order.originalCollectedAt!),
                        )
                      : l.offiOriginalWithCourier(courier),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (order.originalReturnedAt == null) ...[
                  const SizedBox(height: 10),
                  OfficineOutlineButton(
                    label: l.offiOriginalReceived,
                    onPressed: busy ? null : () => run('original-received'),
                  ),
                ],
              ],
            ),
          );

    if (closed) {
      return OfficinePage(
        title: l.offiClosedTitle,
        subtitle: deliveredAt == null
            ? patient
            : l.offiPatientDeliveredAt(
                patient,
                officineTime(context, deliveredAt),
              ),
        primary: HonamPrimaryButton(
          label: l.offiBackToOrders,
          onPressed: () => Navigator.of(context).pop(),
        ),
        children: [
          ModuleCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.offiCourseSettled,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        l.offiCourseSettledBody(
                          fcfa(order.deliveryPrice),
                          courier,
                          officineTime(context, order.courierPaidAt!),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          officineGap,
          summary,
          if (original != null) ...[officineGap, original],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OfficineTextAction(
              label: l.offiReportDeliveryDefault,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OfficineDefectScreen(order: order),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return OfficinePage(
      title: l.offiDeliveredTo(patient),
      titleIcon: const Icon(
        Icons.check_circle,
        color: AppColors.feedbackSuccess,
        size: 22,
      ),
      subtitle: deliveredAt == null
          ? null
          : l.offiCodeEnteredBy(courier, officineTime(context, deliveredAt)),
      onRefresh: () async => refreshOfficine(ref, order.id),
      primary: HonamPrimaryButton(
        label: declared
            ? l.offiWaitingCourierConfirm(courier)
            : l.offiIPaid(courier),
        busy: busy,
        onPressed: declared ? null : () => run('courier-paid'),
      ),
      secondary: OfficineTextAction(
        label: l.offiReportDeliveryDefault,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OfficineDefectScreen(order: order)),
        ),
      ),
      children: [
        ModuleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficineBigAmount(
                label: l.offiCourseToPay(courier),
                amount: order.deliveryPrice,
                trailing: OfficineTag(
                  declared ? l.offiPending : l.offiToSettle,
                  tone: OfficineTone.warning,
                ),
              ),
              if (wallet != null) ...[
                const SizedBox(height: 10),
                Text(
                  l.offiPayCourierOn(courier),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        wallet,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    OfficineOutlineButton(
                      label: l.offiCopyNumber,
                      icon: Icons.copy,
                      expanded: false,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: wallet));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l.linkCopied)));
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                l.offiNoFeeOnPayment,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        officineGap,
        summary,
        if (original != null) ...[officineGap, original],
      ],
    );
  }
}
