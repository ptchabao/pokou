import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../kory/presentation/kory_ui.dart';
import '../../kory/presentation/kory_wallet.dart';
import '../../modules/shared/module_ui.dart';
import '../data/honam_models.dart';
import 'courier_join_screen.dart' show CourierOfferPrompt;
import 'honam_controller.dart';
import 'honam_order_messages.dart';
import 'honam_pay_screen.dart';
import 'honam_send_screen.dart' show currentPosition, honamPharmacyLine;
import 'honam_tracking.dart';
import 'honam_ui.dart';

/// Le détail d'une commande, côté patient (maquettes Honam patient 2 à 7 et
/// « Suivi sans carte »). Un seul écran qui prend la forme de l'étape : en
/// attente du devis, devis reçu, paiement signalé, produit manquant,
/// ordonnance refusée, en livraison, livrée.
class HonamOrderScreen extends ConsumerStatefulWidget {
  const HonamOrderScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<HonamOrderScreen> createState() => _HonamOrderScreenState();
}

class _HonamOrderScreenState extends ConsumerState<HonamOrderScreen> {
  bool _busy = false;

  /// Produit manquant : le choix en cours (KEEP | CANCEL).
  String? _missingChoice;

  /// Ordonnance refusée : l'autre pharmacie choisie.
  int? _otherPharmacyId;

  int get _id => widget.orderId;

