import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../core/widgets/pokou_illustration.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../modules/shared/module_ui.dart';
import '../data/honam_models.dart';
import 'courier_tracking.dart';
import 'honam_controller.dart';
import 'honam_send_screen.dart';
import 'honam_ui.dart';

/// Le suivi d'une commande (fil de suivi, NAV-04) : devis, paiement à
/// l'officine, code de remise, et les cas particuliers — refus, paiement non
/// reçu, produit manquant.
///
/// L'écran se lit de haut en bas, en sections à plat séparées par une fine
/// bande de fond : où en est la commande, où elle va, ce qu'il reste à
/// faire, ce qu'elle contient, ses dates, les messages. Le geste qui compte
/// maintenant reste en bas, sous le pouce.
class HonamOrderScreen extends ConsumerStatefulWidget {
  const HonamOrderScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<HonamOrderScreen> createState() => _HonamOrderScreenState();
}

class _HonamOrderScreenState extends ConsumerState<HonamOrderScreen> {
  bool _busy = false;

  int get _id => widget.orderId;

  Future<void> _runWith(String action, Map<String, dynamic>? body) async {
    if (_busy) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(honamRepositoryProvider).action(_id, action, body: body);
      HapticFeedback.lightImpact();
      ref.invalidate(honamOrderProvider(_id));
      ref.invalidate(honamOrdersProvider);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.honamFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(String action) => _runWith(action, null);

  void _resend(HonamOrder order) => Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => HonamSendScreen(resendFromOrderId: order.id),
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

  /// Le geste le plus utile maintenant, pour le bouton du bas.
  ({String label, IconData? icon, VoidCallback onPressed}) _primary(
    L l,
    HonamOrder order,
  ) {
    if (order.status == 'QUOTED') {
      return (
        label: l.honamAcceptQuote,
        icon: null,
        onPressed: () => _run('accept'),
      );
    }
    if (order.status == 'ACCEPTED' && !order.patientPaidDeclared) {
      return (
        label: l.honamDeclarePaid,
        icon: null,
        onPressed: () => _run('declare-paid'),
      );
    }
    if (order.status == 'REJECTED' || order.status == 'EXPIRED') {
      return (
        label: l.honamResend,
        icon: Icons.send_outlined,
        onPressed: () => _resend(order),
      );
    }
    return (
      label: order.isFinished ? l.honamUiDeliveryInfo : l.honamUiTrack,
      icon: Icons.timeline,
      onPressed: () => _openTimeline(order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(honamOrderProvider(_id));
    final order = async.valueOrNull;

    final Widget body;
    if (order != null) {
      final primary = _primary(l, order);
      body = Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(honamOrderProvider(_id)),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: _sections(l, order),
              ),
            ),
          ),
          _BottomBar(
            child: HonamPrimaryButton(
              label: primary.label,
              icon: primary.icon,
              busy: _busy,
              onPressed: primary.onPressed,
            ),
          ),
        ],
      );
    } else if (async.hasError) {
      body = ModuleEmptyState(
        icon: Icons.cloud_off,
        title: l.honamFailed,
        message: l.modulesCheckNetwork,
        action: HonamPrimaryButton(
          label: l.actionRetry,
          icon: Icons.refresh,
          expanded: false,
          onPressed: () => ref.invalidate(honamOrderProvider(_id)),
        ),
      );
    } else {
      body = const _OrderSkeleton();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // La barre, sobre : le retour et le numéro de la commande.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const PokouBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.honamOrderTitle('$_id'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 20,
                        letterSpacing: -0.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const HonamHairline(),
          Expanded(child: body),
        ],
      ),
    );
  }

  List<Widget> _sections(L l, HonamOrder order) {
    final refused = order.status == 'REJECTED' || order.status == 'EXPIRED';
    return [
      _Banner(order: order),
      _Section(
        child: Column(
          children: [
            _PlaceRow(
              icon: const Icon(Icons.location_on_outlined),
              title: order.deliveryAddress,
              subtitle: l.honamAddress,
            ),
            if (order.pharmacy case final pharmacy?) ...[
              const HonamHairline(indent: 16),
              _PlaceRow(
                icon: const Icon(Icons.local_pharmacy_outlined),
                title: pharmacy.name,
                subtitle: pharmacy.address.isEmpty
                    ? l.honamUiPharmacy
                    : pharmacy.address,
              ),
            ],
            if (order.courierName case final courier?) ...[
              const HonamHairline(indent: 16),
              _PlaceRow(
                icon: const PokouIcon(PokouModuleIcon.coursier),
                title: courier,
                subtitle: l.honamUiCourier,
              ),
            ],
            const HonamHairline(),
            _StatusRow(order: order, onTap: () => _openTimeline(order)),
          ],
        ),
      ),
      // ── Ce qu'il reste à faire, selon l'état.
      if (refused && order.rejectionReason != null) ...[
        const _Band(),
        _Section(
          padding: const EdgeInsets.all(16),
          child: _NoteRow(
            icon: Icons.info_outline,
            color: AppColors.textSecondary,
            text: l.honamReason(order.rejectionReason!),
          ),
        ),
      ],
      if (order.status == 'ACCEPTED') ...[
        const _Band(),
        _Section(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: _PayStep(order: order),
        ),
      ],
      if (order.deliveryCode != null) ...[
        const _Band(),
        _Section(
          padding: const EdgeInsets.all(16),
          child: _Code(order: order),
        ),
      ],
      if (order.status == 'IN_DELIVERY' ||
          (order.status == 'READY' && order.courierName != null))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CourierTrackingCard(orderId: order.id),
        ),
      if (order.awaitsMissingChoice) ...[
        const _Band(),
        _Section(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(l.honamMissingTitle),
              const SizedBox(height: 6),
              Text(
                l.honamMissingBody(
                  formatFcfa(order.missingAmount!),
                  order.missingReason ?? '',
                ),
                style: _bodyStyle,
              ),
              const SizedBox(height: 14),
              HonamPrimaryButton(
                label: l.honamKeepRest,
                busy: _busy,
                onPressed: () => _runWith('missing-choice', {'choice': 'KEEP'}),
              ),
              const SizedBox(height: 8),
              ModuleQuietButton(
                label: l.honamCancelAll,
                onPressed: _busy
                    ? null
                    : () => _runWith('missing-choice', {'choice': 'CANCEL'}),
              ),
              const SizedBox(height: 10),
              Text(l.honamRefundDelay, style: _hintStyle),
            ],
          ),
        ),
      ],
      if (order.refundDue > 0 && !order.refundConfirmed) ...[
        const _Band(),
        _Section(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(l.honamUiRefundTitle),
              const SizedBox(height: 6),
              Text(
                l.honamRefundDue(
                  formatFcfa(order.refundDue),
                  order.refundReason ?? '',
                ),
                style: _bodyStyle,
              ),
              const SizedBox(height: 4),
              Text(l.honamRefundDelay, style: _hintStyle),
              const SizedBox(height: 12),
              ModuleQuietButton(
                label: l.honamRefundReceived,
                onPressed: _busy ? null : () => _run('refund-received'),
              ),
            ],
          ),
        ),
      ],
      const _Band(),
      _Section(child: _Items(order: order)),
      const _Band(),
      _Section(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: _Info(order: order),
      ),
      const _Band(),
      _Section(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: _OrderMessages(orderId: order.id),
      ),
      if (const {'SUBMITTED', 'QUOTED', 'ACCEPTED'}.contains(order.status))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: TextButton(
              onPressed: _busy ? null : () => _run('cancel'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.securityCritical,
                minimumSize: const Size(64, 48),
              ),
              child: Text(
                l.honamCancel,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

TextStyle get _bodyStyle =>
    TextStyle(fontSize: 14.5, height: 1.4, color: AppColors.textPrimary);

TextStyle get _hintStyle =>
    TextStyle(fontSize: 13, height: 1.35, color: AppColors.textSecondary);

const _figures = [FontFeature.tabularFigures()];

/// Une section à plat : une surface pleine largeur, bordée d'un filet en
/// haut et en bas. Pas d'ombre, pas de coins : c'est la bande de fond entre
/// deux sections qui les sépare.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
    ),
    child: child,
  );
}

