import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Les illustrations de Pokou : des scènes unDraw (licence libre, sans
/// attribution) recolorées aux couleurs de la marque — terre cuite, or,
/// crème — avec des personnages à la peau brune, qui ressemblent aux gens
/// qui utilisent l'app. Elles remplacent les icônes grises des écrans vides,
/// d'erreur et d'accueil : un écran vide doit donner envie, pas constater.
enum PokouIllustrations {
  welcome,
  discussionsEmpty('discussions_empty'),
  group,
  contactsEmpty('contacts_empty'),
  kory,
  payment,
  honam,
  delivery,
  assime,
  market,
  certified,
  security,
  backup,
  calls,
  notificationsEmpty('notifications_empty'),
  searchEmpty('search_empty'),
  allClear('all_clear'),
  team,
  offline;

  const PokouIllustrations([this._file]);

  final String? _file;

  String get asset => 'assets/illustrations/${_file ?? name}.svg';
}

class PokouIllustration extends StatelessWidget {
  const PokouIllustration(this.illustration, {super.key, this.height = 160});

  final PokouIllustrations illustration;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        illustration.asset,
        height: height,
        fit: BoxFit.contain,
        // Un SVG absent (test, asset oublié) ne doit jamais casser l'écran.
        placeholderBuilder: (_) => SizedBox(height: height),
      ),
    );
  }
}
