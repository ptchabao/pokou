import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../kory/presentation/kory_controller.dart' show formatFcfa;
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';

/// Le vocabulaire visuel de l'espace officine : celui de Honam (surfaces à
/// filet, terre cuite pour ce qui se touche), avec les quelques pièces que
/// l'officine est seule à avoir — la frise des cinq temps, la barre d'actions
/// épinglée sous le pouce.

String fcfa(int? amount) => amount == null ? '—' : formatFcfa(amount);

/// Le refus du serveur tel qu'il l'écrit (« Le devis doit être accepté »),
/// sinon la phrase générique.
String officineError(L l, Object error) =>
    error is ApiException && error.message.trim().isNotEmpty
    ? error.message
    : l.honamFailed;

/// « +228 96 •• •• 12 » : le numéro reconnaissable sans être lisible par
/// quelqu'un qui regarde par-dessus l'épaule.
String officineMasked(String? phone) {
  if (phone == null || phone.length < 8) return phone ?? '';
  final head = phone.substring(0, phone.length - 6);
  final tail = phone.substring(phone.length - 2);
  return '$head •• •• $tail';
}

/// Les initiales d'un nom (« Kodjo A. » → « KA »).
String officineInitials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts[1].characters.first : '';
  return (first + second).toUpperCase();
}

/// « 9:42 », à la manière du téléphone.
String officineTime(BuildContext context, DateTime at) => DateFormat.Hm(
  Localizations.localeOf(context).toLanguageTag(),
).format(at.toLocal());

/// « 27/10 » — avec l'année si ce n'est pas celle en cours.
String officineDate(BuildContext context, DateTime at) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final local = at.toLocal();
  return (local.year == DateTime.now().year
          ? DateFormat.MMMd(locale)
          : DateFormat.yMMMd(locale))
      .format(local);
}

/// « il y a 2 min », « il y a 3 h », puis la date.
String officineAgo(BuildContext context, DateTime at) {
  final l = L.of(context);
  final minutes = DateTime.now().toUtc().difference(at.toUtc()).inMinutes;
  if (minutes < 1) return l.offiAgoNow;
  if (minutes < 60) return l.offiAgoMinutes(minutes);
  if (minutes < 24 * 60) return l.offiAgoHours(minutes ~/ 60);
  return officineDate(context, at);
}

/// Le nom de la patiente, ou « Patiente » s'il manque.
String officinePatient(BuildContext context, OfficineOrder order) =>
    order.patientLabel.isEmpty ? L.of(context).offiPatient : order.patientLabel;

/// Les cinq temps d'une commande : reçue, devis, payée, prête, livrée.
int officineStep(String status) => switch (status) {
  'SUBMITTED' => 0,
  'QUOTED' || 'ACCEPTED' => 1,
  'PAID' => 2,
  'READY' || 'IN_DELIVERY' => 3,
  'DELIVERED' => 4,
  _ => 0,
};

/// La frise des cinq temps, en tête des écrans d'une commande en cours.
/// Vert pour ce qui est fait, terre cuite pour l'étape en cours.
class OfficineStepBar extends StatelessWidget {
  const OfficineStepBar({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final labels = [
      l.offiStepReceived,
      l.offiStepQuote,
      l.offiStepPaid,
      l.offiStepReady,
      l.offiStepDelivered,
    ];
    final current = officineStep(status);
    final done = status == 'DELIVERED';
    return Semantics(
      label: l.offiStepSemantics(labels[current]),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < current || done
                            ? AppColors.feedbackSuccess
                            : i == current
                            ? AppColors.accentPrimary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i <= current
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
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

/// Un écran poussé de l'espace officine : le retour, un titre, une ligne
/// de contexte, la frise si on la donne, puis le contenu ; et en bas,
/// épinglés, le geste principal et son alternative discrète.
class OfficinePage extends StatelessWidget {
  const OfficinePage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.titleIcon,
    this.status,
    this.primary,
    this.secondary,
    this.onRefresh,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget? titleIcon;

  /// L'état de la commande : affiche la frise des cinq temps.
  final String? status;
  final List<Widget> children;
  final Widget? primary;
  final Widget? secondary;
  final Future<void> Function()? onRefresh;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (status != null) ...[
          OfficineStepBar(status: status!),
          const SizedBox(height: 14),
        ],
        ...children,
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
              child: Row(
                children: [
                  const PokouBackButton(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (titleIcon != null) ...[
                              titleIcon!,
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...?actions,
                ],
              ),
            ),
          ),
          Expanded(
            child: onRefresh == null
                ? list
                : RefreshIndicator(onRefresh: onRefresh!, child: list),
          ),
          if (primary != null || secondary != null)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [?primary, ?secondary],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// L'alternative discrète sous le bouton principal (« Refuser
/// l'ordonnance », « Pas encore reçu »…), en terre cuite.
class OfficineTextAction extends StatelessWidget {
  const OfficineTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.feedbackDanger : AppColors.accentPrimary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

/// Un bouton à filet terre cuite (« Établir le devis » est plein, « Vérifier
/// le paiement » ne l'est pas).
class OfficineOutlineButton extends StatelessWidget {
  const OfficineOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: BorderSide(color: AppColors.border),
      minimumSize: const Size(48, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    );
    final button = icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 18),
            label: Text(label, textAlign: TextAlign.center),
          );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Une ligne « libellé … montant » d'un récapitulatif.
class OfficineAmountRow extends StatelessWidget {
  const OfficineAmountRow(
    this.label,
    this.amount, {
    super.key,
    this.strong = false,
    this.muted = false,
  });

  final String label;
  final String amount;
  final bool strong;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: strong ? 15 : 14,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
      color: muted ? AppColors.textSecondary : AppColors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(amount, style: style),
        ],
      ),
    );
  }
}

/// Le titre d'une carte (« Produits », « Remise du colis »…).
class OfficineCardTitle extends StatelessWidget {
  const OfficineCardTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Un gros montant (« 5 600 FCFA ») avec son libellé au-dessus.
class OfficineBigAmount extends StatelessWidget {
  const OfficineBigAmount({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
    this.trailing,
  });

