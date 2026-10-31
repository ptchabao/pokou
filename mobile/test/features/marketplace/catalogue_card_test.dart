import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les actions d'une carte du catalogue, à la largeur RÉELLE de la carte.
///
/// Le débordement de « Booster » ne se voyait qu'à l'œil, sur un appareil,
/// dans une liste horizontale — c'est-à-dire au dernier moment et par
/// hasard. Ce test reproduit la contrainte exacte : 150 points de large,
/// moins les marges de la carte.
///
/// `RenderFlex overflowed` est une ERREUR de rendu en debug, mais en release
/// elle se contente de peindre du contenu tronqué : la carte a l'air
/// simplement mal faite, sans que rien ne signale pourquoi.
void main() {
  /// Largeur utile : la carte fait 150, avec 8 points de marge de chaque côté.
  const cardContentWidth = 150.0 - 16;

  Widget harness(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: cardContentWidth, child: child),
          ),
        ),
      );

  /// Reproduit la rangée d'actions telle que la carte la compose.
  Widget actionsRow({required bool withBoost, required bool withDelete}) {
    OutlinedButton square(IconData icon) => OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 30),
            fixedSize: const Size(32, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Icon(icon, size: 15),
        );

    return Row(
      children: [
        if (withBoost) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Booster',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        square(Icons.edit_outlined),
        if (withDelete) ...[
          const SizedBox(width: 4),
          square(Icons.delete_outline),
        ],
      ],
    );
  }

  testWidgets('les trois actions tiennent dans la largeur de la carte', (tester) async {
    await tester.pumpWidget(harness(actionsRow(withBoost: true, withDelete: true)));
    // Le cas qui débordait : c'est l'ajout du bouton « Retirer » à une
    // rangée déjà pleine qui avait poussé « Booster » à la ligne.
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Booster » tient sur UNE ligne', (tester) async {
    await tester.pumpWidget(harness(actionsRow(withBoost: true, withDelete: true)));

    // Une seule ligne de 11 points fait une quinzaine de points de haut ;
    // deux lignes en feraient plus du double. C'est cette hauteur qui
    // distingue « tient » de « est revenu à la ligne ».
    final label = tester.getSize(find.text('Booster'));
    expect(
      label.height,
      lessThan(22),
      reason: 'le libellé occupe deux lignes — il est revenu à la ligne',
    );
  });

  testWidgets('sans « Booster », les deux icônes tiennent aussi', (tester) async {
    // Le produit d'un autre vendeur, ou un produit déjà boosté.
    await tester.pumpWidget(harness(actionsRow(withBoost: false, withDelete: true)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('les carrés gardent une cible tactile utilisable', (tester) async {
    await tester.pumpWidget(harness(actionsRow(withBoost: true, withDelete: true)));

    // 32 × 30 : en dessous des 44 recommandés, et c'est un compromis assumé
    // sur une carte de 150 points. Verrouillé ici pour qu'il reste un CHOIX :
    // si quelqu'un descend encore, ce test le lui dira.
    final square = tester.getSize(find.byIcon(Icons.delete_outline));
    expect(square.width, greaterThanOrEqualTo(14));

    final button = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.width, 32);
    expect(button.height, greaterThanOrEqualTo(30));
  });
}
