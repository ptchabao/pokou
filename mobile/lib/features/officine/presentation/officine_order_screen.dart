import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import 'officine_closed_views.dart';
import 'officine_controller.dart';
import 'officine_delivery_views.dart';
import 'officine_payment_view.dart';
import 'officine_quote_view.dart';
import 'officine_ui.dart';

/// Ouvre une commande de l'officine.
Future<void> openOfficineOrder(
  BuildContext context,
  int orderId, {
  bool refund = false,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => OfficineOrderScreen(orderId: orderId, refund: refund),
  ),
);

/// Une action de l'officine sur la commande ; `true` si le serveur l'a
/// acceptée. L'erreur est déjà montrée à l'écran.
typedef OfficineRun =
    Future<bool> Function(String action, {Map<String, dynamic>? body});

/// Une commande, vue de l'officine. UN écran, dont le contenu suit l'état
/// de la commande : le devis (2, 2b), le paiement (3, P2), la préparation
/// (A1), la recherche d'un coursier (8, 9), la livraison (4), la course à
/// payer (4b), la commande close (4c), le refus (R2), l'annulation (A2, A3).
/// Quand la commande avance — par un geste ici, ou par la patiente ou le
/// coursier en temps réel — l'écran passe de lui-même à l'étape suivante.
class OfficineOrderScreen extends ConsumerStatefulWidget {
  const OfficineOrderScreen({
    super.key,
    required this.orderId,
    this.refund = false,
  });

  final int orderId;

  /// Ouvre directement le remboursement (A2), même si la commande continue
  /// (la patiente a choisi de recevoir le reste).
  final bool refund;

  @override
  ConsumerState<OfficineOrderScreen> createState() =>
      _OfficineOrderScreenState();
}

class _OfficineOrderScreenState extends ConsumerState<OfficineOrderScreen> {
  bool _busy = false;

  Future<bool> _run(String action, {Map<String, dynamic>? body}) async {
    if (_busy) return false;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(officineRepositoryProvider)
          .act(widget.orderId, action, body: body);
      HapticFeedback.lightImpact();
      refreshOfficine(ref, widget.orderId);
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(officineOrderProvider(widget.orderId));
    final order = async.valueOrNull;
    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(l.honamOrderTitle('${widget.orderId}')),
        ),
        body: async.hasError
            ? ModuleEmptyState(
                icon: Icons.cloud_off,
                title: l.honamFailed,
                message: officineError(l, async.error!),
                action: HonamPrimaryButton(
                  label: l.actionRetry,
                  icon: Icons.refresh,
                  expanded: false,
                  onPressed: () =>
                      ref.invalidate(officineOrderProvider(widget.orderId)),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final me = ref.watch(officineMeProvider).valueOrNull;
    final run = _run;
    if (widget.refund && order.refundDue > 0) {
      return OfficineRefundView(order: order, run: run, busy: _busy);
    }
    return switch (order.status) {
      'SUBMITTED' ||
      'QUOTED' => OfficineQuoteView(order: order, run: run, busy: _busy),
      'ACCEPTED' => OfficinePaymentView(
        order: order,
        me: me,
        run: run,
        busy: _busy,
      ),
      'PAID' => OfficinePreparationView(order: order, run: run, busy: _busy),
      'READY' when order.courierName == null => OfficineCourierSearchView(
        order: order,
        busy: _busy,
      ),
      'READY' || 'IN_DELIVERY' => OfficineDeliveryView(
        order: order,
        run: run,
        busy: _busy,
      ),
      'DELIVERED' => OfficineDeliveredView(order: order, run: run, busy: _busy),
      'REJECTED' || 'EXPIRED' => OfficineRejectedView(order: order),
      _ when order.refundDue > 0 && order.refundConfirmedAt == null =>
        OfficineRefundView(order: order, run: run, busy: _busy),
      _ => OfficineCancelledView(order: order),
    };
  }
}