  Future<HonamOrder?> _run(String action, {Map<String, dynamic>? body}) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final order = await ref
          .read(honamRepositoryProvider)
          .action(_id, action, body: body);
      HapticFeedback.lightImpact();
      ref.invalidate(honamOrderProvider(_id));
      ref.invalidate(honamOrdersProvider);
      return order;
    } catch (_) {
      if (mounted) koryToast(context, L.of(context).honamFailed);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(HonamOrder order) async {
    var current = order;
    if (order.status == 'QUOTED') {
      final accepted = await _run('accept');
      if (accepted == null || !mounted) return;
      current = accepted;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HonamPayScreen(order: current)),
    );
  }

  Future<void> _resend(HonamOrder order, Pharmacy pharmacy) async {
    final created = await _run('resend', body: {'pharmacy_id': pharmacy.id});
    if (created == null || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HonamOrderScreen(orderId: created.id)),
    );
  }

  void _openMessages(HonamOrder order) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => HonamOrderMessagesScreen(
        orderId: order.id,
        title: order.pharmacy?.name ?? '',
      ),
    ),
  );

  void _openTimeline(HonamOrder order) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    clipBehavior: Clip.antiAlias,
    builder: (_) => _TimelineSheet(order: order),
  );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(honamOrderProvider(_id));
    final order = async.valueOrNull;
    if (order == null) {
      return KoryPage(
        title: l.honamPMyOrder,
        loading: !async.hasError,
        body: async.hasError
            ? ModuleEmptyState(
                icon: Icons.cloud_off,
                title: l.honamFailed,
                message: l.modulesCheckNetwork,
                action: HonamPrimaryButton(
                  label: l.actionRetry,
                  icon: Icons.refresh,
                  expanded: false,
                  onPressed: () => ref.invalidate(honamOrderProvider(_id)),
                ),
              )
            : const SizedBox.shrink(),
      );
    }
    final pharmacy = order.pharmacy?.name ?? l.honamUiPharmacy;
    final refused = order.status == 'REJECTED' || order.status == 'EXPIRED';
    final delivering =
        order.status == 'IN_DELIVERY' ||
        (order.status == 'READY' && order.courierName != null);

    if (refused) return _refusedPage(l, order, pharmacy);
    if (order.awaitsMissingChoice) return _missingPage(l, order, pharmacy);
    if (delivering) {
      return KoryPage(
        title: l.honamPPharmacyHonam(pharmacy),
        subtitle: l.honamPInDelivery,
        actions: [_menu(l, order)],
        body: HonamTrackingBody(order: order),
      );
    }

    final String title;
    final String subtitle;
    if (order.status == 'QUOTED') {
      final quotedAt = honamStepTime(order, 'QUOTED');
      title = l.honamPQuoteFrom(pharmacy);
      subtitle = [
        if (quotedAt != null) l.honamPReceivedAt(honamWhen(context, quotedAt)),
        if (order.quoteExpiresAt != null)
          l.honamPValidUntil(honamWhen(context, order.quoteExpiresAt!)),
      ].join(' · ');
    } else {
      title = l.honamPMyOrder;
      subtitle = order.status == 'SUBMITTED'
          ? l.honamPSentAt(pharmacy, honamWhen(context, order.createdAt))
          : pharmacy;
    }
    return KoryPage(
      title: title,
      subtitle: subtitle,
      actions: [_menu(l, order)],
      footer: _footer(l, order),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(honamOrderProvider(_id)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            HonamStepRail(status: order.status),
            const SizedBox(height: 16),
            ..._body(l, order, pharmacy),
          ],
        ),
      ),
    );
  }

  Widget _menu(L l, HonamOrder order) => PopupMenuButton<String>(
    tooltip: l.honamPMore,
    icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
    onSelected: (value) => switch (value) {
      'write' => _openMessages(order),
      _ => _openTimeline(order),
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'write', child: Text(l.honamPWriteToPharmacy)),
      PopupMenuItem(value: 'timeline', child: Text(l.honamUiDeliveryInfo)),
    ],
  );

  Widget? _footer(L l, HonamOrder order) {
    final cancel = TextButton(
      onPressed: _busy ? null : () => _run('cancel'),
      style: TextButton.styleFrom(foregroundColor: AppColors.accentPrimaryDark),
      child: Text(l.honamCancel),
    );
    switch (order.status) {
      case 'SUBMITTED':
        return KoryFooter(children: [cancel]);
      case 'QUOTED':
        return KoryFooter(
          children: [
            KoryButton(
              label: l.honamPPayAmount(formatFcfa(order.total ?? 0)),
              busy: _busy,
              onPressed: () => _pay(order),
            ),
            TextButton(
              onPressed: _busy ? null : () => _run('cancel'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimaryDark,
              ),
              child: Text(l.honamPRefuseQuote),
            ),
          ],
        );
      case 'ACCEPTED' when !order.patientPaidDeclared:
        return KoryFooter(
          children: [
            KoryButton(
              label: l.honamPPayAmount(formatFcfa(order.total ?? 0)),
              busy: _busy,
              onPressed: () => _pay(order),
            ),
            cancel,
          ],
        );
      case 'ACCEPTED' || 'PAID' || 'READY':
        return KoryFooter(
          children: [
            KoryButton(
              label: l.honamPFollowOrder,
              onPressed: () => _openTimeline(order),
            ),
          ],
        );
    }
    if (order.refundDue > 0 && !order.refundConfirmed) {
      return KoryFooter(
        children: [
          KoryButton(
            label: l.honamRefundReceived,
            busy: _busy,
            onPressed: () => _run('refund-received'),
          ),
        ],
      );
    }
    return null;
  }

  List<Widget> _body(L l, HonamOrder order, String pharmacy) {
    final write = KoryCard(
      padding: EdgeInsets.zero,
      child: HonamLinkRow(
        icon: Icons.chat_bubble_outline,
        title: l.honamPWriteToPharmacy,
        onTap: () => _openMessages(order),
      ),
    );
    final address = KoryCard(
      padding: EdgeInsets.zero,
      child: HonamLinkRow(
        icon: Icons.location_on_outlined,
        title: l.honamPDeliverTo(order.deliveryAddress),
        subtitle: order.deliveryLandmark == null
            ? null
            : l.honamPLandmark(order.deliveryLandmark!),
      ),
    );
    final refund = order.refundDue > 0
        ? [
            const SizedBox(height: 12),
            KoryNotice(
              tone: order.refundConfirmed ? KoryTone.success : KoryTone.warning,
              title: l.honamUiRefundTitle,
              text: order.refundConfirmed
                  ? l.honamPRefundDone(formatFcfa(order.refundDue))
                  : l.honamRefundDue(
                      formatFcfa(order.refundDue),
                      order.refundReason ?? '',
                    ),
            ),
          ]
        : const <Widget>[];
    switch (order.status) {
      case 'SUBMITTED':
        return [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.terracottaTint,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, color: AppColors.onTerracottaTint),
          ),
          const SizedBox(height: 10),
          Text(
            l.honamPWaitingQuoteBody(pharmacy),
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          KoryCard(
            child: Row(
              children: [
                _PrescriptionThumb(mediaId: order.prescriptionMediaId),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.honamPPrescriptionSent,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (order.patientNote != null)
                        Text(
                          '« ${order.patientNote} »',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          write,
          const SizedBox(height: 8),
          address,
          const SizedBox(height: 12),
          KoryNotice(text: l.honamNotEmergency, icon: Icons.info_outline),
        ];
      case 'QUOTED':
      case 'ACCEPTED' when !order.patientPaidDeclared:
        final generics = order.quoteItems
            .where((i) => i.generic && i.available)
            .map((i) => i.name)
            .toList();
        return [
          _QuoteItems(order: order),
          const SizedBox(height: 12),
          _Totals(order: order),
          if (order.paymentNotReceived) ...[
            const SizedBox(height: 12),
            KoryNotice(tone: KoryTone.danger, text: l.honamPaymentNotReceived),
          ],
          const SizedBox(height: 12),
          KoryNotice(icon: Icons.info_outline, text: l.honamPPayDirectly),
          if (generics.isNotEmpty) ...[
            const SizedBox(height: 8),
            KoryNotice(
              icon: Icons.info_outline,
              text: l.honamPGenericOffered(generics.join(', ')),
            ),
          ],
          if (order.originalRequired) ...[
            const SizedBox(height: 8),
            KoryNotice(icon: Icons.description_outlined, text: l.honamOriginal),
          ],
          const SizedBox(height: 12),
          write,
        ];
      case 'ACCEPTED' || 'PAID' || 'READY':
        return [
          _PaymentSteps(order: order),
          const SizedBox(height: 12),
          KoryNotice(tone: KoryTone.success, text: l.honamPCodeLater),
          const SizedBox(height: 12),
          write,
        ];
      default:
        // Livrée ou annulée : le récapitulatif.
        return [
          KoryNotice(
            tone: order.status == 'DELIVERED'
                ? KoryTone.success
                : KoryTone.neutral,
            icon: order.status == 'DELIVERED'
                ? Icons.check_circle_outline
                : Icons.info_outline,
            text: honamStatusPhrase(context, order),
          ),
          // Maquette Coursiers 0 : l'encart après une livraison reçue.
          if (order.status == 'DELIVERED' && order.courierName != null) ...[
            const SizedBox(height: 12),
            CourierOfferPrompt(
              deliveredBy: order.deliveredAt == null
                  ? order.courierName!
                  : l.courierByAt(
                      order.courierName!,
                      honamWhen(context, order.deliveredAt!),
                    ),
            ),
          ],
          ...refund,
          if (order.quoteItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _QuoteItems(order: order),
            const SizedBox(height: 12),
            _Totals(order: order),
          ],
          const SizedBox(height: 12),
          address,
          const SizedBox(height: 8),
          write,
        ];
    }
  }

  // ── Maquette Honam patient 6 : un produit manque ──────────────────────

  Widget _missingPage(L l, HonamOrder order, String pharmacy) {
    final phone = ref.watch(authControllerProvider).user?.phone;
    final wallet = KoryWallet.of(phone);
    final total = (order.medicinesTotal ?? 0) + (order.deliveryPrice ?? 0);
    return KoryPage(
      title: l.honamMissingTitle,
      subtitle: l.honamPPaidOrderOf(pharmacy),
      footer: KoryFooter(
        children: [
          KoryButton(
            label: l.honamPValidateChoice,
            busy: _busy,
            onPressed: _missingChoice == null
                ? null
                : () => _run('missing-choice', body: {'choice': _missingChoice}),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.securityWarning.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppColors.securityWarning,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.honamPMissingLead(pharmacy, order.missingReason ?? ''),
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          KoryChoice(
            selected: _missingChoice == 'KEEP',
            title: l.honamKeepRest,
            subtitle: l.honamPKeepRestBody(
              formatFcfa(order.missingAmount ?? 0),
            ),
            onTap: () => setState(() => _missingChoice = 'KEEP'),
          ),
          KoryChoice(
            selected: _missingChoice == 'CANCEL',
            title: l.honamCancelAll,
            subtitle: l.honamPCancelAllBody(formatFcfa(total)),
            onTap: () => setState(() => _missingChoice = 'CANCEL'),
          ),
          KoryNotice(
            icon: Icons.info_outline,
            text: l.honamPRefundToPayer(wallet?.label ?? ''),
          ),
          const SizedBox(height: 10),
          Text(
            l.honamPMissingNoAnswer,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Maquette Honam patient 7 : ordonnance refusée ─────────────────────

  Widget _refusedPage(L l, HonamOrder order, String pharmacy) {
    final others = (ref.watch(honamOtherPharmaciesProvider).valueOrNull ??
            const <Pharmacy>[])
        .where((p) => p.id != order.pharmacy?.id)
        .take(5)
        .toList();
    final chosen =
        others.where((p) => p.id == _otherPharmacyId).firstOrNull ??
        others.firstOrNull;
    return KoryPage(
      title: order.status == 'EXPIRED'
          ? l.honamUiHeadExpired
          : l.honamPRefusedTitle,
      subtitle: l.honamPNothingPaid(pharmacy),
      footer: KoryFooter(
        children: [
          if (chosen != null)
            KoryButton(
              label: l.honamPSendTo(chosen.name),
              busy: _busy,
              onPressed: () => _resend(order, chosen),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimaryDark,
            ),
            child: Text(l.honamPLater),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          KoryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.honamPReason,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.status == 'EXPIRED'
                        ? l.honamUiHelpExpired
                        : '« ${order.rejectionReason ?? l.honamUiHelpRejected} »',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          KorySection(l.honamPSendElsewhere),
          if (others.isEmpty)
            KoryNotice(text: l.honamNoPharmacy)
          else
            for (final p in others)
              KoryChoice(
                selected: p.id == chosen?.id,
                title: p.name,
                subtitle: honamPharmacyLine(context, p),
                onTap: () => setState(() => _otherPharmacyId = p.id),
              ),
          Text(
            l.honamPSamePhoto,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Les officines à qui renvoyer une ordonnance refusée, les plus proches
/// d'abord, sans redemander la position.
final honamOtherPharmaciesProvider = FutureProvider.autoDispose<List<Pharmacy>>(
  (ref) async {
    final position = await currentPosition(ask: false);
    return ref
        .watch(honamRepositoryProvider)
        .pharmacies(lat: position?.latitude, lng: position?.longitude);
  },
);

/// La vignette de l'ordonnance envoyée.
class _PrescriptionThumb extends ConsumerWidget {
  const _PrescriptionThumb({required this.mediaId});

  final int? mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = mediaId;
    const fallback = HonamThumb(child: Icon(Icons.description_outlined));
    if (id == null) return fallback;
    return FutureBuilder<File>(
      future: ref.read(mediaRepositoryProvider).resolveLocalFile(id, largeur: 96),
      builder: (context, snapshot) => snapshot.hasData
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                snapshot.data!,
                width: 48,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
          : fallback,
    );
  }
}

/// Les lignes du devis : nom, conditionnement, « Générique », prix.
class _QuoteItems extends StatelessWidget {
  const _QuoteItems({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return KoryCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, item) in order.quoteItems.indexed) ...[
            if (index > 0) Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: item.available
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            decoration: item.available
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              item.packaging ?? '×${item.quantity}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (item.packaging != null && item.quantity > 1)
                              HonamPill('×${item.quantity}'),
                            if (item.generic) HonamPill(l.honamPGeneric),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.available
                        ? formatFcfa(item.unitPrice * item.quantity)
                        : l.honamUnavailableItem,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Médicaments, course ajoutée par Honam, total à payer.
class _Totals extends StatelessWidget {
  const _Totals({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return KoryCard(
      child: Column(
        children: [
          KoryLine(l.honamMedicines, formatFcfa(order.medicinesTotal ?? 0)),
          KoryLine(l.honamPDeliveryByHonam, formatFcfa(order.deliveryPrice ?? 0)),
          Divider(height: 16, color: AppColors.border),
          KoryLine(l.honamPTotalToPay, formatFcfa(order.total ?? 0), strong: true),
        ],
      ),
    );
  }
}

/// Maquette Honam patient 5 : paiement signalé, vérification par la
/// pharmacie, préparation puis départ du coursier.
class _PaymentSteps extends StatelessWidget {
  const _PaymentSteps({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final paid = order.status != 'ACCEPTED';
    final declared = order.paymentDeclaredAt;
    final steps = [
      (
        l.honamPStepPaymentSignaled,
        [
          if (declared != null) honamWhen(context, declared),
          if (order.paymentReference != null)
            l.honamPRef(order.paymentReference!),
        ].join(' · '),
        true,
      ),
      (
        paid ? l.honamPStepPaymentReceived : l.honamPStepPharmacyChecks,
        paid ? l.honamUiHeadPaid : l.honamPOnItsWallet,
        paid,
      ),
      (l.honamPStepPreparing, l.honamPStepPreparingBody, order.status == 'READY'),
    ];
    return KoryCard(
      child: Column(
        children: [
          for (final (index, (title, subtitle, done)) in steps.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.feedbackSuccess
                          : AppColors.surfaceElevated,
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

TextStyle get _hintStyle =>
    TextStyle(fontSize: 13, height: 1.35, color: AppColors.textSecondary);

const _figures = [FontFeature.tabularFigures()];


/// « Suivi de livraison » : la frise des étapes, la plus récente en haut.
class _TimelineSheet extends StatelessWidget {
  const _TimelineSheet({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final steps = order.timeline.reversed.toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 96),
                    child: Text(
                      l.honamUiDeliveryInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 6,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentPrimaryDark,
                        minimumSize: const Size(64, 44),
                      ),
                      child: Text(
                        l.actionClose,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const HonamHairline(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.honamUiOrderId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${order.id}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFeatures: _figures,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 8, color: AppColors.background),
            Flexible(
              child: steps.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.honamUiNoSteps,
                        textAlign: TextAlign.center,
                        style: _hintStyle,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      itemCount: steps.length,
                      itemBuilder: (context, index) => _TimelineRow(
                        step: steps[index],
                        current: index == 0,
                        first: index == 0,
                        last: index == steps.length - 1,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une étape de la frise : la date et l'heure à gauche, le point et le
/// trait, puis le libellé dans son bloc gris. L'étape courante porte le
/// point plein, en terre cuite.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.current,
    required this.first,
    required this.last,
  });

  final TimelineStep step;
  final bool current;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final at = step.at.toLocal();
    final rail = AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat.MMMd(locale).format(at),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.Hm(locale).format(at),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontFeatures: _figures,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: first ? Colors.transparent : rail,
                  ),
                ),
                Container(
                  width: current ? 14 : 8,
                  height: current ? 14 : 8,
                  decoration: BoxDecoration(
                    color: current ? AppColors.accentPrimaryDark : rail,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last ? Colors.transparent : rail,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  step.note ?? honamStatusLabel(l, step.status),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
