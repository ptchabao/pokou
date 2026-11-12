import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/pokou_illustration.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';

// Les pièces de l'onglet Kory (kory_screen.dart) : le bloc du mois, la
// recherche, les filtres, le carrousel « À la une », les états d'attente.
//
// Tout est PLAT : des surfaces à filet ou des aplats pastel, jamais d'ombre.
// Les couleurs viennent de `AppColors` — elles suivent le mode sombre.

/// L'allure d'une collecte selon sa nature : la teinte de sa vignette,
/// l'encre posée dessus, et la scène de sa carte « À la une ».
///
/// Kory n'a pas de photo par cagnotte : la carte porte une illustration de
/// la marque sur un aplat pastel, jamais une fausse photo.
class KoryKindLook {
  const KoryKindLook({
    required this.tint,
    required this.ink,
    required this.sceneTint,
    required this.scene,
  });

  /// L'aplat de la vignette — il suit le mode sombre.
  final Color tint;
  final Color ink;

  /// L'aplat derrière l'illustration. Il reste CLAIR en mode sombre : les
  /// scènes sont dessinées au trait ébène, qui disparaîtrait sur un fond
  /// foncé — une illustration se traite comme une photo, pas comme un fond.
  final Color sceneTint;
  final PokouIllustrations scene;

  factory KoryKindLook.of(KoryPot pot) {
    final dark = AppColors.isDark;
    if (pot.isTontine) {
      return KoryKindLook(
        tint: AppColors.feedbackSuccess.withValues(alpha: dark ? 0.24 : 0.12),
        ink: dark ? AppColors.textPrimary : AppColors.feedbackSuccess,
        sceneTint: Color.alphaBlend(
          AppColors.feedbackSuccess.withValues(alpha: 0.12),
          AppColors.neutralCreme,
        ),
        scene: PokouIllustrations.group,
      );
    }
    if (pot.isCotisation) {
      return KoryKindLook(
        tint: AppColors.brandOr.withValues(alpha: dark ? 0.20 : 0.22),
        ink: AppColors.securityWarning,
        sceneTint: Color.alphaBlend(
          AppColors.brandOr.withValues(alpha: 0.22),
          AppColors.neutralCreme,
        ),
        scene: PokouIllustrations.payment,
      );
    }
    return KoryKindLook(
      tint: AppColors.terracottaTint,
      ink: AppColors.onTerracottaTint,
      sceneTint: AppColors.brandTerracotta100,
      scene: PokouIllustrations.kory,
    );
  }
}

String koryKindLabel(L l, KoryPot pot) => pot.isTontine
    ? l.koryKindTontine
    : pot.isCotisation
    ? l.koryKindCotisation
    : l.koryKindCagnotte;

/// Le tour en cours d'une tontine, s'il y en a un.
KoryRound? koryCurrentRound(KoryPot pot) {
  if (!pot.isTontine || pot.rounds.isEmpty) return null;
  final current = pot.currentRound;
  if (current != null && current > 0 && current <= pot.rounds.length) {
    return pot.rounds[current - 1];
  }
  return pot.rounds.first;
}

/// Ce qu'une carte chiffre : le réuni, la cible, et l'avancement.
///
/// Une cagnotte avance vers son objectif ; une tontine, vers la somme
/// attendue pour le tour en cours. Sans cible, pas de barre.
class KoryPotFigures {
  const KoryPotFigures({required this.amount, this.target, this.value});

  final int amount;
  final int? target;
  final double? value;

  int? get percent => value == null ? null : (value! * 100).round();

  factory KoryPotFigures.of(KoryPot pot) {
    final round = koryCurrentRound(pot);
    if (round != null && round.expectedTotal > 0) {
      return KoryPotFigures(
        amount: round.confirmedTotal,
        target: round.expectedTotal,
        value: (round.confirmedTotal / round.expectedTotal)
            .clamp(0, 1)
            .toDouble(),
      );
    }
    return KoryPotFigures(
      amount: pot.confirmedTotal,
      target: pot.progress == null ? null : pot.goalAmount,
      value: pot.progress,
    );
  }
}

/// Les jours qui restent avant l'échéance : `null` sans échéance, négatif
/// une fois la date passée. L'heure du serveur prime sur celle du téléphone.
int? koryDaysLeft(KoryPot pot) {
  final due = pot.dueAt;
  if (due == null) return null;
  final now = pot.serverNow ?? DateTime.now();
  if (pot.isDue || due.isBefore(now)) return -1;
  return due.difference(now).inDays;
}

/// Les filtres de la liste : la nature d'une collecte, puis son état — ce
/// que le modèle distingue réellement, rien de plus.
enum KoryHomeFilter {
  all,
  cagnottes,
  cotisations,
  tontines,
  open,
  closed;