/// La fine bande de fond entre deux sections.
class _Band extends StatelessWidget {
  const _Band();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 8);
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: 'Outfit',
      fontSize: 18,
      height: 1.25,
      letterSpacing: -0.2,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );
}

/// Le bandeau pastel : où en est la commande, en gras, la phrase qui aide,
/// et une scène à droite.
class _Banner extends StatelessWidget {
  const _Banner({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final (title, help) = switch (order.status) {
      'SUBMITTED' => (l.honamUiHeadSubmitted, l.honamUiHelpSubmitted),
      'QUOTED' => (l.honamUiHeadQuoted, l.honamUiHelpQuoted),
      'ACCEPTED' => (
        l.honamUiHeadAccepted,
        order.patientPaidDeclared ? l.honamPaidDeclared : l.honamUiHelpAccepted,
      ),
      'PAID' => (l.honamUiHeadPaid, l.honamUiHelpPaid),
      'READY' => (l.honamUiHeadReady, l.honamUiHelpReady),
      'IN_DELIVERY' => (l.honamUiHeadInDelivery, l.honamUiHelpInDelivery),
      'DELIVERED' => (l.honamUiHeadDelivered, l.honamUiHelpDelivered),
      'REJECTED' => (l.honamUiHeadRejected, l.honamUiHelpRejected),
      'EXPIRED' => (l.honamUiHeadExpired, l.honamUiHelpExpired),
      _ => (l.honamUiHeadCancelled, l.honamUiHelpCancelled),
    };
    final tint = switch (honamFilterOf(order)) {
      HonamOrderFilter.toReceive => AppColors.terracottaTint,
      HonamOrderFilter.completed => AppColors.feedbackSuccess.withValues(
        alpha: AppColors.isDark ? 0.2 : 0.12,
      ),
      HonamOrderFilter.cancelled => AppColors.surfaceElevated,
    };
    final onTheWay = const {
      'READY',
      'IN_DELIVERY',
      'DELIVERED',
    }.contains(order.status);
    return Container(
      color: tint,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 22,
                      height: 1.2,
                      letterSpacing: -0.3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    help,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PokouIllustration(
              onTheWay ? PokouIllustrations.delivery : PokouIllustrations.honam,
              height: 92,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un lieu ou une personne de la commande : repère, nom en gras, précision.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.terracottaTint,
            shape: BoxShape.circle,
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: AppColors.onTerracottaTint, size: 20),
            child: icon,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// « Livrée le 16/07 à 20:53 › » : la ligne d'état, qui ouvre le suivi.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.order, required this.onTap});

  final HonamOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    hint: L.of(context).honamUiDeliveryInfo,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Icon(
                  honamStatusIcon(order.status),
                  size: 20,
                  color: honamStatusColor(order),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  honamStatusPhrase(context, order),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.accentPrimaryDark),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Une icône et une phrase : un motif, un avertissement, une précision.
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.icon,
    required this.color,
    required this.text,
    this.tinted = false,
  });

  final IconData icon;
  final Color color;
  final String text;

  /// Un avertissement : la phrase prend la couleur de l'icône.
  final bool tinted;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: tinted ? color : AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}

/// Le paiement à l'officine : combien, à quel numéro, et où il en est. Le
/// bouton « J'ai payé » est celui du bas de l'écran.
class _PayStep extends StatelessWidget {
  const _PayStep({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final phone = order.payToPhone ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.honamPayTo(formatFcfa(order.total ?? 0), phone),
          style: _bodyStyle,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 4, 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textPrimary,
                    fontFeatures: _figures,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l.koryCopied)));
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimaryDark,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l.koryCopyPhone),
              ),
            ],
          ),
        ),
        if (order.paymentNotReceived) ...[
          const SizedBox(height: 12),
          _NoteRow(
            icon: Icons.error_outline,
            color: AppColors.securityCritical,
            text: l.honamPaymentNotReceived,
            tinted: true,
          ),
        ],
        if (order.patientPaidDeclared) ...[
          const SizedBox(height: 12),
          _NoteRow(
            icon: Icons.hourglass_top_rounded,
            color: AppColors.securityWarning,
            text: l.honamPaidDeclared,
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Le code de remise, en grand : c'est lui qu'on dicte au coursier.
class _Code extends StatelessWidget {
  const _Code({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.terracottaTint,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        children: [
          Text(
            l.honamCode,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onTerracottaTint,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            label: order.deliveryCode!.split('').join(' '),
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  order.deliveryCode!,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 36,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                    color: AppColors.textPrimary,
                    fontFeatures: _figures,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(l.honamCodeHelp, textAlign: TextAlign.center, style: _hintStyle),
        ],
      ),
    );
  }
}

/// « Articles de la commande » : le devis du pharmacien, ligne à ligne, puis
/// les médicaments, la course et le total.
class _Items extends StatelessWidget {
  const _Items({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hasQuote = order.quoteItems.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(child: _SectionHeading(l.honamUiItemsTitle)),
              if (hasQuote) ...[
                const SizedBox(width: 12),
                Text(
                  l.honamUiItemsCount(honamItemsCount(order)),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const HonamHairline(),
        if (!hasQuote)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const HonamThumb(child: PokouIcon(PokouModuleIcon.honam)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.honamUiPrescription,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.status == 'SUBMITTED'
                            ? l.honamUiQuotePendingBody
                            : honamStatusLabel(l, order.status),
                        style: _hintStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final (index, item) in order.quoteItems.indexed) ...[
            if (index > 0) const HonamHairline(indent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _ItemRow(item: item),
            ),
          ],
          const HonamHairline(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                _AmountRow(
                  label: l.honamMedicines,
                  value: formatFcfa(order.medicinesTotal ?? 0),
                ),
                const SizedBox(height: 8),
                _AmountRow(
                  label: l.honamDelivery,
                  value: formatFcfa(order.deliveryPrice ?? 0),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.honamTotal,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatFcfa(order.total ?? 0),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentPrimaryDark,
                        fontFeatures: _figures,
                      ),
                    ),
                  ],
                ),
                if (order.originalRequired) ...[
                  const SizedBox(height: 12),
                  _NoteRow(
                    icon: Icons.description_outlined,
                    color: AppColors.textSecondary,
                    text: l.honamOriginal,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final QuoteItem item;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HonamThumb(child: Icon(Icons.medication_outlined)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: item.available
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  decoration: item.available
                      ? null
                      : TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            l.honamUiUnitPrice(formatFcfa(item.unitPrice)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontFeatures: _figures,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        HonamPill('×${item.quantity}'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.available
                        ? formatFcfa(item.unitPrice * item.quantity)
                        : l.honamUnavailableItem,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: item.available
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontFeatures: _figures,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontFeatures: _figures,
        ),
      ),
    ],
  );
}

/// Les repères de la commande, en lignes libellé / valeur : son numéro, et
/// les heures que son fil de suivi a réellement enregistrées.
class _Info extends StatelessWidget {
  const _Info({required this.order});

  final HonamOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final closed =
        honamStepTime(order, 'REJECTED') ??
        honamStepTime(order, 'EXPIRED') ??
        honamStepTime(order, 'CANCELLED');
    final times = <(String, DateTime?)>[
      (l.honamUiOrderTime, order.createdAt),
      (l.honamUiQuoteTime, honamStepTime(order, 'QUOTED', last: false)),
      (l.honamUiPaymentTime, honamStepTime(order, 'PAID', last: false)),
      (l.honamUiShipTime, honamStepTime(order, 'IN_DELIVERY', last: false)),
      (l.honamUiDeliveredTime, honamStepTime(order, 'DELIVERED')),
      (l.honamUiClosedTime, closed),
    ];
    final id = '${order.id}';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.honamUiOrderId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              id,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: _figures,
              ),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: id));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l.honamUiOrderIdCopied)));
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimaryDark,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsetsDirectional.only(start: 10),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: Text(
                l.honamUiCopy,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        for (final (label, at) in times)
          if (at != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    honamDateTime(context, at),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontFeatures: _figures,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Le bouton principal, épinglé en bas de l'écran.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: child,
    ),
  );
}

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

