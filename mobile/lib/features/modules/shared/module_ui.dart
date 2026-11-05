import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_back_button.dart';

/// Le vocabulaire visuel des écrans de module.
///
/// Écrit une fois plutôt que cinq, et surtout **emprunté au reste de
/// l'application plutôt qu'inventé** : la surface blanche à filet, le vert
/// d'action, la pastille colorée, la puce de sélection de la Marketplace.
/// Cinq écrans avec cinq langages se liraient comme cinq applications
/// collées ensemble.
///
/// La règle que ce fichier fait respecter tient en une phrase : **la couleur
/// d'un module ne vit que dans sa pastille d'icône**. Les verbes — activer,
/// payer, publier — portent tous le vert de Pokou. Un bouton par teinte
/// apprendrait à l'utilisateur que la couleur ne veut rien dire, et la
/// pastille cesserait alors d'identifier quoi que ce soit.

/// L'ossature d'un écran de module : en-tête, puis contenu.
///
/// Pas d'`AppBar` Material : le reste de l'application dessine ses en-têtes
/// à la main (voir `ScreenHeader`), avec un bouton retour adouci et un
/// sous-titre qui dit à quoi sert la page. Une barre Material ici trancherait
/// au premier coup d'œil.
class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
              child: Row(
                children: [
                  const PokouBackButton(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
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
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Carte à filet, avec couleur personnalisable pour les résumés accentués.
class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.subtle,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: AppRadius.card, child: card),
    );
  }
}

/// La pastille d'icône utilise le couple action/texte de la palette Pokou.
///
/// Elle ne porte plus la couleur du module : une teinte par module donnait à
/// une liste l'allure d'un nuancier, où plus aucune couleur ne signifiait
/// quoi que ce soit. C'est l'icône qui identifie, pas la teinte.
class ModuleBadge extends StatelessWidget {
  const ModuleBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.muted = false,
  });

  final IconData icon;

  /// Conservée pour les rares endroits où la couleur d'un module dit encore
  /// quelque chose — une barre d'avancement, par exemple. La pastille, elle,
  /// ne s'en sert plus.
  final Color color;

  final double size;

  /// Une pastille éteinte : l'élément existe mais n'appelle à rien. Elle perd
  /// sa couleur au lieu de changer de forme, pour que l'œil trie la liste
  /// sans la lire.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: muted
            ? AppColors.surfaceElevated
            : AppColors.actionButtonBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        color: muted ? AppColors.textMuted : AppColors.actionButtonForeground,
        size: size * 0.5,
      ),
    );
  }
}

/// Le verbe. Toujours vert, sur tous les écrans, pour toutes les actions.
class ModuleActionButton extends StatelessWidget {
  const ModuleActionButton({
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
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.actionButtonBackground,
      foregroundColor: AppColors.actionButtonForeground,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
    final child = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.actionButtonForeground,
            ),
          )
        : Text(label);

    final button = icon == null || busy
        ? FilledButton(
            onPressed: busy ? null : onPressed,
            style: style,
            child: child,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// L'action de retrait — refuser, clôturer, fermer.
///
/// Elle n'est pas verte : un retrait et une adhésion qui se ressemblent se
/// confondent au moment précis où l'on appuie vite.
class ModuleQuietButton extends StatelessWidget {
  const ModuleQuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      child: Text(label),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Le sélecteur de vue — les puces de la Marketplace, pas des onglets
/// Material.
///
/// L'application n'utilise d'onglets nulle part ailleurs ; en poser ici
/// aurait introduit un composant de navigation de plus, avec sa propre
/// animation et son propre soulignement, pour un choix entre deux listes.
class ModuleSegmented extends StatelessWidget {
  const ModuleSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, position) {
          final selected = position == index;
          return ChoiceChip(
            label: Text(labels[position]),
            selected: selected,
            showCheckmark: false,
            backgroundColor: AppColors.surfaceElevated,
            selectedColor: AppColors.accentPrimaryLight,
            side: BorderSide(
              color: selected ? AppColors.accentPrimaryDark : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            onSelected: (_) => onChanged(position),
          );
        },
      ),
    );
  }
}

/// L'état vide, dit une fois pour les cinq.
///
/// Même forme que la galerie des modules : une icône éteinte, un titre, une
/// phrase. L'icône reste grise — un état vide n'est pas un endroit où attirer
/// l'œil avec de la couleur.
class ModuleEmptyState extends StatelessWidget {
  const ModuleEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Le titre d'une section dans une liste.
class ModuleSectionTitle extends StatelessWidget {
  const ModuleSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une barre d'avancement.
///
/// L'un des deux seuls endroits, avec la pastille, où la couleur d'un module
/// est admise : ici elle ne décore pas, elle DIT où l'on en est. Quand
/// l'objectif est atteint, elle passe au vert de l'application — la couleur
/// du succès y est la même partout.
class ModuleProgressBar extends StatelessWidget {
  const ModuleProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.done = false,
    this.height = 8,
  });

  final double value;
  final Color color;
  final bool done;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: AppColors.surfaceElevated,
        valueColor: AlwaysStoppedAnimation(
          done ? AppColors.accentPrimary : color,
        ),
      ),
    );
  }
}

/// La feuille du bas, toujours dessinée de la même façon.
///
/// Elle remonte avec le clavier (`viewInsets`) : sans cela, le champ que
/// l'on vient de toucher disparaît derrière le clavier, et c'est le défaut
/// le plus visible d'un formulaire en feuille.
Future<T?> showModuleSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: builder(sheetContext),
      ),
    ),
  );
}

/// Le titre d'une feuille.
class ModuleSheetTitle extends StatelessWidget {
  const ModuleSheetTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}

/// Un choix de montant.
///
/// Des puces plutôt qu'un champ libre : taper un nombre demande un clavier,
/// une décision et une validation, là où le geste attendu est « celui-là ».
/// Le champ libre reste disponible là où le montant est vraiment libre.
class ModuleAmountPicker extends StatelessWidget {
  const ModuleAmountPicker({
    super.key,
    required this.amounts,
    required this.selected,
    required this.onChanged,
  });

  final List<int> amounts;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final amount in amounts)
          ChoiceChip(
            label: Text('$amount F'),
            selected: amount == selected,
            showCheckmark: false,
            backgroundColor: AppColors.surfaceElevated,
            selectedColor: AppColors.accentPrimaryLight,
            side: BorderSide(
              color: amount == selected
                  ? AppColors.accentPrimaryDark
                  : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            labelStyle: TextStyle(
              color: amount == selected
                  ? Colors.white
                  : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: amount == selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
            onSelected: (_) => onChanged(amount),
          ),
      ],
    );
  }
}