  bool matches(KoryPot pot) => switch (this) {
    KoryHomeFilter.all => true,
    KoryHomeFilter.cagnottes => !pot.isTontine && !pot.isCotisation,
    KoryHomeFilter.cotisations => pot.isCotisation,
    KoryHomeFilter.tontines => pot.isTontine,
    KoryHomeFilter.open => pot.isOpen,
    KoryHomeFilter.closed => !pot.isOpen,
  };

  String label(L l) => switch (this) {
    KoryHomeFilter.all => l.koryHomeFilterAll,
    KoryHomeFilter.cagnottes => l.koryHomeFilterCagnottes,
    KoryHomeFilter.cotisations => l.koryHomeFilterCotisations,
    KoryHomeFilter.tontines => l.koryHomeFilterTontines,
    KoryHomeFilter.open => l.koryHomeFilterOpen,
    KoryHomeFilter.closed => l.koryHomeFilterClosed,
  };
}

// ── Le bloc du mois ──────────────────────────────────────────────────────

/// L'encadré de tête : mes contributions confirmées du mois en grand, et à
/// droite le geste principal — ouvrir une nouvelle cagnotte.
///
/// Ce n'est PAS un solde : Pokou ne détient rien (BM-01). Le libellé le dit,
/// et le chiffre vient tel quel du serveur.
class KoryHomeHero extends StatelessWidget {
  const KoryHomeHero({
    super.key,
    required this.monthTotal,
    required this.monthLoading,
    required this.activeCount,
    required this.statsLoading,
    required this.collectedTotal,
    required this.onCreate,
    required this.onJoin,
    this.onJournal,
  });

  /// `null` tant que le résumé n'est pas arrivé, ou s'il est indisponible.
  final int? monthTotal;

  /// Le résumé est en route : le chiffre attend en gris. Indisponible, il
  /// laisse un tiret — jamais un zéro que le serveur n'a pas dit.
  final bool monthLoading;

  /// `null` tant que les cagnottes ne sont pas arrivées (ou indisponibles).
  final int? activeCount;

  /// Les cagnottes sont en route : la ligne des chiffres attend en gris.
  final bool statsLoading;

  /// Le confirmé réuni dans mes cagnottes ouvertes.
  final int collectedTotal;

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  /// Absent quand il n'y a aucun journal à ouvrir.
  final VoidCallback? onJournal;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.balance,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.koryMonthTotal,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: monthTotal == null && monthLoading
                    ? const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SkeletonPulse(
                          child: SkeletonBox(
                            width: 132,
                            height: 34,
                            radius: 10,
                          ),
                        ),
                      )
                    : _HeroAmount(amount: monthTotal),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 0,
                child: _HeroCreateButton(
                  label: l.koryHomeNewPot,
                  onPressed: onCreate,
                ),
              ),
            ],
          ),
          if (activeCount != null || statsLoading) const SizedBox(height: 10),
          if (activeCount == null) ...[
            if (statsLoading)
              const SkeletonPulse(child: SkeletonBox(width: 190, height: 14)),
          ] else
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _HeroStat(
                  icon: Icons.circle,
                  iconSize: 8,
                  iconColor: activeCount! > 0
                      ? AppColors.feedbackSuccess
                      : AppColors.textMuted,
                  label: l.koryHomeActivePots(activeCount!),
                ),
                if (collectedTotal > 0)
                  _HeroStat(
                    icon: Icons.savings_outlined,
                    iconSize: 15,
                    iconColor: AppColors.accentPrimaryDark,
                    label: l.koryHomeCollected(formatFcfa(collectedTotal)),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
          Row(
            children: [
              Expanded(
                child: _HeroAction(
                  icon: Icons.key_outlined,
                  label: l.koryJoin,
                  tooltip: l.koryJoinTitle,
                  onPressed: onJoin,
                ),
              ),
              if (onJournal != null) ...[
                Container(width: 1, height: 20, color: AppColors.border),
                Expanded(
                  child: _HeroAction(
                    icon: Icons.receipt_long_outlined,
                    label: l.koryJournalTab,
                    tooltip: l.koryJournal,
                    onPressed: onJournal!,
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

/// « 15 000 FCFA » : le chiffre en grand, la devise en terre cuite. Un très
/// gros montant rétrécit plutôt que de déborder ou de se couper.
class _HeroAmount extends StatelessWidget {
  const _HeroAmount({required this.amount});

  /// `null` : le montant n'est pas connu.
  final int? amount;

  @override
  Widget build(BuildContext context) {
    final amount = this.amount;
    if (amount == null) {
      return Text(
        '—',
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      );
    }
    // Le montant sort avec des espaces insécables (fines entre les milliers),
    // que la police des titres ne dessine pas : on les remet en espaces
    // ordinaires, et l'on sépare le chiffre de sa devise.
    final text = formatFcfa(amount).replaceAll(RegExp('[\u00A0\u202F]'), ' ');
    final split = text.lastIndexOf(' ');
    final figure = split > 0 ? text.substring(0, split) : text;
    final currency = split > 0 ? text.substring(split + 1) : '';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: figure,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 34,
                height: 1.15,
                letterSpacing: -0.6,
                wordSpacing: -3,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (currency.isNotEmpty)
              TextSpan(
                text: ' $currency',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPrimaryDark,
                ),
              ),
          ],
        ),
        maxLines: 1,
        // Un montant se lit de gauche à droite dans toutes les langues :
        // sans cela, l'arabe retournerait « 15 000 » en « 000 15 ».
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

class _HeroCreateButton extends StatelessWidget {
  const _HeroCreateButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.actionButtonBackground,
      foregroundColor: AppColors.actionButtonForeground,
      minimumSize: const Size(0, 46),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
      shape: const StadiumBorder(),
      elevation: 0,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_forward, size: 18),
      ],
    ),
  );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.accentPrimaryDark),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );
}