/// Les messages de la commande, et le champ pour écrire.
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
    final l = L.of(context);
    final messages = ref.watch(honamOrderMessagesProvider(widget.orderId));
    final Widget list;
    if (messages.hasValue) {
      final items = messages.requireValue;
      list = items.isEmpty
          ? Text(l.honamUiNoMessages, style: _hintStyle)
          : Column(
              children: [
                for (final (index, message) in items.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                    child: _MessageBlock(message: message),
                  ),
              ],
            );
    } else if (messages.hasError) {
      list = Text(l.honamFailed, style: _hintStyle);
    } else {
      list = const SkeletonPulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: double.infinity, height: 56, radius: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 220, height: 56, radius: 12),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(l.honamOrderMessages),
        const SizedBox(height: 12),
        list,
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                contextMenuBuilder: pokouContextMenuBuilder,
                controller: _controller,
                maxLength: 1000,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l.honamWriteMessage,
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _send,
              tooltip: l.actionSend,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.actionButtonBackground,
                foregroundColor: AppColors.actionButtonForeground,
                disabledBackgroundColor: AppColors.surfaceElevated,
                minimumSize: const Size(48, 48),
              ),
              icon: _sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted,
                      ),
                    )
                  : const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({required this.message});

  final HonamOrderMessage message;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message.senderName ?? message.senderRole,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat.Hm(locale).format(message.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontFeatures: _figures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            message.body,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// La forme de l'écran pendant le chargement : le bandeau, les repères, les
/// articles, les dates.
class _OrderSkeleton extends StatelessWidget {
  const _OrderSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget place(double title, double subtitle) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const SkeletonCircle(size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: title, height: 14),
              const SizedBox(height: 8),
              SkeletonBox(width: subtitle, height: 12),
            ],
          ),
        ],
      ),
    );
    Widget item(double name) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          const SkeletonBox(width: 48, height: 48, radius: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: name, height: 14),
                const SizedBox(height: 9),
                const SkeletonBox(width: 96, height: 12),
              ],
            ),
          ),
          const SkeletonBox(width: 64, height: 12),
        ],
      ),
    );
    Widget info(double label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SkeletonBox(width: label, height: 12),
          const Spacer(),
          const SkeletonBox(width: 104, height: 12),
        ],
      ),
    );
    return SkeletonPulse(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 124,
              color: AppColors.surfaceElevated,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 190, height: 20),
                        SizedBox(height: 12),
                        SkeletonBox(width: 220, height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 160, height: 12),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 84, height: 84, radius: 18),
                ],
              ),
            ),
            _Section(
              child: Column(
                children: [
                  place(180, 120),
                  const HonamHairline(indent: 16),
                  place(150, 190),
                  const HonamHairline(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(28, 18, 16, 18),
                    child: Row(
                      children: [
                        SkeletonBox(width: 18, height: 18, radius: 9),
                        SizedBox(width: 22),
                        SkeletonBox(width: 170, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _Band(),
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Row(
                      children: [
                        SkeletonBox(width: 190, height: 16),
                        Spacer(),
                        SkeletonBox(width: 60, height: 12),
                      ],
                    ),
                  ),
                  const HonamHairline(),
                  item(200),
                  const HonamHairline(indent: 16),
                  item(150),
                ],
              ),
            ),
            const _Band(),
            _Section(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(children: [info(120), info(140), info(100)]),
            ),
          ],
        ),
      ),
    );
  }
}
