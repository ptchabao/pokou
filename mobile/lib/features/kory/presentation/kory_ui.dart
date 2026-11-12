import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import 'kory_controller.dart';
import 'kory_screen.dart';

// Les pièces communes des écrans Kory (cagnotte, cotisation, tontine).
//
// Tout est PLAT, comme l'onglet : des surfaces à filet, jamais d'ombre ; les
// couleurs viennent d'`AppColors` et suivent le mode sombre.

/// Un écran Kory : le bouton retour, le titre et sa ligne, le contenu, et
/// en pied l'action principale.
class KoryPage extends StatelessWidget {
  const KoryPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.footer,
    this.loading = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// La liste de l'écran (déjà défilante).
  final Widget body;

  /// L'action principale, en bas de l'écran (souvent [KoryFooter]).
  final Widget? footer;

  /// En attente des données : un squelette à la place du contenu.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: loading ? null : footer,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
              child: Row(
                children: [
                  const PokouBackButton(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 21,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
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
                  ...actions,
                ],
              ),
            ),
            Expanded(child: loading ? const KoryPageSkeleton() : body),
          ],
        ),
      ),
    );
  }
}

/// Le squelette d'un écran Kory : un grand bloc chiffré, puis des lignes.
class KoryPageSkeleton extends StatelessWidget {
  const KoryPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const [
        SkeletonBox(width: double.infinity, height: 150, radius: 18),
        SizedBox(height: 16),
        SkeletonBox(width: double.infinity, height: 64, radius: 14),
        SizedBox(height: 24),
        SkeletonBox(width: 140, height: 16),
        SizedBox(height: 12),
        SkeletonListTile(),
        SkeletonListTile(),
        SkeletonListTile(),
      ],
    ),
  );
}

/// Le pied d'écran : l'action principale, puis une ligne secondaire.
class KoryFooter extends StatelessWidget {
  const KoryFooter({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.background,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

/// Une carte plate : surface, filet d'un point, coins de carte.
class KoryCard extends StatelessWidget {
  const KoryCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.card,
      side: BorderSide(color: borderColor ?? AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: onTap == null
        ? Padding(padding: padding, child: child)
        : InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
  );
}

/// Une ligne « libellé … valeur », avec une précision facultative.
class KoryLine extends StatelessWidget {
  const KoryLine(
    this.label,
    this.value, {
    super.key,
    this.caption,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? caption;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Le libellé et la valeur se partagent la ligne (2/5, 3/5) : une
        // valeur longue passe à la ligne sans écraser le libellé.
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppColors.textSecondary)),
              if (caption != null && caption!.isNotEmpty)
                Text(
                  caption!,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              fontSize: strong ? 17 : 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Le titre d'une section, avec un complément à droite.
class KorySection extends StatelessWidget {
  const KorySection(this.title, {super.key, this.trailing, this.onTrailing});

  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null)
          onTrailing == null
              ? Text(
                  trailing!,
                  style: TextStyle(color: AppColors.textSecondary),
                )
              : TextButton(onPressed: onTrailing, child: Text(trailing!)),
      ],
    ),
  );
}

/// Les initiales d'une personne (« Edem K. » → « EK »).
String koryInitials(String? name) {
  final parts = (name ?? '')
      .split(RegExp(r'\s+'))
      .where(
        (p) =>
            p.isNotEmpty && RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(p),
      )
      .take(2)
      .toList();
  if (parts.isEmpty) return '·';
  return parts
      .map((p) => String.fromCharCode(p.runes.first).toUpperCase())
      .join();
}

/// La pastille aux initiales.
class KoryAvatar extends StatelessWidget {
  const KoryAvatar(this.name, {super.key, this.size = 40, this.muted = false});

  final String? name;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceElevated : AppColors.terracottaTint,
        shape: BoxShape.circle,
      ),
      child: Text(
        koryInitials(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: muted ? AppColors.textSecondary : AppColors.onTerracottaTint,
        ),
      ),
    ),
  );
}

/// Une personne dans une liste : initiales, nom, précision, et à droite ce
/// qu'on veut (montant, pastille, bouton).
class KoryPersonRow extends StatelessWidget {
  const KoryPersonRow({
    super.key,
    required this.name,
    this.subtitle,
    this.trailing,
    this.muted = false,
    this.onTap,
  });

