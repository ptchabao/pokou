import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';

/// Le vocabulaire visuel de Honam, partagé par l'onglet et le détail d'une
/// commande : des surfaces PLATES (un filet, jamais d'ombre), des aplats
/// pastel, et la terre cuite pour ce qui se touche.

/// Les trois pilules de « Mes commandes ».
enum HonamOrderFilter { toReceive, completed, cancelled }

HonamOrderFilter honamFilterOf(HonamOrder order) => !order.isFinished
    ? HonamOrderFilter.toReceive
    : order.status == 'DELIVERED'
    ? HonamOrderFilter.completed
    : HonamOrderFilter.cancelled;

/// Les cinq temps d'une commande : envoyée, devis, payée, en route, livrée.
const honamStepCount = 5;

int honamStepIndex(String status) => switch (status) {
  'QUOTED' || 'ACCEPTED' => 1,
  'PAID' => 2,
  'READY' || 'IN_DELIVERY' => 3,
  'DELIVERED' => 4,
  _ => 0,
};

IconData honamStatusIcon(String status) => switch (status) {
  'SUBMITTED' => Icons.hourglass_top_rounded,
  'QUOTED' => Icons.receipt_long_outlined,
  'ACCEPTED' => Icons.account_balance_wallet_outlined,
  'PAID' => Icons.inventory_2_outlined,
  'READY' || 'IN_DELIVERY' => Icons.delivery_dining_outlined,
  'DELIVERED' => Icons.check_circle_outline,
  _ => Icons.highlight_off,
};

/// La couleur de l'icône d'état : terre cuite tant que la commande avance,
/// vert une fois livrée, éteinte quand elle s'est arrêtée. Jamais seule : la
/// phrase d'à côté dit la même chose.
Color honamStatusColor(HonamOrder order) => switch (honamFilterOf(order)) {
  HonamOrderFilter.toReceive => AppColors.accentPrimaryDark,
  HonamOrderFilter.completed => AppColors.feedbackSuccess,
  HonamOrderFilter.cancelled => AppColors.textMuted,
};

/// L'heure à laquelle la commande est passée par [status], lue dans son fil
/// de suivi. `null` si elle n'y est jamais passée.
DateTime? honamStepTime(HonamOrder order, String status, {bool last = true}) {
  final steps = order.timeline.where((step) => step.status == status);
  if (steps.isEmpty) return null;
  return last ? steps.last.at : steps.first.at;
}

/// « 16/07 à 20:53 » — avec l'année si ce n'est pas celle en cours.
String honamDateTime(BuildContext context, DateTime at) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final local = at.toLocal();
  final date = local.year == DateTime.now().year
      ? DateFormat.Md(locale)
      : DateFormat.yMd(locale);
  return L
      .of(context)
      .honamUiDateAt(date.format(local), DateFormat.Hm(locale).format(local));
}

/// La phrase d'état d'une commande, datée quand la date dit quelque chose
/// (« Livrée le 16/07 à 20:53 »). Jamais un nom de médicament (HON-04).
String honamStatusPhrase(BuildContext context, HonamOrder order) {
  final l = L.of(context);
  String? on(String status) {
    final at = honamStepTime(order, status);
    return at == null ? null : honamDateTime(context, at);
  }

  switch (order.status) {
    case 'SUBMITTED':
      return l.honamUiSubmittedOn(honamDateTime(context, order.createdAt));
    case 'QUOTED':
      final date = on('QUOTED');
      return date == null ? l.honamStQuoted : l.honamUiQuotedOn(date);
    case 'IN_DELIVERY':
      final courier = order.courierName;
      return courier == null
          ? l.honamStInDelivery
          : l.honamTrackingTitle(courier);
    case 'DELIVERED':
      final date = on('DELIVERED');
      return date == null ? l.honamStDelivered : l.honamUiDeliveredOn(date);
    case 'REJECTED':
      final date = on('REJECTED');
      return date == null ? l.honamStRejected : l.honamUiRejectedOn(date);
    case 'EXPIRED':
      final date = on('EXPIRED');
      return date == null ? l.honamStExpired : l.honamUiExpiredOn(date);
    case 'CANCELLED':
      final date = on('CANCELLED');
      return date == null ? l.honamStCancelled : l.honamUiCancelledOn(date);
    default:
      return honamStatusLabel(l, order.status);
  }
}

/// Le nombre d'articles d'un devis : la somme des quantités disponibles.
int honamItemsCount(HonamOrder order) {
  final available = order.quoteItems
      .where((item) => item.available)
      .fold<int>(0, (sum, item) => sum + item.quantity);
  return available > 0 ? available : order.quoteItems.length;
}

/// Un filet d'un point, entre deux bandes d'une même surface.
class HonamHairline extends StatelessWidget {
  const HonamHairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsetsDirectional.only(start: indent, end: indent),
    color: AppColors.border,
  );
}

/// La vignette carrée d'une ligne de commande.
class HonamThumb extends StatelessWidget {
  const HonamThumb({super.key, required this.child, this.size = 48});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.terracottaTint,
      borderRadius: BorderRadius.circular(13),
    ),
    child: IconTheme.merge(
      data: IconThemeData(color: AppColors.onTerracottaTint, size: size * 0.5),
      child: child,
    ),
  );
}

/// Une petite pastille : la quantité (« ×3 »), « De garde »…
class HonamPill extends StatelessWidget {
  const HonamPill(this.label, {super.key, this.background, this.ink});

  final String label;
  final Color? background;
  final Color? ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background ?? AppColors.terracottaTint,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: ink ?? AppColors.onTerracottaTint,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Le bouton principal de Honam : la pastille terre cuite, à plat.
class HonamPrimaryButton extends StatelessWidget {
  const HonamPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.actionButtonBackground,
        foregroundColor: AppColors.actionButtonForeground,
        disabledBackgroundColor: AppColors.actionButtonBackground.withValues(
          alpha: 0.5,
        ),
        disabledForegroundColor: AppColors.actionButtonForeground,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