// ── Recherche et filtres ─────────────────────────────────────────────────

/// La recherche en pilule, la loupe à droite. Elle filtre la liste sur
/// place, par nom : rien ne part au serveur.
class KoryHomeSearchField extends StatelessWidget {
  const KoryHomeSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Expanded(
              child: TextField(
                contextMenuBuilder: pokouContextMenuBuilder,
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                cursorColor: AppColors.accentPrimary,
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: l.koryHomeSearchHint,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                  ),
                  filled: false,
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (controller.text.isEmpty)
              ExcludeSemantics(
                child: SizedBox(
                  width: 52,
                  height: 48,
                  child: Icon(Icons.search, color: AppColors.textMuted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: IconButton(
                  tooltip: l.koryHomeSearchClear,
                  onPressed: onClear,
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Les filtres en pilules, qui défilent à l'horizontale. Celui qui est
/// actif est plein ; les autres, à filet.
class KoryHomeFilterBar extends StatelessWidget {
  const KoryHomeFilterBar({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<KoryHomeFilter> filters;
  final KoryHomeFilter selected;
  final ValueChanged<KoryHomeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (i, filter) in filters.indexed)
            Padding(
              padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 8),
              child: _FilterPill(
                label: filter.label(l),
                active: filter == selected,
                onTap: () => onSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    child: Material(
      // L'encre de l'app, inversée : ébène en clair, crème en sombre.
      color: active ? AppColors.textPrimary : AppColors.surface,
      shape: StadiumBorder(
        side: active ? BorderSide.none : BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.background : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Titres, barre d'avancement, boutons ──────────────────────────────────

class KoryHomeSectionTitle extends StatelessWidget {
  const KoryHomeSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 26, 20, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              height: 1.3,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ],
    ),
  );
}

/// La barre d'avancement : pleine largeur, bouts ronds. Le pourcentage est
/// toujours écrit à côté — la barre seule ne dit rien à un lecteur d'écran.
class KoryProgressBar extends StatelessWidget {
  const KoryProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.muted = false,
  });

  final double value;
  final double height;

  /// Une collecte clôturée : la barre reste, sans la couleur d'action.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 1).toDouble();
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: AlignmentDirectional.centerStart,
        child: clamped <= 0
            ? null
            : FractionallySizedBox(
                // Un début d'avancement reste visible : au moins un point rond.
                widthFactor: clamped < 0.04 ? 0.04 : clamped,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: muted
                        ? AppColors.textMuted.withValues(alpha: 0.45)
                        : null,
                    gradient: muted ? null : AppGradients.progress,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Le bouton en pastille des cartes et des états : plein pour le geste
/// attendu, discret pour le reste. Cible d'au moins 44 points.
class KoryHomePillButton extends StatelessWidget {
  const KoryHomePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.quiet = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool quiet;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: quiet
          ? AppColors.surfaceElevated
          : AppColors.actionButtonBackground,
      foregroundColor: quiet
          ? AppColors.textPrimary
          : AppColors.actionButtonForeground,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: const StadiumBorder(),
      elevation: 0,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

// ── « À la une » ─────────────────────────────────────────────────────────

/// Une carte du carrousel : la scène sur son aplat pastel, l'échéance en
/// pastille par-dessus, puis le titre et l'avancement.
class KoryFeaturedCard extends StatelessWidget {
  const KoryFeaturedCard({super.key, required this.pot, required this.onTap});

  final KoryPot pot;
  final VoidCallback onTap;

  static const double width = 264;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final look = KoryKindLook.of(pot);
    final figures = KoryPotFigures.of(pot);
    final days = koryDaysLeft(pot);
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 124,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: look.sceneTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(top: 14),
                      child: PokouIllustration(look.scene, height: 104),
                    ),
                    if (days != null)
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: _DeadlineBadge(days: days),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              koryKindLabel(l, pot).toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.7,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentPrimaryDark,
                              ),
                            ),
                          ),
                          if (figures.percent != null)
                            Text(
                              l.koryHomePercent('${figures.percent}'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pot.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (figures.value != null) ...[
                        KoryProgressBar(value: figures.value!),
                        const SizedBox(height: 8),
                      ],
                      KoryFiguresLine(figures: figures),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « 69 000 FCFA sur 150 000 FCFA » ; sans cible, ce que le chiffre est.
class KoryFiguresLine extends StatelessWidget {
  const KoryFiguresLine({super.key, required this.figures});

  final KoryPotFigures figures;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final target = figures.target;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatFcfa(figures.amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(
            text: target == null
                ? ' · ${l.koryTotalConfirmed}'
                : ' ${l.koryOnGoal(formatFcfa(target))}',
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    );
  }
}

/// « 5 jours restants », posé sur la scène. Une icône ET un libellé : le
/// rouge des trois derniers jours ne porte pas le sens à lui seul.
class _DeadlineBadge extends StatelessWidget {
  const _DeadlineBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final urgent = days <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            days < 0 ? Icons.event_busy_outlined : Icons.schedule,
            size: 14,
            color: urgent
                ? AppColors.securityCritical
                : AppColors.accentPrimaryDark,
          ),
          const SizedBox(width: 5),
          Text(
            days < 0 ? l.koryHomeOverdue : l.koryHomeDaysLeft(days),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── États : attente, vide, erreur ────────────────────────────────────────

/// Une scène, un titre, une phrase, et l'action qui sort de l'impasse.
class KoryHomeMessage extends StatelessWidget {
  const KoryHomeMessage({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.actions = const [],
    this.illustrationHeight = 150,
  });

  final PokouIllustrations illustration;
  final String title;
  final String message;
  final List<Widget> actions;
  final double illustrationHeight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Les scènes sont dessinées au trait ébène : en sombre, elles
        // reposent sur une plaque claire au lieu de se fondre dans le fond.
        if (AppColors.isDark)
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            decoration: BoxDecoration(
              color: AppColors.neutralBeige,
              borderRadius: BorderRadius.circular(28),
            ),
            child: PokouIllustration(
              illustration,
              height: illustrationHeight - 22,
            ),
          )
        else
          PokouIllustration(illustration, height: illustrationHeight),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            height: 1.3,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: actions,
          ),
        ],
      ],
    ),
  );
}

/// L'attente, à la forme de ce qui arrive : la recherche, des pilules, deux
/// cartes « À la une », puis des cartes de cagnotte — une vignette, deux
/// lignes, une barre, un bouton. Une seule pulsation pour le tout.
class KoryHomeSkeleton extends StatelessWidget {
  const KoryHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: SkeletonBox(width: double.infinity, height: 52, radius: 26),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (i, width) in const [84.0, 108.0, 116.0, 96.0].indexed)
                Padding(
                  padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 8),
                  child: SkeletonBox(width: width, height: 44, radius: 22),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20, 30, 20, 16),
          child: SkeletonBox(width: 96, height: 18),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            children: [
              _FeaturedSkeleton(),
              SizedBox(width: 12),
              _FeaturedSkeleton(),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20, 30, 20, 16),
          child: SkeletonBox(width: 132, height: 18),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _PotCardSkeleton(titleWidth: 150),
              SizedBox(height: 12),
              _PotCardSkeleton(titleWidth: 118),
              SizedBox(height: 12),
              _PotCardSkeleton(titleWidth: 172),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SkeletonSurface extends StatelessWidget {
  const _SkeletonSurface({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _FeaturedSkeleton extends StatelessWidget {
  const _FeaturedSkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: KoryFeaturedCard.width,
    child: _SkeletonSurface(
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: double.infinity, height: 124, radius: 12),
          Padding(
            padding: EdgeInsets.fromLTRB(6, 14, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 70, height: 10),
                SizedBox(height: 8),
                SkeletonBox(width: 160, height: 15),
                SizedBox(height: 14),
                SkeletonBox(width: double.infinity, height: 8, radius: 4),
                SizedBox(height: 10),
                SkeletonBox(width: 130, height: 12),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PotCardSkeleton extends StatelessWidget {
  const _PotCardSkeleton({required this.titleWidth});

  final double titleWidth;

  @override
  Widget build(BuildContext context) => _SkeletonSurface(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SkeletonBox(width: 52, height: 52, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: titleWidth, height: 15),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 104, height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonBox(width: double.infinity, height: 8, radius: 4),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 110, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 150, height: 11),
                ],
              ),
            ),
            SkeletonBox(width: 112, height: 44, radius: 22),
          ],
        ),
      ],
    ),
  );
}
