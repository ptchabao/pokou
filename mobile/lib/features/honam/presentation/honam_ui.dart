import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// La frise des cinq temps, avec leurs libellés (maquette Honam patient 2) :
/// envoyée, devis, payée, en route, livrée. Le temps en cours en terre
/// cuite, les temps passés en vert.
class HonamStepRail extends StatelessWidget {
  const HonamStepRail({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final active = honamStepIndex(status);
    final finished = status == 'DELIVERED';
    final labels = [
      l.honamPStepSent,
      l.honamPStepQuote,
      l.honamPStepPaid,
      l.honamPStepOnTheWay,
      l.honamPStepDelivered,
    ];
    Color tone(int index) => index < active || finished
        ? AppColors.feedbackSuccess
        : index == active
        ? AppColors.accentPrimaryDark
        : AppColors.surfaceElevated;
    Color ink(int index) => index < active || finished
        ? AppColors.feedbackSuccess
        : index == active
        ? AppColors.accentPrimaryDark
        : AppColors.textMuted;
    return Semantics(
      label: l.honamUiStepOf(active + 1, honamStepCount),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var index = 0; index < honamStepCount; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: tone(index),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: index <= active
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: ink(index),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une ligne qui s'ouvre : une icône, un titre, une précision, un chevron
/// (« Écrire à la pharmacie », « Livrer à … »).
class HonamLinkRow extends StatelessWidget {
  const HonamLinkRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.accentPrimaryDark),
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
            if (onTap != null && trailing == null)
              Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    ),
  );
}

/// La pastille d'état d'une commande dans une liste (« En route »,
/// « Livrée », « Remboursée »…).
Widget honamOrderPill(L l, HonamOrder order) {
  final (String label, Color color) = switch (order.status) {
    _ when order.refundDue > 0 && order.refundConfirmed => (
      l.honamPPillRefunded,
      AppColors.securityWarning,
    ),
    _ when order.refundDue > 0 => (
      l.honamPPillRefundPending,
      AppColors.securityWarning,
    ),
    'SUBMITTED' => (l.honamPPillWaitingQuote, AppColors.textSecondary),
    'QUOTED' || 'ACCEPTED' => (l.honamPPillToPay, AppColors.accentPrimaryDark),
    'PAID' || 'READY' => (l.honamPPillPreparing, AppColors.accentPrimaryDark),
    'IN_DELIVERY' => (l.honamPPillOnTheWay, AppColors.feedbackSuccess),
    'DELIVERED' => (l.honamPPillDelivered, AppColors.feedbackSuccess),
    'REJECTED' => (l.honamPPillRejected, AppColors.textSecondary),
    'EXPIRED' => (l.honamPPillExpired, AppColors.textSecondary),
    _ => (l.honamPPillCancelled, AppColors.textSecondary),
  };
  return HonamPill(
    label,
    background: color.withValues(alpha: AppColors.isDark ? 0.22 : 0.12),
    ink: AppColors.isDark ? AppColors.textPrimary : color,
  );
}

/// Un code en cases (code SMS du wallet, code de remise) : un champ
/// invisible sous des cases qui montrent chaque chiffre.
class HonamCodeBoxes extends StatefulWidget {
  const HonamCodeBoxes({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  State<HonamCodeBoxes> createState() => _HonamCodeBoxesState();
}

class _HonamCodeBoxesState extends State<HonamCodeBoxes> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                setState(() {});
                if (value.length == widget.length) {
                  widget.onCompleted?.call(value);
                }
              },
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.85,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          width: i < text.length ? 2 : 1,
                          color: i < text.length
                              ? AppColors.accentPrimaryDark
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        i < text.length ? text[i] : '',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// La barre d'un écran à étapes (« étape 2 sur 6 »).
class HonamWizardBar extends StatelessWidget {
  const HonamWizardBar({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= total; i++) ...[
        if (i > 1) const SizedBox(width: 5),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: i <= step
                  ? AppColors.accentPrimaryDark
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Une pastille ronde à icône, en tête d'un écran d'état (validé,
/// attention, interdit).
class HonamRoundIcon extends StatelessWidget {
  const HonamRoundIcon({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDark ? 0.24 : 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color),
    ),
  );
}

/// « aujourd'hui, 9:42 », « hier, 17:02 », « 2 nov. à 09:15 ».
String honamWhen(BuildContext context, DateTime at) {
  final l = L.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final local = at.toLocal();
  final now = DateTime.now();
  final time = DateFormat.Hm(locale).format(local);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return l.honamPTodayAt(time);
  if (day == today.subtract(const Duration(days: 1))) {
    return l.honamPYesterdayAt(time);
  }
  if (day == today.add(const Duration(days: 1))) {
    return l.honamPTomorrowAt(time);
  }
  return l.honamUiDateAt(DateFormat.MMMd(locale).format(local), time);
}
