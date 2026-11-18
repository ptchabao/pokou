import 'package:flutter/material.dart';

/// Les feuilles du bas de Pokou.
///
/// `showModalBottomSheet` limite une feuille à 9/16 de l'écran. Une feuille
/// plus longue — l'appui long sur un message en compte une dizaine de
/// lignes — était coupée en bas : ses dernières lignes passaient sous la
/// barre de navigation du téléphone et s'y confondaient, et sur un petit
/// écran on ne pouvait plus les atteindre.
///
/// Ici, une feuille faite d'une colonne d'actions ([scrollable]) prend la
/// hauteur qu'il lui faut, jusqu'à 90 % de l'écran, défile au-delà, et
/// garde toujours une marge au-dessus de la barre système.
Future<T?> showPokouSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollable = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool? isScrollControlled,
  bool? showDragHandle,
  bool isDismissible = true,
  BoxConstraints? constraints,
  Clip? clipBehavior,
}) {
  final screen = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    shape: shape,
    isScrollControlled: scrollable || (isScrollControlled ?? false),
    showDragHandle: showDragHandle,
    isDismissible: isDismissible,
    clipBehavior: clipBehavior,
    constraints:
        constraints ??
        (scrollable ? BoxConstraints(maxHeight: screen * 0.9) : null),
    builder: (sheetContext) {
      final child = builder(sheetContext);
      // La marge de la barre système est posée SOUS la zone utile, et non
      // à la fin du contenu : quand la feuille défile, aucune action ne
      // passe sous la barre de navigation. Le fond de la feuille, lui,
      // descend jusqu'en bas. La marge est retirée pour l'intérieur, qui
      // ne la compte donc pas deux fois (ses `SafeArea` n'ajoutent rien).
      final bottom = MediaQuery.viewPaddingOf(sheetContext).bottom;
      final inner = MediaQuery.removePadding(
        context: sheetContext,
        removeBottom: true,
        child: MediaQuery.removeViewPadding(
          context: sheetContext,
          removeBottom: true,
          child: scrollable ? SingleChildScrollView(child: child) : child,
        ),
      );
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: inner,
      );
    },
  );
}
