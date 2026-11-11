import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Le menu contextuel des champs de saisie, avec « Coller » TOUJOURS
/// proposé quand le champ est modifiable.
///
/// Flutter n'ajoute « Coller » que si son indicateur de presse-papiers dit
/// « texte présent ». Cet indicateur ne se met à jour qu'au retour de
/// l'application au premier plan : un texte copié DANS Pokou (bouton
/// « Copier » d'un message) ne le faisait pas changer, et le menu du champ
/// n'offrait jamais « Coller ». Ici, « Coller » lit le presse-papiers au
/// moment du geste ; s'il est vide, rien ne se passe.
Widget pokouContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  final items = List<ContextMenuButtonItem>.of(
    editableTextState.contextMenuButtonItems,
  );
  final editable = !editableTextState.widget.readOnly;
  if (editable && !items.any((i) => i.type == ContextMenuButtonType.paste)) {
    // Après « Copier » / « Couper », comme le menu du système.
    final after = items.lastIndexWhere(
      (i) =>
          i.type == ContextMenuButtonType.copy ||
          i.type == ContextMenuButtonType.cut,
    );
    items.insert(
      after + 1,
      ContextMenuButtonItem(
        type: ContextMenuButtonType.paste,
        onPressed: () =>
            editableTextState.pasteText(SelectionChangedCause.toolbar),
      ),
    );
  }
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}

/// Vrai si le presse-papiers contient du texte — lu à la demande, pas dans
/// l'indicateur de Flutter (voir ci-dessus).
Future<bool> clipboardHasText() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  return (data?.text ?? '').isNotEmpty;
}