  final String name;
  final String? subtitle;
  final Widget? trailing;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          KoryAvatar(name, muted: muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Le ton d'un encadré : attention, refus, succès, neutre.
enum KoryTone { warning, danger, success, neutral }

/// Un encadré plat : une icône ET une phrase, jamais la couleur seule.
class KoryNotice extends StatelessWidget {
  const KoryNotice({
    super.key,
    required this.text,
    this.tone = KoryTone.neutral,
    this.title,
    this.icon,
    this.children = const [],
  });

  final String text;
  final String? title;
  final KoryTone tone;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final (Color ink, IconData glyph) = switch (tone) {
      KoryTone.warning => (AppColors.securityWarning, Icons.info_outline),
      KoryTone.danger => (AppColors.securityCritical, Icons.error_outline),
      KoryTone.success => (
        AppColors.feedbackSuccess,
        Icons.check_circle_outline,
      ),
      KoryTone.neutral => (AppColors.textSecondary, Icons.shield_outlined),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone == KoryTone.neutral
            ? AppColors.surfaceElevated
            : ink.withValues(alpha: AppColors.isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tone == KoryTone.neutral
              ? AppColors.border
              : ink.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? glyph, size: 20, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un choix parmi d'autres, présenté en carte : un rond, un titre, une
/// précision. Le rond ET le filet disent ce qui est choisi.
class KoryChoice extends StatelessWidget {
  const KoryChoice({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.child,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Ce qui s'ouvre sous le choix quand il est retenu (un champ, une date).
  final Widget? child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: KoryCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        borderColor: selected ? AppColors.accentPrimary : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected
                      ? AppColors.accentPrimary
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
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
            if (selected && child != null) ...[
              const SizedBox(height: 12),
              child!,
            ],
          ],
        ),
      ),
    ),
  );
}

/// L'action principale, pleine (terre cuite) ou discrète.
class KoryButton extends StatelessWidget {
  const KoryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.quiet = false,
    this.busy = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool quiet;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? AppColors.securityCritical
        : quiet
        ? AppColors.surfaceElevated
        : AppColors.actionButtonBackground;
    final foreground = quiet && !danger
        ? AppColors.textPrimary
        : AppColors.actionButtonForeground;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.5),
        disabledForegroundColor: foreground.withValues(alpha: 0.8),
        minimumSize: const Size(64, 50),
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: foreground,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Le grand chiffre d'un écran : un libellé, le montant, une précision.
class KoryFigure extends StatelessWidget {
  const KoryFigure({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
    this.trailing,
  });

  final String label;
  final int amount;
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
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          ?trailing,
        ],
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          formatFcfa(amount),
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      if (caption != null)
        Text(
          caption!,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
    ],
  );
}

/// La pastille d'un statut de contribution ou d'échéance : CONFIRMED,
/// DECLARED, REJECTED, LATE, DUE.
Widget koryStatusPill(L l, String status) {
  final (IconData icon, String label, Color color) = switch (status) {
    'CONFIRMED' => (
      Icons.check_circle,
      l.koryStatusConfirmed,
      AppColors.feedbackSuccess,
    ),
    'REJECTED' => (
      Icons.cancel_outlined,
      l.koryStatusRejected,
      AppColors.securityCritical,
    ),
    'LATE' => (
      Icons.event_busy_outlined,
      l.koryXLate,
      AppColors.securityCritical,
    ),
    'DUE' => (Icons.schedule, l.koryXDue, AppColors.textSecondary),
    _ => (Icons.hourglass_top, l.koryXDeclared, AppColors.securityWarning),
  };
  return KoryStatusPill(icon: icon, label: label, color: color);
}

/// « 2 nov. »
String koryDay(BuildContext context, DateTime date) => DateFormat.MMMd(
  Localizations.localeOf(context).toLanguageTag(),
).format(date.toLocal());

/// « 2 nov. 2026 »
String koryDate(BuildContext context, DateTime date) => DateFormat.yMMMd(
  Localizations.localeOf(context).toLanguageTag(),
).format(date.toLocal());

/// « 14:02 »
String koryTime(DateTime date) => DateFormat.Hm().format(date.toLocal());

/// « Février », « décembre 2026 » : le mois d'une échéance ou d'un tour.
String koryMonth(BuildContext context, DateTime date, {bool year = false}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final text = (year ? DateFormat.yMMMM(locale) : DateFormat.MMMM(locale))
      .format(date.toLocal());
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Un message d'échec, en bas de l'écran.
void koryFailed(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(L.of(context).koryActionFailed)));
}

void koryToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