  final String label;
  final int? amount;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          ?trailing,
        ],
      ),
      const SizedBox(height: 4),
      Text(
        fcfa(amount),
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      if (caption != null)
        Text(
          caption!,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
    ],
  );
}

/// Une étiquette d'état : vert (fait), ambre (à faire), rouge (arrêté).
enum OfficineTone { success, warning, danger, neutral }

class OfficineTag extends StatelessWidget {
  const OfficineTag(this.label, {super.key, this.tone = OfficineTone.neutral});

  final String label;
  final OfficineTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color ink) = switch (tone) {
      OfficineTone.success => (
        AppColors.feedbackSuccess.withValues(alpha: 0.13),
        AppColors.feedbackSuccess,
      ),
      OfficineTone.warning => (
        AppColors.feedbackWarning.withValues(alpha: 0.13),
        AppColors.feedbackWarning,
      ),
      OfficineTone.danger => (
        AppColors.feedbackDanger.withValues(alpha: 0.12),
        AppColors.feedbackDanger,
      ),
      OfficineTone.neutral => (
        AppColors.terracottaTint,
        AppColors.onTerracottaTint,
      ),
    };
    return HonamPill(label, background: bg, ink: ink);
  }
}

/// Une ligne numérotée ou cochée d'une liste d'étapes (écrans 8, 16, R2).
class OfficineStepRow extends StatelessWidget {
  const OfficineStepRow({
    super.key,
    required this.title,
    this.subtitle,
    this.number,
    this.done = false,
    this.current = false,
  });

  final String title;
  final String? subtitle;
  final int? number;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final Widget dot;
    if (done) {
      dot = const CircleAvatar(
        radius: 13,
        backgroundColor: AppColors.feedbackSuccess,
        child: Icon(Icons.check, size: 16, color: Colors.white),
      );
    } else if (current) {
      dot = CircleAvatar(
        radius: 13,
        backgroundColor: AppColors.terracottaTint,
        child: const Icon(
          Icons.history_toggle_off,
          size: 16,
          color: AppColors.accentPrimary,
        ),
      );
    } else {
      dot = CircleAvatar(
        radius: 13,
        backgroundColor: AppColors.surfaceElevated,
        child: Text(
          '${number ?? ''}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dot,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

/// Un choix parmi plusieurs, en cartes (motif de refus, défaut, formule).
class OfficineChoice<T> extends StatelessWidget {
  const OfficineChoice({
    super.key,
    required this.value,
    required this.group,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final T value;
  final T? group;
  final ValueChanged<T> onChanged;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.accentPrimary : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? AppColors.accentPrimary
                      : AppColors.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bloc d'information en pied d'écran : beige avec un (i) par défaut,
/// ou l'encadré coloré de Pokou quand il faut attirer l'œil.
class OfficineNote extends StatelessWidget {
  const OfficineNote(this.text, {super.key, this.tone});

  final String text;
  final CalloutTone? tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: tone != null
        ? ModuleCallout(tone: tone!, text: text)
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}

/// L'espacement entre deux cartes.
const officineGap = SizedBox(height: 12);
